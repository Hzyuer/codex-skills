# Palette Reference

## Canonical Cumulative Palette

| ID | Hex | Name | Default use |
|---|---|---|---|
| C1 | `#4E79A7` | Blue | Single series; first method |
| C2 | `#F28E2B` | Orange | Strong two-series contrast |
| C3 | `#76B7B2` | Teal | Third categorical series |
| C4 | `#E15759` | Brick red | Fourth categorical series |
| C5 | `#B07AA1` | Mauve | Fifth categorical series |
| C6 | `#59A14F` | Green | Sixth categorical series |
| C7 | `#EDC948` | Sand yellow | Seventh series; broad fills preferred |
| C8 | `#9C755F` | Gray brown | Eighth categorical series |

For `n` categorical series, take `C1` through `Cn`. Keep the mapping stable
across the paper.

## Alternative Categorical Palettes

Use an alternative only when the user asks for it or the canonical palette
cannot meet a hard accessibility constraint.

### Okabe-Ito

```text
#E69F00 #56B4E9 #009E73 #F0E442
#0072B2 #D55E00 #CC79A7 #000000
```

Use for strict color-vision accessibility. Replace `#F0E442` with `#DDCC77`
when the yellow is too bright.

### Paul Tol Muted

```text
#332288 #88CCEE #44AA99 #117733 #999933
#DDCC77 #CC6677 #882255 #AA4499
```

Use when the user explicitly prioritizes a muted, low-chroma appearance.

### ColorBrewer Set2

```text
#66C2A5 #FC8D62 #8DA0CB #E78AC3
#A6D854 #FFD92F #E5C494 #B3B3B3
```

Prefer for bars and filled areas. Avoid for many thin lines because the pastel
colors can lose contrast.

## Continuous and Diverging Data

- Sequential values: use `viridis` or `cividis`.
- Diverging values around a meaningful center: use `RdBu` or a Paul Tol
  diverging map.
- Never use a categorical palette for scalar magnitude.
- Never use `jet` or rainbow maps.

## Print and Accessibility Checks

1. Render the final paper page in grayscale.
2. Confirm every category remains identifiable through a non-color channel.
3. Check thin lines at the final column width, not only in a large standalone
   export.
4. Keep labels, marker shapes, line styles, and hatches consistent between the
   plot and legend.
