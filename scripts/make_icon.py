"""Builds the iOS app icon (1024x1024, no alpha) and the in-app logo from docs/iVidiSolitaire_logo.jpeg.

The source is an icon mockup: a rounded metal-framed tile on a dark backdrop. iOS applies its own
rounded mask, so we crop the tile square and paint the dark backdrop left in its corners with the
frame's own metal colour."""
from PIL import Image, ImageDraw, ImageFilter
import sys

SRC = "docs/iVidiSolitaire_logo.jpeg"
LEFT, RIGHT, TOP = 748, 2002, 125          # tile bounds measured on the source
INSET = 6

im = Image.open(SRC).convert("RGB")
side = RIGHT - LEFT - 2 * INSET
box = (LEFT + INSET, TOP + INSET, LEFT + INSET + side, TOP + INSET + side)
tile = im.crop(box)

# Corners: flood the dark backdrop from each corner (limited to the corner region) and paint it
# with the frame's metal tone, sampled along the frame's straight edges.
px = tile.load()
w, h = tile.size
samples = [px[x, 12] for x in range(w // 3, 2 * w // 3, 7)] + [px[12, y] for y in range(h // 3, 2 * h // 3, 7)]
metal = tuple(sorted(c[i] for c in samples)[len(samples) // 2] for i in range(3))
mask = Image.new("L", tile.size, 0)
mp = mask.load()
limit = int(side * 0.2)
def dark(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] < 70
for cx, cy, dx, dy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
    stack = [(cx, cy)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or mp[x, y] or abs(x - cx) > limit or abs(y - cy) > limit or not dark(px[x, y]):
            continue
        mp[x, y] = 255
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2))
tile = Image.composite(Image.new("RGB", tile.size, metal), tile, mask)

icon = tile.resize((1024, 1024), Image.LANCZOS)
icon.save("iVidiSolitaire/Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" if len(sys.argv) < 2 else sys.argv[1])

# Preview with the iOS mask at several sizes.
if len(sys.argv) > 2:
    sheet = Image.new("RGB", (260 + 120 + 60 + 32 + 50, 280), (40, 40, 45))
    x = 10
    for s in (260, 120, 60, 32):
        small = icon.resize((s, s), Image.LANCZOS)
        m = Image.new("L", (s * 4, s * 4), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, s * 4 - 1, s * 4 - 1), radius=int(s * 4 * 0.2237), fill=255)
        sheet.paste(small, (x, 10), m.resize((s, s), Image.LANCZOS))
        x += s + 10
    sheet.save(sys.argv[2])
print("metal", metal, "side", side)

# In-app logo: the tile with its own rounded corners (transparent outside), used on the splash and menu.
logo_dir = "iVidiSolitaire/Sources/Resources/Assets.xcassets/Logo.imageset"
import os, json
os.makedirs(logo_dir, exist_ok=True)
original = im.crop(box)
scale = 4
rounded = Image.new("L", (side * scale, side * scale), 0)
ImageDraw.Draw(rounded).rounded_rectangle((0, 0, side * scale - 1, side * scale - 1), radius=int(side * scale * 0.17), fill=255)
rounded = rounded.resize((side, side), Image.LANCZOS)
logo = original.convert("RGBA")
logo.putalpha(rounded)
logo.resize((900, 900), Image.LANCZOS).save(f"{logo_dir}/logo.png")
json.dump({"images": [{"filename": "logo.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
          open(f"{logo_dir}/Contents.json", "w"), indent=2)
