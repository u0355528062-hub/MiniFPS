"""Mobilier des autres salles du service (étape 2) : accueil, salle d'attente, déchocage,
salle de plâtre, radiologie, scanner, véhicules de secours.

Usage : /opt/bpyenv/bin/python tools/modeles/service.py [nom ...]
Même conventions que accessoires.py (face avant vers -Y Blender = +Z Godot, matériaux nommés).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401  (bpy doit précéder bmesh)
from outils_bpy import *  # noqa
from accessoires import fin, uv_plan  # noqa

PI = math.pi


def banque_accueil():
    """Banque d'accueil : comptoir haut (1,10 m) côté public, plan de travail (0,75 m) côté IOA,
    vitre de protection, deux écrans, retour d'angle."""
    vider_scene()
    L = 2.6
    # Façade côté public (-Y) : panneau stratifié + bandeau blanc.
    boite("facade", (L, 0.04, 1.06), (0, -0.30, 0.53), "bois_porte", arrondi=0.005)
    boite("bandeau", (L, 0.05, 0.12), (0, -0.315, 0.92), "plastique_blanc", arrondi=0.01)
    boite("plinthe", (L, 0.05, 0.08), (0, -0.30, 0.04), "plastique_gris_fonce")
    boite("tablette_haute", (L + 0.04, 0.34, 0.035), (0, -0.20, 1.10), "plan_solide", arrondi=0.012)
    boite("plan_travail", (L, 0.70, 0.03), (0, 0.18, 0.75), "plan_solide", arrondi=0.008)
    boite("caisson", (0.45, 0.60, 0.72), (L / 2 - 0.25, 0.20, 0.36), "metal_peint_blanc", arrondi=0.006)
    for i in range(3):
        boite("tiroir_%d" % i, (0.42, 0.02, 0.20), (L / 2 - 0.25, -0.105, 0.60 - i * 0.23), "plastique_gris_clair",
              arrondi=0.004)
    for x in (-L / 2 + 0.02, L / 2 - 0.02):
        boite("joue_%g" % x, (0.04, 0.70, 1.10), (x, 0.0, 0.55), "bois_porte", arrondi=0.005)
    # Vitre de protection (hygiaphone) sur la tablette.
    boite("vitre", (L - 0.3, 0.012, 0.55), (0, -0.25, 1.40), "verre")
    for x in (-L / 2 + 0.16, 0.0, L / 2 - 0.16):
        boite("montant_%g" % x, (0.03, 0.03, 0.56), (x, -0.25, 1.40), "aluminium")
    boite("passe_doc", (0.36, 0.02, 0.06), (-0.5, -0.25, 1.15), "aluminium")
    # Écrans, claviers, téléphone.
    for i, x in enumerate((-0.6, 0.45)):
        boite("pied_ecran_%d" % i, (0.18, 0.15, 0.02), (x, 0.30, 0.775), "plastique_noir", arrondi=0.005)
        boite("tige_ecran_%d" % i, (0.04, 0.03, 0.30), (x, 0.33, 0.92), "plastique_noir")
        boite("coque_ecran_%d" % i, (0.56, 0.04, 0.34), (x, 0.31, 1.07), "plastique_noir", arrondi=0.006, rot=(0.12, 0, 0))
        e = boite("ecran_pc_%d" % i, (0.53, 0.004, 0.30), (x, 0.287, 1.072), "ecran_pc", rot=(0.12, 0, 0))
        uv_plan(e)
        boite("clavier_%d" % i, (0.44, 0.14, 0.02), (x, 0.05, 0.77), "plastique_noir", arrondi=0.004)
    boite("telephone", (0.18, 0.20, 0.06), (0.95, 0.10, 0.79), "plastique_gris_fonce", arrondi=0.02)
    boite("bac_docs", (0.26, 0.34, 0.08), (-1.05, 0.15, 0.80), "plastique_bleu", arrondi=0.006)
    boite("ramette", (0.21, 0.30, 0.05), (-1.05, 0.15, 0.83), "papier")
    fin("banque_accueil", sans_uv=("ecran",))


