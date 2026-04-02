#!/usr/bin/env python3
"""Generate the MacPerf app icon as a 1024x1024 PNG.

The background fills the entire square edge-to-edge (no baked-in rounded
corners) so that macOS can apply its own squircle mask cleanly.
"""

from PIL import Image, ImageDraw, ImageFont
import math, os, subprocess, shutil

SIZE = 1024

# -- colours --
BG_DARK   = (15, 20, 40)       # dark navy
BG_GRAD   = (25, 35, 65)       # slightly lighter for subtle gradient feel
BAR_TEAL  = (100, 210, 200)
BAR_ORANGE = (240, 175, 70)
BAR_PURPLE = (175, 120, 210)
GREEN_LINE = (130, 220, 80)
TEXT_WHITE = (230, 235, 245)
LABEL_DIM  = (180, 190, 210)
SUBTLE_GLOW = (60, 80, 140, 40)

def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))

def draw_rounded_bar(draw, x, y, w, h, color, radius=18):
    """Draw a single vertical bar with rounded top corners."""
    # Main rectangle (bottom part)
    draw.rectangle([x, y + radius, x + w, y + h], fill=color)
    # Top rounded part
    draw.rectangle([x, y + radius, x + w, y + radius + radius], fill=color)
    draw.pieslice([x, y, x + radius * 2, y + radius * 2], 180, 270, fill=color)
    draw.pieslice([x + w - radius * 2, y, x + w, y + radius * 2], 270, 360, fill=color)
    draw.rectangle([x + radius, y, x + w - radius, y + radius], fill=color)

