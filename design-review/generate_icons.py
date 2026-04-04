#!/usr/bin/env python3
"""Generate 3 icon concept PNGs for MacPerf at 1024x1024."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def lerp_color(c1, c2, t):
    """Linear interpolation between two RGB tuples."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


# ── Icon A: "Refined Clarity" ──────────────────────────────────────────────

def generate_icon_a():
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    blue = hex_to_rgb("#007AFF")

    # The line occupies roughly the center 60%
    margin = int(SIZE * 0.20)
    x_start = margin
    x_end = SIZE - margin
    y_top = margin
    y_bottom = SIZE - margin
    graph_height = y_bottom - y_top

    # 3 data points: up - dip - up (trending upward)
    # Use more points for a smooth Bezier-like curve
    key_points = [
        (x_start, y_top + int(graph_height * 0.55)),        # start mid-high
        (x_start + (x_end - x_start) * 0.5, y_top + int(graph_height * 0.75)),  # dip
        (x_end, y_top + int(graph_height * 0.20)),           # end high
    ]

    # Interpolate a smooth curve through these points using quadratic bezier segments
    def bezier_points(p0, p1, p2, steps=80):
        pts = []
        for i in range(steps + 1):
            t = i / steps
            x = (1 - t)**2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
            y = (1 - t)**2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
            pts.append((x, y))
        return pts

    # Create control points for smooth curve
    # Segment 1: from point0 to point1, with control point pulling the curve
    cp1 = (key_points[0][0] + (key_points[1][0] - key_points[0][0]) * 0.6,
           key_points[0][1] - int(graph_height * 0.15))
    seg1 = bezier_points(key_points[0], cp1, key_points[1], 80)

    # Segment 2: from point1 to point2
    cp2 = (key_points[1][0] + (key_points[2][0] - key_points[1][0]) * 0.4,
           key_points[1][1] + int(graph_height * 0.05))
    seg2 = bezier_points(key_points[1], cp2, key_points[2], 80)

    curve_pts = seg1 + seg2[1:]  # avoid duplicate at junction

    # Draw gradient fill below the line
    fill_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill_img)

    # For each column, draw from curve down to y_bottom with fading alpha
    for i in range(len(curve_pts) - 1):
        x1, y1 = curve_pts[i]
        x2, y2 = curve_pts[i + 1]
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2

        col_x = int(mid_x)
        col_y_top = int(mid_y)
        col_y_bot = y_bottom

        if col_y_bot <= col_y_top:
            continue

        span = col_y_bot - col_y_top
        for row in range(col_y_top, col_y_bot):
            frac = (row - col_y_top) / span
            alpha = int(76 * (1 - frac))  # 30% = 76 at top, fading to 0
            if alpha > 0 and 0 <= col_x < SIZE and 0 <= row < SIZE:
                fill_img.putpixel((col_x, row), (blue[0], blue[1], blue[2], alpha))

    # Blur the fill slightly for smoothness
    fill_img = fill_img.filter(ImageFilter.GaussianBlur(radius=8))
    img = Image.alpha_composite(img, fill_img)

    # Draw the line itself
    draw = ImageDraw.Draw(img)
    # Draw thick line by drawing circles along the curve
    for pt in curve_pts:
        x, y = int(pt[0]), int(pt[1])
        r = 6  # half of 12px stroke
        draw.ellipse([x - r, y - r, x + r, y + r], fill=blue + (255,))

    # Also draw line segments for continuity
    for i in range(len(curve_pts) - 1):
        x1, y1 = int(curve_pts[i][0]), int(curve_pts[i][1])
        x2, y2 = int(curve_pts[i + 1][0]), int(curve_pts[i + 1][1])
        draw.line([(x1, y1), (x2, y2)], fill=blue + (255,), width=12)

    path = os.path.join(OUT_DIR, "icon_a.png")
    img.save(path, "PNG")
    print(f"Saved {path}")


# ── Icon B: "Mission Control" ──────────────────────────────────────────────