def rangee_sieges(n=4):
    """Rangée de sièges sur poutre (salle d'attente) : coques plastique, accoudoirs, pieds acier."""
    vider_scene()
    pas = 0.56
    L = n * pas
    boite("poutre", (L, 0.08, 0.05), (0, 0.05, 0.40), "metal_peint_gris", arrondi=0.008)
    for x in (-L / 2 + 0.2, L / 2 - 0.2):
        tube("pied_%g" % x, courbe_lisse([(x, -0.20, 0.0), (x, -0.05, 0.08), (x, 0.05, 0.38)], 4), 0.02, "metal_peint_gris")
        tube("pied2_%g" % x, courbe_lisse([(x, 0.30, 0.0), (x, 0.15, 0.08), (x, 0.05, 0.38)], 4), 0.02, "metal_peint_gris")
        boite("patin_%g" % x, (0.06, 0.06, 0.012), (x, -0.20, 0.006), "caoutchouc_noir")
        boite("patin2_%g" % x, (0.06, 0.06, 0.012), (x, 0.30, 0.006), "caoutchouc_noir")
    for i in range(n):
        x = -L / 2 + pas * (i + 0.5)
        boite("assise_%d" % i, (0.48, 0.44, 0.04), (x, -0.02, 0.45), "plastique_bleu_nuit", arrondi=0.016)
        boite("dossier_%d" % i, (0.48, 0.035, 0.42), (x, 0.23, 0.72), "plastique_bleu_nuit", arrondi=0.014,
              rot=(-0.16, 0, 0))
        boite("support_%d" % i, (0.05, 0.30, 0.04), (x, 0.06, 0.42), "metal_peint_gris")
    for i in range(n + 1):
        x = -L / 2 + pas * i
        boite("accoudoir_%d" % i, (0.05, 0.36, 0.03), (x, 0.0, 0.64), "plastique_noir", arrondi=0.012)
        boite("montant_acc_%d" % i, (0.03, 0.03, 0.22), (x, 0.12, 0.53), "metal_peint_gris")
    fin("rangee_sieges")


def distributeur():
    """Distributeur de boissons et snacks (façade vitrée éclairée)."""
    vider_scene()
    boite("caisson", (0.90, 0.85, 1.83), (0, 0, 0.915), "metal_peint_gris", arrondi=0.01)
    v = boite("vitrine", (0.62, 0.01, 1.20), (-0.10, -0.43, 1.10), "vitrine_distributeur")
    uv_plan(v)
    boite("cadre_vitre", (0.66, 0.012, 1.24), (-0.10, -0.427, 1.10), "plastique_noir")
    boite("panneau_cmd", (0.18, 0.02, 0.60), (0.33, -0.43, 1.25), "plastique_noir", arrondi=0.005)
    e = boite("ecran_cmd", (0.12, 0.004, 0.07), (0.33, -0.442, 1.45), "ecran_pc")
    uv_plan(e)
    for r in range(4):
        for c in range(3):
            boite("touche_%d_%d" % (r, c), (0.03, 0.006, 0.025), (0.29 + c * 0.04, -0.442, 1.32 - r * 0.035), "chrome")
    boite("monnayeur", (0.10, 0.02, 0.12), (0.33, -0.44, 1.05), "chrome", arrondi=0.005)
    boite("bac", (0.55, 0.06, 0.16), (-0.10, -0.44, 0.30), "plastique_noir", arrondi=0.01)
    boite("fronton", (0.90, 0.02, 0.16), (0, -0.43, 1.82), "fronton_distributeur")
    fin("distributeur", sans_uv=("vitrine", "ecran", "fronton"))


def ecran_tv():
    """Écran d'information mural 55 pouces (temps d'attente, consignes)."""
    vider_scene()
    boite("coque", (1.24, 0.05, 0.72), (0, 0, 0), "plastique_noir", arrondi=0.006)
    e = boite("ecran_info", (1.21, 0.004, 0.69), (0, -0.026, 0.0), "ecran_info")
    uv_plan(e)
    boite("support", (0.30, 0.08, 0.30), (0, 0.06, 0.0), "metal_peint_gris")
    fin("ecran_tv", sans_uv=("ecran",))


