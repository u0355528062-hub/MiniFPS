"""Catalogue des personnages et génération (avec cache) de leurs textures.

Textures : assets/personnages/textures/<cle>/{albedo.jpg, normal.jpg, orm.jpg}
- peau_<teinte>_<h|f>_<tranche d'âge>_<barbe> : partagées par tous les personnages semblables ;
- tenue_<nom>, cheveux_<couleur> : partagées (même atlas UV pour tous les corps).
"""
import os

import numpy as np
from PIL import Image

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(RACINE, "assets", "personnages", "textures")

COULEURS_CHEVEUX = {
    "noir": (0.05, 0.04, 0.035), "brun": (0.16, 0.10, 0.06), "chatain": (0.32, 0.21, 0.12),
    "blond": (0.70, 0.55, 0.32), "roux": (0.55, 0.22, 0.08), "gris": (0.55, 0.54, 0.52),
    "blanc": (0.85, 0.84, 0.82), "poivre_sel": (0.38, 0.37, 0.36),
}


def _ecrire(dossier, alb, nrm, orm):
    os.makedirs(dossier, exist_ok=True)
    for nom, img in (("albedo", alb), ("normal", nrm), ("orm", orm)):
        data = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
        if img.shape[-1] == 4:
            Image.fromarray(data, "RGBA").save(os.path.join(dossier, nom + ".png"), optimize=True)
        else:
            Image.fromarray(data, "RGB").save(os.path.join(dossier, nom + ".jpg"), quality=92, subsampling=0)


def _chemins(dossier):
    r = {k: os.path.join(dossier, k + ".jpg") for k in ("albedo", "normal", "orm")}
    if os.path.exists(os.path.join(dossier, "albedo.png")):
        r["albedo"] = os.path.join(dossier, "albedo.png")
    return r


def cle_peau(p):
    m = p["morpho"]
    s = p.get("peau", {})
    age = m.get("age", 0.5)
    tranche = "jeune" if age < 0.55 else ("mur" if age < 0.75 else "age")
    genre = "h" if m.get("genre", 0.5) > 0.5 else "f"
    barbe = s.get("barbe", 0.35 if genre == "h" else 0.0)
    return "%s_%s_%s_b%d" % (s.get("teinte", "claire"), genre, tranche, int(round(barbe * 10)))


def textures_peau(p, forcer=False):
    from peau import peindre_peau
    cle = cle_peau(p)
    d = os.path.join(TEX, "peau_" + cle)
    if forcer or not os.path.exists(os.path.join(d, "orm.jpg")):
        m = p["morpho"]
        s = dict(p.get("peau", {}))
        s.setdefault("genre", m.get("genre", 0.5))
        s.setdefault("age", m.get("age", 0.5))
        ch = p.get("cheveux", {}).get("couleur", "brun")
        s.setdefault("couleur_poils", COULEURS_CHEVEUX.get(ch, COULEURS_CHEVEUX["brun"]))
        _ecrire(d, *peindre_peau(s, 2048, graine=sum(map(ord, cle))))
    r = _chemins(d)
    r["cle"] = cle
    return r


def textures_tenue(nom, forcer=False):
    from tenues import peindre_tenue
    d = os.path.join(TEX, "tenue_" + nom)
    if forcer or not os.path.exists(os.path.join(d, "orm.jpg")):
        _ecrire(d, *peindre_tenue(nom))
    return _chemins(d)


def textures_cheveux(couleur, forcer=False):
    from tenues import peindre_cheveux
    d = os.path.join(TEX, "cheveux_" + couleur)
    if forcer or not os.path.exists(os.path.join(d, "albedo.png")):
        _ecrire(d, *peindre_cheveux(COULEURS_CHEVEUX[couleur]))
    return _chemins(d)


def soignant(tenue, manches=0.45, chaussures="sabots_blancs"):
    return {"pieces": [
        {"type": "pantalon", "materiau": "tenue_" + tenue, "nom": "Pantalon"},
        {"type": "haut", "materiau": "tenue_" + tenue, "manches": manches, "nom": "Haut"},
        {"type": "chaussures", "materiau": "tenue_" + chaussures, "nom": "Chaussures"},
    ]}


def civil(haut, bas, chaussures="baskets_noires", manches=0.45):
    return {"pieces": [
        {"type": "pantalon", "materiau": "tenue_" + bas, "nom": "Pantalon"},
        {"type": "haut", "materiau": "tenue_" + haut, "manches": manches, "col_v": 0.02, "nom": "Haut"},
        {"type": "chaussures", "materiau": "tenue_" + chaussures, "nom": "Chaussures"},
    ]}


def patient_blouse():
    return {"pieces": [
        {"type": "haut", "materiau": "tenue_blouse_patient", "manches": 0.35, "col_v": 0.03, "bas": 0.05,
         "ample": 0.022, "nom": "Blouse"},
        {"type": "jupe_aide", "materiau": "tenue_blouse_patient", "nom": "BlouseBas"},
    ]}


PERSONNAGES = {
    # --- Soignants -------------------------------------------------------------------------
    "infirmiere_claire": {
        "id": "infirmiere_claire",
        "morpho": {"genre": 0.0, "age": 0.42, "poids": 0.45, "muscle": 0.5, "taille": 0.55,
                   "origines": {"caucasian": 0.9, "african": 0.0, "asian": 0.1}},
        "peau": {"teinte": "claire", "rousseurs": 0.3},
        "cheveux": {"couleur": "chatain", "coupe": "attache", "volume": 0.010},
        "tenue": soignant("pyjama_bleu"),
    },
    "medecin_karim": {
        "id": "medecin_karim",
        "morpho": {"genre": 1.0, "age": 0.55, "poids": 0.5, "muscle": 0.55, "taille": 0.55,
                   "origines": {"caucasian": 0.6, "african": 0.3, "asian": 0.1}},
        "peau": {"teinte": "mate", "barbe": 0.5},
        "cheveux": {"couleur": "noir", "coupe": "court", "volume": 0.008},
        "tenue": soignant("pyjama_vert"),
    },
    # --- Patients ----------------------------------------------------------------------------
    "patient_gerard": {
        "id": "patient_gerard",
        "morpho": {"genre": 1.0, "age": 0.80, "poids": 0.72, "muscle": 0.4, "taille": 0.5,
                   "origines": {"caucasian": 1.0}},
        "peau": {"teinte": "claire", "barbe": 0.25, "rougeur": 0.8},
        "cheveux": {"couleur": "poivre_sel", "coupe": "court", "volume": 0.006},
        "tenue": patient_blouse(),
    },
}
