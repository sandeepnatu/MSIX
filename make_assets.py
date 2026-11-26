"""Makes the package logo PNGs from the app icon. Run with the bundled Python (Pillow is inside):
    python.exe -I make_assets.py <MyMemoriesAlbum.ico> <output Assets folder>
"""
import os
import sys

from PIL import Image

ico_path, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)

ico = Image.open(ico_path)
# Use the largest frame stored in the .ico
sizes = sorted(ico.info.get("sizes", {ico.size}), key=lambda s: s[0] * s[1])
ico.size = sizes[-1]
base = ico.convert("RGBA")
print("icon frame used:", base.size)

targets = {
    "StoreLogo.png": 50,
    "Square44x44Logo.png": 44,
    "Square150x150Logo.png": 150,
    # Larger variants Windows picks for high-DPI screens and the Store tile
    "Square44x44Logo.targetsize-48.png": 48,
    "Square44x44Logo.targetsize-256.png": 256,
    "Square150x150Logo.scale-200.png": 300,
}
for name, px in targets.items():
    img = base.resize((px, px), Image.LANCZOS)
    img.save(os.path.join(out_dir, name), "PNG")
    print("wrote", name, px)
if base.size[0] < 300:
    print("NOTE: the icon's largest frame is smaller than 300 px; the 300 px logo is enlarged.")
