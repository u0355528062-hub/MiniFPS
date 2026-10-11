"""Signalétique et affiches (PIL) : panneaux de box, flèches au sol, affiches de prévention,
traces d'usure. Sortie : assets/textures/signaletique/*.png (RGBA pour les décalques)."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(RACINE, "assets", "textures", "signaletique")
POLICE = os.path.join(RACINE, "assets", "fonts", "Inter.ttf")
os.makedirs(SORTIE, exist_ok=True)
BLEU_URG = (14, 120, 140)


def f(t):
    return ImageFont.truetype(POLICE, t)


def centre(dr, xy, texte, police, coul):
    bb = dr.textbbox((0, 0), texte, font=police)
    dr.text((xy[0] - (bb[2] - bb[0]) / 2 - bb[0], xy[1] - (bb[3] - bb[1]) / 2 - bb[1]), texte, font=police, fill=coul)


def panneau_box(n):
    im = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle((4, 4, 508, 252), 28, fill=(250, 250, 248, 255), outline=(200, 205, 208, 255), width=3)
    dr.rounded_rectangle((4, 4, 170, 252), 28, fill=BLEU_URG + (255,))
    dr.rectangle((140, 4, 170, 252), fill=BLEU_URG + (255,))
    centre(dr, (87, 128), str(n), f(130), (255, 255, 255, 255))
    centre(dr, (340, 100), "BOX", f(84), (30, 40, 48, 255))
    centre(dr, (340, 190), "Examen", f(40), (90, 100, 108, 255))
    im.save(os.path.join(SORTIE, "box_%d.png" % n))


def fleche_sol(texte, nom, coul):
    im = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle((10, 40, 760, 216), 30, fill=coul + (235,))
    dr.polygon([(740, 10), (1010, 128), (740, 246)], fill=coul + (235,))
    centre(dr, (390, 128), texte, f(92), (255, 255, 255, 245))
    # Usure : éclaircissements aléatoires (passage des roues et des pas).
    a = np.array(im).astype(np.float32)
    rng = np.random.default_rng(len(texte))
    bruit = rng.random(a.shape[:2])
    usure = Image.fromarray((bruit * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    u = np.array(usure).astype(np.float32) / 255.0
    a[..., 3] *= np.clip(0.75 + (u - 0.5) * 2.0, 0.35, 1.0)
    Image.fromarray(a.astype(np.uint8)).save(os.path.join(SORTIE, nom + ".png"))


def traces():
    """Traces de roues et de chaussures (décalque sombre, alpha)."""
    im = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    rng = np.random.default_rng(3)
    for _ in range(60):
        x, y = rng.uniform(0, 1024, 2)
        L = rng.uniform(60, 260)
        a = rng.uniform(0, np.pi)
        pts = [(x + np.cos(a + 0.002 * t * rng.normal()) * t, y + np.sin(a) * t) for t in np.linspace(0, L, 12)]
        dr.line(pts, fill=(25, 22, 20, int(rng.uniform(20, 70))), width=int(rng.uniform(2, 6)))
    im = im.filter(ImageFilter.GaussianBlur(1.5))
    im.save(os.path.join(SORTIE, "traces.png"))


def affiche_mains():
    im = Image.new("RGB", (600, 850), (255, 255, 255))
    dr = ImageDraw.Draw(im)
    dr.rectangle((0, 0, 600, 150), fill=BLEU_URG)
    centre(dr, (300, 55), "HYGIÈNE DES MAINS", f(44), (255, 255, 255))
    centre(dr, (300, 112), "Friction hydro-alcoolique", f(30), (210, 240, 245))
    etapes = ["Paume contre paume", "Dos des mains", "Entre les doigts", "Dos des doigts", "Pouces", "Bout des doigts"]
    for i, e in enumerate(etapes):
        cx = 150 + (i % 2) * 300
        cy = 250 + (i // 2) * 190
        dr.ellipse((cx - 70, cy - 70, cx + 70, cy + 70), fill=(225, 243, 246), outline=BLEU_URG, width=4)
        centre(dr, (cx, cy - 8), str(i + 1), f(64), BLEU_URG)
        centre(dr, (cx, cy + 92), e, f(24), (40, 50, 58))
    dr.rectangle((0, 790, 600, 850), fill=(235, 240, 242))
    centre(dr, (300, 820), "20 à 30 secondes — avant et après chaque patient", f(22), (60, 70, 78))
    im.save(os.path.join(SORTIE, "affiche_mains.png"))


def affiche_avc():
    im = Image.new("RGB", (600, 850), (255, 250, 240))
    dr = ImageDraw.Draw(im)
    dr.rectangle((0, 0, 600, 190), fill=(200, 40, 40))
    centre(dr, (300, 70), "AVC : AGIR VITE", f(52), (255, 255, 255))
    centre(dr, (300, 140), "Chaque minute compte", f(32), (255, 220, 220))
    for i, (l, t) in enumerate([("V", "Visage paralysé"), ("I", "Inertie d'un membre"), ("T", "Trouble de la parole"),
                                ("E", "En urgence : faites le 15")]):
        y = 260 + i * 140
        dr.rounded_rectangle((40, y - 50, 140, y + 50), 18, fill=(200, 40, 40))
        centre(dr, (90, y), l, f(70), (255, 255, 255))
        dr.text((170, y - 22), t, font=f(36), fill=(40, 30, 30))
    centre(dr, (300, 810), "SAMU — 15", f(40), (200, 40, 40))
    im.save(os.path.join(SORTIE, "affiche_avc.png"))


def affiche_attente():
    im = Image.new("RGB", (600, 850), (245, 248, 250))
    dr = ImageDraw.Draw(im)
    dr.rectangle((0, 0, 600, 170), fill=(40, 70, 120))
    centre(dr, (300, 62), "AUX URGENCES,", f(46), (255, 255, 255))
    centre(dr, (300, 122), "LA GRAVITÉ PASSE D'ABORD", f(36), (200, 220, 255))
    lignes = ["L'ordre de passage dépend de", "votre état de santé, évalué", "par l'infirmier(ère) d'accueil",
              "et d'orientation (IOA),", "et non de l'heure d'arrivée.", "", "Merci de votre patience."]
    for i, l in enumerate(lignes):
        centre(dr, (300, 260 + i * 62), l, f(34), (40, 50, 60))
    for i, c in enumerate([(192, 57, 43), (230, 126, 34), (241, 196, 15), (39, 174, 96), (47, 128, 200)]):
        dr.rounded_rectangle((60 + i * 100, 720, 140 + i * 100, 800), 14, fill=c)
        centre(dr, (100 + i * 100, 760), str(i + 1), f(44), (255, 255, 255))
    im.save(os.path.join(SORTIE, "affiche_attente.png"))


def panneau_extincteur():
    im = Image.new("RGB", (256, 256), (200, 30, 30))
    dr = ImageDraw.Draw(im)
    dr.rectangle((10, 10, 246, 246), outline=(255, 255, 255), width=8)
    dr.rounded_rectangle((95, 60, 160, 200), 20, fill=(255, 255, 255))
    dr.rectangle((110, 40, 145, 62), fill=(255, 255, 255))
    dr.line((110, 50, 70, 80), fill=(255, 255, 255), width=10)
    im.save(os.path.join(SORTIE, "panneau_extincteur.png"))


if __name__ == "__main__":
    panneau_extincteur()
    for n in range(1, 9):
        panneau_box(n)
    fleche_sol("Radiologie", "fleche_radiologie", (40, 110, 190))
    fleche_sol("Déchocage", "fleche_dechocage", (200, 50, 50))
    fleche_sol("Accueil", "fleche_accueil", (30, 140, 90))
    traces()
    affiche_mains()
    affiche_avc()
    affiche_attente()
    print("signalétique générée")
