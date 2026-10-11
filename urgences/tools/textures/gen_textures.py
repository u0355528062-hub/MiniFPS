"""Génère les textures PBR procédurales du jeu (albedo, normale, ORM).

Usage : python3 tools/textures/gen_textures.py [nom ...]
Sortie : assets/textures/<nom>/{albedo.jpg, normal.png, orm.jpg}
"""
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from bruit import *  # noqa

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures"))


def dossier(nom):
    d = os.path.join(RACINE, nom)
    os.makedirs(d, exist_ok=True)
    return d


def ecrire(nom, albedo, hauteur_ou_normale, ao, rug, metal=None, force_normale=1.0):
    d = dossier(nom)
    sauver_rgb(os.path.join(d, "albedo.jpg"), albedo)
    if hauteur_ou_normale.ndim == 2:
        n = normale_depuis_hauteur(hauteur_ou_normale, force_normale)
    else:
        n = hauteur_ou_normale
    sauver_normale(os.path.join(d, "normal.png"), n)
    if metal is None:
        metal = np.zeros_like(rug)
    sauver_orm(os.path.join(d, "orm.jpg"), ao, rug, metal)
    print("texture", nom, albedo.shape)


# ---------------------------------------------------------------------------------------------
def rayures(h, w, n, longueur, epaisseur, courbure=0.3):
    """Traces fines aléatoires (frottements de chaussures, roues) : renvoie un masque 0..1."""
    m = np.zeros((h, w))
    for _ in range(n):
        x, y = RNG.uniform(0, w), RNG.uniform(0, h)
        ang = RNG.uniform(0, np.pi)
        L = RNG.uniform(0.3, 1.0) * longueur
        k = RNG.uniform(-courbure, courbure) / max(L, 1)
        pas = int(L)
        t = np.arange(pas)
        a = ang + k * t
        xs = (x + np.cumsum(np.cos(a))).astype(int) % w
        ys = (y + np.cumsum(np.sin(a))).astype(int) % h
        intens = RNG.uniform(0.3, 1.0) * np.sin(np.linspace(0, np.pi, pas)) ** 0.5
        np.maximum.at(m, (ys, xs), intens)
    if epaisseur > 0:
        m = flou(m, epaisseur) * (epaisseur * 2.5)
    return np.clip(m, 0, 1)


def sol_vinyle(nom, base, eclats, taille=2048, soudure="#9aa3a6", rug_base=0.28):
    """Vinyle homogène moucheté type hôpital (2 m x 2 m par tuile, 1 mm/pixel)."""
    graine(sum(map(ord, nom)))
    h = w = taille
    alb = np.ones((h, w, 3)) * couleur(base)
    # Légère variation de teinte à grande échelle.
    var = spectral(h, w, beta=2.2, fmin=2)
    alb *= (0.96 + 0.08 * var)[..., None]
    # Éclats allongés (sens du calandrage) de plusieurs couleurs.
    for i, (col, densite, tail) in enumerate(eclats):
        champ = taches(h, w, tail, aniso=(2.8, 0.7))
        seuil = np.quantile(champ, 1.0 - densite)
        masque = lisser_seuil(champ, seuil, 0.25)
        alb = melanger(alb, np.ones_like(alb) * couleur(col), masque * 0.85)
    # Grain très fin.
    grain = taches(h, w, 1.2)
    alb *= (1.0 + 0.025 * grain)[..., None]
    # Traces de frottement (gomme noire) et usure.
    traces = rayures(h, w, 90, 260, 1.2)
    alb *= (1.0 - 0.18 * traces)[..., None]
    sale = spectral(h, w, beta=2.6, fmin=1.5)
    sale = lisser_seuil(sale, 0.55, 0.3)
    alb *= (1.0 - 0.06 * sale)[..., None]
    # Soudure à chaud entre deux lés (bord gauche de la tuile).
    x = np.arange(w)
    d = np.minimum(x, w - x)
    cordon = np.clip(1.0 - d / 3.0, 0, 1)[None, :] * np.ones((h, 1))
    alb = melanger(alb, np.ones_like(alb) * couleur(soudure), cordon * 0.9)
    # Rugosité : cire lustrée, plus mate aux traces et à la saleté.
    cire = spectral(h, w, beta=2.0, fmin=2)
    rug = rug_base + 0.10 * (cire - 0.5) + 0.25 * traces + 0.12 * sale + 0.15 * cordon
    rug += 0.03 * taches(h, w, 2.0)
    # Hauteur : micro-relief, cordon légèrement en saillie, joints creux.
    haut = 0.15 * spectral(h, w, beta=1.2, fmin=60) + 0.6 * cordon - 0.2 * traces
    ao = ao_depuis_hauteur(haut, 4, 0.6) * (1 - 0.05 * sale)
    ecrire(nom, alb, haut, ao, np.clip(rug, 0.05, 1), force_normale=1.6)


