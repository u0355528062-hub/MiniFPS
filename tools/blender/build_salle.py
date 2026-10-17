"""Mobilier et petit équipement de la salle de déchocage (décor), modélisés dans Blender et
exportés en .glb : échographe, fauteuil roulant, poubelles DASRI (jaune) et ordures ménagères,
étagère murale à bacs colorés, rideau sur rail, pousse-seringues sur pince, horloge murale,
distributeur de solution hydro-alcoolique, porte-boîtes de gants, prises murales, panneau
« Sortie » lumineux, collecteur à aiguilles.

    /home/user/bpyenv/bin/python tools/blender/build_salle.py [--preview] [nom ...]

Coordonnées : g(x, y, z) = point du jeu (Y vers le haut) ; voir bl.py. Les objets muraux ont leur
face vers +Z du jeu et leur dos à z = 0 (contre le mur).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
from bl import g  # noqa: E402
from mathutils import Vector  # noqa: E402
import build_er as BE  # noqa: E402

D = math.radians
PREVIEW_DIR = os.environ.get("APERCU", "/tmp/apercus")


def M():
    m = BE.M()
    m.update({
        "fabric_blue": bl.mat("Tissu bleu", (0.08, 0.16, 0.32), 0.9),
        "yellow_bin": bl.mat("Plastique jaune DASRI", (0.98, 0.78, 0.04), 0.45),
        "grey_bin": bl.mat("Plastique gris", (0.32, 0.34, 0.36), 0.5),
        "black_lid": bl.mat("Couvercle noir", (0.05, 0.05, 0.055), 0.5),
        "pump_grey": bl.mat("Boîtier pompe", (0.78, 0.8, 0.82), 0.4),
        "pump_blue": bl.mat("Bleu pompe", (0.1, 0.3, 0.6), 0.4),
        "lcd": bl.mat("Écran LCD", (0.12, 0.35, 0.45), 0.2, emission=(0.25, 0.75, 0.9), emission_strength=1.5),
        "screen_on": bl.mat("Écran allumé", (0.05, 0.08, 0.1), 0.15, emission=(0.18, 0.3, 0.38), emission_strength=1.2),
        "exit_green": bl.mat("Vert sortie", (0.05, 0.6, 0.25), 0.3, emission=(0.1, 0.95, 0.4), emission_strength=3.0),
        "purple": bl.mat("Violet gants", (0.45, 0.3, 0.75), 0.5),
        "curtain": bl.mat("Rideau", (0.38, 0.62, 0.72), 0.85),
        "curtain_mesh": bl.mat("Rideau filet", (0.92, 0.94, 0.95), 0.8, alpha=0.55),
    })
    return m


def grouped(d):
    return BE.grouped(d)


# ---------------------------------------------------------------- Échographe

def build_echographe(m):
    """Échographe sur chariot : base à 4 roulettes, colonne, console à clavier et boule, 3 sondes
    dans leurs supports (câbles), écran sur bras (nœud « Ecran », image d'échographie). Face vers +Z."""
    nodes = {"echographe": [], "Ecran": []}
    p = nodes["echographe"]
    p.append(bl.box("base", (0.5, 0.55, 0.08), g(0, 0.14, 0), m["warm_white"], bev=0.025))
    for x in (-0.2, 0.2):
        for z in (-0.22, 0.22):
            p.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["grey"], r=0.04))
    p.append(bl.box("colonne", (0.18, 0.14, 0.62), g(0, 0.48, -0.08), m["warm_white"], bev=0.03))
    p.append(bl.box("panier", (0.4, 0.3, 0.12), g(0, 0.26, 0.02), m["grey"], bev=0.02))
    # Console
    p.append(bl.box("console", (0.6, 0.42, 0.07), g(0, 0.86, 0.04), m["warm_white"], bev=0.03))
    p.append(bl.box("clavier", (0.42, 0.18, 0.01), g(0, 0.9, 0.08), m["dark"], bev=0.004))
    for i in range(10):
        for j in range(3):
            p.append(bl.box("touche", (0.026, 0.026, 0.008), g(-0.17 + i * 0.033, 0.905, 0.03 + j * 0.034), m["grey"] if (i + j) % 4 else m["pump_blue"], bev=0.003))
    p.append(bl.sphere("boule", 0.022, g(0.0, 0.905, 0.15), m["black_lid"]))
    p.append(bl.cyl("bague_boule", 0.032, 0.006, g(0.0, 0.896, 0.15), m["grey"], verts=24))
    for k, x in enumerate((-0.22, 0.22)):
        p.append(bl.cyl("molette", 0.018, 0.012, g(x * 0.75, 0.905, 0.17), m["grey"], verts=20, bev=0.003))
    # Sondes dans leurs supports (côté droit), câbles qui pendent
    for k in range(3):
        x = 0.33
        z = -0.05 + k * 0.07
        p.append(bl.box("support_sonde", (0.05, 0.06, 0.06), g(x, 0.84, z), m["grey"], bev=0.01))
        p.append(bl.box("sonde", (0.028, 0.045, 0.12), g(x, 0.9, z), m["black_lid"] if k != 1 else m["warm_white"], bev=0.012))
        cab = bl.bezier_pts(g(x, 0.96, z), g(x + 0.12, 1.0, z), g(x + 0.16, 0.5, z + 0.05), g(0.1, 0.45, -0.1 + k * 0.02), 16)
        p.append(bl.tube("cable_sonde", cab, 0.004, m["dark"], sides=8))
    p.append(bl.box("gel", (0.04, 0.04, 0.12), g(-0.34, 0.92, 0.0), bl.mat("Gel échographie", (0.2, 0.55, 0.85), 0.3), bev=0.01))
    # Bras et écran
    p.append(bl.cyl_between("bras", g(0, 0.88, -0.14), g(0, 1.12, -0.14), 0.025, m["grey"], verts=16))
    p.append(bl.box("ecran_dos", (0.5, 0.36, 0.05), g(0, 1.32, -0.12), m["warm_white"], bev=0.02, rot=(D(-8), 0, 0)))
    scr = bl.box("ecran", (0.44, 0.3, 0.006), g(0, 1.32, -0.092), m["screen_on"], rot=(D(-8), 0, 0))
    nodes["Ecran"].append(scr)
    p.append(bl.box("logo", (0.08, 0.012, 0.004), g(0, 1.13, -0.094), m["pump_blue"]))
    return grouped(nodes)