def generate_icon_b():
    # Background: radial gradient from #1A1A2E center to #0D0D10 edges
    center_col = hex_to_rgb("#1A1A2E")
    edge_col = hex_to_rgb("#0D0D10")

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    pixels = img.load()
    cx, cy = SIZE // 2, SIZE // 2
    max_dist = math.sqrt(cx**2 + cy**2)

    for y in range(SIZE):
        for x in range(SIZE):
            d = math.sqrt((x - cx)**2 + (y - cy)**2)
            t = min(d / max_dist, 1.0)
            c = lerp_color(center_col, edge_col, t)
            pixels[x, y] = (c[0], c[1], c[2], 255)

    draw = ImageDraw.Draw(img)

    # Rounded hexagon: 6 sides, ~700px across, rounded corners
    hex_radius = 350
    hex_cx, hex_cy = SIZE // 2, SIZE // 2
    corner_r = 40  # rounding radius

    # Compute hexagon vertices
    hex_verts = []
    for i in range(6):
        angle = math.radians(60 * i - 90)  # start from top
        hx = hex_cx + hex_radius * math.cos(angle)
        hy = hex_cy + hex_radius * math.sin(angle)
        hex_verts.append((hx, hy))

    # Draw rounded hexagon outline
    # For each edge, draw a line inset by corner_r, then arc at corners
    hex_col = hex_to_rgb("#3B82F6")
    hex_alpha = 128  # 50% opacity

    hex_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hex_draw = ImageDraw.Draw(hex_overlay)

    # For rounded hex: compute inset points on each edge
    def inset_edge(p1, p2, r):
        """Return two points on the edge p1->p2, inset by r from each end."""
        dx = p2[0] - p1[0]
        dy = p2[1] - p1[1]
        length = math.sqrt(dx**2 + dy**2)
        ux, uy = dx / length, dy / length
        a = (p1[0] + ux * r, p1[1] + uy * r)
        b = (p2[0] - ux * r, p2[1] - uy * r)
        return a, b

    # Build the rounded path as a series of line segments + arcs
    # We'll approximate arcs with short line segments
    rounded_pts = []
    n = len(hex_verts)
    for i in range(n):
        p_prev = hex_verts[(i - 1) % n]
        p_curr = hex_verts[i]
        p_next = hex_verts[(i + 1) % n]

        # Inset from current vertex along both edges
        _, a = inset_edge(p_prev, p_curr, corner_r)
        b, _ = inset_edge(p_curr, p_next, corner_r)

        # Arc from a to b around p_curr
        # Use short segments
        arc_steps = 12
        for s in range(arc_steps + 1):
            t = s / arc_steps
            # Simple interpolation with pull toward center of arc
            # Use quadratic bezier with p_curr as control point
            x = (1 - t)**2 * a[0] + 2 * (1 - t) * t * p_curr[0] + t**2 * b[0]
            y = (1 - t)**2 * a[1] + 2 * (1 - t) * t * p_curr[1] + t**2 * b[1]
            rounded_pts.append((x, y))

    # Draw the outline
    for i in range(len(rounded_pts)):
        p1 = rounded_pts[i]
        p2 = rounded_pts[(i + 1) % len(rounded_pts)]
        hex_draw.line([p1, p2], fill=(hex_col[0], hex_col[1], hex_col[2], hex_alpha), width=4)

    img = Image.alpha_composite(img, hex_overlay)
    draw = ImageDraw.Draw(img)

    # Bars inside hexagon: 3 vertical bars, bottom-aligned
    bar_width = 80
    gap = 40
    total_w = 3 * bar_width + 2 * gap  # 320
    bar_left_x = cx - total_w // 2

    bar_colors = [hex_to_rgb("#3B82F6"), hex_to_rgb("#22C55E"), hex_to_rgb("#F59E0B")]
    bar_heights = [280, 380, 320]
    bar_bottom = cy + 120  # bottom of bars
    round_r = 20

    bar_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bar_draw = ImageDraw.Draw(bar_overlay)

    for i in range(3):
        bx = bar_left_x + i * (bar_width + gap)
        by_top = bar_bottom - bar_heights[i]
        by_bot = bar_bottom
        col = bar_colors[i] + (255,)

        # Draw bar with rounded top corners
        # Main rectangle (below the rounded part)
        bar_draw.rectangle([bx, by_top + round_r, bx + bar_width, by_bot], fill=col)
        # Top rounded part
        bar_draw.rounded_rectangle(
            [bx, by_top, bx + bar_width, by_top + round_r * 2],
            radius=round_r,
            fill=col
        )

    img = Image.alpha_composite(img, bar_overlay)
    draw = ImageDraw.Draw(img)

    # "M" letterform below bars
    m_color = hex_to_rgb("#D4D4D8")
    m_y = bar_bottom + 30
    m_size = 80

    # Try to load a bold font
    font = None
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFCompact.ttf",
    ]
    for fp in font_paths:
        try:
            font = ImageFont.truetype(fp, m_size)
            break
        except (IOError, OSError):
            continue

    if font is None:
        font = ImageFont.load_default()

    # Measure and center the M
    bbox = draw.textbbox((0, 0), "M", font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    mx = cx - tw // 2
    my = m_y
    draw.text((mx, my), "M", fill=m_color + (255,), font=font)

    path = os.path.join(OUT_DIR, "icon_b.png")
    img.save(path, "PNG")
    print(f"Saved {path}")


# ── Icon C: "Aurora" ───────────────────────────────────────────────────────

def generate_icon_c():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    pixels = img.load()

    # Gradient mesh: 4 color sources at corners
    colors = {
        "tl": hex_to_rgb("#7C3AED"),  # purple top-left
        "tr": hex_to_rgb("#3B82F6"),  # blue top-right
        "br": hex_to_rgb("#0891B2"),  # teal bottom-right
        "bl": hex_to_rgb("#16A34A"),  # green bottom-left
    }

    # Bilinear interpolation for smooth gradient mesh
    for y in range(SIZE):
        ty = y / (SIZE - 1)
        for x in range(SIZE):
            tx = x / (SIZE - 1)
            # Bilinear blend
            top = lerp_color(colors["tl"], colors["tr"], tx)
            bot = lerp_color(colors["bl"], colors["br"], tx)
            c = lerp_color(top, bot, ty)
            pixels[x, y] = (c[0], c[1], c[2], 255)

    # Add overlapping radial gradients for more organic feel
    radial_sources = [
        (256, 256, "#7C3AED", 400),
        (768, 256, "#3B82F6", 450),
        (768, 768, "#0891B2", 400),
        (256, 768, "#16A34A", 420),
        (512, 512, "#6366F1", 300),  # center accent
    ]

    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ov_pixels = overlay.load()

    for (rcx, rcy, hex_col, radius) in radial_sources:
        col = hex_to_rgb(hex_col)
        for y in range(max(0, rcy - radius), min(SIZE, rcy + radius)):
            for x in range(max(0, rcx - radius), min(SIZE, rcx + radius)):
                d = math.sqrt((x - rcx)**2 + (y - rcy)**2)
                if d < radius:
                    t = 1 - (d / radius)
                    alpha = int(60 * t * t)  # quadratic falloff, subtle
                    existing = ov_pixels[x, y]
                    # Blend additively
                    new_a = min(255, existing[3] + alpha)
                    if existing[3] == 0:
                        ov_pixels[x, y] = (col[0], col[1], col[2], alpha)
                    else:
                        # Blend colors
                        old_w = existing[3]
                        new_w = alpha
                        total = old_w + new_w
                        if total > 0:
                            r = (existing[0] * old_w + col[0] * new_w) // total
                            g = (existing[1] * old_w + col[1] * new_w) // total
                            b = (existing[2] * old_w + col[2] * new_w) // total
                            ov_pixels[x, y] = (r, g, b, min(255, total))

    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=30))
    img = Image.alpha_composite(img, overlay)

    # Subtle radial highlight in center: white at 15% opacity, radius ~300
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    h_pixels = highlight.load()
    h_cx, h_cy = SIZE // 2, SIZE // 2
    h_radius = 300

    for y in range(h_cy - h_radius, h_cy + h_radius):
        if y < 0 or y >= SIZE:
            continue
        for x in range(h_cx - h_radius, h_cx + h_radius):
            if x < 0 or x >= SIZE:
                continue
            d = math.sqrt((x - h_cx)**2 + (y - h_cy)**2)
            if d < h_radius:
                t = 1 - (d / h_radius)
                alpha = int(38 * t * t)  # 15% = 38, quadratic falloff
                h_pixels[x, y] = (255, 255, 255, alpha)

    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(img, highlight)

    # White curved lines (data flow paths)
    lines_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    lines_draw = ImageDraw.Draw(lines_overlay)

    flow_lines = [
        # (control points, width, opacity)
        {
            "pts": [(50, 700), (300, 400), (600, 500), (974, 200)],
            "width": 8, "opacity": 0.7
        },
        {
            "pts": [(100, 900), (350, 600), (700, 650), (950, 350)],
            "width": 10, "opacity": 0.5
        },
        {
            "pts": [(0, 500), (250, 250), (550, 300), (850, 100), (1024, 150)],
            "width": 6, "opacity": 0.3
        },
        {
            "pts": [(50, 800), (400, 750), (650, 400), (974, 500)],
            "width": 7, "opacity": 0.6
        },
    ]

    def catmull_rom_to_bezier(p0, p1, p2, p3, steps=60):
        """Generate smooth curve points using Catmull-Rom spline."""
        points = []
        for i in range(steps + 1):
            t = i / steps
            t2 = t * t
            t3 = t2 * t
            x = 0.5 * ((2 * p1[0]) +
                        (-p0[0] + p2[0]) * t +
                        (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                        (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) +
                        (-p0[1] + p2[1]) * t +
                        (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                        (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            points.append((x, y))
        return points

    def smooth_curve(control_pts, steps_per_seg=60):
        """Generate smooth curve through control points using Catmull-Rom."""
        all_pts = []
        # Pad start and end
        pts = [control_pts[0]] + control_pts + [control_pts[-1]]
        for i in range(1, len(pts) - 2):
            seg = catmull_rom_to_bezier(pts[i-1], pts[i], pts[i+1], pts[i+2], steps_per_seg)
            if all_pts:
                seg = seg[1:]  # skip duplicate
            all_pts.extend(seg)
        return all_pts

    for fl in flow_lines:
        curve = smooth_curve(fl["pts"])
        alpha = int(255 * fl["opacity"])
        w = fl["width"]
        col = (255, 255, 255, alpha)
        for i in range(len(curve) - 1):
            lines_draw.line([curve[i], curve[i+1]], fill=col, width=w)

    # Blur lines slightly for soft look
    lines_overlay = lines_overlay.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.alpha_composite(img, lines_overlay)

    path = os.path.join(OUT_DIR, "icon_c.png")
    img.save(path, "PNG")
    print(f"Saved {path}")


if __name__ == "__main__":
    print("Generating Icon A: Refined Clarity...")
    generate_icon_a()
    print("Generating Icon B: Mission Control...")
    generate_icon_b()
    print("Generating Icon C: Aurora...")
    generate_icon_c()
    print("Done!")
