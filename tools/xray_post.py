"""Finition des radios (après tools/blender/build_xray.py) : courbe du film (atténuation
exponentielle), flou de diffusion, grain, repère « D ». Usage :
    /home/user/bpyenv/bin/python tools/xray_post.py /tmp/xray_mu.npy assets/textures/radio_normale.png"""
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

mu = np.load(sys.argv[1])
mu = np.asarray(Image.fromarray(mu.astype(np.float32), mode="F").resize((mu.shape[1] * 2, mu.shape[0] * 2), Image.BICUBIC))
dst = sys.argv[2]
k = float(sys.argv[3]) if len(sys.argv) > 3 else 9.0
a = 1.0 - np.exp(-k * np.clip(mu, 0, None))
a = np.clip((a - 0.28) / 0.72, 0, 1) ** 1.15
img = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.3))
a = np.asarray(img).astype(np.float32) / 255.0
rng = np.random.default_rng(3)
a = a + rng.normal(0, 0.02, a.shape) * (0.4 + a)
h, w = a.shape
yy, xx = np.mgrid[0:h, 0:w]
vig = 1.0 - 0.18 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
a = np.clip(a * vig, 0, 1)
img = Image.fromarray((a * 255).astype(np.uint8)).convert("RGB")
d = ImageDraw.Draw(img)
try:
    f = ImageFont.truetype("assets/fonts/Inter.ttf", 46)
except Exception:
    f = None
d.text((30, 24), "D", fill=(235, 235, 235), font=f)
img.save(dst)
print("RADIO", dst)