# ---------------------------------------------------------------- Fauteuil roulant

def build_fauteuil_roulant(m):
    """Fauteuil roulant standard : châssis chromé, grandes roues à main courante, roulettes avant,
    assise et dossier en toile bleue, accoudoirs, repose-pieds, poignées. Face vers +Z."""
    p = []
    ch = m["chrome"]
    W = 0.46
    for s in (-1, 1):
        x = s * W / 2
        # Grande roue arrière
        p.append(bl.torus("pneu", 0.29, 0.016, g(x + s * 0.03, 0.305, -0.12), m["black_rubber"], rot=(0, D(90), 0), major=48, minor=10))
        p.append(bl.torus("jante", 0.27, 0.008, g(x + s * 0.03, 0.305, -0.12), m["grey"], rot=(0, D(90), 0), major=48, minor=6))
        p.append(bl.torus("main_courante", 0.25, 0.008, g(x + s * 0.06, 0.305, -0.12), ch, rot=(0, D(90), 0), major=48, minor=8))
        for k in range(12):
            a = k * math.pi / 6
            p.append(bl.cyl_between("rayon", g(x + s * 0.03, 0.305, -0.12), g(x + s * 0.03, 0.305 + 0.265 * math.sin(a), -0.12 + 0.265 * math.cos(a)), 0.0016, ch, verts=4))
        p.append(bl.cyl("moyeu", 0.03, 0.04, g(x + s * 0.03, 0.305, -0.12), m["grey"], rot=(0, D(90), 0), verts=16))
        # Roulette avant
        p.append(bl.caster("roulette", (x, -0.3, 0.0), m["black_rubber"], ch, r=0.06))
        # Montants du châssis
        p.append(bl.cyl_between("montant_av", g(x, 0.2, 0.3), g(x, 0.52, 0.22), 0.011, ch, verts=12))
        p.append(bl.cyl_between("longeron", g(x, 0.48, -0.15), g(x, 0.48, 0.24), 0.011, ch, verts=12))
        p.append(bl.cyl_between("dossier_tube", g(x, 0.3, -0.16), g(x, 0.98, -0.2), 0.011, ch, verts=12))
        h = bl.bezier_pts(g(x, 0.98, -0.2), g(x, 1.02, -0.22), g(x, 1.0, -0.3), g(x, 0.98, -0.32), 8)
        p.append(bl.tube("poignee_tube", h, 0.011, ch, sides=12))
        p.append(bl.cyl_between("poignee", g(x, 0.98, -0.28), g(x, 0.975, -0.36), 0.016, m["black_rubber"], verts=12))
        # Accoudoir
        p.append(bl.cyl_between("accoudoir_av", g(x, 0.5, 0.18), g(x, 0.7, 0.16), 0.01, ch, verts=10))
        p.append(bl.box("accoudoir", (0.05, 0.3, 0.035), g(x, 0.72, 0.0), m["black_lid"], bev=0.012))
        # Repose-pied
        p.append(bl.cyl_between("tige_pied", g(x, 0.5, 0.24), g(x * 0.7, 0.16, 0.36), 0.009, ch, verts=10))
        p.append(bl.box("palette", (0.17, 0.12, 0.012), g(x * 0.55, 0.15, 0.38), m["black_lid"], bev=0.004))
    p.append(bl.cyl_between("croisillon", g(-W / 2, 0.3, 0.0), g(W / 2, 0.47, 0.0), 0.009, ch, verts=10))
    p.append(bl.cyl_between("croisillon2", g(W / 2, 0.3, 0.0), g(-W / 2, 0.47, 0.0), 0.009, ch, verts=10))
    p.append(bl.box("assise", (W, 0.42, 0.03), g(0, 0.5, 0.04), m["fabric_blue"], bev=0.012))
    p.append(bl.box("dossier", (W, 0.025, 0.36), g(0, 0.78, -0.185), m["fabric_blue"], bev=0.01, rot=(D(-6), 0, 0)))
    return grouped({"fauteuil_roulant": p})


