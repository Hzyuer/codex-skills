[CmdletBinding()]
param(
    [string]$Root = "C:\",
    [int]$MinSizeMB = 500,
    [int]$StaleDays = 180,
    [int]$MaxChildren = 20,
    [string]$OutputRoot = "$env:USERPROFILE\.codex\reports",
    [switch]$IncludeCsv
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Continue"

$script:Candidates = New-Object System.Collections.Generic.List[object]
$script:Skipped = New-Object System.Collections.Generic.List[object]
$script:Seen = @{}

$MinSizeBytes = [int64]$MinSizeMB * 1MB
$StaleCutoff = (Get-Date).AddDays(-1 * $StaleDays)
$StartedAt = Get-Date

function ConvertTo-DisplaySize {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Add-SkippedPath {
    param(
        [string]$Path,
        [string]$Reason
    )
    $script:Skipped.Add([pscustomobject]@{
        Path = $Path
        Reason = $Reason
    }) | Out-Null
}

function Test-ReparsePoint {
    param([System.IO.FileSystemInfo]$Item)
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Get-ItemSafe {
    param([string]$Path)
    try {
        return Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
    catch {
        Add-SkippedPath -Path $Path -Reason $_.Exception.Message
        return $null
    }
}

function Test-PathSafe {
    param([string]$Path)
    try {
        return Test-Path -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        Add-SkippedPath -Path $Path -Reason $_.Exception.Message
        return $false
    }
}

function Measure-PathSize {
    param([string]$Path)

    $item = Get-ItemSafe -Path $Path
    if ($null -eq $item) {
        return [pscustomobject]@{
            SizeBytes = 0L
            FileCount = 0
            DirectoryCount = 0
            ErrorCount = 1
        }
    }

    if ($item -is [System.IO.FileInfo]) {
        return [pscustomobject]@{
            SizeBytes = [int64]$item.Length
            FileCount = 1
            DirectoryCount = 0
            ErrorCount = 0
        }
    }

    if (Test-ReparsePoint -Item $item) {
        Add-SkippedPath -Path $item.FullName -Reason "Skipped reparse point"
        return [pscustomobject]@{
            SizeBytes = 0L
            FileCount = 0
            DirectoryCount = 0
            ErrorCount = 1
        }
    }

    $size = [int64]0
    $files = 0
    $dirs = 0
    $errors = 0
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($item.FullName)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()

        try {
            $childFiles = Get-ChildItem -LiteralPath $current -Force -File -ErrorAction Stop
            foreach ($file in $childFiles) {
                $size += [int64]$file.Length
                $files++
            }
        }
        catch {
            $errors++
            Add-SkippedPath -Path $current -Reason $_.Exception.Message
        }

        try {
            $childDirs = Get-ChildItem -LiteralPath $current -Force -Directory -ErrorAction Stop
            foreach ($dir in $childDirs) {
                if (Test-ReparsePoint -Item $dir) {
                    Add-SkippedPath -Path $dir.FullName -Reason "Skipped reparse point"
                    continue
                }
                $dirs++
                $stack.Push($dir.FullName)
            }
        }
        catch {
            $errors++
            Add-SkippedPath -Path $current -Reason $_.Exception.Message
        }
    }

    return [pscustomobject]@{
        SizeBytes = $size
        FileCount = $files
        DirectoryCount = $dirs
        ErrorCount = $errors
    }
}

function Get-FirstLevelChildren {
    param(
        [string]$Path,
        [int]$Limit
    )

    $item = Get-ItemSafe -Path $Path
    if ($null -eq $item -or $item -isnot [System.IO.DirectoryInfo]) {
        return @()
    }

    $children = New-Object System.Collections.Generic.List[object]
    try {
        $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
    }
    catch {
        Add-SkippedPath -Path $Path -Reason $_.Exception.Message
        return @()
    }

    foreach ($child in $items) {
        if ($child -is [System.IO.DirectoryInfo] -and (Test-ReparsePoint -Item $child)) {
            Add-SkippedPath -Path $child.FullName -Reason "Skipped reparse point"
            continue
        }
        $measure = Measure-PathSize -Path $child.FullName
        $children.Add([pscustomobject]@{
            Name = $child.Name
            Path = $child.FullName
            Type = if ($child -is [System.IO.DirectoryInfo]) { "Directory" } else { "File" }
            SizeBytes = [int64]$measure.SizeBytes
            Size = ConvertTo-DisplaySize -Bytes ([int64]$measure.SizeBytes)
            LastWriteTime = $child.LastWriteTime
        }) | Out-Null
    }

    return @($children | Sort-Object SizeBytes -Descending | Select-Object -First $Limit)
}

function Add-Candidate {
    param(
        [string]$Category,
        [string]$Path,
        [string]$Reason,
        [string]$SuggestedAction,
        [string]$Confidence = "Conservative",
        [string]$Notes = ""
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $item = Get-ItemSafe -Path $Path
    if ($null -eq $item) { return }

    $canonical = $item.FullName.TrimEnd("\").ToLowerInvariant()
    if ($script:Seen.ContainsKey($canonical)) { return }
    $script:Seen[$canonical] = $true

    $measure = Measure-PathSize -Path $item.FullName
    if ([int64]$measure.SizeBytes -lt $MinSizeBytes) { return }

    $children = @()
    if ($item -is [System.IO.DirectoryInfo]) {
        $children = Get-FirstLevelChildren -Path $item.FullName -Limit $MaxChildren
    }

    $script:Candidates.Add([pscustomobject]@{
        Category = $Category
        Path = $item.FullName
        Type = if ($item -is [System.IO.DirectoryInfo]) { "Directory" } else { "File" }
        SizeBytes = [int64]$measure.SizeBytes
        Size = ConvertTo-DisplaySize -Bytes ([int64]$measure.SizeBytes)
        FileCount = $measure.FileCount
        DirectoryCount = $measure.DirectoryCount
        LastWriteTime = $item.LastWriteTime
        LastAccessTime = $item.LastAccessTime
        Reason = $Reason
        SuggestedAction = $SuggestedAction
        Confidence = $Confidence
        Notes = $Notes
        FirstLevelChildren = $children
    }) | Out-Null
}

function Add-PathPatternCandidates {
    param(
        [string]$Category,
        [string]$Pattern,
        [string]$Reason,
        [string]$SuggestedAction
    )

    try {
        $matches = Get-ChildItem -Path $Pattern -Force -ErrorAction SilentlyContinue
        foreach ($match in $matches) {
            Add-Candidate -Category $Category -Path $match.FullName -Reason $Reason -SuggestedAction $SuggestedAction
        }
    }
    catch {
        Add-SkippedPath -Path $Pattern -Reason $_.Exception.Message
    }
}

function Get-UserRoots {
    $usersRoot = Join-Path $Root "Users"
    if (-not (Test-PathSafe -Path $usersRoot)) { return @() }
    try {
        return @(Get-ChildItem -LiteralPath $usersRoot -Force -Directory -ErrorAction Stop |
            Where-Object { $_.Name -notin @("All Users", "Default", "Default User", "Public") -and -not (Test-ReparsePoint -Item $_) })
    }
    catch {
        Add-SkippedPath -Path $usersRoot -Reason $_.Exception.Message
        return @()
    }
}

function Add-CacheCandidates {
    param([System.IO.DirectoryInfo[]]$UserRoots)

    $systemCachePaths = @(
        @{ Path = (Join-Path $env:WINDIR "Temp"); Reason = "Windows temporary files"; Action = "Review and clear through Storage Sense or Disk Cleanup." },
        @{ Path = (Join-Path $env:WINDIR "SoftwareDistribution\Download"); Reason = "Windows Update download cache"; Action = "Clear through Windows Update cleanup or Storage Sense after updates are healthy." },
        @{ Path = (Join-Path $Root "Windows.old"); Reason = "Previous Windows installation files"; Action = "Remove through Storage Sense or Disk Cleanup only." }
    )

    foreach ($entry in $systemCachePaths) {
        if (Test-PathSafe -Path $entry.Path) {
            Add-Candidate -Category "无痛删除" -Path $entry.Path -Reason $entry.Reason -SuggestedAction $entry.Action
        }
    }

    foreach ($user in $UserRoots) {
        $base = $user.FullName
        $cacheEntries = @(
            @{ Path = "$base\AppData\Local\Temp"; Reason = "User temporary files"; Action = "Close applications, then clear through Windows Settings or a reviewed manual cleanup." },
            @{ Path = "$base\AppData\Local\Microsoft\Windows\INetCache"; Reason = "Windows internet cache"; Action = "Clear through browser or Windows cache settings." },
            @{ Path = "$base\AppData\Local\npm-cache"; Reason = "npm package cache"; Action = "Clear with npm cache tooling after confirming active workflows." },
            @{ Path = "$base\AppData\Roaming\npm-cache"; Reason = "npm package cache"; Action = "Clear with npm cache tooling after confirming active workflows." },
            @{ Path = "$base\AppData\Local\Yarn\Cache"; Reason = "Yarn package cache"; Action = "Clear with yarn cache tooling after confirming active workflows." },
            @{ Path = "$base\AppData\Local\pnpm-store"; Reason = "pnpm package store"; Action = "Prune or clear with pnpm tooling after confirming active workflows." },
            @{ Path = "$base\.pnpm-store"; Reason = "pnpm package store"; Action = "Prune or clear with pnpm tooling after confirming active workflows." },
            @{ Path = "$base\AppData\Local\pip\Cache"; Reason = "pip package cache"; Action = "Clear with pip cache purge after confirming active workflows." },
            @{ Path = "$base\.cache\pip"; Reason = "pip package cache"; Action = "Clear with pip cache tooling after confirming active workflows." },
            @{ Path = "$base\.cache\huggingface"; Reason = "Hugging Face model/dataset cache"; Action = "Review cached models before deleting; they may be expensive to redownload." },
            @{ Path = "$base\.cache\torch"; Reason = "PyTorch model cache"; Action = "Review cached models before deleting; they may be redownloaded later." },
            @{ Path = "$base\.cargo\registry"; Reason = "Cargo registry cache"; Action = "Clear through cargo cache tooling or after confirming projects can rebuild." },
            @{ Path = "$base\.cargo\git"; Reason = "Cargo git cache"; Action = "Clear through cargo cache tooling or after confirming projects can rebuild." },
            @{ Path = "$base\go\pkg\mod\cache"; Reason = "Go module download cache"; Action = "Clear with go clean -modcache only after confirming active projects." },
            @{ Path = "$base\.nuget\packages"; Reason = "NuGet package cache"; Action = "Clear with nuget/dotnet cache tooling after confirming active projects." },
            @{ Path = "$base\AppData\Local\NuGet\Cache"; Reason = "NuGet HTTP cache"; Action = "Clear with nuget/dotnet cache tooling after confirming active projects." },
            @{ Path = "$base\.gradle\caches"; Reason = "Gradle build cache"; Action = "Clear with Gradle cleanup after confirming active projects." }
        )

        foreach ($entry in $cacheEntries) {
            if (Test-PathSafe -Path $entry.Path) {
                Add-Candidate -Category "无痛删除" -Path $entry.Path -Reason $entry.Reason -SuggestedAction $entry.Action
            }
        }

        $browserPatterns = @(
            "$base\AppData\Local\Google\Chrome\User Data\*\Cache",
            "$base\AppData\Local\Google\Chrome\User Data\*\Code Cache",
            "$base\AppData\Local\Microsoft\Edge\User Data\*\Cache",
            "$base\AppData\Local\Microsoft\Edge\User Data\*\Code Cache",
            "$base\AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Cache",
            "$base\AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Code Cache",
            "$base\AppData\Local\Mozilla\Firefox\Profiles\*\cache2"
        )

        foreach ($pattern in $browserPatterns) {
            Add-PathPatternCandidates -Category "无痛删除" -Pattern $pattern -Reason "Browser cache" -SuggestedAction "Clear through the browser's own settings."
        }
    }
}

function Add-MigratableCandidates {
    param([System.IO.DirectoryInfo[]]$UserRoots)

    $largeFileExtensions = @(
        ".7z", ".zip", ".rar", ".tar", ".gz", ".xz",
        ".iso", ".img", ".dmg",
        ".vhd", ".vhdx", ".ova", ".ovf",
        ".bak", ".backup", ".old",
        ".mp4", ".mov", ".mkv", ".avi", ".wmv",
        ".psd", ".ai", ".blend",
        ".msi", ".exe"
    )

    foreach ($user in $UserRoots) {
        $scanFolders = @("Downloads", "Desktop", "Documents", "Pictures", "Videos", "Music")
        foreach ($folderName in $scanFolders) {
            $folder = Join-Path $user.FullName $folderName
            if (-not (Test-PathSafe -Path $folder)) { continue }

            try {
                $topItems = Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop
                foreach ($item in $topItems) {
                    if ($item -is [System.IO.DirectoryInfo] -and (Test-ReparsePoint -Item $item)) {
                        Add-SkippedPath -Path $item.FullName -Reason "Skipped reparse point"
                        continue
                    }
                    Add-Candidate -Category "可迁移文件" -Path $item.FullName -Reason "Large user-owned item in $folderName" -SuggestedAction "Review, archive, or migrate to another drive/cloud storage."
                }
            }
            catch {
                Add-SkippedPath -Path $folder -Reason $_.Exception.Message
            }

            try {
                $largeFiles = Get-ChildItem -LiteralPath $folder -Force -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -ge $MinSizeBytes -and $largeFileExtensions -contains $_.Extension.ToLowerInvariant() }
                foreach ($file in $largeFiles) {
                    Add-Candidate -Category "可迁移文件" -Path $file.FullName -Reason "Large archive, media, installer, backup, or disk image" -SuggestedAction "Review, archive, or migrate to another drive/cloud storage."
                }
            }
            catch {
                Add-SkippedPath -Path $folder -Reason $_.Exception.Message
            }
        }

        $vhdPattern = "$($user.FullName)\AppData\Local\Packages\*\LocalState\ext4.vhdx"
        Add-PathPatternCandidates -Category "可迁移文件" -Pattern $vhdPattern -Reason "WSL distribution virtual disk" -SuggestedAction "Review distribution usage; migrate/export WSL distro rather than deleting the VHDX directly."
    }
}

function Get-InstalledSoftware {
    function Get-ObjectPropertyString {
        param(
            [object]$Object,
            [string]$Name
        )
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property -or $null -eq $property.Value) { return "" }
        return [string]$property.Value
    }

    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $software = New-Object System.Collections.Generic.List[object]
    foreach ($regPath in $registryPaths) {
        try {
            $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $displayName = Get-ObjectPropertyString -Object $item -Name "DisplayName"
                if ([string]::IsNullOrWhiteSpace($displayName)) { continue }
                $software.Add([pscustomobject]@{
                    DisplayName = $displayName
                    InstallLocation = Get-ObjectPropertyString -Object $item -Name "InstallLocation"
                    Publisher = Get-ObjectPropertyString -Object $item -Name "Publisher"
                    UninstallString = Get-ObjectPropertyString -Object $item -Name "UninstallString"
                }) | Out-Null
            }
        }
        catch {
            Add-SkippedPath -Path $regPath -Reason $_.Exception.Message
        }
    }
    return @($software.ToArray())
}

function Test-RegisteredSoftwareDirectory {
    param(
        [string]$Directory,
        [object[]]$InstalledSoftware
    )

    $directoryLower = $Directory.TrimEnd("\").ToLowerInvariant()
    foreach ($software in $InstalledSoftware) {
        if (-not [string]::IsNullOrWhiteSpace($software.InstallLocation)) {
            $installLower = $software.InstallLocation.TrimEnd("\").ToLowerInvariant()
            if ($installLower.StartsWith($directoryLower) -or $directoryLower.StartsWith($installLower)) {
                return $software.DisplayName
            }
        }
    }
    return ""
}

function Add-StaleSoftwareCandidates {
    param([System.IO.DirectoryInfo[]]$UserRoots)

    $installed = Get-InstalledSoftware
    $softwareRoots = New-Object System.Collections.Generic.List[string]
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    foreach ($path in @($env:ProgramFiles, $programFilesX86, $env:ProgramData)) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-PathSafe -Path $path)) {
            $softwareRoots.Add($path) | Out-Null
        }
    }
    foreach ($user in $UserRoots) {
        foreach ($path in @("$($user.FullName)\AppData\Local\Programs", "$($user.FullName)\AppData\Local")) {
            if (Test-PathSafe -Path $path) {
                $softwareRoots.Add($path) | Out-Null
            }
        }
    }

    $excludedNames = @(
        "Microsoft", "Windows", "WindowsApps", "Packages", "Temp", "CrashDumps",
        "Google\Chrome", "Microsoft\Edge", "Mozilla", "Packages"
    )

    foreach ($rootPath in ($softwareRoots | Select-Object -Unique)) {
        try {
            $children = Get-ChildItem -LiteralPath $rootPath -Force -Directory -ErrorAction Stop
        }
        catch {
            Add-SkippedPath -Path $rootPath -Reason $_.Exception.Message
            continue
        }

        foreach ($dir in $children) {
            if (Test-ReparsePoint -Item $dir) {
                Add-SkippedPath -Path $dir.FullName -Reason "Skipped reparse point"
                continue
            }
            if ($excludedNames -contains $dir.Name) { continue }
            if ($dir.LastWriteTime -gt $StaleCutoff) { continue }

            $registeredName = Test-RegisteredSoftwareDirectory -Directory $dir.FullName -InstalledSoftware $installed
            $reason = if ([string]::IsNullOrWhiteSpace($registeredName)) {
                "Large software-like directory with stale files; this is not proof that the software is unused"
            }
            else {
                "Large installed software directory with stale install files: $registeredName; this is not proof that the app is unused"
            }

            Add-Candidate -Category "长期未使用的软件内容" -Path $dir.FullName -Reason $reason -SuggestedAction "Confirm actual usage first, then review in Settings > Apps or vendor uninstaller; do not manually delete until confirmed."
        }
    }
}

function Get-RepositoryRemoteHint {
    param([string]$RepoPath)
    $configPath = Join-Path $RepoPath ".git\config"
    if (-not (Test-PathSafe -Path $configPath)) { return "No .git/config found" }
    try {
        $config = Get-Content -LiteralPath $configPath -ErrorAction Stop
        $remoteLine = $config | Where-Object { $_ -match "^\s*url\s*=" } | Select-Object -First 1
        if ($remoteLine) {
            return ($remoteLine -replace "^\s*url\s*=\s*", "").Trim()
        }
    }
    catch {
        Add-SkippedPath -Path $configPath -Reason $_.Exception.Message
    }
    return "No remote url found"
}

function Find-GitRepositories {
    param(
        [string[]]$SearchRoots,
        [int]$MaxDepth = 7
    )

    $skipNames = @(
        "AppData", "Application Data", "node_modules", ".venv", "venv", "env",
        ".cache", ".gradle", ".nuget", "packages", "Package Cache",
        "Windows", "Program Files", "Program Files (x86)", "ProgramData",
        '$Recycle.Bin', "System Volume Information"
    )
    $repos = New-Object System.Collections.Generic.List[string]

    foreach ($searchRoot in $SearchRoots | Select-Object -Unique) {
        if ([string]::IsNullOrWhiteSpace($searchRoot) -or -not (Test-PathSafe -Path $searchRoot)) { continue }
        $rootItem = Get-ItemSafe -Path $searchRoot
        if ($null -eq $rootItem -or $rootItem -isnot [System.IO.DirectoryInfo]) { continue }

        $queue = New-Object System.Collections.Generic.Queue[object]
        $queue.Enqueue([pscustomobject]@{ Path = $rootItem.FullName; Depth = 0 })

        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            $currentItem = Get-ItemSafe -Path $current.Path
            if ($null -eq $currentItem -or $currentItem -isnot [System.IO.DirectoryInfo]) { continue }
            if (Test-ReparsePoint -Item $currentItem) {
                Add-SkippedPath -Path $current.Path -Reason "Skipped reparse point"
                continue
            }
            if ($skipNames -contains $currentItem.Name -and $current.Depth -gt 0) { continue }

            $gitDir = Join-Path $current.Path ".git"
            if (Test-PathSafe -Path $gitDir) {
                $repos.Add($current.Path) | Out-Null
                continue
            }

            if ($current.Depth -ge $MaxDepth) { continue }

            try {
                $children = Get-ChildItem -LiteralPath $current.Path -Force -Directory -ErrorAction Stop
                foreach ($child in $children) {
                    if ($skipNames -contains $child.Name) { continue }
                    $queue.Enqueue([pscustomobject]@{ Path = $child.FullName; Depth = $current.Depth + 1 })
                }
            }
            catch {
                Add-SkippedPath -Path $current.Path -Reason $_.Exception.Message
            }
        }
    }

    return @($repos.ToArray() | Select-Object -Unique)
}

