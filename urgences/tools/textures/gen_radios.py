"""Clichés radiographiques procéduraux pour les résultats d'examens.

Modèle : chaque structure (tissus mous, poumons, os) est un masque ; son épaisseur traversée
est estimée par une transformée de distance (plus épais au centre). Les densités sont sommées
puis converties en image par la loi d'atténuation (I = 1 - exp(-k·densité)), ce qui donne les
dégradés doux, la corticale osseuse brillante et les superpositions d'une vraie radiographie.
Usage : /opt/bpyenv/bin/python tools/textures/gen_radios.py   (numpy, scipy, Pillow)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(RACINE, "assets", "textures", "radios")
POLICE = os.path.join(RACINE, "assets", "fonts", "Inter.ttf")
os.makedirs(SORTIE, exist_ok=True)
W, H = 768, 896
RNG = np.random.default_rng(7)


def masque(dessin):
    im = Image.new("L", (W, H), 0)
    dessin(ImageDraw.Draw(im))
    return np.array(im) > 127


def epaisseur(m, lissage=6.0):
    """Épaisseur traversée ~ profil arrondi à partir de la distance au bord."""
    d = ndimage.distance_transform_edt(m)
    e = np.sqrt(np.clip(d, 0, None))
    return ndimage.gaussian_filter(e, lissage) * m


def os_(m, base=1.0, corticale=1.2):
    """Os : corticale dense sur les bords + médullaire trabéculaire."""
    d = ndimage.distance_transform_edt(m)
    cort = np.exp(-d / 3.5) * corticale
    trab = 0.35 + 0.15 * ndimage.gaussian_filter(RNG.standard_normal((H, W)), 1.4)
    e = epaisseur(m, 2.0)
    return (cort + trab * e / max(e.max(), 1e-6) * 2.0) * m * base


def rendre(densite, nom, legende, k=0.9):
    img = 1.0 - np.exp(-k * densite)
    img = ndimage.gaussian_filter(img, 1.2)
    img = img + RNG.normal(0, 0.012, img.shape)
    y, x = np.mgrid[0:H, 0:W]
    img *= 1.0 - 0.18 * (((x - W / 2) / W) ** 2 + ((y - H / 2) / H) ** 2) * 2
    a = (np.clip(img, 0, 1) ** 0.85 * 255).astype(np.uint8)
    im = Image.fromarray(a).convert("RGB")
    dr = ImageDraw.Draw(im)
    dr.text((18, 14), legende, font=ImageFont.truetype(POLICE, 22), fill=(225, 225, 225))
    dr.text((W - 44, 14), "D", font=ImageFont.truetype(POLICE, 34), fill=(235, 235, 235))
    im.save(os.path.join(SORTIE, nom + ".png"))
    print("radio", nom)


def spline(pts, n=10):
    """Catmull-Rom : polyligne lisse passant par les points."""
    P = [np.array(p, dtype=float) for p in pts]
    out = []
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-1])
    return out


def courbe(dr, pts, largeur, effile=False):
    pts = spline(pts)
    if effile:
        for i in range(len(pts) - 1):
            w = int(largeur * (1.0 - 0.45 * i / len(pts)))
            dr.line((tuple(pts[i]), tuple(pts[i + 1])), fill=255, width=max(w, 2))
    else:
        dr.line([tuple(p) for p in pts], fill=255, width=largeur, joint="curve")
    for p in (pts[0], pts[-1]):
        dr.ellipse((p[0] - largeur / 2, p[1] - largeur / 2, p[0] + largeur / 2, p[1] + largeur / 2), fill=255)


def thorax(nom, legende, opacite=None, distension=False):
    cx = W / 2
    tronc = masque(lambda d: d.ellipse((30, 40, 738, 1060), fill=255))
    k = 1.07 if distension else 1.0
    # Champs pulmonaires en « D » (bord médiastinal droit, bord costal arrondi), apex en haut.
    def poumon(s):
        pts = [(cx + s * 30, 150), (cx + s * 120, 120), (cx + s * 230, 170), (cx + s * 290, 330),
               (cx + s * 300, 520 * k), (cx + s * 270, 720 * k), (cx + s * 150, 690 * k), (cx + s * 45, 620 * k)]
        return masque(lambda d: d.polygon([tuple(p) for p in spline(pts + [pts[0]], 8)], fill=255))
    pg = poumon(-1)
    pd = poumon(1)
    # Silhouette cardiaque : bord droit discret, bord gauche convexe jusqu'à la pointe.
    cpts = [(cx - 55, 450), (cx - 75, 560), (cx - 60, 700), (cx + 60, 740), (cx + (190 if not distension else 150), 700),
            (cx + (180 if not distension else 140), 560), (cx + 70, 470)]
    coeur = masque(lambda d: d.polygon([tuple(p) for p in spline(cpts + [cpts[0]], 8)], fill=255))
    medi = masque(lambda d: d.rectangle((340, 90, 428, 560), fill=255))
    diaph = masque(lambda d: (d.ellipse((90, 700 + 45 * distension, 395, 980), fill=255),
                              d.ellipse((372, 680 + 45 * distension, 680, 980), fill=255)))
    densite = epaisseur(tronc, 12) * 0.11
    poumons = (pg | pd) & ~coeur & ~diaph
    densite -= epaisseur(poumons, 8) * 0.13
    densite += epaisseur(coeur | medi, 6) * 0.06 + epaisseur(diaph & tronc, 6) * 0.05
    # Vascularisation pulmonaire : branches fines depuis les hiles.
    vx = Image.new("L", (W, H), 0)
    dv = ImageDraw.Draw(vx)
    for hx in (cx - 60, cx + 60):
        for _ in range(26):
            x, y = hx, 400 + RNG.uniform(-40, 40)
            ang = RNG.uniform(0.6, 2.5) * (1 if hx > cx else -1) - (np.pi / 2 if hx > cx else -np.pi / 2)
            ang = RNG.uniform(-2.6, 2.6)
            if (hx < cx and np.cos(ang) > 0) or (hx > cx and np.cos(ang) < 0):
                ang = np.pi - ang
            larg = 7.0
            for _ in range(14):
                nx = x + np.cos(ang) * 18
                ny = y + np.sin(ang) * 18
                dv.line((x, y, nx, ny), fill=int(110 + larg * 10), width=max(1, int(larg)))
                x, y = nx, ny
                ang += RNG.normal(0, 0.25)
                larg *= 0.85
    densite += ndimage.gaussian_filter(np.array(vx) / 255.0, 1.5) * 0.35 * poumons
    # Côtes postérieures et antérieures (arcs), clavicules, omoplates, rachis.
    osm = np.zeros((H, W))
    for i in range(10):
        y0 = 180 + i * 50 * k
        for s in (-1, 1):
            pts = [(cx + s * 28, y0), (cx + s * 90, y0 - 22), (cx + s * 180, y0 - 12), (cx + s * 255, y0 + 30),
                   (cx + s * 292, y0 + 95), (cx + s * 296, y0 + 140)]
            m = masque(lambda d: courbe(d, pts, 14, effile=True))
            osm += os_(m & tronc, 0.42)
            pts2 = [(cx + s * 296, y0 + 140), (cx + s * 250, y0 + 168), (cx + s * 170, y0 + 182), (cx + s * 110, y0 + 186)]
            m2 = masque(lambda d: courbe(d, pts2, 10, effile=True))
            osm += os_(m2 & tronc, 0.22)
    for s in (-1, 1):
        cl = masque(lambda d: courbe(d, [(cx + s * 30, 175), (cx + s * 140, 150), (cx + s * 270, 135)], 20))
        osm += os_(cl, 0.8)
        om = masque(lambda d: d.polygon([(cx + s * 230, 140), (cx + s * 330, 160), (cx + s * 300, 420)], fill=255))
        osm += os_(om & tronc, 0.25)
    for i in range(17):
        v = masque(lambda d: d.rounded_rectangle((cx - 22, 95 + i * 41, cx + 22, 128 + i * 41), 6, fill=255))
        osm += os_(v, 0.55)
    densite += osm
    if opacite:
        x0, y0, x1, y1 = opacite
        o = masque(lambda d: d.ellipse((x0, y0, x1, y1), fill=255))
        densite += ndimage.gaussian_filter(o * 1.0, 16) * 1.3 * poumons
    rendre(np.clip(densite, 0, None), nom, legende)


def poignet(nom, legende, fracture=False):
    tissu = masque(lambda d: d.polygon([(230, 896), (540, 896), (575, 430), (610, 120), (170, 120), (205, 430)], fill=255))
    densite = epaisseur(tissu, 10) * 0.10
    ox = np.zeros((H, W))
    radius = masque(lambda d: d.rounded_rectangle((262, 480, 372, 900), 35, fill=255))
    ulna = masque(lambda d: d.rounded_rectangle((402, 505, 478, 900), 28, fill=255))
    epi = masque(lambda d: d.rounded_rectangle((242, 420, 388, 500), 30, fill=255))
    if fracture:
        epi = masque(lambda d: d.polygon([(240, 418), (390, 398), (396, 478), (246, 502)], fill=255))
        radius &= ~masque(lambda d: d.line((250, 500, 385, 482), fill=255, width=9))
    for m in (radius, ulna, epi):
        ox += os_(m, 0.9)
    for (x, y, r) in [(262, 352, 30), (322, 342, 30), (382, 352, 30), (440, 372, 28), (292, 292, 28), (352, 282, 30),
                      (410, 292, 28)]:
        ox += os_(masque(lambda d: d.ellipse((x, y, x + 2 * r, y + 2 * r), fill=255)), 0.8)
    for i in range(5):
        x = 245 + i * 62
        ox += os_(masque(lambda d: d.rounded_rectangle((x, 110, x + 32, 290), 15, fill=255)), 0.8)
    rendre(densite + ox, nom, legende)


def cheville(nom, legende):
    tissu = masque(lambda d: d.polygon([(250, 0), (530, 0), (565, 600), (720, 760), (700, 896), (170, 896), (215, 600)], fill=255))
    densite = epaisseur(tissu, 10) * 0.10
    ox = np.zeros((H, W))
    for f in [lambda d: d.rounded_rectangle((300, -20, 425, 565), 35, fill=255),
              lambda d: d.rounded_rectangle((448, -20, 502, 595), 22, fill=255),
              lambda d: d.ellipse((296, 535, 472, 668), fill=255),
              lambda d: d.ellipse((245, 640, 472, 828), fill=255),
              lambda d: d.ellipse((468, 640, 690, 765), fill=255)]:
        ox += os_(masque(f), 0.9)
    rendre(densite + ox, nom, legende)


def bassin(nom, legende, fracture=False):
    cx = W / 2
    tissu = masque(lambda d: d.ellipse((10, 80, 758, 960), fill=255))
    densite = epaisseur(tissu, 14) * 0.10
    ox = np.zeros((H, W))
    for s in (-1, 1):
        # Aile iliaque en éventail, cotyle, branches ischio- et ilio-pubiennes, trou obturé.
        aile = [(cx + s * 60, 230), (cx + s * 120, 150), (cx + s * 250, 120), (cx + s * 330, 180), (cx + s * 320, 330),
                (cx + s * 240, 470), (cx + s * 175, 520), (cx + s * 95, 420)]
        ox += os_(masque(lambda d: d.polygon([tuple(p) for p in spline(aile + [aile[0]], 8)], fill=255)), 0.7)
        obt = [(cx + s * 40, 600), (cx + s * 120, 560), (cx + s * 175, 610), (cx + s * 150, 690), (cx + s * 70, 700)]
        anneau = masque(lambda d: d.polygon([tuple(p) for p in spline(obt + [obt[0]], 8)], fill=255))
        cadre = ndimage.binary_dilation(anneau, iterations=22) & ~anneau
        ox += os_(cadre, 0.75)
        # Tête et col fémoral, grand trochanter, diaphyse.
        tete = masque(lambda d: d.ellipse((cx + s * 200 - 62, 470, cx + s * 200 + 62, 594), fill=255))
        col = masque(lambda d: courbe(d, [(cx + s * 205, 535), (cx + s * 255, 590), (cx + s * 285, 640)], 70))
        troch = masque(lambda d: d.ellipse((cx + s * 290 - 45, 580, cx + s * 290 + 45, 690), fill=255))
        diaph = masque(lambda d: courbe(d, [(cx + s * 280, 640), (cx + s * 265, 780), (cx + s * 250, 920)], 82))
        ox += os_(tete | col | troch | diaph, 0.9)
    sac = [(cx - 85, 150), (cx + 85, 150), (cx + 55, 420), (cx, 470), (cx - 55, 420)]
    ox += os_(masque(lambda d: d.polygon([tuple(p) for p in spline(sac + [sac[0]], 6)], fill=255)), 0.75)
    for i in range(3):
        ox += os_(masque(lambda d: d.rounded_rectangle((cx - 45, 20 + i * 45, cx + 45, 55 + i * 45), 8, fill=255)), 0.6)
    if fracture:
        ox -= os_(masque(lambda d: d.line((cx - 120, 565, cx - 85, 650), fill=255, width=8)), 1.0)
        ox -= os_(masque(lambda d: d.line((cx + 200, 330, cx + 290, 380), fill=255, width=7)), 1.0)
    rendre(densite + np.clip(ox, 0, None), nom, legende)


if __name__ == "__main__":
    thorax("thorax_normal", "Thorax de face")
    thorax("thorax_pneumopathie", "Thorax de face", opacite=(430, 520, 640, 700))
    thorax("thorax_distension", "Thorax de face", distension=True)
    poignet("poignet_fracture", "Poignet droit de face", fracture=True)
    poignet("poignet_normal", "Poignet de face")
    cheville("cheville_normale", "Cheville de profil")
    bassin("bassin_fracture", "Bassin de face", fracture=True)