# ---------------------------------------------------------------- Poubelles

def _bin(m, body, lid, label):
    p = []
    prof = [(0.0, 0.02), (0.15, 0.02), (0.165, 0.6), (0.0, 0.6)]
    shell = bl.extrude_profile("cuve", [(pp.x, pp.y) for pp in bl.rounded_rect_path(0.36, 0.33, 0.05)], 0.6, 0.02, body, bev=0.01)
    p.append(shell)
    p.append(bl.box("couvercle", (0.38, 0.35, 0.03), g(0, 0.63, 0), lid, bev=0.012))
    p.append(bl.box("charniere", (0.3, 0.03, 0.02), g(0, 0.62, -0.17), lid, bev=0.006))
    p.append(bl.box("pedale", (0.16, 0.08, 0.02), g(0, 0.04, 0.2), m["dark"], bev=0.006))
    p.append(bl.box("socle", (0.34, 0.31, 0.03), g(0, 0.015, 0), m["dark"], bev=0.008))
    if label:
        p.append(bl.box("etiquette", (0.2, 0.004, 0.16), g(0, 0.4, 0.167), m["white"], bev=0.004))
        # Pictogramme danger biologique : triangle noir sur fond jaune
        tri = bl.extrude_profile("triangle", [(-0.05, 0.0), (0.05, 0.0), (0.0, 0.085)], 0.003, 0.0, m["black_lid"])
        tri.rotation_euler = (D(90), 0, 0)
        tri.location = g(0, 0.37, 0.172)
        p.append(tri)
        p.append(bl.text("dasri", "DASRI", 0.03, g(0, 0.46, 0.171), m["black_lid"], extrude=0.0008))
    _ = prof
    return p


