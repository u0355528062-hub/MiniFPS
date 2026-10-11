"""Textures des tenues dans l'atlas UV du corps (partagées par tous les personnages).

Coutures aux bords des îlots UV (ce sont les vraies coutures du patron), poches et ourlets
placés en 3D sur l'humain neutre, tissage fin et plis aux articulations.
"""
import numpy as np
from scipy import ndimage

from mh_textures import normale_depuis_hauteur, bruit_uv
from peau import atlas, _ss


def _tissage(T, pas=3.0, graine=0, serge=True):
    y, x = np.mgrid[0:T, 0:T].astype(np.float32)
    if serge:
        t = 0.5 + 0.5 * np.sin((x + y) * 2 * np.pi / pas)
    else:
        t = 0.5 + 0.25 * np.sin(x * 2 * np.pi / pas) + 0.25 * np.sin(y * 2 * np.pi / pas)
    return t + 0.15 * bruit_uv(T, 0.6, graine)


def peindre_tenue(nom, taille=2048, graine=5):
    A = atlas(taille)
    T = A.taille
    pos = A.pos
    art = A.art
    y = pos[..., 1]
    spec = TENUES[nom]
    coul = np.array(spec["couleur"]) ** 2.2
    alb = np.ones((T, T, 3), np.float32) * coul
    # Variation de teinte douce (lavages) et plis.
    v = A.b3(4.0, 4, graine)
    alb *= (1 + 0.05 * v)[..., None]
    plis = A.b3(14.0, 3, graine + 1)
    # Plis plus marqués aux coudes, genoux, aisselles, entrejambe.
    zones_plis = np.zeros((T, T), np.float32)
    for j, r in (("lowerarm01.L____head", 0.08), ("lowerarm01.R____head", 0.08), ("lowerleg01.L____head", 0.10),
                 ("lowerleg01.R____head", 0.10), ("upperarm01.L____head", 0.09), ("upperarm01.R____head", 0.09),
                 ("pelvis.L____tail", 0.12), ("pelvis.R____tail", 0.12)):
        if j in art:
            zones_plis += np.exp(-(A.dist(art[j]) / r) ** 2)
    pl = A.b3(30.0, 2, graine + 2)
    haut = 0.6 * plis + 1.2 * np.clip(zones_plis, 0, 1) * pl
    # Tissage.
    tis = _tissage(T, spec.get("pas", 3.0), graine, spec.get("serge", True))
    haut_fin = tis * spec.get("relief", 0.6)
    alb *= (0.94 + 0.08 * tis)[..., None]
    # Coutures : aux bords des îlots UV, double surpiqûre.
    d = A.distance_bord
    couture = np.exp(-((d - 5.0) / 1.2) ** 2) + 0.7 * np.exp(-((d - 9.0) / 0.8) ** 2)
    pointilles = 0.5 + 0.5 * np.sign(np.sin((np.arange(T)[None, :] + np.arange(T)[:, None]) * 0.9))
    haut_fin -= 1.5 * np.exp(-((d - 2.0) / 1.5) ** 2)
    if "fil" in spec:
        fil = np.array(spec["fil"]) ** 2.2
        m = np.clip(couture * pointilles * 0.8, 0, 1)
        alb = alb * (1 - m[..., None]) + fil * m[..., None]
    # Poche poitrine gauche (côté gauche du personnage = x positif).
    if spec.get("poche"):
        c = art["breast.L____head"]
        dx = pos[..., 0] - (c[0] - 0.01)
        dy = y - (c[1] + 0.05)
        dev = pos[..., 2] > c[2] - 0.05
        bord = np.maximum(np.abs(dx) / 0.065, np.abs(dy) / 0.075)
        dans = (bord < 1.0) & dev
        cad = dev & (np.abs(bord - 1.0) < 0.06)
        haut += np.where(dans, 0.35, 0.0) - 0.8 * cad
        alb *= np.where(cad[..., None], 0.85, 1.0)
    # Bandes horizontales (tenues de secours : bandes rétroréfléchissantes aux bras et au torse).
    if "bandes" in spec:
        bc = np.array(spec["bandes"]) ** 2.2
        torse_y = art["breast.L____head"][1] - 0.04
        b = (np.abs(y - torse_y) < 0.025).astype(np.float32)
        for c in ("L", "R"):
            coude = art["lowerarm01.%s____head" % c][1]
            b += (np.abs(y - (coude - 0.05)) < 0.02) * (np.abs(pos[..., 0]) > abs(art["upperarm01.%s____head" % c][0]) + 0.02)
        genou = art["lowerleg01.L____head"][1]
        b += (np.abs(y - (genou - 0.12)) < 0.022) * (y < art["pelvis.L____tail"][1] - 0.2)
        b = np.clip(ndimage.gaussian_filter(b, 1.0), 0, 1)
        alb = alb * (1 - b[..., None]) + bc * b[..., None]
    # Logo / texte au dos (ex. « SAMU », « URGENCES »).
    rug = np.clip(spec.get("rug", 0.85) + 0.05 * tis - 0.05 * v, 0.3, 1.0)
    nrm = normale_depuis_hauteur(haut_fin + 6.0 * haut, 1.0)
    ao = np.clip(1.0 - 0.25 * np.clip(-pl * zones_plis, 0, 1), 0.7, 1.0)
    orm = np.stack([ao, rug, np.zeros_like(rug)], -1)
    return np.clip(alb, 0, 1) ** (1 / 2.2), nrm, orm


