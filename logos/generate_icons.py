#!/usr/bin/env python3
"""Generate all icon assets for Fiddlehead app — frog peeking design.
Uses numpy + Pillow for fast rendering at all sizes."""

import numpy as np
from PIL import Image
import json
import os

LOGO_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(LOGO_DIR)
ASSETS_DIR = os.path.join(PROJECT_ROOT, "Fiddlehead", "Resources", "Assets.xcassets")
APPICON_DIR = os.path.join(ASSETS_DIR, "AppIcon.appiconset")
MENUBAR_DIR = os.path.join(ASSETS_DIR, "MenuBarIcon.imageset")


def draw_frog(size, fg=(255, 255, 255), bg=(17, 17, 17), rounded_corners=True, transparent_bg=False):
    """Draw the frog peeking icon using numpy vectorized ops. Returns RGBA Image."""
    s = size / 128.0

    # Create coordinate grids
    y_coords, x_coords = np.mgrid[0:size, 0:size]
    x = x_coords.astype(np.float64)
    y = y_coords.astype(np.float64)

    # Rounded corners mask
    corner_mask = np.zeros((size, size), dtype=bool)
    if rounded_corners:
        cr = int(size * 0.21875)
        if cr > 0:
            tl = (x_coords < cr) & (y_coords < cr) & ((x - cr)**2 + (y - cr)**2 > cr**2)
            tr = (x_coords >= size - cr) & (y_coords < cr) & ((x - (size - cr - 1))**2 + (y - cr)**2 > cr**2)
            bl = (x_coords < cr) & (y_coords >= size - cr) & ((x - cr)**2 + (y - (size - cr - 1))**2 > cr**2)
            br = (x_coords >= size - cr) & (y_coords >= size - cr) & ((x - (size - cr - 1))**2 + (y - (size - cr - 1))**2 > cr**2)
            corner_mask = tl | tr | bl | br

    # Head dome
    in_head = ((x - 64*s)/(46*s))**2 + ((y - 94*s)/(32*s))**2 <= 1.0
    in_head &= y < 94*s + 32*s*0.6

    # Eye bulges
    in_left_eye = ((x - 42*s)/(16*s))**2 + ((y - 72*s)/(18*s))**2 <= 1.0
    in_right_eye = ((x - 86*s)/(16*s))**2 + ((y - 72*s)/(18*s))**2 <= 1.0

    # Frog body
    frog = in_head | in_left_eye | in_right_eye

    # Pupil holes
    left_hole = ((x - 42*s)/(8*s))**2 + ((y - 68*s)/(9*s))**2 <= 1.0
    right_hole = ((x - 86*s)/(8*s))**2 + ((y - 68*s)/(9*s))**2 <= 1.0
    holes = left_hole | right_hole

    # Pupil dots
    left_dot = (x - 44*s)**2 + (y - 67*s)**2 <= (4*s)**2
    right_dot = (x - 88*s)**2 + (y - 67*s)**2 <= (4*s)**2
    dots = left_dot | right_dot

    # Final foreground mask
    is_fg = (frog & ~holes) | dots

    # Build RGBA
    img = np.zeros((size, size, 4), dtype=np.uint8)

    if transparent_bg:
        img[is_fg, 0] = fg[0]
        img[is_fg, 1] = fg[1]
        img[is_fg, 2] = fg[2]
        img[is_fg, 3] = 255
    else:
        img[:, :, 0] = bg[0]
        img[:, :, 1] = bg[1]
        img[:, :, 2] = bg[2]
        img[:, :, 3] = 255
        img[is_fg, 0] = fg[0]
        img[is_fg, 1] = fg[1]
        img[is_fg, 2] = fg[2]

    # Corners transparent
    img[corner_mask, 3] = 0

    return Image.fromarray(img, 'RGBA')


def generate_app_icons():
    """Generate all macOS app icon sizes."""
    print("Generating App Icons...")
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    os.makedirs(APPICON_DIR, exist_ok=True)

    for filename, size in sizes.items():
        print(f"  {filename} ({size}x{size})")
        img = draw_frog(size)
        img.save(os.path.join(APPICON_DIR, filename))

    contents = {
        "images": [
            {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon_16x16.png"},
            {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon_16x16@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon_32x32.png"},
            {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon_32x32@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
            {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
            {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
            {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
        ],
        "info": {"version": 1, "author": "xcode"}
    }
    with open(os.path.join(APPICON_DIR, "Contents.json"), 'w') as f:
        json.dump(contents, f, indent=2)
    print("  Contents.json written")


def generate_menubar_icon():
    """Generate menubar template icons — black on transparent."""
    print("\nGenerating Menu Bar Icons...")
    os.makedirs(MENUBAR_DIR, exist_ok=True)

    for name, size in [("MenuBarIcon.png", 18), ("MenuBarIcon@2x.png", 36), ("MenuBarIcon@3x.png", 54)]:
        print(f"  {name} ({size}x{size})")
        img = draw_frog(size, fg=(0, 0, 0), rounded_corners=False, transparent_bg=True)
        img.save(os.path.join(MENUBAR_DIR, name))

    # Remove old PDF
    old_pdf = os.path.join(MENUBAR_DIR, "MenuBarIcon.pdf")
    if os.path.exists(old_pdf):
        os.remove(old_pdf)
        print("  Removed old MenuBarIcon.pdf")

    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x", "filename": "MenuBarIcon.png"},
            {"idiom": "universal", "scale": "2x", "filename": "MenuBarIcon@2x.png"},
            {"idiom": "universal", "scale": "3x", "filename": "MenuBarIcon@3x.png"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {
            "template-rendering-intent": "template"
        }
    }
    with open(os.path.join(MENUBAR_DIR, "Contents.json"), 'w') as f:
        json.dump(contents, f, indent=2)
    print("  Contents.json written")


def generate_large_logo():
    """Generate large versions for marketing/future use."""
    print("\nGenerating Large Logos...")
    for size in [1024, 2048]:
        filename = f"fiddlehead-logo-{size}px.png"
        print(f"  {filename}...")
        img = draw_frog(size)
        img.save(os.path.join(LOGO_DIR, filename))
    print("  Done")


if __name__ == "__main__":
    generate_app_icons()
    generate_menubar_icon()
    generate_large_logo()
    print("\nAll icons generated!")
