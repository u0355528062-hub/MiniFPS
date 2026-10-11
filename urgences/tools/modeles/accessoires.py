"""Modèles 3D du mobilier hospitalier, générés par script (Blender en module Python).

Usage : /opt/bpyenv/bin/python tools/modeles/accessoires.py [nom ...]
Sortie : assets/models/mobilier/<nom>.glb

Repère Blender : X = longueur, Y = profondeur (la FACE AVANT regarde -Y), Z = haut.
À l'export glTF (Y haut), la face avant regarde +Z dans Godot.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from outils_bpy import *  # noqa

SORTIE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "mobilier"))
PI = math.pi


def fin(nom, uv=1.0, sans_uv=()):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not any(o.name.startswith(s) for s in sans_uv):
            uv_cube(o, uv)
    fusionner_tout(nom)
    exporter(os.path.join(SORTIE, nom + ".glb"))


def uv_plan(o):
    """UV 0..1 sur la face avant (écrans, étiquettes) : projection X/Z sur la boîte englobante."""
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    uv = me.uv_layers.active.data
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))


# =============================================================================================
def brancard():
    """Brancard d'urgence (type Stryker) : dossier relevé à 35°, barrières baissées."""
    vider_scene()
    L, W = 2.02, 0.70
    zp = 0.60  # hauteur du plan de couchage (dessus du sommier)
    # Châssis bas : carénage plastique.
    boite("base_carenage", (1.62, 0.56, 0.10), (0, 0, 0.22), "plastique_gris", arrondi=0.03, segments=3)
    boite("base_cadre", (1.80, 0.50, 0.04), (0, 0, 0.16), "metal_peint_gris", arrondi=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            roulette("roul_%d_%d" % (sx, sy), (sx * 0.80, sy * 0.24, 0.0), rayon=0.075)
        # Pédales de frein (rouge) et de direction (vert).
        boite("pedale_%d" % sx, (0.06, 0.46, 0.025), (sx * 0.93, 0, 0.13), "plastique_rouge" if sx > 0 else "plastique_vert",
              arrondi=0.008)
    # Colonnes hydrauliques avec soufflets.
    for x in (-0.42, 0.42):
        cylindre("colonne_%g" % x, 0.07, 0.30, (x, 0, 0.42), "plastique_noir", segments=28, biseau_l=0.01)
        for k in range(8):
            tore("soufflet_%g_%d" % (x, k), 0.072, 0.006, (x, 0, 0.29 + k * 0.035), "plastique_noir", seg=28, seg2=8)
    # Cadre du sommier en tube inox.
    zc = zp - 0.06
    for sy in (-1, 1):
        tube("longeron_%d" % sy, [(-L / 2 + 0.06, sy * 0.30, zc), (L / 2 - 0.06, sy * 0.30, zc)], 0.017, "inox")
    for x in (-L / 2 + 0.06, 0.20):
        tube("traverse_%g" % x, [(x, -0.30, zc), (x, 0.30, zc)], 0.015, "inox")
    boite("sommier_jambes", (1.20, 0.60, 0.012), (-0.40, 0, zp - 0.03), "metal_peint_blanc", arrondi=0.004)
    # Dossier relevé (charnière en x = 0.20).
    ang = math.radians(35)
    lg_dos = 0.78
    cx = 0.20 + math.cos(ang) * lg_dos / 2
    cz = zp - 0.03 + math.sin(ang) * lg_dos / 2
    boite("sommier_dos", (lg_dos, 0.60, 0.012), (cx, 0, cz), "metal_peint_blanc", arrondi=0.004, rot=(0, -ang, 0))
    vb = boite("verin_dos", (0.30, 0.03, 0.03), (0.40, 0, zp - 0.15), "inox", rot=(0, -0.5, 0))
    # Matelas en deux parties (skaï bleu, coins très arrondis).
    ep = 0.10
    boite("matelas_jambes", (1.22, 0.64, ep), (-0.40, 0, zp - 0.03 + ep / 2 + 0.006), "skai_bleu", arrondi=0.035, segments=4)
    mx = 0.20 + math.cos(ang) * lg_dos / 2 - math.sin(ang) * (ep / 2 + 0.006)
    mz = zp - 0.03 + math.sin(ang) * lg_dos / 2 + math.cos(ang) * (ep / 2 + 0.006)
    boite("matelas_dos", (lg_dos, 0.64, ep), (mx, 0, mz), "skai_bleu", arrondi=0.035, segments=4, rot=(0, -ang, 0))
    # Drap (fine couche blanche sur le matelas, légèrement plus large) et oreiller.
    boite("drap_jambes", (1.20, 0.66, 0.012), (-0.41, 0, zp - 0.03 + ep + 0.012), "tissu_drap", arrondi=0.005)
    dx = 0.20 + math.cos(ang) * lg_dos / 2 - math.sin(ang) * (ep + 0.012)
    dz = zp - 0.03 + math.sin(ang) * lg_dos / 2 + math.cos(ang) * (ep + 0.012)
    boite("drap_dos", (lg_dos - 0.02, 0.66, 0.012), (dx, 0, dz), "tissu_drap", arrondi=0.005, rot=(0, -ang, 0))
    ox = 0.20 + math.cos(ang) * (lg_dos - 0.16) - math.sin(ang) * (ep + 0.06)
    oz = zp - 0.03 + math.sin(ang) * (lg_dos - 0.16) + math.cos(ang) * (ep + 0.06)
    o = boite("oreiller", (0.36, 0.56, 0.11), (ox, 0, oz), "tissu_oreiller", arrondi=0.045, segments=5, rot=(0, -ang, 0))
    # Barrières latérales baissées (tubes inox).
    for sy in (-1, 1):
        y = sy * 0.36
        for z in (zp - 0.02, zp + 0.10):
            tube("barriere_%d_%g" % (sy, z), courbe_lisse([(-0.55, y, z), (-0.50, y, z + 0.0), (0.45, y, z), (0.50, y, z)], 4),
                 0.012, "inox")
        for x in (-0.50, -0.02, 0.45):
            tube("barreau_%d_%g" % (sy, x), [(x, y, zp - 0.02), (x, y, zp + 0.10)], 0.010, "inox")
        boite("bras_barriere_%d" % sy, (0.04, 0.06, 0.08), (-0.52, sy * 0.33, zp - 0.05), "plastique_gris", arrondi=0.008)
    # Poignées de poussée (pied du brancard).
    for sy in (-1, 1):
        tube("poignee_%d" % sy, courbe_lisse([(-L / 2 + 0.05, sy * 0.27, zc), (-L / 2 - 0.02, sy * 0.27, zc + 0.10),
                                             (-L / 2 - 0.03, sy * 0.24, zc + 0.30), (-L / 2 - 0.03, 0, zc + 0.32)], 5),
             0.016, "inox")
    # Pare-chocs d'angle et fourreaux de pied à perfusion.
    for sx in (-1, 1):
        for sy in (-1, 1):
            cylindre("parechoc_%d_%d" % (sx, sy), 0.035, 0.05, (sx * (L / 2 - 0.04), sy * 0.31, zc), "caoutchouc_gris", 20)
            cylindre("fourreau_%d_%d" % (sx, sy), 0.012, 0.08, (sx * (L / 2 - 0.10), sy * 0.33, zc + 0.02), "inox", 12)
    # Porte-bouteille d'oxygène (support simple) sous le pied.
    boite("bac_rangement", (0.40, 0.42, 0.05), (-0.62, 0, 0.30), "plastique_gris_fonce", arrondi=0.01)
    fin("brancard")


# =============================================================================================
def moniteur():
    """Moniteur multiparamétrique (ECG, SpO2, PNI, température) monté sur bras mural."""
    vider_scene()
    # Boîtier 32 x 26 cm, profondeur 9 cm. Face avant vers -Y.
    boite("boitier", (0.34, 0.10, 0.28), (0, 0, 0), "plastique_blanc", arrondi=0.018, segments=4)
    boite("cadre_ecran", (0.30, 0.012, 0.215), (0.0, -0.051, 0.018), "plastique_noir", arrondi=0.004)
    e = boite("ecran_moniteur", (0.278, 0.004, 0.19), (0.0, -0.058, 0.018), "ecran_moniteur")
    uv_plan(e)
    # Bandeau de touches et molette.
    boite("bandeau", (0.30, 0.012, 0.03), (0, -0.051, -0.112), "plastique_gris", arrondi=0.004)
    for i in range(6):
        boite("touche_%d" % i, (0.026, 0.006, 0.014), (-0.12 + i * 0.034, -0.058, -0.112), "plastique_gris_fonce",
              arrondi=0.003)
    cylindre("molette", 0.014, 0.012, (0.125, -0.06, -0.112), "plastique_noir", 20, (PI / 2, 0, 0), biseau_l=0.002)
    boite("led_alarme", (0.06, 0.006, 0.008), (0.0, -0.051, 0.135), "led_alarme")
    # Poignée de transport.
    tube("poignee", courbe_lisse([(-0.12, 0, 0.14), (-0.10, 0, 0.18), (0.10, 0, 0.18), (0.12, 0, 0.14)], 6), 0.012,
         "plastique_gris")
    # Bras articulé mural (rail GCX).
    boite("support", (0.10, 0.06, 0.10), (0, 0.08, -0.04), "aluminium", arrondi=0.01)
    tube("bras1", [(0, 0.11, -0.04), (0, 0.30, -0.06)], 0.022, "aluminium", seg=16)
    cylindre("articulation", 0.03, 0.06, (0, 0.30, -0.06), "plastique_gris_fonce", 20)
    tube("bras2", [(0, 0.30, -0.06), (0.0, 0.48, -0.06)], 0.022, "aluminium", seg=16)
    boite("platine_murale", (0.12, 0.02, 0.22), (0, 0.49, -0.06), "aluminium", arrondi=0.005)
    # Câbles (faisceau vers le patient) qui sortent sur le côté gauche.
    for i, c in enumerate(("cable_gris", "cable_bleu", "cable_gris")):
        tube("cable_%d" % i, courbe_lisse([(-0.17, -0.01, -0.05 - i * 0.02), (-0.20, -0.03, -0.10 - i * 0.02),
                                          (-0.21, -0.06, -0.30), (-0.18, -0.12, -0.50)], 6), 0.004, c, seg=8)
    fin("moniteur", sans_uv=("ecran",))


# =============================================================================================
def pied_perfusion():
    """Pied à perfusion à 5 branches, poche de soluté, chambre compte-gouttes et tubulure."""
    vider_scene()
    for i in range(5):
        a = 2 * PI * i / 5
        x, y = math.cos(a) * 0.30, math.sin(a) * 0.30
        tube("branche_%d" % i, [(0, 0, 0.09), (x * 0.95, y * 0.95, 0.07)], 0.014, "inox", seg=10)
        roulette("roul_%d" % i, (x, y, 0.0), rayon=0.033)
    cylindre("moyeu", 0.04, 0.06, (0, 0, 0.09), "plastique_gris_fonce", 20, biseau_l=0.006)
    cylindre("mat_bas", 0.016, 1.10, (0, 0, 0.66), "inox", 16)
    cylindre("bague", 0.022, 0.05, (0, 0, 1.22), "plastique_gris_fonce", 16, biseau_l=0.004)
    cylindre("mat_haut", 0.011, 0.85, (0, 0, 1.64), "inox", 16)
    sphere("bout", 0.014, (0, 0, 2.07), "inox")
    # Couronne à 4 crochets.
    cylindre("couronne", 0.02, 0.03, (0, 0, 2.02), "inox", 16)
    for i in range(4):
        a = PI / 4 + i * PI / 2
        x, y = math.cos(a), math.sin(a)
        tube("crochet_%d" % i, courbe_lisse([(0, 0, 2.02), (x * 0.10, y * 0.10, 2.04), (x * 0.14, y * 0.14, 2.02),
                                             (x * 0.15, y * 0.15, 1.98), (x * 0.13, y * 0.13, 1.96)], 5), 0.004, "inox", seg=8)
    # Poche de 500 mL suspendue au crochet avant (-Y).
    a = PI / 4 + 3 * PI / 2
    px, py = math.cos(a) * 0.14, math.sin(a) * 0.14
    p = sphere("poche", 0.5, (px, py, 1.80), "poche_perf", seg=24, anneaux=16, echelle=(0.11, 0.035, 0.20))
    boite("etiquette_poche", (0.07, 0.002, 0.08), (px, py - 0.017, 1.80), "etiquette")
    boite("liquide", (0.10, 0.02, 0.12), (px, py, 1.75), "liquide", arrondi=0.008)
    cylindre("embout_poche", 0.006, 0.04, (px, py, 1.69), "plastique_blanc", 10)
    cylindre("chambre", 0.009, 0.06, (px, py, 1.63), "poche_perf", 14)
    cylindre("chambre_liq", 0.0085, 0.02, (px, py, 1.61), "liquide", 14)
    tube("tubulure", courbe_lisse([(px, py, 1.60), (px, py - 0.02, 1.40), (px + 0.05, py - 0.10, 1.10),
                                   (px + 0.25, py - 0.20, 0.95), (px + 0.45, py - 0.25, 0.90)], 6), 0.002, "tubulure", seg=6)
    cylindre("molette_debit", 0.008, 0.03, (px, py - 0.02, 1.38), "plastique_blanc", 10, biseau_l=0.002)
    fin("pied_perfusion")


# =============================================================================================
def bandeau_tete_lit():
    """Bandeau de tête de lit (gaz médicaux, prises, éclairage indirect). Plaqué au mur (face -Y)."""
    vider_scene()
    lg = 1.80
    boite("profil", (lg, 0.09, 0.26), (0, 0, 0), "aluminium_laque", arrondi=0.02, segments=4)
    boite("diffuseur_haut", (lg - 0.04, 0.05, 0.01), (0, -0.01, 0.13), "led_indirect")
    # Prises de courant françaises (blanches) et prises ondulées (rouges).
    for i, x in enumerate((-0.70, -0.58, -0.46, 0.46, 0.58)):
        mat = "plastique_rouge" if i >= 3 else "plastique_blanc"
        boite("prise_%d" % i, (0.08, 0.012, 0.08), (x, -0.05, 0.02), mat, arrondi=0.008)
        cylindre("prise_creux_%d" % i, 0.022, 0.006, (x, -0.057, 0.02), "plastique_gris", 20, (PI / 2, 0, 0))
    # Prises de fluides : O2 (blanc), air (noir/blanc), vide (jaune).
    fluides = [("o2", -0.20, "plastique_blanc"), ("air", -0.06, "plastique_noir"), ("vide", 0.24, "plastique_jaune")]
    for nom, x, mat in fluides:
        cylindre("prise_%s" % nom, 0.034, 0.025, (x, -0.055, -0.02), mat, 24, (PI / 2, 0, 0), biseau_l=0.004)
        cylindre("prise_%s_inox" % nom, 0.016, 0.02, (x, -0.07, -0.02), "inox_poli", 20, (PI / 2, 0, 0))
    # Débitmètre d'oxygène + humidificateur.
    x = -0.20
    cylindre("debit_corps", 0.022, 0.16, (x, -0.11, 0.06), "plastique_transparent", 20)
    sphere("debit_bille", 0.006, (x, -0.11, 0.05), "plastique_vert")
    cylindre("debit_bouton", 0.018, 0.03, (x, -0.11, 0.155), "plastique_vert", 20, biseau_l=0.004)
    cylindre("debit_base", 0.02, 0.05, (x, -0.10, -0.02), "inox_poli", 16, (PI / 2, 0, 0))
    cylindre("humidif", 0.035, 0.12, (x, -0.11, -0.12), "plastique_transparent", 24)
    cylindre("humidif_eau", 0.032, 0.07, (x, -0.11, -0.145), "eau", 24)
    # Régulateur de vide + bocal d'aspiration.
    x = 0.24
    cylindre("regul_corps", 0.03, 0.05, (x, -0.10, -0.02), "plastique_blanc", 20, (PI / 2, 0, 0), biseau_l=0.005)
    cylindre("regul_cadran", 0.026, 0.006, (x, -0.128, -0.02), "cadran", 20, (PI / 2, 0, 0))
    boite("rail_bocal", (0.20, 0.03, 0.04), (x + 0.02, -0.06, -0.09), "aluminium", arrondi=0.005)
    cylindre("bocal", 0.065, 0.20, (x + 0.02, -0.13, -0.22), "plastique_transparent", 28, biseau_l=0.01)
    cylindre("bocal_couv", 0.068, 0.025, (x + 0.02, -0.13, -0.11), "plastique_bleu", 28, biseau_l=0.006)
    tube("tuyau_aspi", courbe_lisse([(x + 0.04, -0.13, -0.10), (x + 0.10, -0.16, -0.05), (x + 0.20, -0.18, -0.15),
                                     (x + 0.25, -0.15, -0.40)], 6), 0.006, "tubulure", seg=8)
    # Lampe de lecture articulée et interrupteur d'appel infirmière.
    boite("appel", (0.06, 0.012, 0.06), (0.72, -0.05, 0.02), "plastique_blanc", arrondi=0.006)
    cylindre("appel_bouton", 0.015, 0.006, (0.72, -0.058, 0.02), "plastique_orange", 16, (PI / 2, 0, 0))
    fin("bandeau_tete_lit")


# =============================================================================================
def lavabo():
    """Lave-mains inox à commande au coude + distributeurs (savon, SHA, essuie-mains). Face -Y."""
    vider_scene()
    # Vasque : coque arrondie.
    boite("plan", (0.50, 0.40, 0.04), (0, -0.20, 0.85), "inox", arrondi=0.015)
    tour("vasque", [(0.0, 0.70), (0.06, 0.70), (0.16, 0.73), (0.19, 0.80), (0.20, 0.86), (0.21, 0.865)],
         (0, -0.21, 0), "inox", seg=40).scale = (1.15, 0.9, 1.0)
    boite("dosseret", (0.50, 0.02, 0.25), (0, -0.01, 0.98), "inox", arrondi=0.006)
    boite("habillage", (0.30, 0.25, 0.30), (0, -0.13, 0.62), "inox", arrondi=0.01)
    # Robinet col de cygne + levier coude.
    tube("col", courbe_lisse([(0, -0.03, 0.95), (0, -0.04, 1.12), (0, -0.12, 1.16), (0, -0.20, 1.08)], 8), 0.012, "chrome")
    cylindre("mitigeur", 0.025, 0.06, (0.08, -0.04, 0.96), "chrome", 20, biseau_l=0.004)
    tube("levier", [(0.08, -0.04, 0.99), (0.08, -0.22, 1.00)], 0.006, "chrome")
    # Distributeurs muraux.
    def distrib(nom, x, z, mat, h=0.22):
        boite(nom, (0.11, 0.10, h), (x, -0.06, z), mat, arrondi=0.015)
        boite(nom + "_fenetre", (0.05, 0.004, 0.06), (x, -0.112, z + 0.02), "plastique_transparent", arrondi=0.003)
        boite(nom + "_poussoir", (0.08, 0.03, 0.05), (x, -0.10, z - h / 2 + 0.03), "plastique_gris", arrondi=0.008)
    distrib("savon", -0.17, 1.30, "plastique_blanc")
    distrib("sha", 0.17, 1.30, "plastique_bleu")
    boite("essuie_mains", (0.30, 0.13, 0.38), (0.48, -0.065, 1.35), "plastique_blanc", arrondi=0.02, segments=4)
    boite("essuie_fenetre", (0.18, 0.004, 0.04), (0.48, -0.132, 1.40), "plastique_transparent")
    boite("essuie_papier", (0.22, 0.02, 0.06), (0.48, -0.12, 1.15), "papier", arrondi=0.004)
    fin("lavabo")


# =============================================================================================
def chariot_soins():
    """Chariot de soins à tiroirs (plastique gris, façades colorées), plateau supérieur."""
    vider_scene()
    lx, ly, hz = 0.62, 0.48, 0.92
    boite("caisson", (lx, ly, 0.72), (0, 0, 0.47), "plastique_gris_clair", arrondi=0.02, segments=3)
    boite("plateau", (lx + 0.04, ly + 0.04, 0.04), (0, 0, hz - 0.06), "plastique_gris", arrondi=0.015)
    for sx in (-1, 1):
        boite("rebord_%d" % sx, (0.03, ly + 0.04, 0.05), (sx * (lx / 2 + 0.005), 0, hz - 0.02), "plastique_gris", arrondi=0.01)
    couleurs = ["plastique_bleu", "plastique_bleu", "plastique_vert", "plastique_jaune", "plastique_rouge"]
    z = 0.78
    for i, h in enumerate((0.08, 0.08, 0.14, 0.14, 0.18)):
        z -= h + 0.01
        boite("facade_%d" % i, (lx - 0.06, 0.02, h), (0, -ly / 2 - 0.005, z + h / 2), couleurs[i], arrondi=0.006)
        boite("poignee_%d" % i, (0.16, 0.025, 0.018), (0, -ly / 2 - 0.02, z + h - 0.025), "plastique_gris_fonce",
              arrondi=0.006)
        boite("etiq_%d" % i, (0.08, 0.004, 0.025), (0.17, -ly / 2 - 0.016, z + h / 2), "etiquette")
    tube("guidon", courbe_lisse([(-0.26, ly / 2, 0.80), (-0.26, ly / 2 + 0.06, 0.86), (0.26, ly / 2 + 0.06, 0.86),
                                 (0.26, ly / 2, 0.80)], 6), 0.014, "aluminium")
    for sx in (-1, 1):
        for sy in (-1, 1):
            roulette("r_%d_%d" % (sx, sy), (sx * 0.24, sy * 0.18, 0.0), rayon=0.05)
    # Collecteur à aiguilles jaune (couvercle rouge) sur le côté.
    boite("support_collecteur", (0.02, 0.16, 0.12), (lx / 2 + 0.01, 0, 0.70), "aluminium", arrondi=0.004)
    boite("collecteur", (0.13, 0.13, 0.17), (lx / 2 + 0.085, 0, 0.73), "plastique_jaune", arrondi=0.012)
    boite("collecteur_couv", (0.135, 0.135, 0.03), (lx / 2 + 0.085, 0, 0.83), "plastique_rouge", arrondi=0.008)
    # Petit matériel sur le plateau : boîte de gants, compresses, haricot.
    boite("gants", (0.24, 0.12, 0.08), (-0.14, 0.08, hz - 0.0), "carton_bleu", arrondi=0.004)
    boite("compresses", (0.10, 0.08, 0.03), (0.12, 0.10, hz - 0.025), "papier", arrondi=0.003)
    tour("haricot", [(0.0, 0.0), (0.05, 0.0), (0.07, 0.02), (0.072, 0.035)], (0.15, -0.08, hz - 0.04), "inox_poli",
         seg=32).scale = (1.6, 0.8, 1.0)
    fin("chariot_soins")


# =============================================================================================
def tabouret():
    vider_scene()
    for i in range(5):
        a = 2 * PI * i / 5
        x, y = math.cos(a) * 0.26, math.sin(a) * 0.26
        tube("pied_%d" % i, [(0, 0, 0.11), (x, y, 0.08)], 0.016, "plastique_noir", seg=10)
        roulette("r_%d" % i, (x, y, 0.0), rayon=0.03)
    cylindre("verin_bas", 0.03, 0.18, (0, 0, 0.18), "plastique_noir", 20)
    cylindre("verin_haut", 0.015, 0.20, (0, 0, 0.36), "chrome", 16)
    cylindre("assise", 0.19, 0.07, (0, 0, 0.50), "skai_noir", 40, biseau_l=0.025)
    cylindre("sous_assise", 0.16, 0.02, (0, 0, 0.46), "plastique_noir", 32)
    tore("repose_pieds", 0.20, 0.008, (0, 0, 0.26), "chrome", seg=40, seg2=8)
    fin("tabouret")


def chaise():
    """Chaise visiteur luge chromée, coque plastique."""
    vider_scene()
    for sx in (-1, 1):
        x = sx * 0.21
        tube("luge_%d" % sx, courbe_lisse([(x, 0.20, 0.44), (x, 0.24, 0.44), (x, 0.26, 0.40), (x, 0.24, 0.02),
                                         (x, 0.20, 0.0), (x, -0.22, 0.0), (x, -0.24, 0.02), (x, -0.21, 0.44)], 5),
             0.011, "chrome")
    boite("assise", (0.46, 0.44, 0.03), (0, 0.0, 0.46), "plastique_bleu_nuit", arrondi=0.012)
    d = boite("dossier", (0.46, 0.025, 0.36), (0, 0.24, 0.70), "plastique_bleu_nuit", arrondi=0.010, rot=(-0.17, 0, 0))
    fin("chaise")


def poubelle_dasri():
    """Conteneur DASRI jaune à pédale (déchets d'activité de soins à risque infectieux)."""
    vider_scene()
    tour("cuve", [(0.0, 0.02), (0.17, 0.02), (0.19, 0.60), (0.0, 0.60)], (0, 0, 0), "plastique_jaune", seg=40)
    tour("couvercle", [(0.0, 0.64), (0.20, 0.63), (0.205, 0.60), (0.0, 0.60)], (0, 0, 0), "plastique_jaune", seg=40)
    boite("pedale", (0.12, 0.08, 0.025), (0, -0.20, 0.03), "plastique_gris_fonce", arrondi=0.008)
    uv_plan(boite("logo", (0.14, 0.004, 0.14), (0, -0.183, 0.38), "logo_biorisque", rot=(0.07, 0, 0)))
    fin("poubelle_dasri", sans_uv=("logo",))


def poubelle_menagere():
    vider_scene()
    tour("cuve", [(0.0, 0.02), (0.15, 0.02), (0.165, 0.55), (0.0, 0.55)], (0, 0, 0), "plastique_gris", seg=40)
    tour("sac", [(0.168, 0.53), (0.172, 0.57), (0.0, 0.57)], (0, 0, 0), "sac_noir", seg=40)
    tour("couvercle", [(0.0, 0.60), (0.175, 0.59), (0.178, 0.56), (0.0, 0.56)], (0, 0, 0), "plastique_gris", seg=40)
    boite("pedale", (0.10, 0.07, 0.02), (0, -0.18, 0.03), "plastique_gris_fonce", arrondi=0.006)
    fin("poubelle_menagere")


def plafonnier_led():
    """Dalle LED 600 x 600 encastrée (cadre + diffuseur opale émissif)."""
    vider_scene()
    boite("cadre", (0.60, 0.60, 0.012), (0, 0, -0.006), "metal_peint_blanc", arrondi=0.003)
    boite("diffuseur", (0.56, 0.56, 0.004), (0, 0, -0.013), "led_panel")
    fin("plafonnier_led")


def lampe_examen():
    """Lampe d'examen LED sur pied roulant à col de cygne."""
    vider_scene()
    for i in range(5):
        a = 2 * PI * i / 5
        x, y = math.cos(a) * 0.25, math.sin(a) * 0.25
        tube("pied_%d" % i, [(0, 0, 0.08), (x, y, 0.06)], 0.012, "metal_peint_blanc", seg=10)
        roulette("r_%d" % i, (x, y, 0.0), rayon=0.025)
    cylindre("mat", 0.013, 1.05, (0, 0, 0.60), "metal_peint_blanc", 16)
    pts = courbe_lisse([(0, 0, 1.12), (0, 0, 1.30), (0.05, -0.10, 1.45), (0.18, -0.25, 1.50), (0.30, -0.35, 1.42)], 8)
    tube("col", pts, 0.009, "plastique_gris_fonce", seg=10)
    tour("tete", [(0.0, 0.0), (0.075, 0.0), (0.085, 0.02), (0.08, 0.06), (0.04, 0.08), (0.0, 0.08)],
         (0.32, -0.37, 1.32), "plastique_blanc", seg=32)
    cylindre("led", 0.068, 0.004, (0.32, -0.37, 1.318), "led_lampe", 32)
    fin("lampe_examen")


def rail_rideau(longueur=3.2):
    """Rail de rideau droit fixé au plafond (aluminium), suspentes tous les 80 cm."""
    vider_scene()
    boite("rail", (longueur, 0.025, 0.018), (0, 0, 0), "aluminium", arrondi=0.004)
    n = int(longueur / 0.8) + 1
    for i in range(n):
        x = -longueur / 2 + longueur * i / (n - 1)
        cylindre("suspente_%d" % i, 0.005, 0.04, (x, 0, 0.03), "aluminium", 8)
    fin("rail_rideau")


def rideau(longueur=2.0, hauteur=1.95, plis=22):
    """Rideau plissé de box (partie basse en tissu, partie haute en filet). Origine = haut gauche, s'étend vers +X.
    Les plis ondulent en Y ; dans le jeu, on l'ouvre/ferme en jouant sur l'échelle X."""
    import bmesh
    vider_scene()
    for (nom, z0, z1, mat) in (("tissu", -hauteur, -0.50, "rideau"), ("filet", -0.50, -0.06, "filet_rideau")):
        bm = bmesh.new()
        nx = plis * 8
        nz = 8
        grille = []
        for i in range(nx + 1):
            x = longueur * i / nx
            col = []
            for j in range(nz + 1):
                z = z0 + (z1 - z0) * j / nz
                amp = 0.045 + 0.01 * math.sin(i * 0.37)
                y = amp * math.sin(2 * PI * plis * i / nx)
                col.append(bm.verts.new((x, y, z)))
            grille.append(col)
        for i in range(nx):
            for j in range(nz):
                bm.faces.new((grille[i][j], grille[i + 1][j], grille[i + 1][j + 1], grille[i][j + 1]))
        me = bpy.data.meshes.new(nom)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new(nom, me)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(materiau(mat))
        mod = o.modifiers.new("epaisseur", "SOLIDIFY")
        mod.thickness = 0.002
    # Ourlet et galon renforcé.
    boite("galon", (longueur, 0.006, 0.05), (longueur / 2, 0, -0.035), "tissu_drap")
    for i in range(plis + 1):
        x = longueur * i / plis
        tore("anneau_%d" % i, 0.012, 0.0025, (x, 0, 0.0), "plastique_blanc", seg=12, seg2=6, rot=(PI / 2, 0, 0))
    fin("rideau", uv=0.25)


def distributeur_gants():
    """Porte-boîtes de gants mural (S, M, L)."""
    vider_scene()
    boite("support", (0.80, 0.10, 0.17), (0, -0.05, 0), "plastique_transparent", arrondi=0.008)
    for i, mat in enumerate(("carton_violet", "carton_bleu", "carton_vert")):
        boite("boite_%d" % i, (0.24, 0.085, 0.13), (-0.26 + i * 0.26, -0.05, 0.0), mat, arrondi=0.003)
        boite("fente_%d" % i, (0.10, 0.002, 0.04), (-0.26 + i * 0.26, -0.094, 0.02), "gants_bleus", arrondi=0.002)
    fin("distributeur_gants")


def armoire_murale():
    """Armoire haute vitrée à pharmacie (stockage de petit matériel). Face -Y."""
    vider_scene()
    boite("caisson", (0.90, 0.40, 1.00), (0, 0, 0), "metal_peint_blanc", arrondi=0.008)
    for sx in (-1, 1):
        boite("porte_cadre_%d" % sx, (0.44, 0.02, 0.96), (sx * 0.225, -0.21, 0), "aluminium", arrondi=0.004)
        boite("porte_verre_%d" % sx, (0.38, 0.006, 0.88), (sx * 0.225, -0.222, 0), "verre", arrondi=0.002)
        boite("poignee_%d" % sx, (0.015, 0.03, 0.18), (sx * 0.03, -0.235, 0.0), "aluminium", arrondi=0.005)
    for z in (-0.25, 0.08):
        boite("etagere_%g" % z, (0.86, 0.36, 0.01), (0, 0, z), "verre_depoli")
    # Contenu : bacs de rangement colorés.
    cols = ["plastique_bleu", "plastique_vert", "plastique_jaune", "plastique_rouge", "plastique_bleu"]
    for i in range(5):
        boite("bac_b_%d" % i, (0.15, 0.30, 0.10), (-0.34 + i * 0.17, 0, -0.19), cols[i], arrondi=0.006)
        boite("bac_h_%d" % i, (0.15, 0.30, 0.10), (-0.34 + i * 0.17, 0, 0.14), cols[(i + 2) % 5], arrondi=0.006)
    for i in range(7):
        boite("boite_%d" % i, (0.10, 0.20, 0.14 + 0.03 * (i % 3)), (-0.36 + i * 0.12, 0, -0.42 + 0.015 * (i % 3)),
              "carton_blanc" if i % 2 else "carton_bleu", arrondi=0.003)
    fin("armoire_murale")


def tensiometre_mural():
    """Tensiomètre anéroïde mural + panier du brassard."""
    vider_scene()
    boite("platine", (0.14, 0.03, 0.22), (0, -0.015, 0), "plastique_gris", arrondi=0.01)
    cylindre("cadran", 0.06, 0.03, (0, -0.045, 0.05), "plastique_blanc", 40, (PI / 2, 0, 0), biseau_l=0.006)
    c = cylindre("cadran_face", 0.055, 0.003, (0, -0.061, 0.05), "cadran", 40, (PI / 2, 0, 0))
    boite("panier", (0.13, 0.06, 0.07), (0, -0.05, -0.07), "plastique_gris_fonce", arrondi=0.008)
    boite("brassard", (0.11, 0.05, 0.05), (0, -0.05, -0.04), "brassard", arrondi=0.015)
    tube("tuyau_tensio", courbe_lisse([(0.0, -0.06, 0.0), (0.05, -0.09, -0.03), (0.08, -0.08, -0.10),
                                       (0.04, -0.07, -0.06)], 6), 0.004, "caoutchouc_noir", seg=8)
    fin("tensiometre_mural")


def ordinateur_mural():
    """Poste informatique sur bras (dossier patient informatisé)."""
    vider_scene()
    boite("ecran_coque", (0.52, 0.05, 0.32), (0, 0, 0), "plastique_noir", arrondi=0.008)
    e = boite("ecran_pc", (0.50, 0.004, 0.29), (0, -0.026, 0.005), "ecran_pc")
    uv_plan(e)
    boite("clavier", (0.44, 0.15, 0.02), (0, -0.25, -0.25), "plastique_noir", arrondi=0.005)
    boite("plateau", (0.55, 0.30, 0.02), (0, -0.20, -0.27), "metal_peint_gris", arrondi=0.005)
    boite("souris", (0.06, 0.10, 0.03), (0.32, -0.25, -0.25), "plastique_noir", arrondi=0.014)
    tube("bras", [(0, 0.03, 0), (0, 0.25, -0.05), (0, 0.30, -0.27)], 0.02, "aluminium", seg=12)
    boite("fixation", (0.12, 0.02, 0.20), (0, 0.31, -0.15), "aluminium", arrondi=0.005)
    fin("ordinateur_mural", sans_uv=("ecran",))


def porte(nom="porte_90", largeur=0.90, hauteur=2.04, oculus=True):
    """Porte battante stratifiée (huisserie métal, plaque de propreté inox, béquille, oculus). Origine au sol,
    centrée ; s'insère dans une ouverture de largeur + 0,10 m."""
    vider_scene()
    ep = 0.045
    hu = 0.05
    # Huisserie (cadre) métal peint.
    for sx in (-1, 1):
        boite("montant_%d" % sx, (hu, 0.14, hauteur + hu), (sx * (largeur / 2 + hu / 2), 0, (hauteur + hu) / 2),
              "metal_peint_gris", arrondi=0.004)
    boite("traverse", (largeur + 2 * hu, 0.14, hu), (0, 0, hauteur + hu / 2), "metal_peint_gris", arrondi=0.004)
    # Vantail.
    if oculus:
        # Vantail en quatre morceaux autour de l'oculus (30 x 60 cm à 1,10 m).
        ox0, ox1, oz0, oz1 = -0.15, 0.15, 1.10, 1.70
        boite("v_bas", (largeur, ep, oz0), (0, 0, oz0 / 2), "bois_porte", arrondi=0.003)
        boite("v_haut", (largeur, ep, hauteur - oz1), (0, 0, (hauteur + oz1) / 2), "bois_porte", arrondi=0.003)
        boite("v_g", (largeur / 2 + ox0, ep, oz1 - oz0), ((-largeur / 2 + ox0) / 2, 0, (oz0 + oz1) / 2), "bois_porte")
        boite("v_d", (largeur / 2 - ox1, ep, oz1 - oz0), ((largeur / 2 + ox1) / 2, 0, (oz0 + oz1) / 2), "bois_porte")
        boite("vitre", (0.30, 0.008, 0.60), (0, 0, (oz0 + oz1) / 2), "verre")
        for sy in (-1, 1):
            boite("cadre_oc_h_%d" % sy, (0.34, 0.012, 0.02), (0, sy * 0.026, oz1 + 0.01), "aluminium")
            boite("cadre_oc_b_%d" % sy, (0.34, 0.012, 0.02), (0, sy * 0.026, oz0 - 0.01), "aluminium")
            boite("cadre_oc_g_%d" % sy, (0.02, 0.012, 0.64), (-0.16, sy * 0.026, (oz0 + oz1) / 2), "aluminium")
            boite("cadre_oc_d_%d" % sy, (0.02, 0.012, 0.64), (0.16, sy * 0.026, (oz0 + oz1) / 2), "aluminium")
    else:
        boite("vantail", (largeur, ep, hauteur), (0, 0, hauteur / 2), "bois_porte", arrondi=0.003)
    for sy in (-1, 1):
        boite("plaque_%d" % sy, (largeur - 0.04, 0.002, 0.30), (0, sy * (ep / 2 + 0.001), 0.17), "inox")
        # Béquille.
        cylindre("rosace_%d" % sy, 0.025, 0.01, (largeur / 2 - 0.08, sy * (ep / 2 + 0.005), 1.05), "inox_poli", 20,
                 (PI / 2, 0, 0))
        tube("bequille_%d" % sy, courbe_lisse([(largeur / 2 - 0.08, sy * (ep / 2 + 0.005), 1.05),
                                               (largeur / 2 - 0.08, sy * (ep / 2 + 0.05), 1.05),
                                               (largeur / 2 - 0.20, sy * (ep / 2 + 0.055), 1.05)], 4), 0.009, "inox_poli")
    fin(nom)


def horloge():
    """Horloge murale (face -Y)."""
    vider_scene()
    tour("boitier", [(0.0, 0.0), (0.16, 0.0), (0.165, 0.02), (0.16, 0.045), (0.15, 0.045)], (0, 0, 0), "plastique_blanc",
         seg=48, rot=(PI / 2, 0, 0))
    c = cylindre("cadran_horloge", 0.148, 0.003, (0, -0.04, 0), "cadran_horloge", 48, (PI / 2, 0, 0))
    uv_plan(c)
    cylindre("vitre", 0.15, 0.003, (0, -0.046, 0), "verre", 48, (PI / 2, 0, 0))
    fin("horloge", sans_uv=("cadran",))


TOUS = {
    "porte_90": lambda: porte("porte_90", 0.90), "porte_120": lambda: porte("porte_120", 1.10),
    "horloge": horloge,
    "brancard": brancard, "moniteur": moniteur, "pied_perfusion": pied_perfusion,
    "bandeau_tete_lit": bandeau_tete_lit, "lavabo": lavabo, "chariot_soins": chariot_soins,
    "tabouret": tabouret, "chaise": chaise, "poubelle_dasri": poubelle_dasri,
    "poubelle_menagere": poubelle_menagere, "plafonnier_led": plafonnier_led, "lampe_examen": lampe_examen,
    "rail_rideau": rail_rideau, "rideau": rideau, "distributeur_gants": distributeur_gants,
    "armoire_murale": armoire_murale, "tensiometre_mural": tensiometre_mural,
    "ordinateur_mural": ordinateur_mural,
}

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    for n in (args or list(TOUS)):
        TOUS[n]()
