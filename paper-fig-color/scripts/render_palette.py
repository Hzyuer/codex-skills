#!/usr/bin/env python3
"""Render canonical paper-color swatches as PNG and PDF."""

from __future__ import annotations

import argparse
import os
import tempfile
from pathlib import Path

os.environ.setdefault(
    "MPLCONFIGDIR", str(Path(tempfile.gettempdir()) / "paper-fig-color-mpl")
)

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb
from matplotlib.patches import Rectangle


PALETTE = [
    "#4E79A7",
    "#F28E2B",
    "#76B7B2",
    "#E15759",
    "#B07AA1",
    "#59A14F",
    "#EDC948",
    "#9C755F",
]
NAMES = ["Blue", "Orange", "Teal", "Brick red", "Mauve", "Green", "Sand", "Brown"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.cwd(),
        help="Directory for generated PNG and PDF files.",
    )
    parser.add_argument(
        "--stem",
        default="paper-fig-color-preview",
        help="Output filename without extension.",
    )
    parser.add_argument(
        "--max-colors",
        type=int,
        choices=range(1, len(PALETTE) + 1),
        default=len(PALETTE),
        metavar="1-8",
        help="Largest cumulative subset to display.",
    )
    parser.add_argument("--dpi", type=int, default=240)
    return parser.parse_args()


def gray_hex(color: str) -> str:
    red, green, blue = to_rgb(color)
    value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    channel = round(value * 255)
    return f"#{channel:02X}{channel:02X}{channel:02X}"


def configure_matplotlib() -> None:
    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Times", "DejaVu Serif"],
            "font.size": 8.0,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "savefig.facecolor": "white",
            "figure.facecolor": "white",
            "axes.facecolor": "white",
        }
    )


def draw_master(ax: plt.Axes) -> None:
    ax.set_xlim(0, len(PALETTE))
    ax.set_ylim(-0.55, 1.15)
    for index, (color, name) in enumerate(zip(PALETTE, NAMES)):
        ax.add_patch(
            Rectangle(
                (index, 0.18),
                1,
                0.72,
                facecolor=color,
                edgecolor="#202020",
                linewidth=0.55,
            )
        )
        ax.text(index + 0.5, 1.02, f"C{index + 1}", ha="center", va="bottom")
        ax.text(index + 0.5, 0.02, color, ha="center", va="top", fontsize=6.4)
        ax.text(index + 0.5, -0.31, name, ha="center", va="top", fontsize=6.4)
    ax.axis("off")


def draw_subsets(ax: plt.Axes, max_colors: int) -> None:
    ax.set_xlim(-1.05, max_colors)
    ax.set_ylim(-0.15, max_colors + 0.9)
    for row, count in enumerate(range(1, max_colors + 1)):
        y = max_colors - row
        label = f"{count} color" if count == 1 else f"{count} colors"
        ax.text(-0.12, y + 0.33, label, ha="right", va="center")
        for index, color in enumerate(PALETTE[:count]):
            ax.add_patch(
                Rectangle(
                    (index, y),
                    1,
                    0.66,
                    facecolor=color,
                    edgecolor="#202020",
                    linewidth=0.45,
                )
            )
    ax.axis("off")


def draw_grayscale(ax: plt.Axes) -> None:
    ax.set_xlim(-1.05, len(PALETTE))
    ax.set_ylim(-0.05, 0.85)
    ax.text(-0.12, 0.34, "Grayscale", ha="right", va="center")
    for index, color in enumerate(PALETTE):
        ax.add_patch(
            Rectangle(
                (index, 0),
                1,
                0.68,
                facecolor=gray_hex(color),
                edgecolor="#202020",
                linewidth=0.45,
            )
        )
    ax.axis("off")


def main() -> None:
    args = parse_args()
    configure_matplotlib()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    height = 2.0 + args.max_colors * 0.38
    fig = plt.figure(figsize=(7.12, height))
    grid = fig.add_gridspec(
        3,
        1,
        height_ratios=[0.9, max(1.0, args.max_colors * 0.55), 0.55],
        hspace=0.08,
    )
    draw_master(fig.add_subplot(grid[0]))
    draw_subsets(fig.add_subplot(grid[1]), args.max_colors)
    draw_grayscale(fig.add_subplot(grid[2]))
    fig.subplots_adjust(left=0.11, right=0.995, top=0.98, bottom=0.03)

    for extension, options in (
        ("pdf", {}),
        ("png", {"dpi": args.dpi}),
    ):
        fig.savefig(
            args.output_dir / f"{args.stem}.{extension}",
            bbox_inches="tight",
            pad_inches=0.03,
            metadata={"Title": "Paper figure color palette"},
            **options,
        )
    plt.close(fig)


if __name__ == "__main__":
    main()
