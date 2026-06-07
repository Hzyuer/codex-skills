---
name: c-drive-cleanup-audit
description: Run a conservative read-only Windows C drive cleanup audit that reports large deletable, migratable, stale software, and stale code repository candidates without deleting anything.
---

# C Drive Cleanup Audit

Use this skill when the user wants a conservative, read-only audit of `C:\` to find local Windows files, folders, caches, software content, or code repositories that may be deleted, migrated, uninstalled, or archived later to save disk space.

## Safety Contract

- Do not delete, move, uninstall, stop services, clear caches, rewrite registries, or modify scanned directories.
- The only permitted write is creating audit output under the configured report directory.
- Treat every result as a candidate requiring user confirmation before cleanup.
- If a path is under `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData`, or another protected system area, recommend a supported cleanup path such as Windows Storage Sense, Disk Cleanup, Settings > Apps, or the product's uninstaller.
- Skip access-denied paths, reparse points, junctions, and symlink loops. Record them in the report instead of trying to force access.

## Default Audit

Run the bundled PowerShell scanner from the skill directory:

```powershell
$script = Join-Path $env:USERPROFILE ".codex\skills\c-drive-cleanup-audit\scripts\Invoke-CDriveCleanupAudit.ps1"
pwsh -NoProfile -ExecutionPolicy Bypass -File $script
```

If `pwsh` is unavailable, use Windows PowerShell:

```powershell
$script = Join-Path $env:USERPROFILE ".codex\skills\c-drive-cleanup-audit\scripts\Invoke-CDriveCleanupAudit.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $script
```

Default parameters:

- `-Root C:\`
- `-MinSizeMB 500`
- `-StaleDays 180`
- `-MaxChildren 20`
- `-OutputRoot $env:USERPROFILE\.codex\reports`

Example with a stricter threshold:

```powershell
$script = Join-Path $env:USERPROFILE ".codex\skills\c-drive-cleanup-audit\scripts\Invoke-CDriveCleanupAudit.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $script -MinSizeMB 1024 -StaleDays 365
```

## Output

The scanner creates a timestamped report directory containing:

- `c-drive-cleanup-audit.md`: grouped human-readable report.
- `c-drive-cleanup-audit.json`: structured candidates and skipped paths.
- `c-drive-cleanup-audit.csv`: flat candidate table when `-IncludeCsv` is used.

Report categories are ordered exactly as:

1. `无痛删除`: obvious caches, temporary files, and rebuildable package caches.
2. `可迁移文件`: large user files, archives, installers, VM images, media, and backups.
3. `长期未使用的软件内容`: large stale software directories or possible leftovers.
4. `长期未使用或疑似废弃的工具代码资源库`: stale Git/code repositories and large rebuildable project artifacts.

Within each category, candidates must be sorted by size descending. Folder candidates must include first-level child entries sorted by size descending.

## Classification Rules

- Use `无痛删除` only for clearly rebuildable or supported-cleanup content, such as user temp directories, browser caches, Windows update download cache, npm/pnpm/yarn/pip/cargo/nuget/gradle caches, and similar package caches.
- Use `可迁移文件` for large user-owned files or folders that should be moved or archived instead of deleted directly.
- Use `长期未使用的软件内容` only as a review bucket for large software directories whose files have not changed within `StaleDays`. Do not claim the application itself is unused; install directory timestamps often stay old even when the app is used daily.
- Use `长期未使用或疑似废弃的工具代码资源库` for Git repositories or project directories that are large and stale. Treat `node_modules`, `.venv`, `target`, `dist`, `.next`, and similar build outputs as rebuildable subcontent, but do not delete them without confirmation.

## Reporting Guidance

- Lead with the largest confirmed opportunities and the expected safe action.
- Keep conservative wording: "candidate", "review", "migrate", "clear through supported tool", or "uninstall through Settings". For installed applications, explicitly say that stale install files are not proof of inactive use.
- Include skipped paths and scan limitations so the user can decide whether an administrator deep scan is warranted.
- Never convert an audit result into cleanup instructions unless the user explicitly requests a separate cleanup plan.
