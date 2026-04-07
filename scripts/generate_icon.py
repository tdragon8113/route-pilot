#!/usr/bin/env python3
"""Generate RoutePilot app icon"""

from PIL import Image, ImageDraw
import math
import os

def create_icon(size):
    """Create a single icon at the given size"""
    # Create image with transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background - rounded rectangle with gradient simulation
    margin = size // 10
    corner_radius = size // 5

    # Draw rounded rectangle background (blue gradient simulation)
    for i in range(size - 2 * margin):
        for j in range(size - 2 * margin):
            x, y = i + margin, j + margin
            # Check if inside rounded rectangle
            in_corner = False
            for cx, cy in [(corner_radius, corner_radius),
                          (size - margin - corner_radius, corner_radius),
                          (corner_radius, size - margin - corner_radius),
                          (size - margin - corner_radius, size - margin - corner_radius)]:
                if x < cx + corner_radius and x > cx - corner_radius and y < cy + corner_radius and y > cy - corner_radius:
                    if math.sqrt((x - cx)**2 + (y - cy)**2) <= corner_radius:
                        in_corner = True
                        break

            if margin <= x < size - margin and margin <= y < size - margin:
                if (margin + corner_radius <= x < size - margin - corner_radius) or \
                   (margin + corner_radius <= y < size - margin - corner_radius) or in_corner:
                    # Gradient effect
                    gradient = (x + y) / (2 * size)
                    r = int(30 + gradient * 30)
                    g = int(140 + gradient * 40)
                    b = int(200 + gradient * 55)
                    img.putpixel((x, y), (r, g, b, 255))

    # Draw route path
    center = size // 2
    stroke_width = max(2, size // 50)

    # Curved path
    points = []
    for t in range(20):
        t = t / 19
        # Bezier curve
        x = int(margin + size * 0.2 + t * (size - 2 * margin - size * 0.4))
        y = int(margin + size * 0.7 - t * size * 0.4)
        points.append((x, y))

    # Draw path
    for i in range(len(points) - 1):
        draw.line([points[i], points[i+1]], fill=(255, 255, 255, 255), width=stroke_width)

    # Start point (circle)
    start_x = int(margin + size * 0.2)
    start_y = int(margin + size * 0.7)
    point_radius = max(3, size // 40)
    draw.ellipse([start_x - point_radius, start_y - point_radius,
                  start_x + point_radius, start_y + point_radius],
                 fill=(255, 255, 255, 255))

    # End point (arrow/north indicator)
    end_x = int(margin + size * 0.8)
    end_y = int(margin + size * 0.3)
    arrow_size = max(4, size // 30)

    # Draw arrow pointing up-right
    arrow_points = [
        (end_x, end_y - arrow_size),
        (end_x - arrow_size, end_y + arrow_size // 2),
        (end_x + arrow_size // 2, end_y + arrow_size // 2),
    ]
    draw.polygon(arrow_points, fill=(255, 255, 255, 255))

    # Decorative circle
    circle_radius = int(size * 0.35)
    draw.ellipse([center - circle_radius, center - circle_radius,
                  center + circle_radius, center + circle_radius],
                 outline=(255, 255, 255, 60), width=max(1, size // 80))

    return img

def main():
    output_dir = "RoutePilot/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    # Required sizes for macOS
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]

    for size, scale in sizes:
        actual_size = size * scale
        filename = f"icon_{size}x{size}"
        if scale == 2:
            filename += "@2x"
        filename += ".png"

        print(f"Creating {filename} ({actual_size}x{actual_size})...")
        img = create_icon(actual_size)
        img.save(os.path.join(output_dir, filename))

    print(f"\nIcons generated in {output_dir}")

    # Update Contents.json
    contents = '''{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''

    with open(os.path.join(output_dir, 'Contents.json'), 'w') as f:
        f.write(contents)
    print("Updated Contents.json")

if __name__ == '__main__':
    main()