function Add-CodeRepositoryCandidates {
    param([System.IO.DirectoryInfo[]]$UserRoots)

    $searchRoots = New-Object System.Collections.Generic.List[string]
    foreach ($user in $UserRoots) {
        foreach ($relative in @("", "source", "source\repos", "repos", "workspace", "work", "dev", "code", "projects", "Documents", "Desktop")) {
            $path = if ([string]::IsNullOrWhiteSpace($relative)) { $user.FullName } else { Join-Path $user.FullName $relative }
            if (Test-PathSafe -Path $path) { $searchRoots.Add($path) | Out-Null }
        }
    }
    foreach ($path in @("C:\dev", "C:\src", "C:\code", "C:\repos", "C:\workspace", "C:\Projects")) {
        if (Test-PathSafe -Path $path) { $searchRoots.Add($path) | Out-Null }
    }

    $repos = Find-GitRepositories -SearchRoots @($searchRoots) -MaxDepth 7
    foreach ($repo in $repos) {
        $item = Get-ItemSafe -Path $repo
        if ($null -eq $item) { continue }
        $gitDir = Join-Path $repo ".git"
        $gitItem = Get-ItemSafe -Path $gitDir
        $recentWrite = $item.LastWriteTime
        if ($null -ne $gitItem -and $gitItem.LastWriteTime -gt $recentWrite) {
            $recentWrite = $gitItem.LastWriteTime
        }
        if ($recentWrite -gt $StaleCutoff) { continue }

        $remoteHint = Get-RepositoryRemoteHint -RepoPath $repo
        Add-Candidate -Category "长期未使用或疑似废弃的工具代码资源库" -Path $repo -Reason "Large Git repository not modified within $StaleDays days" -SuggestedAction "Review branch/remote state, archive if needed, then decide whether to remove or clean rebuildable artifacts." -Notes "Remote hint: $remoteHint"
    }
}