def defibrillateur():
    vider_scene()
    boite("corps", (0.30, 0.22, 0.24), (0, 0, 0.12), "plastique_jaune", arrondi=0.025)
    boite("facade", (0.26, 0.01, 0.18), (0, -0.11, 0.13), "plastique_gris_fonce", arrondi=0.01)
    e = boite("ecran_defib", (0.12, 0.004, 0.08), (-0.05, -0.117, 0.16), "ecran_moniteur")
    uv_plan(e)
    cylindre("bouton_choc", 0.018, 0.012, (0.08, -0.12, 0.17), "plastique_orange", 20, (PI / 2, 0, 0), biseau_l=0.003)
    cylindre("molette", 0.022, 0.015, (0.08, -0.12, 0.10), "plastique_noir", 20, (PI / 2, 0, 0), biseau_l=0.003)
    for sx in (-1, 1):
        boite("palette_%d" % sx, (0.07, 0.11, 0.05), (sx * 0.20, 0.0, 0.08), "plastique_gris", arrondi=0.015)
    tube("cable_d", courbe_lisse([(-0.2, 0.04, 0.10), (-0.25, 0.10, 0.05), (-0.15, 0.13, 0.02)], 6), 0.006, "cable_gris", seg=8)
    boite("poignee", (0.20, 0.03, 0.03), (0, 0.0, 0.26), "plastique_gris_fonce", arrondi=0.01)
    fin("defibrillateur", sans_uv=("ecran",))


def chariot_urgence():
    """Chariot d'urgence rouge (5 tiroirs, plan de massage, bouteille d'O2, défibrillateur posé)."""
    vider_scene()
    lx, ly = 0.75, 0.55
    boite("caisson", (lx, ly, 0.85), (0, 0, 0.52), "metal_peint_rouge", arrondi=0.015)
    boite("plateau", (lx + 0.06, ly + 0.06, 0.04), (0, 0, 0.97), "plastique_gris_fonce", arrondi=0.012)
    z = 0.92
    for i, h in enumerate((0.10, 0.10, 0.15, 0.20, 0.22)):
        z -= h + 0.012
        boite("facade_%d" % i, (lx - 0.06, 0.02, h), (0, -ly / 2 - 0.005, z + h / 2), "metal_peint_rouge", arrondi=0.005)
        boite("poignee_%d" % i, (0.40, 0.03, 0.02), (0, -ly / 2 - 0.022, z + h - 0.03), "aluminium", arrondi=0.006)
        boite("scelle_%d" % i, (0.03, 0.01, 0.03), (0.30, -ly / 2 - 0.018, z + h / 2), "plastique_jaune")
    boite("planche_massage", (0.04, 0.45, 0.55), (-lx / 2 - 0.03, 0, 0.62), "plastique_orange", arrondi=0.01)
    cylindre("bouteille_o2", 0.07, 0.60, (lx / 2 + 0.09, 0.10, 0.45), "blanc_o2", 24, biseau_l=0.02)
    cylindre("robinet_o2", 0.03, 0.08, (lx / 2 + 0.09, 0.10, 0.79), "chrome", 16)
    boite("support_o2", (0.04, 0.18, 0.05), (lx / 2 + 0.02, 0.10, 0.50), "aluminium")
    for sx in (-1, 1):
        for sy in (-1, 1):
            roulette("r_%d_%d" % (sx, sy), (sx * 0.30, sy * 0.21, 0.0), rayon=0.06)
    # Défibrillateur posé sur le plateau.
    boite("defib", (0.30, 0.22, 0.24), (0.10, 0.02, 1.11), "plastique_jaune", arrondi=0.025)
    boite("defib_facade", (0.26, 0.01, 0.18), (0.10, -0.09, 1.12), "plastique_gris_fonce", arrondi=0.01)
    boite("ambu", (0.25, 0.10, 0.10), (-0.22, 0.05, 1.04), "plastique_vert_clair", arrondi=0.04)
    fin("chariot_urgence")