def peindre_cheveux(couleur, taille=1024, graine=7):
    """Texture de calotte de cheveux : mèches orientées (du front vers la nuque)."""
    A = atlas(2048)
    T = 2048
    pos = A.pos
    art = A.art
    tete = art["head____head"]
    # Direction des mèches : on paramètre par l'angle autour de la tête, les mèches suivent
    # les méridiens -> bruit très étiré le long de la coordonnée « méridien ».
    rel = pos - tete[None, None, :]
    lon = np.arctan2(rel[..., 0], rel[..., 2])
    lat = np.arctan2(rel[..., 1], np.hypot(rel[..., 0], rel[..., 2]))
    rng = np.random.default_rng(graine)
    # Bruit indexé (longitude fine, latitude grossière) : mèches.
    from mh_textures import bruit3d
    q = np.stack([lon * 60.0, lat * 4.0, np.zeros_like(lon)], -1).reshape(-1, 3)
    meches = bruit3d(q, 1.0, 4, graine).reshape(T, T)
    meches2 = bruit3d(q * np.array([2.3, 1.5, 1]), 1.0, 3, graine + 1).reshape(T, T)
    c = np.array(couleur) ** 2.2
    alb = c[None, None, :] * (0.65 + 0.35 * (0.5 + 0.5 * meches))[..., None]
    alb *= (0.85 + 0.25 * (0.5 + 0.5 * meches2))[..., None]
    haut = meches * 0.6 + meches2 * 0.4
    nrm = normale_depuis_hauteur(haut.astype(np.float32), 3.0)
    rug = np.clip(0.42 + 0.15 * meches2, 0.25, 0.8)
    orm = np.stack([np.ones_like(rug), rug, np.zeros_like(rug)], -1)
    # Lisière irrégulière : alpha qui s'estompe sous la ligne des cheveux (petites mèches).
    from vetements import ligne_cheveux
    lim, _ = ligne_cheveux(A.p_flat, art)
    marge = pos[..., 1] - lim.reshape(T, T)
    franges = 0.004 * meches + 0.003 * bruit3d(A.p_flat * 3.0, 90.0, 2, graine + 4).reshape(T, T)
    alpha = np.clip((marge + franges + 0.002) / 0.006, 0, 1)
    alb = np.concatenate([np.clip(alb, 0, 1) ** (1 / 2.2), alpha[..., None]], -1)
    # Assombrit les racines près de la lisière (épaisseur visible).
    return alb, nrm, orm


TENUES = {
    "tenue_pompier": {"couleur": (0.10, 0.13, 0.22), "fil": (0.08, 0.10, 0.18), "poche": True, "bandes": (0.95, 0.85, 0.1)},
    "tenue_samu": {"couleur": (0.90, 0.91, 0.92), "fil": (0.2, 0.35, 0.65), "poche": True, "bandes": (0.15, 0.30, 0.65)},
    "pyjama_bleu": {"couleur": (0.36, 0.55, 0.78), "fil": (0.30, 0.47, 0.70), "poche": True},
    "pyjama_vert": {"couleur": (0.33, 0.62, 0.55), "fil": (0.28, 0.53, 0.47), "poche": True},
    "pyjama_bordeaux": {"couleur": (0.50, 0.16, 0.24), "fil": (0.42, 0.12, 0.2), "poche": True},
    "pyjama_blanc": {"couleur": (0.90, 0.91, 0.92), "fil": (0.80, 0.82, 0.85), "poche": True},
    "blouse_blanche": {"couleur": (0.93, 0.94, 0.95), "fil": (0.85, 0.86, 0.88), "poche": True, "rug": 0.75},
    "blouse_patient": {"couleur": (0.62, 0.74, 0.82), "fil": (0.55, 0.66, 0.75), "serge": False},
    "jean": {"couleur": (0.17, 0.25, 0.40), "fil": (0.75, 0.55, 0.25), "pas": 2.5},
    "tshirt_gris": {"couleur": (0.45, 0.46, 0.48), "serge": False, "pas": 2.0, "relief": 0.4},
    "tshirt_rouge": {"couleur": (0.65, 0.12, 0.12), "serge": False, "pas": 2.0, "relief": 0.4},
    "pull_marine": {"couleur": (0.12, 0.16, 0.28), "serge": False, "pas": 4.0, "relief": 1.0},
    "pantalon_beige": {"couleur": (0.62, 0.55, 0.42), "fil": (0.55, 0.48, 0.36)},
    "sabots_blancs": {"couleur": (0.92, 0.92, 0.92), "rug": 0.35, "relief": 0.1},
    "baskets_noires": {"couleur": (0.08, 0.08, 0.09), "rug": 0.6, "relief": 0.3},
    "chaussures_marron": {"couleur": (0.25, 0.14, 0.08), "rug": 0.4, "relief": 0.1},
}