def draw_bar_highlight(draw, x, y, w, h, color, radius=18):
    """Draw a subtle lighter strip on the left side of a bar."""
    highlight = lerp_color(color, (255, 255, 255), 0.25)
    strip_w = max(w // 5, 4)
    draw.rectangle([x + 4, y + radius + 2, x + 4 + strip_w, y + h - 2], fill=highlight)

def main():
    img = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)

    # --- background gradient (top-to-bottom) ---
    for row in range(SIZE):
        t = row / SIZE
        c = lerp_color(BG_GRAD, BG_DARK, t)
        draw.line([(0, row), (SIZE - 1, row)], fill=c)

    # --- subtle radial glow behind bars ---
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = SIZE // 2, SIZE // 2 - 30
    for r in range(300, 0, -3):
        alpha = int(35 * (r / 300))
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                          fill=(70, 100, 180, alpha))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # --- layout constants ---
    bar_area_left = 200
    bar_area_right = 824
    bar_bottom = 780
    bar_gap = 40
    num_bars = 3
    total_gap = bar_gap * (num_bars - 1)
    bar_w = (bar_area_right - bar_area_left - total_gap) // num_bars

    bar_heights = [340, 420, 360]  # CPU, MEM, DISK
    bar_colors = [BAR_TEAL, BAR_ORANGE, BAR_PURPLE]
    bar_labels = ["CPU", "MEM", "DISK"]

    bar_positions = []
    for i in range(num_bars):
        bx = bar_area_left + i * (bar_w + bar_gap)
        by = bar_bottom - bar_heights[i]
        bar_positions.append((bx, by, bar_w, bar_heights[i]))

    # --- draw bars ---
    for i, (bx, by, bw, bh) in enumerate(bar_positions):
        draw_rounded_bar(draw, bx, by, bw, bh, bar_colors[i], radius=16)
        draw_bar_highlight(draw, bx, by, bw, bh, bar_colors[i], radius=16)

    # --- bar labels ---
    try:
        label_font = ImageFont.truetype("/System/Library/Fonts/SFCompact.ttf", 36)
    except (IOError, OSError):
        try:
            label_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
        except (IOError, OSError):
            label_font = ImageFont.load_default()

    for i, (bx, by, bw, bh) in enumerate(bar_positions):
        lbl = bar_labels[i]
        bbox = draw.textbbox((0, 0), lbl, font=label_font)
        tw = bbox[2] - bbox[0]
        tx = bx + (bw - tw) // 2
        ty = bar_bottom - 50
        draw.text((tx, ty), lbl, fill=LABEL_DIM, font=label_font)

    # --- small hardware icons (simple geometric shapes) ---
    icon_y_offset = -70  # above the label
    for i, (bx, by, bw, bh) in enumerate(bar_positions):
        icx = bx + bw // 2
        icy = bar_bottom - 50 + icon_y_offset
        if i == 0:  # CPU — small chip square
            s = 20
            draw.rectangle([icx - s, icy - s, icx + s, icy + s], outline=LABEL_DIM, width=2)
            # pins
            for p in range(-s + 6, s, 10):
                draw.line([(icx + p, icy - s), (icx + p, icy - s - 5)], fill=LABEL_DIM, width=2)
                draw.line([(icx + p, icy + s), (icx + p, icy + s + 5)], fill=LABEL_DIM, width=2)
        elif i == 1:  # MEM — RAM stick shape
            draw.rectangle([icx - 22, icy - 12, icx + 22, icy + 12], outline=LABEL_DIM, width=2)
            for p in range(-16, 20, 10):
                draw.rectangle([icx + p, icy - 7, icx + p + 5, icy + 7], outline=LABEL_DIM, width=1)
        else:  # DISK — simple drive shape
            draw.rectangle([icx - 22, icy - 14, icx + 22, icy + 14], outline=LABEL_DIM, width=2)
            draw.ellipse([icx + 8, icy + 2, icx + 18, icy + 12], outline=LABEL_DIM, width=2)

    # --- green trend line ---
    line_points = []
    for i, (bx, by, bw, bh) in enumerate(bar_positions):
        px = bx + bw // 2
        py = by + 30 + (0 if i != 1 else -20)  # curve up more at middle
        line_points.append((px, py))

    # Extend arrow beyond last bar
    last = line_points[-1]
    arrow_end = (last[0] + 80, last[1] - 100)
    line_points.append(arrow_end)

    # Draw thick green line
    for j in range(len(line_points) - 1):
        draw.line([line_points[j], line_points[j + 1]], fill=GREEN_LINE, width=10)

    # Arrowhead
    ax, ay = arrow_end
    angle = math.atan2(arrow_end[1] - line_points[-2][1],
                       arrow_end[0] - line_points[-2][0])
    arr_len = 35
    for da in [2.6, -2.6]:
        ex = ax - arr_len * math.cos(angle + da)
        ey = ay - arr_len * math.sin(angle + da)
        draw.line([(ax, ay), (ex, ey)], fill=GREEN_LINE, width=10)

    # --- "MacPerf" title ---
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/SFCompact.ttf", 72)
    except (IOError, OSError):
        try:
            title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
        except (IOError, OSError):
            title_font = ImageFont.load_default()

    title = "MacPerf"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    draw.text(((SIZE - tw) // 2, 860), title, fill=TEXT_WHITE, font=title_font)

    # --- save ---
    out = os.path.join(os.path.dirname(__file__), "icon_1024.png")
    img.save(out, "PNG")
    print(f"Saved {out}")
    return out


def build_icns(png_path):
    """Create MacPerf.iconset/ with all required sizes, then run iconutil."""
    base_dir = os.path.dirname(png_path)
    iconset = os.path.join(base_dir, "MacPerf.iconset")
    if os.path.exists(iconset):
        shutil.rmtree(iconset)
    os.makedirs(iconset)

    src = Image.open(png_path).convert("RGBA")

    # macOS iconset required sizes
    sizes = [16, 32, 64, 128, 256, 512]
    for s in sizes:
        # 1x
        resized = src.resize((s, s), Image.LANCZOS)
        resized.save(os.path.join(iconset, f"icon_{s}x{s}.png"))
        # 2x
        resized2 = src.resize((s * 2, s * 2), Image.LANCZOS)
        resized2.save(os.path.join(iconset, f"icon_{s}x{s}@2x.png"))

    # 512@2x is 1024
    src.save(os.path.join(iconset, "icon_512x512@2x.png"))

    icns_path = os.path.join(base_dir, "MacPerf.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns_path], check=True)
    print(f"Created {icns_path}")

    # Clean up iconset directory
    shutil.rmtree(iconset)
    return icns_path


if __name__ == "__main__":
    png = main()
    build_icns(png)