def respirateur():
    """Respirateur de réanimation sur pied roulant (écran tactile, circuit patient)."""
    vider_scene()
    for i in range(5):
        a = 2 * PI * i / 5
        x, y = math.cos(a) * 0.30, math.sin(a) * 0.30
        tube("branche_%d" % i, [(0, 0, 0.09), (x, y, 0.07)], 0.016, "plastique_gris", seg=10)
        roulette("r_%d" % i, (x, y, 0.0), rayon=0.04)
    cylindre("colonne", 0.035, 0.80, (0, 0, 0.50), "aluminium", 20)
    boite("corps", (0.40, 0.32, 0.30), (0, 0, 1.05), "plastique_blanc", arrondi=0.03)
    boite("ecran_cadre", (0.36, 0.04, 0.28), (0, -0.19, 1.36), "plastique_gris_fonce", arrondi=0.015, rot=(0.25, 0, 0))
    e = boite("ecran_resp", (0.32, 0.004, 0.22), (0, -0.212, 1.365), "ecran_moniteur", rot=(0.25, 0, 0))
    uv_plan(e)
    tube("circuit_insp", courbe_lisse([(0.12, -0.16, 1.00), (0.25, -0.30, 0.95), (0.35, -0.55, 1.00), (0.40, -0.80, 0.95)], 8),
         0.011, "tubulure_bleue", seg=10)
    tube("circuit_exp", courbe_lisse([(0.05, -0.16, 1.00), (0.15, -0.32, 0.90), (0.30, -0.58, 0.92), (0.40, -0.80, 0.95)], 8),
         0.011, "tubulure", seg=10)
    tube("bras_support", courbe_lisse([(0.20, 0.0, 1.10), (0.35, -0.10, 1.25), (0.42, -0.35, 1.25)], 6), 0.01, "aluminium")
    fin("respirateur", sans_uv=("ecran",))


def scialytique():
    """Éclairage opératoire plafonnier à deux coupoles (déchocage). Origine = fixation au plafond."""
    vider_scene()
    cylindre("platine", 0.15, 0.04, (0, 0, -0.02), "metal_peint_blanc", 32)
    cylindre("axe", 0.04, 0.35, (0, 0, -0.20), "metal_peint_blanc", 20)
    for k, (ang, lg, h) in enumerate(((0.3, 0.9, -0.55), (2.6, 0.75, -0.70))):
        x, y = math.cos(ang) * lg, math.sin(ang) * lg
        tube("bras_%d" % k, [(0, 0, -0.35 - k * 0.06), (x * 0.6, y * 0.6, -0.35 - k * 0.06), (x, y, h + 0.12)], 0.035,
             "metal_peint_blanc", seg=14)
        tour("coupole_%d" % k, [(0.0, 0.0), (0.30, 0.0), (0.34, 0.04), (0.30, 0.12), (0.10, 0.16), (0.0, 0.16)],
             (x, y, h - 0.06), "metal_peint_blanc", seg=40)
        cylindre("led_%d" % k, 0.28, 0.005, (x, y, h - 0.063), "led_lampe", 40)
        cylindre("poignee_%d" % k, 0.03, 0.12, (x, y, h - 0.12), "plastique_gris", 16)
    fin("scialytique")


def table_platre():
    """Table d'examen fixe (salle de plâtre) avec rouleau de papier, seau et bandes."""
    vider_scene()
    boite("socle", (0.50, 0.45, 0.55), (0, 0, 0.30), "metal_peint_blanc", arrondi=0.02)
    boite("plateau", (1.90, 0.68, 0.03), (0, 0, 0.62), "metal_peint_blanc", arrondi=0.01)
    boite("matelas", (1.86, 0.66, 0.08), (0, 0, 0.675), "skai_vert", arrondi=0.03, segments=4)
    boite("papier", (1.40, 0.50, 0.004), (-0.15, 0, 0.717), "papier")
    cylindre("rouleau", 0.06, 0.55, (0.98, 0, 0.72), "papier", 24, (PI / 2, 0, 0))
    cylindre("seau", 0.16, 0.30, (1.25, -0.60, 0.15), "plastique_bleu", 32, rayon2=0.18, biseau_l=0.01)
    cylindre("eau_seau", 0.17, 0.01, (1.25, -0.60, 0.26), "eau", 32)
    for i in range(4):
        cylindre("bande_%d" % i, 0.04, 0.10, (-0.70 + i * 0.12, -0.20, 0.77), "platre", 20, (0, PI / 2, 0))
    fin("table_platre")


