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


def _p(pid, genre, age, poids, teinte, cheveux, coupe, tenue, origines=None, taille=0.5, muscle=0.5, barbe=None,
       rousseurs=0.0, details=None):
    d = {"id": pid,
         "morpho": {"genre": genre, "age": age, "poids": poids, "muscle": muscle, "taille": taille,
                    "origines": origines or {"caucasian": 1.0}},
         "peau": {"teinte": teinte, "rousseurs": rousseurs},
         "cheveux": {"couleur": cheveux, "coupe": coupe, "volume": 0.010},
         "tenue": tenue}
    if barbe is not None:
        d["peau"]["barbe"] = barbe
    if details:
        d["morpho"]["details"] = details
    return d


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
    # --- Patients civils (arrivées à pied) -----------------------------------------------------
    "p_homme_jeune_jean": _p("p_homme_jeune_jean", 1.0, 0.45, 0.5, "moyenne", "brun", "court",
                             civil("tshirt_gris", "jean"), barbe=0.3),
    "p_femme_jeune": _p("p_femme_jeune", 0.0, 0.40, 0.4, "claire", "blond", "attache",
                        civil("tshirt_rouge", "jean", "baskets_noires"), rousseurs=0.4),
    "p_homme_age_pull": _p("p_homme_age_pull", 1.0, 0.85, 0.65, "claire", "blanc", "court",
                           civil("pull_marine", "pantalon_beige", "chaussures_marron", manches=1.95), barbe=0.15),
    "p_femme_agee": _p("p_femme_agee", 0.0, 0.88, 0.6, "tres_claire", "gris", "attache",
                       civil("pull_marine", "pantalon_beige", "chaussures_marron", manches=1.95)),
    "p_homme_africain": _p("p_homme_africain", 1.0, 0.55, 0.55, "foncee", "noir", "court",
                           civil("tshirt_gris", "jean"), origines={"african": 1.0}, barbe=0.4, muscle=0.6),
    "p_femme_africaine": _p("p_femme_africaine", 0.0, 0.52, 0.6, "brune", "noir", "attache",
                            civil("tshirt_rouge", "pantalon_beige", "baskets_noires"), origines={"african": 1.0}),
    "p_homme_asiatique": _p("p_homme_asiatique", 1.0, 0.48, 0.42, "mate", "noir", "court",
                            civil("pull_marine", "jean", "baskets_noires", manches=1.95), origines={"asian": 1.0}, barbe=0.1),
    "p_femme_mur": _p("p_femme_mur", 0.0, 0.65, 0.7, "moyenne", "chatain", "attache",
                      civil("pull_marine", "jean", "chaussures_marron", manches=1.95), origines={"caucasian": 0.7, "african": 0.3}),
    "p_homme_mur_fort": _p("p_homme_mur_fort", 1.0, 0.62, 0.85, "claire", "chatain", "court",
                           civil("tshirt_gris", "pantalon_beige", "chaussures_marron"), barbe=0.6),
    "p_ado": _p("p_ado", 1.0, 0.30, 0.4, "claire", "chatain", "court", civil("tshirt_rouge", "jean"), barbe=0.0,
                taille=0.55),
    # --- Patients en blouse (installés) ----------------------------------------------------------
    "p_femme_blouse": _p("p_femme_blouse", 0.0, 0.70, 0.55, "claire", "gris", "attache", patient_blouse()),
    "p_homme_blouse": _p("p_homme_blouse", 1.0, 0.55, 0.6, "mate", "noir", "court", patient_blouse(),
                         origines={"caucasian": 0.5, "african": 0.5}, barbe=0.4),
    # --- Collègues et secouristes -----------------------------------------------------------------
    "brancardier_paul": _p("brancardier_paul", 1.0, 0.5, 0.6, "moyenne", "brun", "court", soignant("pyjama_blanc"),
                           barbe=0.5, muscle=0.65),
    "ide_julien": _p("ide_julien", 1.0, 0.42, 0.45, "claire", "blond", "court", soignant("pyjama_bleu"), barbe=0.2),
    "interne_ines": _p("interne_ines", 0.0, 0.40, 0.45, "mate", "noir", "attache", soignant("pyjama_bordeaux"),
                       origines={"caucasian": 0.4, "african": 0.3, "asian": 0.3}),
    "pompier_1": _p("pompier_1", 1.0, 0.45, 0.5, "claire", "chatain", "court",
                    soignant("tenue_pompier", manches=1.95, chaussures="baskets_noires"), barbe=0.3, muscle=0.7),
    "pompier_2": _p("pompier_2", 1.0, 0.5, 0.55, "brune", "noir", "court",
                    soignant("tenue_pompier", manches=1.95, chaussures="baskets_noires"), origines={"african": 1.0},
                    barbe=0.2, muscle=0.7),
    "ambulancier_samu": _p("ambulancier_samu", 0.0, 0.48, 0.5, "claire", "chatain", "attache",
                           soignant("tenue_samu", manches=1.95, chaussures="baskets_noires")),
}