def build_poubelle_dasri(m):
    """Poubelle à pédale jaune DASRI (déchets d'activités de soins à risques infectieux), 50 L."""
    return grouped({"poubelle_dasri": _bin(m, m["yellow_bin"], m["yellow_bin"], True)})


def build_poubelle_daom(m):
    """Poubelle à pédale grise à couvercle noir (déchets ménagers), 50 L."""
    return grouped({"poubelle_daom": _bin(m, m["grey_bin"], m["black_lid"], False)})


def build_collecteur(m):
    """Collecteur à aiguilles jaune à couvercle rouge (sur support mural, dos contre le mur)."""
    p = []
    p.append(bl.extrude_profile("cuve", [(pp.x, pp.y - 0.06) for pp in bl.rounded_rect_path(0.14, 0.11, 0.02)], 0.16, 0.0, m["yellow_bin"], bev=0.006))
    p.append(bl.box("couvercle", (0.15, 0.12, 0.03), g(0, 0.175, 0.06), m["red"], bev=0.008))
    p.append(bl.box("ouverture", (0.07, 0.03, 0.004), g(0, 0.191, 0.07), m["black_lid"]))
    p.append(bl.box("support", (0.16, 0.01, 0.08), g(0, 0.06, 0.005), m["grey"], bev=0.003))
    return grouped({"collecteur": p})


# ---------------------------------------------------------------- Étagère murale à bacs

def build_etagere_bacs(m):
    """Étagère murale à bacs à bec colorés (3 rangées de 4) sur rails, avec étiquettes et matériel
    dedans (sachets, boîtes). 1,0 m x 0,9 m, dos contre le mur."""
    p = []
    cols = [(0.15, 0.4, 0.85), (0.85, 0.15, 0.15), (0.98, 0.75, 0.1), (0.15, 0.62, 0.3), (0.95, 0.45, 0.1), (0.55, 0.3, 0.75)]
    p.append(bl.box("panneau", (1.02, 0.015, 0.92), g(0, 0.46, 0.0075), m["warm_white"], bev=0.004))
    for r in range(3):
        y = 0.08 + r * 0.29
        p.append(bl.box("rail", (1.0, 0.02, 0.025), g(0, y + 0.17, 0.025), m["alu"], bev=0.003))
        for c in range(4):
            col = cols[(r * 4 + c * 3) % len(cols)]
            mt = bl.mat("Bac %d" % ((r * 4 + c * 3) % len(cols)), col, 0.45)
            x = -0.375 + c * 0.25
            # Bac à bec : boîte plus haute à l'arrière, ouverte devant
            prof = [(0.0, 0.0), (0.0, 0.18), (0.06, 0.18), (0.2, 0.09), (0.2, 0.0)]
            for sx in (-1, 1):
                side = bl.extrude_profile("flanc", prof, 0.004, 0.0, mt)
                side.rotation_euler = (D(90), 0, D(-90))
                side.location = g(x + sx * 0.11, y, 0.025)
                p.append(side)
            p.append(bl.box("fond", (0.22, 0.2, 0.006), g(x, y + 0.003, 0.125), mt))
            p.append(bl.box("dos", (0.22, 0.006, 0.18), g(x, y + 0.09, 0.028), mt))
            p.append(bl.box("devant", (0.22, 0.004, 0.09), g(x, y + 0.045, 0.223), mt))
            p.append(bl.box("etiquette", (0.1, 0.004, 0.035), g(x, y + 0.05, 0.227), m["white"]))
            # Contenu
            for k in range(3):
                p.append(bl.box("sachet", (0.05, 0.12, 0.012 + 0.005 * k), g(x - 0.06 + k * 0.06, y + 0.09 + 0.01 * k, 0.11), m["white"] if (k + c) % 2 else bl.mat("Emballage bleu", (0.6, 0.75, 0.9), 0.6), bev=0.004, rot=(D(-35), 0, 0)))
    return grouped({"etagere_bacs": p})


