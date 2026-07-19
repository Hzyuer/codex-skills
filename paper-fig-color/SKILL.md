---
name: paper-fig-color
description: Select, apply, and validate a consistent publication-ready color system for academic paper figures. Use when Codex needs to color or recolor Matplotlib, Seaborn, R/ggplot2, MATLAB, or LaTeX figures; standardize method colors across a paper; generate palette swatches; redraw INFOCOM-style charts; or check color, color-vision, and grayscale legibility.
---

# Paper Figure Colors

Apply the canonical cumulative palette exactly. Preserve the figure's data,
geometry, typography, labels, and layout unless the user requests other edits.

## Canonical Palette

Use the first `n` colors for `n` categorical series:

```text
C1 #4E79A7  blue
C2 #F28E2B  orange
C3 #76B7B2  teal
C4 #E15759  brick red
C5 #B07AA1  mauve
C6 #59A14F  green
C7 #EDC948  sand yellow
C8 #9C755F  gray brown
```

Keep category-to-color mappings stable across every figure. Do not reorder the
palette merely because a figure displays fewer categories.

For the NetProt/INFOCOM figures, use this fixed mapping:

```text
TrafficFormer -> C1 #4E79A7
ET-BERT       -> C2 #F28E2B
NetMamba      -> C3 #76B7B2
YaTC          -> C4 #E15759
```

## Workflow

1. Inspect the plotting source, generated figure, and LaTeX inclusion point.
2. Identify categorical series and any existing semantic color assignments.
3. Apply the first `n` canonical colors while preserving stable mappings.
4. Add redundant encoding when two or more series share a plot:
   - lines: distinct markers and line styles;
   - bars: distinct hatches and dark borders;
   - scatter: distinct marker shapes, with open/filled variants if needed.
5. Export vector PDF for the paper and PNG for visual review.
6. If the figure is embedded in LaTeX, compile the paper and inspect the final
   page at submission scale.
7. Check a grayscale rendering. If categories merge, strengthen markers,
   hatches, line styles, borders, or direct labels; do not replace the canonical
   colors without user approval.
8. Report the final mapping, modified files, validation performed, and any
   remaining readability concern.

## Figure-Type Rules

- Use the original color at full strength for thin lines, markers, and borders.
- For broad bar or area fills, optionally mix 20-30% white while retaining the
  original color on the border, marker, or legend key.
- Prefer direct labels over a distant legend when space permits.
- Keep neutral structure light: gray grid lines, black or dark-gray axes, and a
  white background.
- Do not use color alone to encode meaning.
- Avoid red-green adjacency as the only distinction.
- For more than eight categories, stop extending the palette. Use grouping,
  facets, labels, shapes, or textures.
- Do not use categorical colors for heatmaps or continuous values. Read
  `references/palettes.md` for sequential and diverging choices.
- Never use `jet` or rainbow maps for scientific data.

## Code Patterns

Python:

```python
PAPER_COLORS = [
    "#4E79A7", "#F28E2B", "#76B7B2", "#E15759",
    "#B07AA1", "#59A14F", "#EDC948", "#9C755F",
]
colors = PAPER_COLORS[:n_series]
```

R:

```r
paper_colors <- c(
  "#4E79A7", "#F28E2B", "#76B7B2", "#E15759",
  "#B07AA1", "#59A14F", "#EDC948", "#9C755F"
)
p + scale_color_manual(values = paper_colors[seq_len(n_series)])
```

## Resources

- Run `scripts/render_palette.py` to create PNG and PDF swatches of the
  canonical palette and its cumulative subsets.
- Read `references/palettes.md` only when the canonical palette is unsuitable,
  the user asks for alternatives, or the figure encodes continuous/diverging
  data.
