"""Build LeoCore ERP Play Store creatives (feature graphic + promo screenshots)."""
from PIL import Image, ImageDraw, ImageFilter

SP = r"C:/Users/MURTUZ~1/AppData/Local/Temp/claude/d--Antigravity-LeoCoreMobile/a4e634aa-bd3e-4eb4-a1d3-6a2db47bcae5/scratchpad/"
OUT = SP + "ads/"
F = SP + "fonts/IBMPlexSans-%s.ttf"

from PIL import ImageFont
def font(w, size):
    return ImageFont.truetype(F % w, size)

# Brand palette
OX_HI = (0x7A, 0x17, 0x28)
OX = (0x6E, 0x14, 0x23)
OX_LO = (0x48, 0x0C, 0x17)
GOLD = (0xC9, 0xA2, 0x4B)
SAND = (0xF4, 0xF1, 0xEA)
WHITE = (255, 255, 255)


def vgrad(size, top, mid, bot):
    """Vertical 3-stop gradient."""
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        if t < 0.45:
            u = t / 0.45
            c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
        else:
            u = (t - 0.45) / 0.55
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * u) for i in range(3))
        px[0, y] = c
    return img.resize(size, Image.BILINEAR)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def phone(screen_path, width, crop_bottom=None):
    """Device-framed screenshot: dark bezel + rounded screen."""
    s = Image.open(screen_path).convert("RGB")
    if crop_bottom:
        s = s.crop((0, 0, s.size[0], int(s.size[1] * crop_bottom)))
    h = int(width / s.size[0] * s.size[1])
    s = s.resize((width, h), Image.LANCZOS)
    s = rounded(s, 34)
    bez = 14
    frame = Image.new("RGBA", (width + bez * 2, h + bez * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, frame.size[0] - 1, frame.size[1] - 1], radius=48, fill=(0x0F, 0x0D, 0x0B, 255))
    frame.paste(s, (bez, bez), s)
    return frame


def shadow_paste(base, img, xy, blur=28, alpha=120, dy=14):
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    m = Image.new("L", base.size, 0)
    a = img.split()[3]
    m.paste(a, (xy[0], xy[1] + dy))
    sh.putalpha(m.filter(ImageFilter.GaussianBlur(blur)))
    black = Image.new("RGBA", base.size, (0, 0, 0, alpha))
    black.putalpha(sh.split()[3].point(lambda v: int(v * alpha / 255)))
    base.alpha_composite(black)
    base.alpha_composite(img, xy)


def mark(d, x, y, cell, gap, light=True):
    """LeoCore 2x2 logo mark."""
    r = int(cell * 0.28)
    c = WHITE if light else OX
    d.rounded_rectangle([x, y, x + cell, y + cell], radius=r, fill=c)
    d.rounded_rectangle([x, y + cell + gap, x + cell, y + 2 * cell + gap], radius=r, fill=c)
    g = int(cell * 0.8)
    x2, y2 = x + 2 * cell + gap, y + 2 * cell + gap
    d.rounded_rectangle([x2 - g, y2 - g, x2, y2], radius=int(g * 0.28), fill=GOLD)


def wrap(d, text, fnt, maxw):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=fnt) <= maxw:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def wordmark(d, x, y, size):
    fb = font("Bold", size)
    d.text((x, y), "Leo", font=fb, fill=WHITE)
    w = d.textlength("Leo", font=fb)
    d.text((x + w, y), "Core", font=fb, fill=GOLD)
    return d.textlength("LeoCore", font=fb)


# ─────────────────────────────────────────────────────────────
# Promo screenshots — 1080x1920
# ─────────────────────────────────────────────────────────────
def promo(filename, headline, sub, bullets, screen, crop_bottom=None):
    W, H = 1080, 1920
    base = vgrad((W, H), OX_HI, OX, OX_LO).convert("RGBA")
    d = ImageDraw.Draw(base)

    # brand row
    mark(d, 72, 92, 26, 8)
    wordmark(d, 150, 84, 44)

    y = 190
    fh = font("Bold", 68)
    for line in wrap(d, headline, fh, W - 144):
        d.text((72, y), line, font=fh, fill=WHITE)
        y += 82

    y += 12
    fs = font("Regular", 33)
    for line in wrap(d, sub, fs, W - 160):
        d.text((72, y), line, font=fs, fill=(255, 255, 255, 200))
        y += 46

    y += 26
    fb = font("SemiBold", 30)
    for b in bullets:
        d.ellipse([74, y + 12, 86, y + 24], fill=GOLD)
        d.text((104, y), b, font=fb, fill=(255, 255, 255, 235))
        y += 50

    # Device sits large and bleeds off the bottom edge.
    ph = phone(SP + screen, 648)
    x = (W - ph.size[0]) // 2
    shadow_paste(base, ph, (x, 706))
    base.convert("RGB").save(OUT + filename, quality=95)
    print("wrote", filename, base.size)


promo(
    "01_dashboard.png",
    "Your ERP, in your pocket",
    "Live sales, collections, receivables and stock — straight from LeoCore ERP.",
    ["Today's sales & collections", "Outstanding AR & ageing", "Low-stock alerts", "Role-based access"],
    "scr_home.png",
    crop_bottom=0.80,
)

promo(
    "02_cashsale.png",
    "Scan. Sell. Get paid.",
    "Barcode scan-to-cart with VAT, split payments and an 80mm thermal receipt.",
    ["Camera barcode scanning", "Cash sale with 10% VAT", "Split Cash / Card / Bank", "Print & share receipt"],
    "scr_invoice.png",
    crop_bottom=0.80,
)

promo(
    "03_customers.png",
    "Every customer. Every number.",
    "Statements, ageing, stock ledger and reports — wherever the work happens.",
    ["Customer 360 & ageing", "Statements with as-on date", "Stock ledger & alerts", "Sales & purchase reports"],
    "scr_customer.png",
    crop_bottom=0.80,
)


# ─────────────────────────────────────────────────────────────
# Feature graphic — 1024x500 (required, no alpha)
# ─────────────────────────────────────────────────────────────
def feature():
    W, H = 1024, 500
    base = vgrad((W, H), OX_HI, OX, OX_LO).convert("RGBA")
    d = ImageDraw.Draw(base)

    mark(d, 60, 66, 20, 6)
    wordmark(d, 118, 60, 36)

    fh = font("Bold", 52)
    y = 150
    for line in wrap(d, "Your ERP, in the field.", fh, 600):
        d.text((60, y), line, font=fh, fill=WHITE)
        y += 62

    fs = font("Regular", 25)
    y += 6
    for line in wrap(d, "Sales, stock, statements and reports — live, offline-first, BHD to the fils.", fs, 560):
        d.text((60, y), line, font=fs, fill=(255, 255, 255, 205))
        y += 34

    fb = font("SemiBold", 22)
    y += 14
    for b in ["Scan to sell", "Customer 360", "Live dashboards"]:
        d.ellipse([62, y + 9, 72, y + 19], fill=GOLD)
        d.text((86, y), b, font=fb, fill=(255, 255, 255, 235))
        y += 33

    ph = phone(SP + "scr_home.png", 250, crop_bottom=0.62)
    shadow_paste(base, ph, (W - ph.size[0] - 70, 60), blur=22, alpha=110)

    base.convert("RGB").save(OUT + "00_feature_graphic.png", quality=95)
    print("wrote 00_feature_graphic.png", base.size)


feature()
