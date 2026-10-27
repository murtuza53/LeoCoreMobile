from PIL import Image, ImageDraw, ImageFilter
import math, os, sys

OUT = sys.argv[1]
S, SS = 1000, 4              # final size, supersample factor
W = S * SS

def bg():
    """Soft studio backdrop: warm grey, brighter behind the subject."""
    im = Image.new("RGB", (W, W), (238, 235, 228))
    g = Image.new("L", (W, W))
    d = ImageDraw.Draw(g)
    cx, cy, R = W * 0.5, W * 0.44, W * 0.62
    steps = 90
    for i in range(steps, 0, -1):
        r = R * i / steps
        v = int(255 * (1 - i / steps) ** 1.4)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=v)
    return Image.composite(Image.new("RGB", (W, W), (250, 249, 245)), im, g)

def vgrad(box, top, bot):
    """Vertical linear gradient image sized to box."""
    x0, y0, x1, y1 = box
    w, h = int(x1 - x0), int(y1 - y0)
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[c] + (bot[c] - top[c]) * t) for c in range(3)))
    return g.resize((w, h), Image.BICUBIC)

STEEL_T, STEEL_B = (176, 183, 192), (92, 100, 112)
BRASS_T, BRASS_B = (206, 178, 116), (122, 96, 48)

def paint(base, mask, box, top, bot, spec=True):
    """Fill mask with a metal gradient + a soft specular band."""
    grad = vgrad(box, top, bot)
    layer = Image.new("RGB", (W, W), (0, 0, 0))
    layer.paste(grad, (int(box[0]), int(box[1])))
    if spec:
        sh = Image.new("L", (W, W), 0)
        sd = ImageDraw.Draw(sh)
        y0, y1 = box[1], box[3]
        band = y0 + (y1 - y0) * 0.26
        sd.rectangle([box[0], band, box[2], band + (y1 - y0) * 0.13], fill=120)
        sh = sh.filter(ImageFilter.GaussianBlur(W * 0.012))
        layer = Image.composite(Image.new("RGB", (W, W), (255, 255, 255)), layer, sh)
    base.paste(layer, (0, 0), mask)

def shadow(base, mask, dy, blur, alpha):
    sh = mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha))
    shifted = Image.new("L", (W, W), 0)
    shifted.paste(sh, (0, int(dy)))
    base.paste(Image.new("RGB", (W, W), (60, 58, 54)), (0, 0), shifted)

def hole(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=0)

def finish(im, name):
    im = im.resize((S, S), Image.LANCZOS)
    im.save(os.path.join(OUT, name), "PNG", optimize=True)
    print("wrote", name)

def bracket(name, wide, holes, metal):
    base = bg()
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    t = W * (0.128 if wide else 0.110)
    ox, oy = W * 0.27, W * 0.28
    av, ah = W * (0.36 if wide else 0.44), W * (0.46 if wide else 0.36)
    d.polygon([(ox, oy), (ox + ah, oy), (ox + ah, oy + t), (ox + t, oy + t),
               (ox + t, oy + av), (ox, oy + av)], fill=255)
    for i in range(holes):                                  # holes on the long arm
        hole(d, ox + ah * (i + 1) / (holes + 1) + t * 0.22, oy + t / 2, t * 0.26)
    for i in range(max(2, holes - 1)):                      # holes on the upright
        hole(d, ox + t / 2, oy + av * (i + 1) / (max(2, holes - 1) + 1) + t * 0.30, t * 0.26)
    shadow(base, m, W * 0.022, W * 0.020, 0.34)
    paint(base, m, (ox, oy, ox + ah, oy + av), *metal)
    finish(base, name)

def bolt(name, length, nut, metal):
    base = bg()
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    cy, r, hx = W * 0.50, W * 0.115, W * 0.29
    pts = [(hx + r * math.cos(a), cy + r * math.sin(a))
           for a in (math.pi / 6 + i * math.pi / 3 for i in range(6))]
    d.polygon(pts, fill=255)
    sx, sh_ = hx + r * 0.84, W * 0.050
    d.rectangle([sx, cy - sh_, sx + length, cy + sh_], fill=255)
    d.ellipse([sx + length - sh_ * 0.5, cy - sh_, sx + length + sh_ * 0.5, cy + sh_], fill=255)
    if nut:
        d.rectangle([sx + length * 0.55, cy - sh_ * 1.5, sx + length * 0.72, cy + sh_ * 1.5], fill=255)
    shadow(base, m, W * 0.020, W * 0.018, 0.32)
    paint(base, m, (hx - r, cy - r, sx + length + sh_, cy + r), *metal)
    # thread grooves, cut as darker strokes over the shaft
    ov = base.copy()
    od = ImageDraw.Draw(ov)
    x = sx + sh_ * 1.1
    while x < sx + length - sh_ * 0.8:
        od.line([(x, cy - sh_ * 0.96), (x - sh_ * 0.52, cy + sh_ * 0.96)],
                fill=(70, 76, 86), width=int(W * 0.0075))
        x += sh_ * 0.62
    gm = Image.new("L", (W, W), 0)
    ImageDraw.Draw(gm).rectangle([sx, cy - sh_, sx + length, cy + sh_], fill=150)
    base = Image.composite(ov, base, gm)
    finish(base, name)

bracket("p_bracket40.png", False, 2, (STEEL_T, STEEL_B))
bracket("p_bracket45.png", True,  3, (STEEL_T, STEEL_B))
bolt("p_fastener28.png", W * 0.34, False, (STEEL_T, STEEL_B))
bolt("p_fastener33.png", W * 0.28, True,  (BRASS_T, BRASS_B))

# Usage:  python3 _make_product_images.py <output-dir>     (needs Pillow)
#
# Renders catalogue images for demo products on leocoredemo.seksolution.com.
# Uploaded 2026-09-24 via POST /api/mobile/v1/products/{id}/images (multipart,
# field name `images`) so the 6.9" products screenshot shows real thumbnails:
#
#   id 40  DEMO-1039  Classic Bracket 40    p_bracket40.png
#   id 45  DEMO-1044  Classic Bracket 45    p_bracket45.png
#   id 28  DEMO-1027  Classic Fastener 28   p_fastener28.png
#   id 33  DEMO-1032  Classic Fastener 33   p_fastener33.png
#
# These are synthetic renders, not photographs - no third-party image rights.
# Reversible with DELETE /api/mobile/v1/products/{id}/images/{imageId}.