def table_radio():
    """Salle de radiologie : table flottante, tube radiogène sur colonne plafonnière, détecteur mural."""
    vider_scene()
    boite("socle", (0.60, 0.50, 0.55), (0, 0, 0.28), "plastique_blanc", arrondi=0.03)
    boite("plateau", (2.10, 0.80, 0.06), (0, 0, 0.78), "carbone", arrondi=0.02)
    # Colonne télescopique suspendue au rail du plafond (le rail est posé par le jeu).
    boite("chariot_rail", (0.40, 0.40, 0.12), (0.2, 0, 2.62), "metal_peint_blanc", arrondi=0.02)
    boite("colonne", (0.16, 0.16, 0.95), (0.2, 0, 2.10), "metal_peint_blanc", arrondi=0.02)
    boite("tube", (0.48, 0.24, 0.22), (0.2, 0, 1.55), "metal_peint_blanc", arrondi=0.04)
    boite("collimateur", (0.24, 0.22, 0.16), (0.2, 0, 1.37), "plastique_gris", arrondi=0.02)
    boite("poignees", (0.36, 0.05, 0.04), (0.2, -0.16, 1.40), "plastique_gris_fonce", arrondi=0.015)
    e = boite("ecran_radio", (0.14, 0.004, 0.09), (0.2, -0.122, 1.56), "ecran_pc")
    uv_plan(e)
    fin("table_radio", sans_uv=("ecran",))


def scanner():
    """Scanner (tomodensitomètre) : statif annulaire et table mobile."""
    vider_scene()
    # Statif : couronne épaisse (face avant -Y).
    tore("anneau_ext", 0.78, 0.30, (0, 0, 1.05), "plastique_blanc", seg=64, seg2=24, rot=(PI / 2, 0, 0))
    boite("carenage", (2.10, 0.95, 1.90), (0, 0.0, 0.98), "plastique_blanc", arrondi=0.25, segments=6)
    tour("tunnel", [(0.36, -0.49), (0.37, -0.45), (0.37, 0.45), (0.36, 0.49)], (0, 0, 1.05), "plastique_gris_clair",
         seg=64, rot=(PI / 2, 0, 0))
    boite("bandeau_bleu", (1.20, 0.01, 0.06), (0, -0.48, 1.85), "led_bleue")
    e = boite("ecran_scanner", (0.20, 0.004, 0.12), (-0.55, -0.48, 1.30), "ecran_pc")
    uv_plan(e)
    # Table.
    boite("socle_table", (1.30, 0.50, 0.70), (0, -1.35, 0.35), "plastique_blanc", arrondi=0.06)
    boite("plateau_table", (2.20, 0.42, 0.06), (0, -1.15, 0.85), "carbone", arrondi=0.02, rot=(0, 0, PI / 2))
    boite("matelas_table", (2.00, 0.40, 0.05), (0, -1.15, 0.90), "skai_noir", arrondi=0.02, rot=(0, 0, PI / 2))
    fin("scanner", sans_uv=("ecran",))


