"""Génère les textures procédurales répétables (tileables) du bloc : peau, champ non-tissé,
vaisseaux, tissu humide, graisse en lobules, muscle, fibrine, sang.
Usage : python3 tools/gen_textures.py  (écrit dans assets/textures/)"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1234)


def pnoise(n, sigma, seed=None, aniso=(1.0, 1.0)):
    """Bruit gaussien périodique (filtrage FFT), normalisé 0..1."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * aniso[0]
    k = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * k))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def fbm(n, base_sigma, octaves=5, seed=0, gain=0.5):
    v = np.zeros((n, n))
    a, s, tot = 1.0, base_sigma, 0.0
    for o in range(octaves):
        v += a * (pnoise(n, s, seed + o) - 0.5)
        tot += a
        a *= gain
        s /= 2.0
    v = v / tot
    v -= v.min()
    return v / max(v.max(), 1e-9)


def blur(img, sigma):
    n = img.shape[0]
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    k = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(img) * k))


def warp(img, dx, dy):
    n = img.shape[0]
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + dx) % n
    y = (yy + dy) % n
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = x - x0
    fy = y - y0
    x1 = (x0 + 1) % n
    y1 = (y0 + 1) % n
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy) +
            img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nz = -dx / l, dy / l, nz / l
    return np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], -1)


def dots(n, count, rmin, rmax, seed):
    """Points arrondis (pores, points de soudure) périodiques : carte 0..1."""
    r = np.random.default_rng(seed)
    img = np.zeros((n, n))
    pts = r.random((count, 2)) * n
    rad = r.uniform(rmin, rmax, count)
    for (x, y), rr in zip(pts, rad):
        R = int(np.ceil(rr * 2.5))
        ys = np.arange(int(y) - R, int(y) + R + 1)
        xs = np.arange(int(x) - R, int(x) + R + 1)
        gx, gy = np.meshgrid(xs, ys)
        d2 = (gx - x) ** 2 + (gy - y) ** 2
        v = np.exp(-d2 / (2 * rr * rr))
        img[np.ix_(ys % n, xs % n)] = np.maximum(img[np.ix_(ys % n, xs % n)], v)
    return img


