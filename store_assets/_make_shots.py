"""Play Store phone screenshots (1080x1920, exact 9:16) for LeoCore ERP Mobile."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SP = r"C:/Users/MURTUZ~1/AppData/Local/Temp/claude/d--Antigravity-LeoCoreMobile/a4e634aa-bd3e-4eb4-a1d3-6a2db47bcae5/scratchpad/"
OUT = SP + "shots/"
F = SP + "fonts/IBMPlexSans-%s.ttf"

def font(w, s):
    return ImageFont.truetype(F % w, s)

OX_HI = (0x7A, 0x17, 0x28)
OX = (0x6E, 0x14, 0x23)
OX_LO = (0x48, 0x0C, 0x17)
GOLD = (0xC9, 0xA2, 0x4B)
WHITE = (255, 255, 255)


def vgrad(size, top, mid, bot):
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


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=r, fill=255)
    o = img.convert("RGBA")
    o.putalpha(m)
    return o


def phone(path, width):
    s = Image.open(path).convert("RGB")
    h = int(width / s.size[0] * s.size[1])
    s = rounded(s.resize((width, h), Image.LANCZOS), 36)
    bez = 14
    fr = Image.new("RGBA", (width + bez * 2, h + bez * 2), (0, 0, 0, 0))
    ImageDraw.Draw(fr).rounded_rectangle([0, 0, fr.size[0] - 1, fr.size[1] - 1], radius=50, fill=(0x0F, 0x0D, 0x0B, 255))
    fr.paste(s, (bez, bez), s)
    return fr


def shadow_paste(base, img, xy, blur=30, alpha=130, dy=16):
    m = Image.new("L", base.size, 0)
    m.paste(img.split()[3], (xy[0], xy[1] + dy))
    m = m.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha / 255))
    black = Image.new("RGBA", base.size, (0, 0, 0, 255))
    black.putalpha(m)
    base.alpha_composite(black)
    base.alpha_composite(img, xy)


def mark(d, x, y, cell, gap):
    r = int(cell * 0.28)
    d.rounded_rectangle([x, y, x + cell, y + cell], radius=r, fill=WHITE)
    d.rounded_rectangle([x, y + cell + gap, x + cell, y + 2 * cell + gap], radius=r, fill=WHITE)
    g = int(cell * 0.8)
    x2, y2 = x + 2 * cell + gap, y + 2 * cell + gap
    d.rounded_rectangle([x2 - g, y2 - g, x2, y2], radius=int(g * 0.28), fill=GOLD)


def wrap(d, t, f, mw):
    words, lines, cur = t.split(), [], ""
    for w in words:
        s = (cur + " " + w).strip()
        if d.textlength(s, font=f) <= mw:
            cur = s
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def shot(name, title, sub, screen):
    W, H = 1080, 1920
    base = vgrad((W, H), OX_HI, OX, OX_LO).convert("RGBA")
    d = ImageDraw.Draw(base)

    mark(d, 74, 92, 22, 7)
    fw = font("Bold", 38)
    d.text((140, 84), "Leo", font=fw, fill=WHITE)
    d.text((140 + d.textlength("Leo", font=fw), 84), "Core", font=fw, fill=GOLD)

    y = 188
    ft = font("Bold", 58)
    for ln in wrap(d, title, ft, W - 148):
        d.text((74, y), ln, font=ft, fill=WHITE)
        y += 70

    fs = font("Regular", 31)
    y += 6
    for ln in wrap(d, sub, fs, W - 170):
        d.text((74, y), ln, font=fs, fill=(255, 255, 255, 200))
        y += 42

    ph = phone(SP + screen, 742)
    shadow_paste(base, ph, ((W - ph.size[0]) // 2, y + 44))
    base.convert("RGB").save(OUT + name, quality=95)
    print("wrote", name, base.size)


shot("01_dashboard.png", "Live dashboard",
     "Today's sales, collections, receivables and low stock — at a glance.", "scr_home.png")

shot("02_products.png", "Find any product fast",
     "Search by name, code or barcode. Prices and stock badges built in.", "scr_products.png")

shot("03_cash_sale.png", "Sell and get paid",
     "Scan to cart, 10% VAT, split Cash / Card / Bank and change due.", "scr_invoice.png")

shot("04_customer360.png", "Customer 360",
     "Outstanding balance, ageing buckets, statements, call & navigate.", "scr_customer.png")

shot("05_reports.png", "Reports that travel",
     "Sales vs purchases, top customers and items for any date range.", "scr_reports.png")