def peinture_mur(nom, taille=1024):
    """Peinture satinée sur plâtre : peau d'orange au rouleau, presque uniforme (teinte dans le matériau)."""
    graine(11)
    h = w = taille
    peau = spectral(h, w, beta=1.0, fmin=40, fmax=220)
    ondul = spectral(h, w, beta=3.0, fmin=1)
    alb = np.ones((h, w, 3)) * (0.92 + 0.03 * ondul + 0.012 * peau)[..., None]
    sale = lisser_seuil(spectral(h, w, beta=2.4, fmin=2), 0.62, 0.3)
    alb *= (1 - 0.015 * sale)[..., None]
    rug = 0.55 + 0.08 * peau + 0.04 * sale
    haut = 0.6 * peau + 0.8 * ondul
    ao = np.ones((h, w))
    ecrire(nom, alb, haut, ao, rug, force_normale=0.9)


def dalle_plafond(nom, taille=1024):
    """Dalle minérale 600 x 600 mm à bords feuillurés + ossature T blanche."""
    graine(21)
    h = w = taille
    px = 600.0 / taille  # mm par pixel
    y, x = np.mgrid[0:h, 0:w]
    bord = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)) * px  # mm au bord
    # Ossature T de 24 mm (12 mm de chaque côté du joint).
    ossature = (bord < 12).astype(float)
    feuillure = np.clip((bord - 12) / 10.0, 0, 1)  # descente de la dalle
    # Surface fissurée : creux sinueux + piqûres.
    fiss = taches(h, w, 6.0, aniso=(1.0, 1.0))
    fiss2 = taches(h, w, 3.0)
    vermiculures = np.exp(-(fiss * 3.0) ** 2) * 0.7 + np.exp(-(fiss2 * 4.0) ** 2) * 0.3
    trous = (RNG.random((h, w)) < 0.0035).astype(float)
    trous = np.clip(flou(trous, 0.9) * 6, 0, 1)
    surf = 0.6 - 0.35 * vermiculures - 0.5 * trous + 0.1 * taches(h, w, 1.5) * 0.3
    haut = np.where(ossature > 0, 1.0, feuillure * 0.55 + surf * 0.25 * feuillure)
    alb_d = 0.93 - 0.10 * vermiculures - 0.25 * trous
    alb = np.where(ossature > 0, 0.95, alb_d)
    alb = np.stack([alb, alb, alb * 0.985], -1)
    rug = np.where(ossature > 0, 0.35, 0.92)
    ao = ao_depuis_hauteur(haut, 5, 2.0)
    ecrire(nom, alb, haut, ao, rug, force_normale=6.0)


def inox_brosse(nom, taille=1024):
    graine(31)
    h = w = taille
    lignes = taches(h, w, 0.8, aniso=(120.0, 1.0))
    lignes2 = taches(h, w, 0.6, aniso=(40.0, 1.0))
    taches_doigts = lisser_seuil(spectral(h, w, beta=2.5, fmin=3), 0.6, 0.2)
    v = 0.5 + 0.5 * np.tanh(0.6 * lignes + 0.4 * lignes2)
    alb = np.ones((h, w, 3)) * (0.70 + 0.06 * v)[..., None] * couleur("#e8ebee")
    rug = 0.26 + 0.10 * v + 0.12 * taches_doigts
    haut = 0.5 * lignes + 0.3 * lignes2
    ecrire(nom, alb, haut, np.ones((h, w)), rug, np.ones((h, w)), force_normale=0.25)


