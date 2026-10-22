"""Render iPhone-only App Store creative assets from existing PayJoy artwork."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
HOME = ROOT / "marketing/xiaohongshu/app-screens/home.png"
WIDGETS = ROOT / "marketing/xiaohongshu/app-screens/widgets.png"
MASCOT = ROOT / "PayJoy/Assets.xcassets/classic_overtime_summary_worker_v1.imageset/classic_overtime_summary_worker_v1.png"
ICON = ROOT / "PayJoy/Assets.xcassets/AppIcon.appiconset/app_icon_draft_1024.png"
CUTOUT = OUT / "brand-mascot-cutout.png"
LETTERING = ROOT / "PayJoy/Assets.xcassets/home_header_lettering_v1.imageset/home_header_lettering_v1.png"
SEARCH_SCREEN = OUT / "search-right-iphone-source.png"

NAVY = "#10243B"
YELLOW = "#FFD746"
WHITE = "#FFF9E8"


def font(size):
    return ImageFont.truetype(FONT, size)


def background(size):
    width, height = size
    canvas = Image.new("RGBA", size, NAVY)
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((width * .28, -height * .95, width * 1.18, height * .85), fill="#183754")
    draw.ellipse((width * .58, height * .15, width * 1.12, height * 1.28), fill=YELLOW)
    draw.ellipse((-width * .18, height * .79, width * .20, height * 1.58), fill="#173552")
    return canvas, draw


def paste_mascot(canvas, x, y, width, height):
    art = Image.open(MASCOT).convert("RGBA").resize((width, height), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", canvas.size)
    shadow.alpha_composite(art, (x + 24, y + 35))
    alpha = shadow.getchannel("A").filter(ImageFilter.GaussianBlur(45))
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade.putalpha(alpha.point(lambda a: int(a * .32)))
    canvas.alpha_composite(shade)
    canvas.alpha_composite(art, (x, y))


def phone(canvas, source, x, y, width):
    original = Image.open(source)
    height = round(width * original.height / original.width)
    size = (width + 36, height + 36)
    device = Image.new("RGBA", size)
    draw = ImageDraw.Draw(device)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=112, fill="#8E969A")
    draw.rounded_rectangle((8, 8, size[0] - 9, size[1] - 9), radius=106, fill="#101318")
    screen = original.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=88, fill=255)
    device.paste(screen, (18, 18), mask)
    shadow = Image.new("RGBA", canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x + 35, y + 47, x + size[0] + 35, y + size[1] + 47), radius=112, fill=(0, 0, 0, 95))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(58)))
    canvas.alpha_composite(device, (x, y))


def header():
    canvas = Image.new("RGBA", (3840, 1646), "#FFD33D")
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((1760, -300, 3880, 1820), fill="#FFE998")
    draw.ellipse((1930, -130, 3710, 1650), outline="#FFDA62", width=24)
    draw.ellipse((-510, 1260, 610, 2380), fill="#FFC629")
    draw.rounded_rectangle((0, 1550, 3840, 1646), radius=0, fill="#FFC629")

    lettering = Image.open(LETTERING).convert("RGBA").resize((1370, 885), Image.Resampling.LANCZOS)
    canvas.alpha_composite(lettering, (265, 430))
    mascot = Image.open(CUTOUT).convert("RGBA").resize((1810, 1810), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", canvas.size)
    shadow.alpha_composite(mascot, (1950, 80))
    alpha = shadow.getchannel("A").filter(ImageFilter.GaussianBlur(55))
    shade = Image.new("RGBA", canvas.size)
    shade.putalpha(alpha.point(lambda a: int(a * .18)))
    canvas.alpha_composite(shade)
    canvas.alpha_composite(mascot, (1910, 25))
    path = OUT / "header-zh-Hans-3840x1646.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def search():
    canvas = Image.new("RGBA", (3840, 2560), "#FFD33D")
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((1900, -280, 4430, 2850), fill="#FFE998")
    draw.ellipse((2070, -90, 4260, 2660), outline="#FFDA62", width=24)
    draw.ellipse((-440, 2050, 620, 3110), fill="#FFC629")

    lettering = Image.open(LETTERING).convert("RGBA").resize((1440, 929), Image.Resampling.LANCZOS)
    canvas.alpha_composite(lettering, (230, 330))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((245, 1508, 1530, 1700), radius=96, fill="#FFF8E8")
    draw.rounded_rectangle((245, 1770, 1530, 1962), radius=96, fill="#FFF8E8")
    draw.ellipse((304, 1573, 364, 1633), fill="#FFD33D")
    draw.ellipse((304, 1835, 364, 1895), fill="#FFD33D")
    draw.text((412, 1549), "实时工资进度", font=font(93), fill="#1C1C1C")
    draw.text((412, 1811), "下班倒计时", font=font(93), fill="#1C1C1C")
    phone(canvas, SEARCH_SCREEN, 2360, 85, 1100)
    path = OUT / "search-results-zh-Hans-3840x2560.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    paths = [header(), search()]
    manifest = {
        "source_images": [str(path.relative_to(ROOT)) for path in (ICON, LETTERING, HOME, WIDGETS, MASCOT)] + [CUTOUT.name, SEARCH_SCREEN.name],
        "assets": [{"file": path.name, "size": Image.open(path).size, "mode": Image.open(path).mode} for path in paths],
        "note": "Simplified Chinese creative assets using existing iPhone UI and classic theme illustration. Review in App Store Connect Preview before submission.",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    for path in paths:
        print(path)
