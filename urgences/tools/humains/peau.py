"""Textures de peau procédurales (albedo, normale, ORM) dans l'atlas UV MakeHuman."""
import numpy as np
from scipy import ndimage

from mh_donnees import base
from mh_textures import Atlas, masque_cible, normale_depuis_hauteur, bruit_uv

# Teintes de base (sRGB linéarisé plus loin) du plus clair au plus foncé.
TEINTES = {
    "tres_claire": (0.90, 0.71, 0.60),
    "claire": (0.84, 0.63, 0.51),
    "moyenne": (0.78, 0.57, 0.43),
    "mate": (0.66, 0.46, 0.32),
    "brune": (0.47, 0.31, 0.21),
    "foncee": (0.30, 0.19, 0.13),
}


def _ss(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


_ATLAS = {}


def atlas(taille=2048):
    if taille not in _ATLAS:
        b = base()
        n = len(b.v)
        reg = {
            "levres": np.maximum(masque_cible("mouth/mouth-lowerlip-volume-incr", 1.4),
                                 masque_cible("mouth/mouth-upperlip-volume-incr", 1.4)),
            "sourcils": masque_cible("eyebrows/eyebrows-trans-up", 1.2),
            "joues": np.maximum(masque_cible("cheek/l-cheek-volume-incr", 0.8), masque_cible("cheek/r-cheek-volume-incr", 0.8)),
            "nez": masque_cible("nose/nose-volume-incr", 0.8),
            "oreilles": np.maximum(masque_cible("ears/l-ear-scale-incr", 0.5), masque_cible("ears/r-ear-scale-incr", 0.5)),
            "cernes": np.maximum(masque_cible("eyes/l-eye-bag-incr", 1.0), masque_cible("eyes/r-eye-bag-incr", 1.0)),
            "paupieres": np.maximum(masque_cible("eyes/l-eye-eyefold-down", 1.0), masque_cible("eyes/r-eye-eyefold-down", 1.0)),
        }
        _ATLAS[taille] = Atlas(taille, reg)
    return _ATLAS[taille]


def peindre_peau(p, taille=2048, graine=1):
    """p : teinte, genre (0..1), age (0..1), barbe (0..1), rousseurs (0..1), rougeur (0..1)."""
    A = atlas(taille)
    rng = np.random.default_rng(graine)
    T = A.taille
    teinte = np.array(TEINTES.get(p.get("teinte", "claire"), p.get("teinte")) if isinstance(p.get("teinte"), str) else p.get("teinte", TEINTES["claire"]))
    lin = teinte ** 2.2
    homme = p.get("genre", 0.5) > 0.5
    age = p.get("age", 0.5)
    sombre = 1.0 - float(np.mean(teinte))
    alb = np.ones((T, T, 3), dtype=np.float32) * lin[None, None, :]
    pos = A.pos
    art = A.art
    tete = art["head____head"]
    yeux_y = 0.5 * (art["eye.L____head"][1] + art["eye.R____head"][1])
    menton = art["jaw____tail"]
    dans_tete = _ss(pos[..., 1], tete[1] - 0.02, tete[1] + 0.03)

    # --- Variations globales (bruits 3D : aucune couture) ----------------------------------
    marbrure = A.b3(9.0, 4, graine)
    alb *= (1.0 + 0.07 * marbrure)[..., None]
    teinte_var = A.b3(3.0, 3, graine + 7)
    rouge = np.array([1.06, 0.97, 0.96])
    jaune = np.array([1.02, 1.01, 0.93])
    alb *= (1 + 0.5 * teinte_var[..., None] * (rouge - 1)) * (1 + 0.5 * (1 - teinte_var[..., None]) * (jaune - 1))

    # --- Rougeurs : joues, nez, oreilles, lèvres, mains, genoux, coudes ---------------------
    rougeur = p.get("rougeur", 0.5)
    r = (0.55 * A.reg["joues"] + 0.5 * A.reg["nez"] + 0.6 * A.reg["oreilles"]) * dans_tete
    for j in ("lowerarm01.L____head", "lowerarm01.R____head", "lowerleg01.L____head", "lowerleg01.R____head"):
        r += 0.35 * np.exp(-(A.dist(art[j]) / 0.05) ** 2)
    for j in ("wrist.L____head", "wrist.R____head"):
        r += 0.25 * _ss(-A.dist(art[j]), -0.14, -0.04)
    r = np.clip(r * rougeur * (1.0 - 0.6 * sombre), 0, 1)
    alb *= (1 + r[..., None] * (np.array([1.10, 0.86, 0.84]) - 1))
    # Cernes légèrement violacés, paupières plus sombres.
    c = np.clip(A.reg["cernes"] * 0.8 + A.reg["paupieres"] * 0.6, 0, 1) * dans_tete
    alb *= (1 + c[..., None] * (np.array([0.90, 0.86, 0.92]) - 1) * (0.6 + 0.6 * age))

    # --- Lèvres -------------------------------------------------------------------------------
    lev = _ss(A.reg["levres"], 0.08, 0.45) * dans_tete
    coul_lev = lin * np.array([1.05, 0.70, 0.72]) * (0.85 if sombre > 0.4 else 1.0)
    if p.get("rouge_levres"):
        coul_lev = np.array(p["rouge_levres"]) ** 2.2
    alb = alb * (1 - lev[..., None]) + coul_lev[None, None, :] * lev[..., None] * (0.95 + 0.05 * marbrure[..., None])

    # --- Barbe (ombre de rasage ou barbe courte) -------------------------------------------
    barbe = p.get("barbe", 0.35 if homme else 0.0)
    if barbe > 0:
        y = pos[..., 1]
        z = pos[..., 2]
        zone = (_ss(y, menton[1] - 0.05, menton[1] - 0.01) * (1 - _ss(y, yeux_y - 0.060, yeux_y - 0.035))
                * _ss(z, tete[2] + 0.01, tete[2] + 0.05))
        # Joues : la barbe s'arrête plus bas sur les pommettes.
        zone *= 1 - 0.8 * _ss(A.reg["joues"], 0.5, 0.9) * _ss(y, yeux_y - 0.07, yeux_y - 0.03)
        zone *= 1 - _ss(A.reg["levres"], 0.05, 0.3)
        poils = np.clip(bruit_uv(T, 0.6, graine + 3) * 1.4, 0, 1)
        dens = zone * barbe * (0.55 + 0.45 * poils)
        coul_barbe = np.array(p.get("couleur_poils", (0.08, 0.06, 0.05))) ** 2.2
        alb = alb * (1 - 0.75 * dens[..., None]) + coul_barbe[None, None, :] * 0.75 * dens[..., None]

    # --- Sourcils ------------------------------------------------------------------------------
    # Sourcils dessinés géométriquement : arc au-dessus de chaque œil, plus épais côté nez.
    oeil = art["eye.L____head"]
    ax = np.abs(pos[..., 0])
    u = np.clip((ax - 0.010) / 0.052, 0, 1)
    y_arc = oeil[1] + 0.019 + 0.007 * np.sin(np.pi * np.clip(u * 1.1, 0, 1))
    epais = 0.0055 * (1.0 - 0.55 * u)
    devant = _ss(pos[..., 2], oeil[2] - 0.035, oeil[2] - 0.015)
    sour = (_ss(-np.abs(pos[..., 1] - y_arc), -epais, -epais * 0.4) * _ss(ax, 0.008, 0.013)
            * (1 - _ss(ax, 0.058, 0.066)) * devant * dans_tete)
    poils = bruit_uv(T, 0.5, graine + 9)
    poils = ndimage.gaussian_filter(poils, (0.4, 2.2))  # traits allongés
    s = np.clip(sour * (0.75 + 0.6 * poils) * p.get("sourcils", 1.0), 0, 1)
    coul_poils = np.array(p.get("couleur_poils", (0.10, 0.07, 0.05))) ** 2.2
    alb = alb * (1 - 0.85 * s[..., None]) + coul_poils[None, None, :] * 0.85 * s[..., None]

    # --- Cuir chevelu (repousse sous les cheveux, plus sombre) -------------------------------
    from vetements import ligne_cheveux
    lim, _ = ligne_cheveux(A.p_flat, art)
    cuir = _ss(pos[..., 1] - lim.reshape(T, T), -0.004, 0.006) * dans_tete * (1 - _ss(A.reg["oreilles"], 0.1, 0.3))
    alb = alb * (1 - 0.22 * cuir[..., None]) + coul_poils[None, None, :] * 0.22 * cuir[..., None]

    # --- Taches de rousseur, grains de beauté ------------------------------------------------
    rous = p.get("rousseurs", 0.0)
    if rous > 0:
        f = np.clip((A.b3(220.0, 2, graine + 21) - 0.45) * 6, 0, 1)
        zone_f = np.clip(A.reg["joues"] * 1.2 + A.reg["nez"], 0, 1) + 0.4 * _ss(pos[..., 1], art["spine01____head"][1], art["neck01____head"][1])
        alb *= (1 - (f * zone_f * rous * 0.35)[..., None] * np.array([0.25, 0.45, 0.55]))
    grains = (A.b3(160.0, 1, graine + 33) > 0.92).astype(np.float32)
    alb *= (1 - 0.45 * grains[..., None] * np.array([0.5, 0.65, 0.75]))

    # --- Relief : pores, rides, plis -------------------------------------------------------------
    pores = bruit_uv(T, 0.7, graine + 41)
    pores_g = bruit_uv(T, 1.6, graine + 43)
    visage = dans_tete * (0.6 + 0.6 * np.clip(A.reg["nez"] + A.reg["joues"], 0, 1))
    haut = (0.35 * pores + 0.25 * pores_g) * (0.5 + 0.8 * visage)
    # Rides du front et pattes d'oie selon l'âge.
    rides = max(0.0, (age - 0.45) / 0.55)
    if rides > 0:
        y = pos[..., 1]
        front = _ss(y, yeux_y + 0.03, yeux_y + 0.045) * (1 - _ss(y, yeux_y + 0.075, yeux_y + 0.095)) * _ss(pos[..., 2], tete[2] + 0.06, tete[2] + 0.09)
        lignes = np.sin((y - yeux_y) * 2 * np.pi / 0.0085 + 1.5 * A.b3(30.0, 2, graine + 5))
        haut -= front * rides * 1.8 * _ss(lignes, 0.6, 1.0)
        for oeil in ("eye.L____head", "eye.R____head"):
            e = art[oeil]
            d = A.dist(e)
            ang = np.arctan2(pos[..., 1] - e[1], np.abs(pos[..., 0]) - abs(e[0]))
            patte = _ss(d, 0.018, 0.024) * (1 - _ss(d, 0.035, 0.045)) * (np.abs(pos[..., 0]) > abs(e[0]) + 0.01)
            haut -= patte * rides * 1.3 * _ss(np.sin(ang * 14), 0.7, 1.0)
        # Plis nasogéniens.
        haut -= 0.8 * rides * _ss(A.reg["joues"], 0.25, 0.4) * (1 - _ss(A.reg["joues"], 0.4, 0.55)) * dans_tete
    # Lèvres : stries verticales.
    haut += lev * 0.5 * np.sin(pos[..., 0] * 2 * np.pi / 0.0022)
    nrm = normale_depuis_hauteur(haut.astype(np.float32), 1.1)

    # --- Rugosité : zone T plus brillante, lèvres satinées -------------------------------------
    rug = 0.52 + 0.06 * pores_g - 0.10 * np.clip(A.reg["nez"] * 1.5, 0, 1) * dans_tete - 0.16 * lev
    front = _ss(pos[..., 1], yeux_y + 0.02, yeux_y + 0.05) * dans_tete * (1 - cuir)
    rug -= 0.06 * front
    rug += 0.08 * cuir + 0.1 * s
    ao = np.clip(1.0 + 0.25 * np.minimum(haut, 0), 0.6, 1.0)
    alb_srgb = np.clip(alb, 0, 1) ** (1 / 2.2)
    orm = np.stack([ao, np.clip(rug, 0.2, 0.9), np.zeros_like(rug)], -1)
    return alb_srgb, nrm, orm