def tissu_rideau(nom, taille=1024):
    """Rideau de box : tissu non feu à motif géométrique discret (10 cm par tuile répétée 4 fois)."""
    graine(41)
    h = w = taille
    y, x = np.mgrid[0:h, 0:w] / taille
    # Tissage toile.
    n = 256
    fils_x = 0.5 + 0.5 * np.sin(2 * np.pi * x * n)
    fils_y = 0.5 + 0.5 * np.sin(2 * np.pi * y * n)
    damier = (np.sin(2 * np.pi * x * n / 2) * np.sin(2 * np.pi * y * n / 2) > 0)
    tissage = np.where(damier, fils_x, fils_y)
    # Motif : losanges pastel sur fond bleu-vert.
    u = (x * 4) % 1.0
    v = (y * 4) % 1.0
    los = np.abs(u - 0.5) + np.abs(v - 0.5)
    trait = np.exp(-((los - 0.42) / 0.018) ** 2) + np.exp(-((los - 0.30) / 0.012) ** 2) * 0.6
    fond = couleur("#7fb3b5")
    motif = couleur("#d9ece6")
    alb = melanger(np.ones((h, w, 3)) * fond, np.ones((h, w, 3)) * motif, np.clip(trait, 0, 1))
    alb *= (0.9 + 0.12 * tissage)[..., None]
    alb *= (0.97 + 0.06 * spectral(h, w, beta=2, fmin=4))[..., None]
    rug = 0.85 + 0.1 * tissage
    haut = tissage + 0.3 * taches(h, w, 1.0)
    ao = 0.85 + 0.15 * tissage
    ecrire(nom, alb, haut, ao, rug, force_normale=0.6)


def skai(nom, taille=1024):
    """Similicuir (matelas, fauteuils) : grain cuir cellulaire, teinte neutre."""
    graine(51)
    h = w = taille
    # Cellules par différence de deux bruits seuillés (grain cuir).
    a = taches(h, w, 3.5)
    b = taches(h, w, 3.5)
    grain = np.minimum(np.abs(a), np.abs(b))
    plis = np.exp(-(grain * 2.5) ** 2)
    haut = -plis * 0.8 + 0.2 * taches(h, w, 1.0)
    alb = np.ones((h, w, 3)) * (0.85 - 0.12 * plis)[..., None]
    usure = lisser_seuil(spectral(h, w, beta=2.4, fmin=2), 0.6, 0.25)
    rug = 0.42 + 0.18 * plis - 0.12 * usure
    ao = ao_depuis_hauteur(haut, 3, 1.5)
    ecrire(nom, alb, haut, ao, rug, force_normale=1.2)


def plastique_grain(nom, taille=512):
    graine(61)
    h = w = taille
    g = taches(h, w, 1.6)
    haut = g
    alb = np.ones((h, w, 3)) * (0.93 + 0.02 * g)[..., None]
    rug = 0.48 + 0.06 * g + 0.08 * lisser_seuil(spectral(h, w, beta=2.4, fmin=2), 0.6, 0.3)
    ecrire(nom, alb, haut, np.ones((h, w)), rug, force_normale=0.7)


def bois_stratifie(nom, taille=1024):
    """Stratifié imitation hêtre (portes, plans de travail)."""
    graine(71)
    h = w = taille
    y, x = np.mgrid[0:h, 0:w] / taille
    distor = taches(h, w, 30.0, aniso=(6.0, 1.0)) * 0.03 + taches(h, w, 8.0, aniso=(8, 1)) * 0.006
    cernes = np.sin((y + distor) * 2 * np.pi * 38) * 0.5 + 0.5
    cernes = cernes ** 3
    fibres = taches(h, w, 0.7, aniso=(60.0, 1.0))
    clair = couleur("#c99a6b")
    fonce = couleur("#9c6b42")
    alb = melanger(np.ones((h, w, 3)) * clair, np.ones((h, w, 3)) * fonce, cernes * 0.6 + 0.08 * fibres)
    alb *= (0.95 + 0.08 * spectral(h, w, beta=2.2, fmin=2))[..., None]
    rug = 0.45 + 0.08 * cernes
    haut = 0.3 * fibres - 0.2 * cernes
    ecrire(nom, alb, haut, np.ones((h, w)), rug, force_normale=0.5)


def tissu_serge(nom, taille=512):
    """Serge (pyjamas et blouses) : sergé en diagonale, teinte dans le matériau."""
    graine(81)
    h = w = taille
    y, x = np.mgrid[0:h, 0:w] / taille
    n = 128
    diag = 0.5 + 0.5 * np.sin(2 * np.pi * (x + y) * n)
    fil = 0.5 + 0.5 * np.sin(2 * np.pi * x * n * 2)
    tissage = 0.7 * diag + 0.3 * fil
    alb = np.ones((h, w, 3)) * (0.88 + 0.12 * tissage)[..., None]
    alb *= (0.97 + 0.05 * spectral(h, w, beta=2.0, fmin=3))[..., None]
    rug = 0.88 + 0.08 * tissage
    ecrire(nom, alb, tissage, 0.9 + 0.1 * tissage, rug, force_normale=2.0)


