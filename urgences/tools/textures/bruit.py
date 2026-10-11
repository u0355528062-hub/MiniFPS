"""Bruits tuilables (synthèse spectrale par FFT) et utilitaires PBR.

Tout bruit obtenu par filtrage dans le domaine fréquentiel est périodique : les textures
se raccordent donc parfaitement sur leurs bords, sans traitement supplémentaire.
"""
import numpy as np
from PIL import Image

RNG = np.random.default_rng(1234)


def graine(n):
    global RNG
    RNG = np.random.default_rng(n)


def _frequences(h, w):
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    return fy, fx


def normaliser(a):
    a = a - a.min()
    m = a.max()
    return a / m if m > 0 else a


def spectral(h, w, beta=2.0, fmin=1.0, fmax=None, aniso=(1.0, 1.0)):
    """Bruit fractal 1/f^beta. aniso étire les structures (sx, sy) : sx>1 allonge en x."""
    bruit = RNG.standard_normal((h, w))
    F = np.fft.fft2(bruit)
    fy, fx = _frequences(h, w)
    f = np.sqrt((fx * w / aniso[0]) ** 2 + (fy * h / aniso[1]) ** 2)
    filtre = np.zeros_like(f)
    masque = f >= fmin
    filtre[masque] = 1.0 / f[masque] ** (beta / 2.0)
    if fmax is not None:
        filtre *= np.exp(-((f / fmax) ** 2))
    out = np.real(np.fft.ifft2(F * filtre))
    return normaliser(out)


def taches(h, w, taille, aniso=(1.0, 1.0)):
    """Bruit lisse à une échelle (gaussienne) : bon pour faire des taches/éclats par seuillage."""
    bruit = RNG.standard_normal((h, w))
    F = np.fft.fft2(bruit)
    fy, fx = _frequences(h, w)
    sx = taille * aniso[0]
    sy = taille * aniso[1]
    filtre = np.exp(-((fx * sx) ** 2 + (fy * sy) ** 2) * (np.pi ** 2) / 2.0)
    out = np.real(np.fft.ifft2(F * filtre))
    out = (out - out.mean()) / (out.std() + 1e-9)
    return out


def flou(a, sigma):
    """Flou gaussien périodique."""
    h, w = a.shape
    fy, fx = _frequences(h, w)
    filtre = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * filtre))


def lisser_seuil(a, seuil, largeur):
    return np.clip((a - seuil) / max(largeur, 1e-6), 0.0, 1.0)


def normale_depuis_hauteur(hauteur, force=1.0):
    """Carte de normales (convention OpenGL, Y+ vers le haut, comme Godot) depuis une hauteur."""
    dx = (np.roll(hauteur, -1, axis=1) - np.roll(hauteur, 1, axis=1)) * 0.5
    dy = (np.roll(hauteur, -1, axis=0) - np.roll(hauteur, 1, axis=0)) * 0.5
    nx = -dx * force
    ny = dy * force
    nz = np.ones_like(hauteur)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], axis=-1)
    return n * 0.5 + 0.5


def ao_depuis_hauteur(hauteur, rayon=6.0, force=1.0):
    """Occlusion approximative : creux = plus sombre que leur voisinage flouté."""
    moyen = flou(hauteur, rayon)
    cav = np.clip((moyen - hauteur) * force, 0.0, 1.0)
    return 1.0 - cav


def melanger(a, b, t):
    t = t[..., None] if (np.ndim(t) == 2 and np.ndim(a) == 3) else t
    return a * (1 - t) + b * t


def couleur(hexa):
    hexa = hexa.lstrip("#")
    return np.array([int(hexa[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def srgb_vers_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_vers_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def sauver_rgb(chemin, rgb, qualite=93):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    if chemin.endswith(".jpg"):
        img.save(chemin, quality=qualite, subsampling=0)
    else:
        img.save(chemin, optimize=True)


def sauver_orm(chemin, ao, rugosite, metal):
    """Texture ORM de Godot : R = occlusion, G = rugosité, B = métal."""
    sauver_rgb(chemin, np.stack([ao, rugosite, metal], axis=-1))


def sauver_normale(chemin, n):
    sauver_rgb(chemin, n)