def vehicule(nom, couleur_caisse, bande, texte_mat):
    """Véhicule de secours (fourgon) : SAMU (blanc à bandes) ou VSAV pompiers (rouge)."""
    vider_scene()
    L, W, H = 5.9, 2.05, 2.55
    # Caisse sanitaire arrière.
    boite("cellule", (3.6, W, 2.15), (-0.95, 0, 1.35), couleur_caisse, arrondi=0.08, segments=4)
    # Cabine avec capot incliné.
    boite("cabine", (1.6, W - 0.04, 1.35), (1.65, 0, 1.30), couleur_caisse, arrondi=0.12, segments=4)
    boite("capot", (0.75, W - 0.10, 0.55), (2.70, 0, 0.95), couleur_caisse, arrondi=0.15, segments=4, rot=(0, 0.25, 0))
    boite("pare_brise", (0.05, W - 0.20, 0.80), (2.42, 0, 1.55), "verre_teinte", rot=(0, -0.45, 0))
    for sy in (-1, 1):
        boite("vitre_porte_%d" % sy, (0.80, 0.02, 0.55), (1.75, sy * (W / 2 - 0.005), 1.62), "verre_teinte")
        boite("bande_%d" % sy, (5.2, 0.02, 0.22), (0.1, sy * (W / 2 + 0.005), 1.05), bande)
        t = boite("texte_%d" % sy, (2.4, 0.02, 0.40), (-1.0, sy * (W / 2 + 0.012), 1.75), texte_mat,
                  rot=(0, 0, PI if sy > 0 else 0))
        uv_plan(t)
        boite("retro_%d" % sy, (0.10, 0.20, 0.25), (2.30, sy * (W / 2 + 0.10), 1.70), "plastique_noir", arrondi=0.03)
    boite("calandre", (0.06, 1.40, 0.35), (3.06, 0, 0.82), "plastique_noir", arrondi=0.03)
    for sy in (-1, 1):
        boite("phare_%d" % sy, (0.06, 0.32, 0.16), (3.05, sy * 0.78, 1.00), "phare", arrondi=0.03)
    boite("pare_choc", (0.20, W, 0.25), (3.05, 0, 0.45), "plastique_gris_fonce", arrondi=0.06)
    boite("pare_choc_ar", (0.20, W, 0.25), (-2.80, 0, 0.45), "plastique_gris_fonce", arrondi=0.06)
    boite("portes_ar", (0.03, W - 0.15, 1.70), (-2.76, 0, 1.30), couleur_caisse)
    boite("vitres_ar", (0.035, 1.40, 0.35), (-2.77, 0, 1.85), "verre_teinte")
    boite("plancher", (5.4, W - 0.2, 0.25), (0.2, 0, 0.40), "metal_peint_gris")
    # Rampe de gyrophares et feux à éclats.
    boite("rampe", (0.30, 1.50, 0.10), (2.20, 0, 2.03), "plastique_noir", arrondi=0.03)
    for sy in (-1, 1):
        boite("gyro_%d" % sy, (0.26, 0.50, 0.09), (2.20, sy * 0.45, 2.10), "gyrophare", arrondi=0.03)
        boite("feu_ar_%d" % sy, (0.08, 0.15, 0.25), (-2.75, sy * 0.92, 2.25), "gyrophare", arrondi=0.02)
    # Roues.
    for x in (2.15, -1.75):
        for sy in (-1, 1):
            cylindre("pneu_%g_%d" % (x, sy), 0.38, 0.26, (x, sy * 0.90, 0.38), "caoutchouc_noir", 32, (PI / 2, 0, 0),
                     biseau_l=0.05)
            cylindre("jante_%g_%d" % (x, sy), 0.22, 0.27, (x, sy * 0.90, 0.38), "aluminium", 24, (PI / 2, 0, 0))
    fin(nom, uv=1.0, sans_uv=("texte",))


TOUS = {
    "banque_accueil": banque_accueil, "rangee_sieges": rangee_sieges, "distributeur": distributeur,
    "ecran_tv": ecran_tv, "defibrillateur": defibrillateur, "chariot_urgence": chariot_urgence,
    "respirateur": respirateur, "scialytique": scialytique, "table_platre": table_platre,
    "table_radio": table_radio, "scanner": scanner,
    "ambulance_samu": lambda: vehicule("ambulance_samu", "carrosserie_blanche", "bande_samu", "texte_samu"),
    "vsav_pompiers": lambda: vehicule("vsav_pompiers", "carrosserie_rouge", "bande_pompiers", "texte_pompiers"),
}

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    for n in (args or list(TOUS)):
        TOUS[n]()
