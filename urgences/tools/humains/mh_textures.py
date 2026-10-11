"""Peinture procédurale en espace UV du maillage MakeHuman (peau, vêtements).

Principe : on rastérise chaque triangle du corps dans la texture en interpolant des attributs
par sommet (position 3D de repos, normale, masques de régions). On peint ensuite avec des
fonctions de l'espace 3D (bruits 3D, distances aux articulations) : pas de couture visible.
"""
import numpy as np
from scipy import ndimage

from mh_donnees import base, cible, articulations, morpher


# ---------------------------------------------------------------------------------------------
def rasteriser(taille, uv_tris, attrs):
    """uv_tris : (T, 3, 2) ; attrs : (T, 3, K). Renvoie image (H, W, K), masque (H, W)."""
    H = W = taille
    K = attrs.shape[2]
    img = np.zeros((H, W, K), dtype=np.float32)
    masque = np.zeros((H, W), dtype=bool)
    P = np.empty_like(uv_tris)
    P[..., 0] = uv_tris[..., 0] * W - 0.5
    P[..., 1] = (1.0 - uv_tris[..., 1]) * H - 0.5
    for t in range(len(P)):
        p = P[t]
        x0 = max(int(np.floor(p[:, 0].min())), 0)
        x1 = min(int(np.ceil(p[:, 0].max())), W - 1)
        y0 = max(int(np.floor(p[:, 1].min())), 0)
        y1 = min(int(np.ceil(p[:, 1].max())), H - 1)
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        a, b, c = p
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l3 = 1 - l1 - l2
        dedans = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not dedans.any():
            continue
        yy, xx = ys[dedans], xs[dedans]
        v = l1[dedans, None] * attrs[t, 0] + l2[dedans, None] * attrs[t, 1] + l3[dedans, None] * attrs[t, 2]
        img[yy, xx] = v
        masque[yy, xx] = True
    return img, masque


def dilater(img, masque):
    """Étend les îlots UV (remplit les vides par le texel couvert le plus proche) : pas de
    liseré sombre aux coutures quand les mipmaps mélangent les texels."""
    _, (iy, ix) = ndimage.distance_transform_edt(~masque, return_indices=True)
    return img[iy, ix]


# ---------------------------------------------------------------------------------------------
def bruit3d(p, freq, octaves=4, graine=0, persistance=0.5):
    """Bruit de valeur fractal 3D (vectorisé), p : (N, 3). Renvoie (N,) dans ~[-1, 1]."""
    total = np.zeros(len(p), dtype=np.float32)
    amp = 1.0
    norme = 0.0
    for o in range(octaves):
        q = p * freq * (2.0 ** o)
        i = np.floor(q).astype(np.int64)
        f = q - i
        f = f * f * (3 - 2 * f)

        def h(dx, dy, dz):
            n = (i[:, 0] + dx) * 73856093 ^ (i[:, 1] + dy) * 19349663 ^ (i[:, 2] + dz) * 83492791 ^ (graine + o) * 2654435761
            n = (n ^ (n >> 13)) * 1274126177
            return ((n & 0xFFFF).astype(np.float32) / 32767.5) - 1.0

        c000, c100, c010, c110 = h(0, 0, 0), h(1, 0, 0), h(0, 1, 0), h(1, 1, 0)
        c001, c101, c011, c111 = h(0, 0, 1), h(1, 0, 1), h(0, 1, 1), h(1, 1, 1)
        x, y, z = f[:, 0], f[:, 1], f[:, 2]
        v = (((c000 * (1 - x) + c100 * x) * (1 - y) + (c010 * (1 - x) + c110 * x) * y) * (1 - z)
             + ((c001 * (1 - x) + c101 * x) * (1 - y) + (c011 * (1 - x) + c111 * x) * y) * z)
        total += v * amp
        norme += amp
        amp *= persistance
    return total / norme


def normale_depuis_hauteur(h, force):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    n = np.stack([-dx * force, dy * force, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def bruit_uv(taille, sigma, graine):
    """Bruit fin en espace UV (pores, grain) : gaussienne filtrée."""
    r = np.random.default_rng(graine)
    return ndimage.gaussian_filter(r.standard_normal((taille, taille)).astype(np.float32), sigma, mode="wrap")


# ---------------------------------------------------------------------------------------------
def masque_cible(chemin, puissance=0.7, n_sommets=None):
    """Poids par sommet d'une région définie par une morphose (amplitude normalisée)."""
    b = base()
    n = n_sommets or len(b.v)
    w = np.zeros(n, dtype=np.float32)
    t = cible(chemin)
    if t is None:
        return w
    m = np.linalg.norm(t[1], axis=1)
    m = (m / m.max()) ** puissance
    ok = t[0] < n
    w[t[0][ok]] = np.maximum(w[t[0][ok]], m[ok])
    return w


def normales_sommets(co, faces):
    n = np.zeros_like(co)
    a, b_, c, d = (co[faces[:, i]] for i in range(4))
    fn = np.cross(c - a, d - b_)
    for i in range(4):
        np.add.at(n, faces[:, i], fn)
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    return n


class Atlas:
    """Rastérisation du corps (groupe « body ») avec attributs : position neutre (m), normale,
    régions. Calculée une fois et réutilisée pour toutes les textures (peau, vêtements)."""

    def __init__(self, taille=2048, regions=None):
        b = base()
        self.taille = taille
        co = morpher({}) * 0.1  # neutre, en mètres
        self.co = co
        self.art = {k: v * 0.1 for k, v in articulations(morpher({})).items()}
        fidx = b.faces_groupe("body")
        faces = b.faces[fidx]
        fuv = b.fuv[fidx]
        nrm = normales_sommets(co, faces)
        regions = regions or {}
        self.noms_regions = list(regions)
        attr_v = [co, nrm] + [regions[k][:, None] for k in self.noms_regions]
        attr_v = np.concatenate(attr_v, axis=1).astype(np.float32)
        # Quads -> triangles.
        tris = np.concatenate([faces[:, [0, 1, 2]], faces[:, [0, 2, 3]]])
        tuv = np.concatenate([fuv[:, [0, 1, 2]], fuv[:, [0, 2, 3]]])
        uv_tris = b.vt[tuv]
        attrs = attr_v[tris]
        img, self.masque = rasteriser(taille, uv_tris, attrs)
        self.distance_bord = ndimage.distance_transform_edt(self.masque)
        img = dilater(img, self.masque)
        self.pos = img[..., 0:3]
        self.nrm = img[..., 3:6]
        self.reg = {k: img[..., 6 + i] for i, k in enumerate(self.noms_regions)}
        self.p_flat = self.pos.reshape(-1, 3)

    def b3(self, freq, octaves=4, graine=0, persistance=0.5):
        t = self.taille
        return bruit3d(self.p_flat, freq, octaves, graine, persistance).reshape(t, t)

    def dist(self, point):
        return np.linalg.norm(self.pos - np.asarray(point)[None, None, :], axis=-1)

    def art_m(self, nom):
        return self.art[nom]
