"""Affiches murales de la salle de déchocage (textures PNG, Pillow) :
  - affiche_hygiene.png : friction hydro-alcoolique des mains en 6 étapes ;
  - affiche_acr.png : arrêt cardiaque, algorithme de réanimation (choc / pas de choc) ;
  - affiche_douleur.png : échelle d'évaluation de la douleur (0 à 10, visages).

    python3 tools/build_affiches.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "textures")
FONT = os.path.join(ROOT, "assets", "fonts", "Inter.ttf")
W, H = 600, 840


def font(size):
    return ImageFont.truetype(FONT, size)


def header(d, text, sub, col):
    d.rectangle([0, 0, W, 120], fill=col)
    d.text((W // 2, 50), text, font=font(46), fill="white", anchor="mm")
    d.text((W // 2, 98), sub, font=font(22), fill=(235, 245, 255), anchor="mm")


def footer(d, text):
    d.rectangle([0, H - 50, W, H], fill=(230, 234, 238))
    d.text((W // 2, H - 25), text, font=font(18), fill=(90, 100, 110), anchor="mm")


def hand(d, cx, cy, s, col, angle=0.0):
    """Silhouette de main simplifiée (paume et doigts)."""
    ca, sa = math.cos(angle), math.sin(angle)

    def rot(x, y):
        return (cx + (x * ca - y * sa) * s, cy + (x * sa + y * ca) * s)

    palm = [rot(x, y) for x, y in [(-0.5, 0.2), (0.5, 0.2), (0.45, 0.9), (-0.45, 0.9)]]
    d.polygon(palm, fill=col)
    for k, (fx, L) in enumerate([(-0.38, 0.75), (-0.13, 0.9), (0.12, 0.85), (0.36, 0.7)]):
        a = rot(fx, 0.25)
        b = rot(fx, 0.25 - L)
        d.line([a, b], fill=col, width=int(0.22 * s))
        d.ellipse([b[0] - 0.11 * s, b[1] - 0.11 * s, b[0] + 0.11 * s, b[1] + 0.11 * s], fill=col)
    t0 = rot(-0.5, 0.6)
    t1 = rot(-0.95, 0.15)
    d.line([t0, t1], fill=col, width=int(0.24 * s))


def hygiene():
    im = Image.new("RGB", (W, H), (250, 251, 252))
    d = ImageDraw.Draw(im)
    header(d, "Hygiène des mains", "Friction hydro-alcoolique : 30 secondes", (20, 120, 170))
    steps = ["Paume contre paume", "Dos des mains", "Entre les doigts", "Dos des doigts", "Pouces", "Bout des doigts"]
    for i, s in enumerate(steps):
        col, row = i % 2, i // 2
        x0 = 30 + col * 280
        y0 = 145 + row * 195
        d.rounded_rectangle([x0, y0, x0 + 260, y0 + 180], 18, fill=(225, 240, 248), outline=(150, 195, 220), width=3)
        d.ellipse([x0 + 12, y0 + 12, x0 + 56, y0 + 56], fill=(20, 120, 170))
        d.text((x0 + 34, y0 + 34), str(i + 1), font=font(28), fill="white", anchor="mm")
        hand(d, x0 + 110, y0 + 95, 55, (240, 200, 175), -0.3 + 0.1 * i)
        hand(d, x0 + 160, y0 + 100, 55, (225, 180, 155), 0.4 - 0.1 * i)
        d.text((x0 + 130, y0 + 160), s, font=font(22), fill=(30, 50, 70), anchor="mm")
    d.text((W // 2, 762), "Avant et après chaque contact patient", font=font(24), fill=(20, 120, 170), anchor="mm")
    footer(d, "Équipe opérationnelle d'hygiène")
    im.save(os.path.join(OUT, "affiche_hygiene.png"))


def box(d, xy, text, fill, size=22, tc="white"):
    d.rounded_rectangle(xy, 14, fill=fill)
    cx = (xy[0] + xy[2]) // 2
    cy = (xy[1] + xy[3]) // 2
    lines = text.split("\n")
    for k, ln in enumerate(lines):
        d.text((cx, cy + (k - (len(lines) - 1) / 2) * (size + 6)), ln, font=font(size), fill=tc, anchor="mm")


def arrow(d, a, b):
    d.line([a, b], fill=(60, 70, 80), width=5)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    p1 = (b[0] - 16 * math.cos(ang - 0.45), b[1] - 16 * math.sin(ang - 0.45))
    p2 = (b[0] - 16 * math.cos(ang + 0.45), b[1] - 16 * math.sin(ang + 0.45))
    d.polygon([b, p1, p2], fill=(60, 70, 80))


def acr():
    im = Image.new("RGB", (W, H), (252, 252, 250))
    d = ImageDraw.Draw(im)
    header(d, "Arrêt cardiaque", "Réanimation cardio-pulmonaire de l'adulte", (200, 30, 40))
    box(d, (120, 140, 480, 200), "Ne répond pas, ne respire pas", (60, 70, 80))
    arrow(d, (300, 200), (300, 225))
    box(d, (90, 228, 510, 290), "RCP 30:2 · défibrillateur", (200, 30, 40))
    arrow(d, (300, 290), (300, 315))
    box(d, (150, 318, 450, 370), "Analyse du rythme", (70, 80, 95))
    arrow(d, (230, 370), (150, 410))
    arrow(d, (370, 370), (450, 410))
    box(d, (30, 412, 280, 470), "Choc indiqué\nFV / TV sans pouls", (230, 120, 20), 20)
    box(d, (320, 412, 570, 470), "Pas de choc\nAESP / asystolie", (40, 120, 190), 20)
    box(d, (30, 490, 280, 560), "1 choc puis\nRCP 2 min", (230, 120, 20), 22)
    box(d, (320, 490, 570, 560), "RCP 2 min\nadrénaline 1 mg", (40, 120, 190), 22)
    arrow(d, (155, 470), (155, 488))
    arrow(d, (445, 470), (445, 488))
    d.rounded_rectangle([30, 590, 570, 770], 14, fill=(245, 236, 236), outline=(200, 30, 40), width=3)
    tips = ["Compressions 100-120/min, 5-6 cm", "Relâchement complet du thorax", "Adrénaline 1 mg après le 3e choc",
            "Amiodarone 300 mg après le 3e choc", "Causes réversibles : 4H / 4T"]
    for k, t in enumerate(tips):
        d.text((55, 615 + k * 32), "• " + t, font=font(22), fill=(80, 20, 25))
    footer(d, "Recommandations ERC / SFMU")
    im.save(os.path.join(OUT, "affiche_acr.png"))


def douleur():
    im = Image.new("RGB", (W, H), (252, 252, 250))
    d = ImageDraw.Draw(im)
    header(d, "Évaluer la douleur", "Échelle numérique de 0 à 10", (90, 60, 160))
    d.text((W // 2, 170), "« Quelle note donnez-vous à votre douleur ? »", font=font(23), fill=(50, 50, 60), anchor="mm")
    for i in range(11):
        t = i / 10
        col = (int(60 + 190 * t), int(180 - 130 * t), int(90 - 50 * t))
        x0 = 28 + i * 50
        d.rounded_rectangle([x0, 220, x0 + 44, 300], 8, fill=col)
        d.text((x0 + 22, 260), str(i), font=font(28), fill="white", anchor="mm")
    faces = [(0, "Pas mal"), (2, "Un peu"), (4, "Modéré"), (6, "Beaucoup"), (8, "Très fort"), (10, "Atroce")]
    for k, (v, lab) in enumerate(faces):
        cx = 60 + k * 96
        cy = 400
        t = v / 10
        col = (int(250 - 20 * t), int(220 - 150 * t), int(90 - 40 * t))
        d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=col, outline=(80, 70, 60), width=3)
        d.ellipse([cx - 18, cy - 14, cx - 8, cy - 4], fill=(40, 40, 40))
        d.ellipse([cx + 8, cy - 14, cx + 18, cy - 4], fill=(40, 40, 40))
        curve = 1.0 - 2.0 * t
        pts = [(cx - 20 + j * 4, cy + 16 + curve * 10 * math.sin(math.pi * j / 10)) for j in range(11)]
        d.line(pts, fill=(40, 40, 40), width=4)
        d.text((cx, cy + 62), lab, font=font(18), fill=(50, 50, 60), anchor="mm")
    d.rounded_rectangle([40, 520, 560, 760], 14, fill=(238, 234, 248), outline=(90, 60, 160), width=3)
    lines = ["Réévaluer après chaque traitement", "Douleur ≥ 4 : antalgique", "Douleur ≥ 7 : morphine titrée",
             "Noter le score dans le dossier", "Patient non communicant : ALGOPLUS"]
    for k, t in enumerate(lines):
        d.text((65, 545 + k * 40), "• " + t, font=font(23), fill=(50, 30, 90))
    footer(d, "Comité de lutte contre la douleur")
    im.save(os.path.join(OUT, "affiche_douleur.png"))


if __name__ == "__main__":
    hygiene()
    acr()
    douleur()
    print("affiches écrites dans", OUT)