# ---------------------------------------------------------------- Rideau sur rail

def build_rideau(m):
    """Rideau de séparation sur rail plafonnier : rail alu (1,6 m), glisseurs, filet blanc en haut
    (aération), toile plissée bleu-vert ramassée sur 0,7 m, ourlet. Rail le long de +X, à 2,85 m."""
    p = []
    top = 2.86
    p.append(bl.box("rail", (1.6, 0.03, 0.025), g(0.65, top, 0), m["alu"], bev=0.004))
    W = 0.7
    n = 70
    for part, (y0, y1, mt) in enumerate(((top - 0.06, top - 0.45, m["curtain_mesh"]), (top - 0.45, 0.42, m["curtain"]))):
        bm_pts = []
        for i in range(n + 1):
            u = i / n
            x = u * W
            z = 0.045 * math.sin(u * math.pi * 22) * (0.8 + 0.2 * math.sin(u * 7.0))
            bm_pts.append((x, z))
        verts_top = [g(x, y0, z) for (x, z) in bm_pts]
        verts_bot = [g(x + 0.01 * math.sin(x * 9), y1, z * 1.15) for (x, z) in bm_pts]
        import bmesh
        bm = bmesh.new()
        vt = [bm.verts.new(v) for v in verts_top]
        vb = [bm.verts.new(v) for v in verts_bot]
        for i in range(n):
            bm.faces.new((vt[i], vt[i + 1], vb[i + 1], vb[i]))
        ob = bl._obj_from_bm(bm, "toile%d" % part, mt)
        bl.smooth(ob, 80)
        p.append(ob)
    p.append(bl.tube("ourlet", [g(x, 0.42, z * 1.15) for (x, z) in bm_pts[::2]], 0.006, m["curtain"], sides=6))
    for k in range(14):
        x = k * W / 13
        p.append(bl.cyl_between("glisseur", g(x, top - 0.012, 0), g(x, top - 0.06, 0), 0.004, m["white"], verts=6))
    return grouped({"rideau": p})


# ---------------------------------------------------------------- Pousse-seringues

def _syringe_pump(p, m, y, label_col):
    p.append(bl.box("boitier", (0.3, 0.12, 0.11), g(0, y, 0.09), m["pump_grey"], bev=0.012))
    p.append(bl.box("facade", (0.3, 0.01, 0.1), g(0, y + 0.0, 0.146), m["warm_white"], bev=0.006))
    p.append(bl.box("lcd", (0.08, 0.004, 0.045), g(0.08, y + 0.02, 0.152), m["lcd"]))
    for k in range(6):
        p.append(bl.box("touche", (0.016, 0.005, 0.014), g(0.04 + (k % 3) * 0.03, y - 0.035, 0.151 + 0.0), m["pump_blue"] if k else m["red"], bev=0.002))
    # Seringue de 50 mL posée sur le dessus, serrée par le pousseur
    p.append(bl.cyl_between("seringue", g(-0.12, y + 0.075, 0.12), g(0.07, y + 0.075, 0.12), 0.015, m["clear"], verts=20))
    p.append(bl.cyl_between("liquide", g(-0.04, y + 0.075, 0.12), g(0.07, y + 0.075, 0.12), 0.0135, bl.mat("Liquide pompe", label_col, 0.2, alpha=0.6), verts=16))
    p.append(bl.box("pousseur", (0.03, 0.04, 0.05), g(-0.13, y + 0.075, 0.12), m["pump_blue"], bev=0.006))
    p.append(bl.box("etiquette", (0.06, 0.002, 0.02), g(0.0, y + 0.075, 0.136), m["white"]))
    p.append(bl.box("berceau", (0.24, 0.02, 0.05), g(-0.02, y + 0.055, 0.12), m["pump_grey"], bev=0.006))