function Escape-MarkdownCell {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

function Format-ChildrenMarkdown {
    param([object[]]$Children)
    if ($null -eq $Children -or $Children.Count -eq 0) {
        return "_No first-level children captured._`n"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("| Size | Type | Name | Last write |") | Out-Null
    $lines.Add("| ---: | --- | --- | --- |") | Out-Null
    foreach ($child in $Children) {
        $lines.Add("| $(Escape-MarkdownCell $child.Size) | $(Escape-MarkdownCell $child.Type) | ``$(Escape-MarkdownCell $child.Name)`` | $(Escape-MarkdownCell $child.LastWriteTime) |") | Out-Null
    }
    return (($lines -join "`n") + "`n")
}

function New-MarkdownReport {
    param(
        [object[]]$Candidates,
        [object[]]$Skipped,
        [datetime]$Started,
        [datetime]$Finished
    )

    $categoryOrder = @("无痛删除", "可迁移文件", "长期未使用的软件内容", "长期未使用或疑似废弃的工具代码资源库")
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# C Drive Cleanup Audit") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Root: ``$Root``") | Out-Null
    $lines.Add("- Minimum candidate size: $(ConvertTo-DisplaySize -Bytes $MinSizeBytes)") | Out-Null
    $lines.Add("- Stale threshold: $StaleDays days") | Out-Null
    $lines.Add("- Started: $Started") | Out-Null
    $lines.Add("- Finished: $Finished") | Out-Null
    $lines.Add("- Safety: read-only audit; no files were deleted, moved, uninstalled, or modified by the scanner.") | Out-Null
    $lines.Add("") | Out-Null

    $lines.Add("## Summary") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| Category | Candidates | Total size |") | Out-Null
    $lines.Add("| --- | ---: | ---: |") | Out-Null
    foreach ($category in $categoryOrder) {
        $items = @($Candidates | Where-Object { $_.Category -eq $category })
        $total = [int64](($items | Measure-Object -Property SizeBytes -Sum).Sum)
        $lines.Add("| $(Escape-MarkdownCell $category) | $($items.Count) | $(ConvertTo-DisplaySize -Bytes $total) |") | Out-Null
    }
    $lines.Add("") | Out-Null

    foreach ($category in $categoryOrder) {
        $items = @($Candidates | Where-Object { $_.Category -eq $category } | Sort-Object SizeBytes -Descending)
        $lines.Add("## $category") | Out-Null
        $lines.Add("") | Out-Null
        if ($items.Count -eq 0) {
            $lines.Add("_No candidates above threshold._") | Out-Null
            $lines.Add("") | Out-Null
            continue
        }

        $rank = 1
        foreach ($item in $items) {
            $lines.Add("### $rank. $(Escape-MarkdownCell $item.Size) - ``$($item.Path)``") | Out-Null
            $lines.Add("") | Out-Null
            $lines.Add("- Type: $($item.Type)") | Out-Null
            $lines.Add("- Last write: $($item.LastWriteTime)") | Out-Null
            $lines.Add("- Reason: $(Escape-MarkdownCell $item.Reason)") | Out-Null
            $lines.Add("- Suggested action: $(Escape-MarkdownCell $item.SuggestedAction)") | Out-Null
            if (-not [string]::IsNullOrWhiteSpace($item.Notes)) {
                $lines.Add("- Notes: $(Escape-MarkdownCell $item.Notes)") | Out-Null
            }
            if ($item.Type -eq "Directory") {
                $lines.Add("") | Out-Null
                $lines.Add("First-level children:") | Out-Null
                $lines.Add("") | Out-Null
                $lines.Add((Format-ChildrenMarkdown -Children @($item.FirstLevelChildren))) | Out-Null
            }
            $lines.Add("") | Out-Null
            $rank++
        }
    }

    $lines.Add("## Skipped Paths") | Out-Null
    $lines.Add("") | Out-Null
    if ($Skipped.Count -eq 0) {
        $lines.Add("_No skipped paths recorded._") | Out-Null
    }
    else {
        $lines.Add("| Path | Reason |") | Out-Null
        $lines.Add("| --- | --- |") | Out-Null
        foreach ($skip in ($Skipped | Select-Object -First 250)) {
            $lines.Add("| ``$(Escape-MarkdownCell $skip.Path)`` | $(Escape-MarkdownCell $skip.Reason) |") | Out-Null
        }
        if ($Skipped.Count -gt 250) {
            $lines.Add("| ... | $($Skipped.Count - 250) additional skipped paths omitted from Markdown; see JSON. |") | Out-Null
        }
    }

    return ($lines -join "`n")
}

$resolvedRoot = Get-ItemSafe -Path $Root
if ($null -eq $resolvedRoot -or $resolvedRoot -isnot [System.IO.DirectoryInfo]) {
    throw "Root path is not an accessible directory: $Root"
}
$Root = $resolvedRoot.FullName.TrimEnd("\") + "\"

$userRoots = Get-UserRoots

Write-Host "Starting read-only C drive cleanup audit..."
Write-Host "Root: $Root"
Write-Host "Minimum candidate size: $(ConvertTo-DisplaySize -Bytes $MinSizeBytes)"
Write-Host "Stale threshold: $StaleDays days"

Add-CacheCandidates -UserRoots $userRoots
Add-MigratableCandidates -UserRoots $userRoots
Add-StaleSoftwareCandidates -UserRoots $userRoots
Add-CodeRepositoryCandidates -UserRoots $userRoots

$FinishedAt = Get-Date
$timestamp = $StartedAt.ToString("yyyyMMdd-HHmmss")
$reportDir = Join-Path $OutputRoot "c-drive-cleanup-audit-$timestamp"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$orderedCandidates = @($script:Candidates.ToArray() | Sort-Object Category, @{ Expression = "SizeBytes"; Descending = $true })
$payload = [pscustomobject]@{
    Root = $Root
    MinSizeMB = $MinSizeMB
    StaleDays = $StaleDays
    StartedAt = $StartedAt
    FinishedAt = $FinishedAt
    Safety = "Read-only audit; no scanned files were deleted, moved, uninstalled, or modified."
    Candidates = $orderedCandidates
    Skipped = @($script:Skipped.ToArray())
}

$jsonPath = Join-Path $reportDir "c-drive-cleanup-audit.json"
$mdPath = Join-Path $reportDir "c-drive-cleanup-audit.md"
$csvPath = Join-Path $reportDir "c-drive-cleanup-audit.csv"

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
New-MarkdownReport -Candidates $orderedCandidates -Skipped @($script:Skipped.ToArray()) -Started $StartedAt -Finished $FinishedAt |
    Set-Content -LiteralPath $mdPath -Encoding UTF8

if ($IncludeCsv) {
    $orderedCandidates |
        Select-Object Category, Size, SizeBytes, Type, Path, LastWriteTime, LastAccessTime, Reason, SuggestedAction, Confidence, Notes |
        Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Audit complete."
Write-Host "Markdown report: $mdPath"
Write-Host "JSON report: $jsonPath"
if ($IncludeCsv) { Write-Host "CSV report: $csvPath" }
