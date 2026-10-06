"""Renders the 1024x1024 app icon: a coral usage gauge around a Claude-style spark."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # supersampled, downscaled at the end
img = Image.new("RGB", (S, S))
px = img.load()

# Warm dark radial gradient background.
top, bottom = (58, 40, 32), (16, 12, 11)
cx, cy = S * 0.5, S * 0.38
maxd = math.hypot(S, S) * 0.62
grad = Image.new("RGB", (512, 512))
gp = grad.load()
for y in range(512):
    for x in range(512):
        d = min(1.0, math.hypot(x * 8 - cx, y * 8 - cy) / maxd)
        t = d ** 1.2
        gp[x, y] = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
img = grad.resize((S, S), Image.BICUBIC)

c = S / 2
R = S * 0.33
W = S * 0.075
coral = (217, 119, 87)
peach = (245, 168, 128)

# Track ring.
track = Image.new("L", (S, S), 0)
ImageDraw.Draw(track).ellipse([c - R - W / 2, c - R - W / 2, c + R + W / 2, c + R + W / 2], fill=255)
ImageDraw.Draw(track).ellipse([c - R + W / 2, c - R + W / 2, c + R - W / 2, c + R - W / 2], fill=0)
img.paste((70, 52, 44), (0, 0), track)

# Progress arc (~72%), gradient coral -> peach, round caps.
start, sweep = -90.0, 0.72 * 360
arc = Image.new("RGB", (S, S))
arcmask = Image.new("L", (S, S), 0)
ad = ImageDraw.Draw(arc)
md = ImageDraw.Draw(arcmask)
steps = 720
for i in range(steps):
    a = math.radians(start + sweep * i / steps)
    t = i / steps
    col = tuple(int(coral[k] * (1 - t) + peach[k] * t) for k in range(3))
    x, y = c + R * math.cos(a), c + R * math.sin(a)
    ad.ellipse([x - W / 2, y - W / 2, x + W / 2, y + W / 2], fill=col)
    md.ellipse([x - W / 2, y - W / 2, x + W / 2, y + W / 2], fill=255)

# Soft glow under the arc.
glow = arcmask.filter(ImageFilter.GaussianBlur(S * 0.03)).point(lambda v: int(v * 0.55))
img.paste(coral, (0, 0), glow)
img.paste(arc, (0, 0), arcmask)

# Claude-style spark: rounded rays radiating from the center.
spark = Image.new("L", (S, S), 0)
sd = ImageDraw.Draw(spark)
rays = 12
for i in range(rays):
    a = math.radians(i * 360 / rays + 7 * (i % 3))
    L = S * (0.165 if i % 2 == 0 else 0.13)
    w = S * 0.034
    for j in range(80):
        t = j / 79
        r = S * 0.02 + L * t
        ww = w * (1 - 0.35 * t)
        x, y = c + r * math.cos(a), c + r * math.sin(a)
        sd.ellipse([x - ww / 2, y - ww / 2, x + ww / 2, y + ww / 2], fill=255)
sd.ellipse([c - S * 0.045, c - S * 0.045, c + S * 0.045, c + S * 0.045], fill=255)
img.paste((250, 236, 226), (0, 0), spark)

img.resize((1024, 1024), Image.LANCZOS).save(sys.argv[1])