def build_pompes(m):
    """Deux pousse-seringues empilés sur une pince à fixer au pied à perfusion (mât à l'origine,
    vertical) : boîtier gris, façade, écran LCD allumé, touches, seringue de 50 mL et pousseur."""
    p = []
    p.append(bl.box("rail", (0.06, 0.05, 0.36), g(0, 0.0, 0.035), m["grey"], bev=0.008))
    p.append(bl.cyl_between("pince", g(0, 0.0, -0.02), g(0, 0.0, 0.02), 0.02, m["dark"], verts=16))
    p.append(bl.cyl_between("vis", g(-0.02, -0.05, 0.0), g(-0.06, -0.05, 0.0), 0.006, m["chrome"], verts=10))
    p.append(bl.sphere("bouton_vis", 0.014, g(-0.065, -0.05, 0.0), m["dark"]))
    _syringe_pump(p, m, 0.08, (0.95, 0.95, 0.9))
    _syringe_pump(p, m, -0.08, (0.95, 0.85, 0.4))
    return grouped({"pompes": p})


# ---------------------------------------------------------------- Horloge murale

def build_horloge(m):
    """Horloge murale ronde (Ø 30 cm) : cadre, cadran blanc, index des heures ; aiguilles en nœuds
    séparés (« Aiguille_H », « Aiguille_M », « Aiguille_S ») qui tournent autour de +Z, pointant
    vers +Y (midi) au repos."""
    nodes = {"horloge": [], "Aiguille_H": [], "Aiguille_M": [], "Aiguille_S": []}
    h = nodes["horloge"]
    R = 0.15
    h.append(bl.cyl_between("cadre", g(0, 0, 0.0), g(0, 0, 0.04), R, m["white"], verts=64))
    h.append(bl.torus("bord", R, 0.008, g(0, 0, 0.04), bl.mat("Bord horloge", (0.15, 0.3, 0.55), 0.4), rot=(D(90), 0, 0), major=64, minor=8))
    h.append(bl.cyl_between("cadran", g(0, 0, 0.04), g(0, 0, 0.0405), R - 0.008, bl.mat("Cadran", (0.97, 0.97, 0.95), 0.6), verts=64))
    for k in range(60):
        a = k * math.pi / 30
        big = k % 5 == 0
        L = 0.02 if big else 0.007
        w = 0.005 if big else 0.0015
        r0 = R - 0.016
        b = bl.box("index", (w, 0.001, L), g(math.sin(a) * (r0 - L / 2), math.cos(a) * (r0 - L / 2), 0.041), m["black_lid"])
        b.rotation_euler = (0, a, 0)
        h.append(b)
    for k in range(1, 13):
        a = k * math.pi / 6
        h.append(bl.text("chiffre", str(k), 0.018, g(math.sin(a) * (R - 0.05), math.cos(a) * (R - 0.05), 0.041), m["black_lid"], extrude=0.0))
    h.append(bl.cyl_between("axe", g(0, 0, 0.04), g(0, 0, 0.05), 0.005, m["black_lid"], verts=16))
    nodes["Aiguille_H"].append(bl.box("h", (0.008, 0.002, 0.075), g(0, 0.03, 0.044), m["black_lid"]))
    nodes["Aiguille_M"].append(bl.box("m", (0.005, 0.002, 0.11), g(0, 0.045, 0.046), m["black_lid"]))
    nodes["Aiguille_S"].append(bl.box("s", (0.0018, 0.0015, 0.13), g(0, 0.045, 0.048), m["red"]))
    return grouped(nodes)