def voronoi(n, count, seed):
    """Voronoi périodique : distance au centre (F1), à la frontière (F2-F1), id de cellule."""
    r = np.random.default_rng(seed)
    pts = r.random((count, 2)) * n
    tiles = np.concatenate([pts + np.array([dx, dy]) * n for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    ids = np.tile(np.arange(count), 9)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    cid = np.zeros((n, n), np.int32)
    for (px, py), i in zip(tiles, ids):
        d = np.sqrt((xx - px) ** 2 + (yy - py) ** 2)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2 - f1, cid


def save_rgb(name, arr):
    a = np.clip(arr, 0, 1)
    Image.fromarray((a * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))
    print("écrit", name)


def save_gray(name, arr):
    a = np.clip(arr, 0, 1)
    Image.fromarray((a * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(OUT, name))
    print("écrit", name)


# ------------------------------------------------------------------ Peau (tuile ~6 cm)
def skin():
    n = 1024
    mott = fbm(n, 40, 4, 10)
    red = fbm(n, 22, 4, 20)
    pores = dots(n, 5200, 0.8, 1.7, 30)
    # Grain de la peau : réseau de sillons croisés (losanges)
    g1 = pnoise(n, 1.4, 40, aniso=(1.0, 0.18))
    g2 = pnoise(n, 1.4, 41, aniso=(0.18, 1.0))
    grain1 = warp(g1, (pnoise(n, 30, 42) - 0.5) * 40, (pnoise(n, 30, 43) - 0.5) * 40)
    grain2 = warp(g2, (pnoise(n, 30, 44) - 0.5) * 40, (pnoise(n, 30, 45) - 0.5) * 40)
    crease = np.clip(1 - np.abs(grain1 - 0.5) * 9, 0, 1) ** 2 + np.clip(1 - np.abs(grain2 - 0.5) * 9, 0, 1) ** 2
    crease = np.clip(crease * 0.6, 0, 1)
    # Fins capillaires
    cap = pnoise(n, 3, 50)
    cap = warp(cap, (pnoise(n, 20, 51) - 0.5) * 60, (pnoise(n, 20, 52) - 0.5) * 60)
    capl = np.clip(1 - np.abs(cap - 0.5) * 25, 0, 1) * (fbm(n, 30, 3, 53) > 0.55)
    base = np.array([0.80, 0.60, 0.50])
    col = np.ones((n, n, 3)) * base
    col *= (0.92 + 0.14 * mott)[..., None]
    blot = np.clip((red - 0.55) / 0.45, 0, 1) ** 1.5
    col = col * (1 - blot[..., None] * np.array([0.0, 0.10, 0.08]))
    col *= (1 - 0.13 * pores)[..., None]
    col *= (1 - 0.06 * crease)[..., None]
    col = col * (1 - capl[..., None] * np.array([0.02, 0.18, 0.15]))
    save_rgb("skin_albedo.png", col)
    h = -pores * 1.0 - crease * 0.45 + (fbm(n, 2.5, 3, 60) - 0.5) * 0.35 + (mott - 0.5) * 0.4
    save_rgb("skin_normal.png", normal_from_height(blur(h, 0.6), 2.2))
    # Rugosité : pores et sillons plus mats
    save_gray("skin_rough.png", 0.45 + 0.25 * pores + 0.12 * crease + 0.1 * (fbm(n, 6, 3, 61) - 0.5))


# ------------------------------------------------------------------ Champ non-tissé SMS (tuile ~4 cm)
def fabric():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n] / n
    # Points de soudure en losanges (motif typique des champs jetables)
    k = 22
    u = (xx + yy) * k
    v = (xx - yy) * k
    du = np.abs(u - np.round(u))
    dv = np.abs(v - np.round(v))
    bond = np.clip(1 - (du + dv) * 5.5, 0, 1)
    # Fibres : traits courts orientés au hasard
    fib = np.zeros((n, n))
    r = np.random.default_rng(70)
    for i in range(9000):
        x, y = r.random(2) * n
        a = r.random() * np.pi
        L = r.uniform(6, 22)
        t = np.linspace(-L / 2, L / 2, int(L * 2))
        px = (x + np.cos(a) * t).astype(int) % n
        py = (y + np.sin(a) * t).astype(int) % n
        fib[py, px] += r.uniform(0.3, 1.0)
    fib = blur(fib, 0.7)
    fib = fib / np.percentile(fib, 99.5)
    clump = fbm(n, 14, 3, 71)
    h = -bond * 0.9 + np.clip(fib, 0, 1.2) * 0.35 + (clump - 0.5) * 0.5
    save_rgb("fabric_normal.png", normal_from_height(blur(h, 0.5), 2.0))
    save_gray("fabric_detail.png", 0.82 + 0.1 * np.clip(fib, 0, 1) - 0.12 * bond + 0.08 * (clump - 0.5))


# ------------------------------------------------------------------ Vaisseaux + tissu humide (tuile ~8 cm)
def vessels():
    n = 1024
    def ridge(sigma, seed, wamp, width):
        b = pnoise(n, sigma, seed)
        b = warp(b, (pnoise(n, sigma * 6, seed + 1) - 0.5) * wamp, (pnoise(n, sigma * 6, seed + 2) - 0.5) * wamp)
        return np.clip(1 - np.abs(b - 0.5) * width, 0, 1)
    big = ridge(26, 80, 160, 30) ** 1.5
    mid = ridge(10, 84, 90, 26) ** 1.5 * (fbm(n, 40, 3, 88) > 0.42)
    cap = ridge(4, 90, 50, 20) ** 2 * (fbm(n, 25, 3, 94) > 0.5)
    mott = fbm(n, 30, 4, 96)
    save_rgb("vessels.png", np.stack([big, mid, cap], -1))
    h = (fbm(n, 12, 4, 100) - 0.5) * 1.0 + (fbm(n, 2.0, 2, 101) - 0.5) * 0.25 + big * 0.5 + mid * 0.25
    save_rgb("tissue_normal.png", normal_from_height(blur(h, 0.8), 3.0))
    save_gray("tissue_mottle.png", mott)


# ------------------------------------------------------------------ Graisse en lobules (tuile ~3 cm)
def fat():
    n = 512
    f1, edge, cid = voronoi(n, 70, 110)
    r = np.random.default_rng(111)
    tint = r.uniform(0.9, 1.1, 70)[cid]
    lob = np.clip(edge / 9.0, 0, 1)
    dome = np.sqrt(np.clip(lob, 0, 1))
    sub_f1, sub_edge, _ = voronoi(n, 260, 112)
    sub = np.clip(sub_edge / 4.0, 0, 1)
    col = np.ones((n, n, 3)) * np.array([0.98, 0.82, 0.38])
    col *= (0.75 + 0.25 * dome * tint)[..., None]
    col *= (0.96 + 0.04 * np.sqrt(sub))[..., None]
    septa = 1 - np.clip(edge / 2.5, 0, 1)
    col = col * (1 - septa[..., None]) + np.array([0.85, 0.45, 0.35]) * septa[..., None]
    save_rgb("fat_albedo.png", col)
    save_rgb("fat_normal.png", normal_from_height(blur(dome * 1.0 + np.sqrt(sub) * 0.12, 1.0), 6.0))


# ------------------------------------------------------------------ Muscle (fibres le long de U, tuile ~3 cm)
def muscle():
    n = 512
    f = pnoise(n, 1.6, 120, aniso=(0.04, 1.0))
    f = warp(f, (pnoise(n, 40, 121) - 0.5) * 10, (pnoise(n, 40, 122) - 0.5) * 30)
    bundles = pnoise(n, 6, 123, aniso=(0.05, 1.0))
    v = 0.6 * f + 0.4 * bundles
    save_gray("muscle.png", v)
    save_rgb("muscle_normal.png", normal_from_height(blur(v, 0.6), 4.0))


# ------------------------------------------------------------------ Fibrine / exsudat et sang
def fibrin():
    n = 512
    m = fbm(n, 18, 5, 130)
    m = np.clip((m - 0.55) / 0.2, 0, 1)
    speck = dots(n, 900, 0.8, 2.0, 131)
    save_gray("fibrin.png", np.clip(m + speck * 0.6, 0, 1))
    b = fbm(n, 22, 5, 140)
    save_gray("blood.png", b)


# ------------------------------------------------------------------ Sol vinyle moucheté (tuile 1 m) et murs
def room():
    n = 1024
    speck = dots(n, 9000, 0.6, 1.4, 150)
    speck2 = dots(n, 2500, 0.6, 1.2, 151)
    wear = fbm(n, 60, 4, 152)
    v = 0.92 + 0.08 * (fbm(n, 4, 3, 153) - 0.5) - 0.18 * speck + 0.12 * speck2
    save_gray("floor_detail.png", np.clip(v * (0.95 + 0.08 * (wear - 0.5)), 0, 1))
    save_gray("floor_rough.png", 0.2 + 0.25 * wear + 0.1 * speck)
    h = (fbm(n, 3, 3, 154) - 0.5) * 0.3 + (wear - 0.5) * 0.4
    save_rgb("floor_normal.png", normal_from_height(blur(h, 1.0), 1.0))
    save_gray("wall_detail.png", 0.94 + 0.06 * (fbm(512, 20, 4, 155) - 0.5) * 2)


if __name__ == "__main__":
    room()
    skin()
    fabric()
    vessels()
    fat()
    muscle()
    fibrin()
