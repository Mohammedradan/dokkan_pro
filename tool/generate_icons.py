#!/usr/bin/env python3
"""توليد أيقونات تطبيق دكاني (launcher icons) - سلة تسوق بيضاء على خلفية خضراء."""
from PIL import Image, ImageDraw
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
TEAL = (0, 137, 123, 255)          # خلفية
WHITE = (255, 255, 255, 255)
LEAF = (255, 224, 130, 255)        # لمسة ذهبية

def draw_basket(draw, cx, cy, scale, color):
    """سلة تسوق: جسم + مقبض + فواكه فوقها. scale = حجم السلة نسبة إلى 108."""
    w = 54 * scale   # عرض السلة
    h = 38 * scale   # ارتفاع الجسم
    x0 = cx - w / 2
    y0 = cy - h / 2
    # المقبض
    r = 16 * scale
    draw.arc([cx - r, cy - h / 2 - r + 6 * scale, cx + r, cy - h / 2 + r + 6 * scale],
             start=0, end=180, fill=color, width=max(3, int(4 * scale)))
    # جسم السلة (شبه منحرف مقلوب)
    tw = 6 * scale
    pts = [(x0 - tw, y0 + h), (x0, y0), (x0 + w, y0), (x0 + w + tw, y0 + h)]
    draw.polygon(pts, fill=color)
    # خط تقوية أفقي
    draw.line([x0 + 2 * scale, y0 + h * 0.55, x0 + w - 2 * scale, y0 + h * 0.55],
              fill=TEAL, width=max(2, int(2.5 * scale)))
    # فواكه (دوائر) فوق السلة
    fw = 7 * scale
    draw.ellipse([cx - w * 0.30 - fw / 2, y0 - fw / 2 - 2 * scale, cx - w * 0.30 + fw / 2, y0 + fw / 2 - 2 * scale], fill=color)
    draw.ellipse([cx + w * 0.30 - fw / 2, y0 - fw / 2 - 2 * scale, cx + w * 0.30 + fw / 2, y0 + fw / 2 - 2 * scale], fill=color)
    draw.ellipse([cx - fw / 2, y0 - fw / 2 - 6 * scale, cx + fw / 2, y0 + fw / 2 - 6 * scale], fill=LEAF)

def make_legacy(size, path, round_icon):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    r = size * 0.22
    if round_icon:
        draw.ellipse([0, 0, size - 1, size - 1], fill=TEAL)
    else:
        draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=TEAL)
    scale = size / 108.0
    draw_basket(draw, size / 2, size * 0.56, scale, WHITE)
    img.save(path, "PNG")

def make_foreground(size, path):
    """أيقونة تكيّفية: المحتوى داخل 66% الوسطى."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    scale = size / 108.0
    draw_basket(draw, size / 2, size * 0.55, scale * 0.92, WHITE)
    img.save(path, "PNG")

densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, factor in densities.items():
    d = os.path.join(RES, "mipmap-" + name)
    os.makedirs(d, exist_ok=True)
    s = int(48 * factor)
    make_legacy(s, os.path.join(d, "ic_launcher.png"), round_icon=False)
    make_legacy(s, os.path.join(d, "ic_launcher_round.png"), round_icon=True)
    fs = int(108 * factor)
    make_foreground(fs, os.path.join(d, "ic_launcher_foreground.png"))
    print(name, "OK", s, fs)

print("done")