# ---------------------------------------------------------------- Distributeurs muraux

def build_distributeur_sha(m):
    """Distributeur mural de solution hydro-alcoolique : coque blanche, fenêtre sur le flacon, levier
    gris, égouttoir. Dos contre le mur, levier vers le bas à y = 0."""
    p = []
    p.append(bl.box("coque", (0.11, 0.1, 0.25), g(0, 0.14, 0.05), m["white"], bev=0.02))
    p.append(bl.box("fenetre", (0.05, 0.004, 0.08), g(0, 0.18, 0.1), bl.mat("Flacon SHA", (0.55, 0.8, 0.9), 0.15, alpha=0.75), bev=0.003))
    p.append(bl.box("levier", (0.08, 0.06, 0.02), g(0, 0.025, 0.075), m["grey"], bev=0.006))
    p.append(bl.box("bec", (0.015, 0.015, 0.01), g(0, 0.015, 0.06), m["grey"]))
    p.append(bl.box("egouttoir", (0.1, 0.06, 0.01), g(0, -0.2, 0.03), m["grey"], bev=0.004))
    p.append(bl.text("sha", "SHA", 0.018, g(0, 0.235, 0.1005), m["pump_blue"], rot=(D(90), 0, 0), extrude=0.0005))
    return grouped({"distributeur_sha": p})


def build_boites_gants(m):
    """Porte-boîtes de gants mural (inox) avec trois boîtes de gants nitrile S, M, L (bandes de
    couleur), gants qui dépassent. Dos contre le mur, centre à y = 0."""
    p = []
    p.append(bl.box("support", (0.8, 0.13, 0.01), g(0, 0, 0.005), m["steel"], bev=0.003))
    for k, (taille, col) in enumerate((("S", (0.95, 0.75, 0.1)), ("M", (0.15, 0.6, 0.3)), ("L", (0.15, 0.4, 0.85)))):
        x = -0.26 + k * 0.26
        p.append(bl.box("boite", (0.24, 0.12, 0.09), g(x, 0, 0.055), m["white"], bev=0.006))
        p.append(bl.box("bande", (0.24, 0.035, 0.002), g(x, -0.035, 0.1005), bl.mat("Taille %s" % taille, col, 0.5)))
        p.append(bl.text("taille", taille, 0.03, g(x + 0.08, -0.035, 0.102), m["white"], rot=(D(90), 0, 0), extrude=0.0005))
        p.append(bl.box("fente", (0.12, 0.012, 0.003), g(x, 0.02, 0.1005), m["dark"]))
        glove = bl.bezier_pts(g(x - 0.02, 0.02, 0.1), g(x - 0.02, 0.03, 0.14), g(x + 0.03, 0.01, 0.15), g(x + 0.04, -0.03, 0.135), 10)
        p.append(bl.tube("gant", glove, 0.012, m["glove"], sides=8))
    for x in (-0.39, 0.39):
        p.append(bl.box("joue", (0.01, 0.13, 0.1), g(x, 0, 0.05), m["steel"], bev=0.002))
    return grouped({"boites_gants": p})


def build_prises(m):
    """Bloc de prises murales : 3 prises 230 V blanches, 1 rouge (secourue), 1 prise réseau, plaque
    d'identification. Dos contre le mur, centre à y = 0."""
    p = []
    p.append(bl.box("plaque", (0.36, 0.09, 0.012), g(0, 0, 0.006), m["white"], bev=0.004))
    for k in range(4):
        x = -0.135 + k * 0.08
        mt = m["red"] if k == 3 else m["white"]
        p.append(bl.box("prise", (0.065, 0.065, 0.012), g(x, 0, 0.016), mt, bev=0.006))
        p.append(bl.cyl_between("puits", g(x, 0, 0.021), g(x, 0, 0.0225), 0.02, m["grey"] if k < 3 else m["dark"], verts=24))
        for sx in (-1, 1):
            p.append(bl.cyl_between("trou", g(x + sx * 0.0095, 0, 0.022), g(x + sx * 0.0095, 0, 0.0226), 0.0026, m["black_lid"], verts=8))
        p.append(bl.cyl_between("terre", g(x, 0.012, 0.022), g(x, 0.012, 0.03), 0.002, m["chrome"], verts=8))
    p.append(bl.box("rj45", (0.035, 0.035, 0.012), g(0.175, 0, 0.016), m["white"], bev=0.004))
    return grouped({"prises": p})