def carrelage(nom, taille=1024, cote=10, joint="#b8b8b0", base="#eef0ee"):
    """Faïence murale (salle de plâtre, sanitaires) : carreaux de 20 cm, joints."""
    graine(91)
    h = w = taille
    y, x = np.mgrid[0:h, 0:w]
    p = taille / cote
    dx = np.minimum(x % p, p - x % p)
    dy = np.minimum(y % p, p - y % p)
    d = np.minimum(dx, dy)
    jt = np.clip(1.0 - (d - 2.0) / 2.0, 0, 1)
    bombe = np.clip(d / 10.0, 0, 1) ** 0.5
    alb = melanger(np.ones((h, w, 3)) * couleur(base), np.ones((h, w, 3)) * couleur(joint), jt)
    # Légère variation par carreau.
    ix = (x // p).astype(int)
    iy = (y // p).astype(int)
    var = RNG.normal(0, 0.012, (cote + 1, cote + 1))[iy, ix]
    alb *= (1 + var)[..., None]
    rug = 0.12 + 0.6 * jt + 0.03 * taches(h, w, 2)
    haut = bombe - 0.5 * jt
    ao = ao_depuis_hauteur(haut, 3, 1.0)
    ecrire(nom, alb, haut, ao, rug, force_normale=3.0)


def caoutchouc_sol(nom, taille=512):
    """Revêtement de sas / pastilles antidérapantes."""
    graine(101)
    h = w = taille
    y, x = np.mgrid[0:h, 0:w]
    p = taille / 16
    cx = (x % p) - p / 2
    cy = (y % p) - p / 2
    r = np.sqrt(cx ** 2 + cy ** 2)
    pastille = np.clip((p * 0.28 - r) / 2.0, 0, 1)
    alb = np.ones((h, w, 3)) * couleur("#3a3d40") * (0.95 + 0.1 * spectral(h, w, 2, 2))[..., None]
    rug = 0.75 - 0.15 * pastille
    ecrire(nom, alb, pastille, ao_depuis_hauteur(pastille, 3, 1.0), rug, force_normale=3.0)


def beton(nom, taille=1024):
    graine(111)
    h = w = taille
    b = spectral(h, w, beta=1.8, fmin=2)
    g = taches(h, w, 1.3)
    alb = np.ones((h, w, 3)) * couleur("#8e8c88") * (0.85 + 0.25 * b + 0.04 * g)[..., None]
    rug = 0.85 + 0.1 * g
    ecrire(nom, alb, b * 0.5 + 0.2 * g, ao_depuis_hauteur(b, 6, 0.5), rug, force_normale=1.0)


TOUTES = {
    "sol_vinyle_gris": lambda: sol_vinyle(
        "sol_vinyle_gris", "#b9bdb8",
        [("#e9ebe6", 0.10, 7.0), ("#8b9190", 0.08, 5.5), ("#9fb4b8", 0.05, 6.0), ("#d7d2c4", 0.06, 4.0)]),
    "sol_vinyle_bleu": lambda: sol_vinyle(
        "sol_vinyle_bleu", "#8fa5b0",
        [("#c7d3d8", 0.10, 7.0), ("#5f7581", 0.08, 5.5), ("#a9bcc4", 0.07, 6.0)], soudure="#7d939d"),
    "sol_vinyle_vert": lambda: sol_vinyle(
        "sol_vinyle_vert", "#9fb3a6",
        [("#d2ddd3", 0.10, 7.0), ("#6f8676", 0.08, 5.5), ("#b8c7bb", 0.06, 6.0)], soudure="#8aa092"),
    "peinture_mur": lambda: peinture_mur("peinture_mur"),
    "dalle_plafond": lambda: dalle_plafond("dalle_plafond"),
    "inox_brosse": lambda: inox_brosse("inox_brosse"),
    "tissu_rideau": lambda: tissu_rideau("tissu_rideau"),
    "skai": lambda: skai("skai"),
    "plastique_grain": lambda: plastique_grain("plastique_grain"),
    "bois_stratifie": lambda: bois_stratifie("bois_stratifie"),
    "tissu_serge": lambda: tissu_serge("tissu_serge"),
    "carrelage_blanc": lambda: carrelage("carrelage_blanc"),
    "caoutchouc_sol": lambda: caoutchouc_sol("caoutchouc_sol"),
    "beton": lambda: beton("beton"),
}



# ----- Textures de détail (RGBA ou simples) -------------------------------------------------
def details():
    from PIL import Image, ImageDraw, ImageFont
    d = dossier("details")
    police = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "Inter.ttf")
    # Filet de rideau : maille hexagonale ajourée (alpha).
    t = 256
    y, x = np.mgrid[0:t, 0:t] / t
    n = 16
    a = np.abs(np.sin(np.pi * (x * n + 0.5 * np.floor(y * n * 2) % 2 * 0)))
    gx = np.abs(((x * n) % 1.0) - 0.5)
    gy = np.abs(((y * n * 1.15) % 1.0) - 0.5)
    trou = np.clip((0.42 - np.maximum(gx, gy)) / 0.04, 0, 1)
    rgba = np.zeros((t, t, 4))
    rgba[..., :3] = 0.92
    rgba[..., 3] = 1.0 - trou
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(d, "filet.png"))
    # Étiquette de poche / de tiroir : lignes de texte.
    img = Image.new("RGB", (512, 512), (246, 246, 242))
    dr = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(police, 54)
    f2 = ImageFont.truetype(police, 30)
    dr.rectangle((0, 0, 512, 90), fill=(30, 110, 170))
    dr.text((24, 14), "NaCl 0,9 %", font=f1, fill=(255, 255, 255))
    for i, l in enumerate(["Chlorure de sodium", "500 mL  —  perfusion IV", "Lot 24B117   Exp 11/2027",
                           "Poche sans PVC", "Ne pas utiliser si trouble"]):
        dr.text((24, 120 + i * 60), l, font=f2, fill=(40, 40, 40))
    img.save(os.path.join(d, "etiquette.png"))
    # Logo DASRI : fond jaune + pictogramme risque biologique simplifié.
    img = Image.new("RGB", (256, 256), (246, 205, 22))
    dr = ImageDraw.Draw(img)
    c = 128
    for k in range(3):
        ang = np.radians(90 + k * 120)
        cx, cy = c + 34 * np.cos(ang), c - 34 * np.sin(ang)
        dr.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), outline=(15, 15, 15), width=14)
    dr.ellipse((c - 22, c - 22, c + 22, c + 22), fill=(246, 205, 22), outline=(15, 15, 15), width=10)
    dr.text((c - 52, 210), "DASRI", font=ImageFont.truetype(police, 34), fill=(15, 15, 15))
    img.save(os.path.join(d, "logo_dasri.png"))
    # Cadran (tensiomètre, manomètre).
    img = Image.new("RGB", (256, 256), (245, 245, 240))
    dr = ImageDraw.Draw(img)
    for i in range(0, 31):
        ang = np.radians(225 - i * 9)
        r1, r2 = 118, (100 if i % 5 == 0 else 108)
        dr.line((c + r1 * np.cos(ang), c - r1 * np.sin(ang), c + r2 * np.cos(ang), c - r2 * np.sin(ang)),
                fill=(20, 20, 20), width=3 if i % 5 == 0 else 1)
    dr.line((c, c, c + 80 * np.cos(np.radians(200)), c - 80 * np.sin(np.radians(200))), fill=(200, 30, 30), width=4)
    img.save(os.path.join(d, "cadran.png"))
    # Cadran d'horloge.
    img = Image.new("RGB", (512, 512), (250, 250, 248))
    dr = ImageDraw.Draw(img)
    c = 256
    fh = ImageFont.truetype(police, 52)
    for i in range(60):
        ang = np.radians(90 - i * 6)
        r1, r2 = 246, (214 if i % 5 == 0 else 232)
        dr.line((c + r1 * np.cos(ang), c - r1 * np.sin(ang), c + r2 * np.cos(ang), c - r2 * np.sin(ang)),
                fill=(25, 25, 25), width=9 if i % 5 == 0 else 3)
    for h in range(1, 13):
        ang = np.radians(90 - h * 30)
        x, y = c + 170 * np.cos(ang), c - 170 * np.sin(ang)
        t = str(h)
        bb = dr.textbbox((0, 0), t, font=fh)
        dr.text((x - (bb[2] - bb[0]) / 2, y - (bb[3] - bb[1]) / 2 - bb[1]), t, font=fh, fill=(25, 25, 25))
    for ang, lg, ep, col in ((np.radians(90 - 10.4 * 30), 120, 14, (20, 20, 20)), (np.radians(90 - 22 * 6), 190, 9, (20, 20, 20)),
                             (np.radians(90 - 41 * 6), 205, 3, (200, 30, 30))):
        dr.line((c, c, c + lg * np.cos(ang), c - lg * np.sin(ang)), fill=col, width=ep)
    dr.ellipse((c - 12, c - 12, c + 12, c + 12), fill=(20, 20, 20))
    img.save(os.path.join(d, "horloge.png"))
    print("details")


TOUTES["details"] = details


if __name__ == "__main__":
    noms = sys.argv[1:] or list(TOUTES)
    for n in noms:
        TOUTES[n]()
