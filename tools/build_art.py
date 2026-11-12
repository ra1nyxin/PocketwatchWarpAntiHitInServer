"""Build the recolored watch assets from a local DST installation and Stex."""
import argparse
import colorsys
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from PIL import Image


def recolor(image):
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if a and .07 <= h <= .23 and s >= .22 and v >= .12:
                r, g, b = colorsys.hsv_to_rgb(.99, min(1, s * 1.12), v * .84)
                pixels[x, y] = (round(r * 255), round(g * 255), round(b * 255), a)
    return image


def convert(stex, mode, source, dest):
    options = ["-f", "rgba"] if mode == "compress" else []
    subprocess.run([str(stex), mode, "-i", str(source), "-o", str(dest), *options], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("game_data", type=Path)
    parser.add_argument("stex", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        with zipfile.ZipFile(args.game_data / "anim/pocketwatch_warp.zip") as source:
            build = source.read("build.bin")
            (tmp / "original.tex").write_bytes(source.read("atlas-0.tex"))
        old_name, new_name = b"pocketwatch_warp", b"pocketwatch_bloodbound"
        assert build[:4] == b"BILD" and struct.unpack_from("<I", build, 16)[0] == len(old_name)
        assert build[20:20 + len(old_name)] == old_name
        build = build[:16] + struct.pack("<I", len(new_name)) + new_name + build[20 + len(old_name):]
        convert(args.stex, "decompress", tmp / "original.tex", tmp / "animation.png")
        recolor(Image.open(tmp / "animation.png")).save(tmp / "red.png")
        convert(args.stex, "compress", tmp / "red.png", tmp / "atlas-0.tex")
        (root / "anim").mkdir(exist_ok=True)
        with zipfile.ZipFile(root / "anim/pocketwatch_bloodbound.zip", "w", zipfile.ZIP_DEFLATED) as out:
            out.writestr("build.bin", build)
            out.write(tmp / "atlas-0.tex", "atlas-0.tex")

        with zipfile.ZipFile(args.game_data / "databundles/images.zip") as source:
            xml = ET.fromstring(source.read("images/inventoryimages3.xml"))
            element = next(e for e in xml.iter("Element") if e.get("name") == "pocketwatch_warp.tex")
            (tmp / "inventory.tex").write_bytes(source.read("images/inventoryimages3.tex"))
        convert(args.stex, "decompress", tmp / "inventory.tex", tmp / "inventory.png")
        atlas = Image.open(tmp / "inventory.png")
        u1, u2, v1, v2 = (float(element.get(k)) for k in ("u1", "u2", "v1", "v2"))
        box = (round(u1 * atlas.width), round((1-v2) * atlas.height), round(u2 * atlas.width), round((1-v1) * atlas.height))
        icon = recolor(atlas.crop(box))
        # Original atlas elements are 63 pixels wide; place them in a power-of-two texture.
        image = Image.new("RGBA", (64, 64))
        image.alpha_composite(icon, ((64-icon.width)//2, (64-icon.height)//2))
        image.save(tmp / "icon.png")
        (root / "images/inventoryimages").mkdir(parents=True, exist_ok=True)
        convert(args.stex, "compress", tmp / "icon.png", root / "images/inventoryimages/pocketwatch_bloodbound.tex")
        (root / "images/inventoryimages/pocketwatch_bloodbound.xml").write_text(
            '<Atlas><Texture filename="pocketwatch_bloodbound.tex"/><Elements><Element name="pocketwatch_bloodbound.tex" u1="0" u2="1" v1="0" v2="1"/></Elements></Atlas>\n', encoding="utf-8")


if __name__ == "__main__":
    main()