def build_panneau_sortie(m):
    """Bloc autonome d'éclairage de sécurité « SORTIE » : boîtier blanc, face verte lumineuse,
    texte et flèche blancs. Dos contre le mur, centre à y = 0."""
    p = []
    p.append(bl.box("boitier", (0.36, 0.12, 0.06), g(0, 0, 0.03), m["white"], bev=0.008))
    p.append(bl.box("face", (0.33, 0.1, 0.004), g(0, 0, 0.0605), m["exit_green"]))
    p.append(bl.text("sortie", "SORTIE", 0.045, g(0.03, 0, 0.063), m["white"], rot=(D(90), 0, 0), extrude=0.0008))
    arrow = bl.extrude_profile("fleche", [(-0.05, 0.0), (-0.02, 0.025), (-0.02, 0.01), (0.01, 0.01), (0.01, -0.01), (-0.02, -0.01), (-0.02, -0.025)], 0.0015, 0.0, m["white"])
    arrow.rotation_euler = (D(90), 0, 0)
    arrow.location = g(-0.105, 0, 0.0625)
    p.append(arrow)
    return grouped({"panneau_sortie": p})


BUILDERS = {
    "echographe": (build_echographe, ((1.2, -1.6, 1.5), (0.0, 0.0, 0.8))),
    "fauteuil_roulant": (build_fauteuil_roulant, ((1.3, -1.5, 1.2), (0.0, 0.0, 0.5))),
    "poubelle_dasri": (build_poubelle_dasri, ((0.8, -1.0, 0.9), (0.0, 0.0, 0.35))),
    "poubelle_daom": (build_poubelle_daom, ((0.8, -1.0, 0.9), (0.0, 0.0, 0.35))),
    "collecteur": (build_collecteur, ((0.35, -0.4, 0.35), (0.0, 0.0, 0.1))),
    "etagere_bacs": (build_etagere_bacs, ((0.9, -1.8, 0.9), (0.0, 0.0, 0.45))),
    "rideau": (build_rideau, ((1.5, -2.5, 1.6), (0.4, 0.0, 1.5))),
    "pompes": (build_pompes, ((0.5, -0.6, 0.3), (0.0, 0.0, 0.0))),
    "horloge": (build_horloge, ((0.0, -0.6, 0.0), (0.0, 0.0, 0.0))),
    "distributeur_sha": (build_distributeur_sha, ((0.3, -0.5, 0.2), (0.0, 0.0, 0.05))),
    "boites_gants": (build_boites_gants, ((0.5, -0.9, 0.3), (0.0, 0.0, 0.0))),
    "prises": (build_prises, ((0.15, -0.35, 0.1), (0.0, 0.0, 0.0))),
    "panneau_sortie": (build_panneau_sortie, ((0.2, -0.5, 0.1), (0.0, 0.0, 0.0))),
}


def main():
    args = sys.argv[1:]
    do_prev = "--preview" in args
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS.keys())
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        fn, cam = BUILDERS[name]
        bl.reset()
        bl._MATS.clear()
        objs = fn(M())
        bl.export(name, objs)
        if do_prev:
            bl.preview(os.path.join(PREVIEW_DIR, name + ".png"), cam[0], cam[1], floor=True)


if __name__ == "__main__":
    main()
