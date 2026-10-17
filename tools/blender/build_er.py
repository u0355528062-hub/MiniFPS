"""Équipement des urgences (salle de déchocage), modélisé dans Blender et exporté en .glb.

    /home/user/bpyenv/bin/python tools/blender/build_er.py [--preview] [nom ...]

Les objets dont le nom commence par une majuscule (Ecran, Bouton_Choc...) sont exportés comme
nœuds séparés : le jeu les retrouve par leur nom (écran animé, boutons cliquables).
Coordonnées : g(x, y, z) = point du jeu (Y vers le haut) ; voir bl.py.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
from bl import g  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402
import build_models as BM  # noqa: E402

PREVIEW_DIR = os.environ.get("APERCU", "/tmp/apercus")
D = math.radians


def M():
    m = BM.M()
    m.update({
        "glove": bl.mat("Gant nitrile", (0.16, 0.36, 0.78), 0.42, 0.0, 0.45),
        "skin": bl.mat("Peau avant-bras", (0.72, 0.5, 0.4), 0.55),
        "scrub": bl.mat("Tunique", (0.12, 0.42, 0.48), 0.85),
        "yellow": bl.mat("Jaune", (0.95, 0.72, 0.05), 0.4),
        "red": bl.mat("Rouge", (0.75, 0.05, 0.04), 0.35),
        "green": bl.mat("Vert", (0.1, 0.55, 0.25), 0.4),
        "o2green": bl.mat("Vert oxygène", (0.92, 0.95, 0.92), 0.35),
        "clear": bl.mat("Plastique transparent", (0.88, 0.93, 0.97), 0.08, 0.0, 0.6, alpha=0.35),
        "silicone": bl.mat("Silicone", (0.85, 0.88, 0.9), 0.3, 0.0, 0.5, alpha=0.6),
        "orange": bl.mat("Orange", (0.95, 0.42, 0.05), 0.4),
    })
    return m


def grouped(parts_by_node):
    """{nom de nœud: [objets]} -> objets joints, un par nœud."""
    out = []
    for name, objs in parts_by_node.items():
        objs = [o for o in objs if o is not None]
        if not objs:
            continue
        bl.finalize(objs)
        out.append(bl.join(objs, name))
    return out


# ---------------------------------------------------------------- Brancard

TOP = 0.80


def build_brancard(m):
    """Brancard de déchocage : châssis sur 4 grandes roues, colonne hydraulique, plateau, matelas
    (dessus à 0,80 m), barrières latérales baissées (soins des deux côtés), poignées, mât
    porte-sérum. Tête vers +X, plateau de x = -1,45 à 0,67."""
    p = []
    x0, x1 = -1.45, 0.67
    cx = (x0 + x1) / 2
    L = x1 - x0
    w = 0.66
    mat_t = 0.1
    deck = TOP - mat_t
    # Châssis bas carénée
    p.append(bl.box("chassis", (L - 0.25, 0.5, 0.12), g(cx, 0.24, 0), m["white"], bev=0.03))
    p.append(bl.box("chassis_gris", (L - 0.2, 0.52, 0.03), g(cx, 0.17, 0), m["grey"], bev=0.01))
    for x in (x0 + 0.14, x1 - 0.14):
        for z in (-0.24, 0.24):
            p.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["grey"], r=0.075))
    # Pédales de frein
    for x in (x0 + 0.1, x1 - 0.1):
        p.append(bl.box("pedale", (0.04, 0.6, 0.02), g(x, 0.16, 0), m["green"] if x > 0 else m["red"], bev=0.008))
    # Colonnes (soufflets) tête et pieds
    for x in (x0 + 0.45, x1 - 0.45):
        p.append(bl.extrude_profile("colonne", [(pp.x + x, pp.y) for pp in bl.rounded_rect_path(0.2, 0.22, 0.04)], deck - 0.36, 0.3, m["grey"], bev=0.01))
        for k in range(5):
            p.append(bl.extrude_profile("soufflet", [(pp.x + x, pp.y) for pp in bl.rounded_rect_path(0.22, 0.24, 0.05)], 0.012, 0.36 + k * 0.06, m["dark"], bev=0.004))
    # Plateau radiotransparent
    p.append(bl.box("plateau", (L, w - 0.04, 0.05), g(cx, deck - 0.025, 0), m["white"], bev=0.015))
    p.append(bl.box("plateau_dessous", (L - 0.1, w - 0.1, 0.04), g(cx, deck - 0.07, 0), m["grey"], bev=0.01))
    # Matelas (dossier légèrement relevable : ici à plat), housse bleu nuit
    mat = bl.mat("Matelas brancard", (0.05, 0.09, 0.17), 0.5, 0.0, 0.4, clearcoat=0.1, coat_rough=0.4)
    p.append(bl.box("matelas", (L - 0.02, w - 0.06, mat_t), g(cx, deck + mat_t / 2, 0), mat, bev=0.035, seg=5))
    # Oreiller mince sous la tête
    p.append(bl.box("oreiller", (0.3, 0.42, 0.035), g(x1 - 0.2, TOP + 0.012, 0), bl.mat("Taie", (0.9, 0.92, 0.95), 0.85), bev=0.016, seg=4))
    # Barrières latérales : tubes
    for side, up in ((1, False), (-1, False)):  # barrières baissées des deux côtés (gestes au bras droit)
        z = side * (w / 2 + 0.02)
        ys = (TOP + 0.2, TOP + 0.03) if up else (deck - 0.06, deck - 0.14)
        for xx in (x0 + 0.35, x1 - 0.55):
            p.append(bl.cyl_between("montant_barriere", g(xx, deck - 0.03, z), g(xx, ys[0], z), 0.012, m["alu"], verts=12))
        rail = [g(x0 + 0.3, ys[0], z), g(x1 - 0.5, ys[0], z)]
        p.append(bl.cyl_between("barriere_haut", rail[0], rail[1], 0.015, m["alu"], verts=16))
        p.append(bl.cyl_between("barriere_bas", g(x0 + 0.3, ys[1], z), g(x1 - 0.5, ys[1], z), 0.012, m["alu"], verts=16))
    # Poignées de poussée aux pieds
    for z in (-0.22, 0.22):
        h = bl.bezier_pts(g(x0 + 0.02, deck - 0.03, z), g(x0 - 0.1, deck + 0.0, z), g(x0 - 0.1, deck + 0.15, z), g(x0 - 0.06, deck + 0.22, z), 14)
        p.append(bl.tube("poignee", h, 0.014, m["alu"], sides=12))
    p.append(bl.cyl_between("traverse", g(x0 - 0.06, deck + 0.22, -0.22), g(x0 - 0.06, deck + 0.22, 0.22), 0.014, m["alu"], verts=14))
    # Mât porte-sérum (coin tête, côté -Z)
    mz = -w / 2 + 0.02
    p.append(bl.cyl_between("mat_serum", g(x1 - 0.03, deck - 0.05, mz), g(x1 - 0.03, 1.95, mz), 0.011, m["chrome"], verts=14))
    for k in range(2):
        a = D(90 + 180 * k)
        base = g(x1 - 0.03, 1.93, mz)
        d = Vector((math.cos(a), math.sin(a), 0))
        hook = bl.bezier_pts(base, base + d * 0.06 + Vector((0, 0, 0.015)), base + d * 0.1, base + d * 0.105 + Vector((0, 0, 0.025)), 10)
        p.append(bl.tube("crochet", hook, 0.004, m["chrome"], sides=8))
    # Range-bouteille d'O2 sous le plateau (pieds)
    p.append(bl.cyl("bouteille", 0.05, 0.5, g(x0 + 0.55, 0.42, -0.12), m["o2green"], rot=(0, D(90), 0), verts=20, bev=0.02))
    return grouped({"brancard": p})


# ---------------------------------------------------------------- Défibrillateur

def build_defibrillateur(m):
    """Défibrillateur moniteur (type LifePak) : coque grise, poignée, écran, molette d'énergie,
    boutons ANALYSE / CHARGE / CHOC (nœuds séparés), câble d'électrodes. Face vers +Z du jeu ;
    base posée en y = 0."""
    body = bl.mat("Coque défib", (0.28, 0.3, 0.32), 0.45)
    face = bl.mat("Façade défib", (0.12, 0.13, 0.14), 0.4)
    nodes = {"defibrillateur": [], "Ecran": [], "Molette": [], "Bouton_Analyse": [], "Bouton_Charge": [], "Bouton_Choc": [], "Bouton_Marche": []}
    W, H, Dp = 0.34, 0.26, 0.24
    b = nodes["defibrillateur"]
    b.append(bl.box("coque", (W, Dp, H), g(0, H / 2, 0), body, bev=0.025, seg=4))
    b.append(bl.box("facade", (W - 0.02, 0.01, H - 0.03), g(0, H / 2 + 0.005, Dp / 2), face, bev=0.006))
    b.append(bl.box("pied", (W - 0.04, Dp - 0.02, 0.012), g(0, 0.006, 0), m["black_rubber"], bev=0.004))
    # Poignée de transport
    h = bl.bezier_pts(g(-0.12, H - 0.01, 0), g(-0.12, H + 0.07, 0), g(0.12, H + 0.07, 0), g(0.12, H - 0.01, 0), 20)
    b.append(bl.tube("poignee", h, 0.014, body, sides=14))
    # Écran (à gauche) avec cadre
    b.append(bl.box("cadre_ecran", (0.19, 0.012, 0.14), g(-0.06, 0.16, Dp / 2 + 0.008), m["dark"], bev=0.006))
    nodes["Ecran"].append(bl.box("ecran", (0.17, 0.004, 0.118), g(-0.06, 0.16, Dp / 2 + 0.015), m["screen"]))
    # Molette d'énergie (à droite, en haut)
    nodes["Molette"].append(bl.cyl("molette", 0.032, 0.025, g(0.11, 0.19, Dp / 2 + 0.02), m["dark"], rot=(D(90), 0, 0), verts=32, bev=0.004))
    nodes["Molette"].append(bl.box("index", (0.006, 0.004, 0.026), g(0.11, 0.205, Dp / 2 + 0.033), m["white"]))
    for k in range(7):
        a = D(-135 + k * 45)
        b.append(bl.box("graduation", (0.004, 0.003, 0.008), g(0.11 + math.sin(a) * 0.045, 0.19 + math.cos(a) * 0.045, Dp / 2 + 0.011), m["white"]))
    # Boutons (rond jaune numéroté 1/2/3 comme sur les vrais appareils)
    def btn(node, x, y, r, mat, label):
        nodes[node].append(bl.cyl(label, r, 0.014, g(x, y, Dp / 2 + 0.014), mat, rot=(D(90), 0, 0), verts=28, bev=0.004))
        nodes[node].append(bl.torus(label + "_bague", r + 0.003, 0.0025, g(x, y, Dp / 2 + 0.011), m["grey"], rot=(D(90), 0, 0), major=24, minor=6))
    btn("Bouton_Analyse", 0.065, 0.11, 0.016, m["yellow"], "analyse")
    btn("Bouton_Charge", 0.11, 0.11, 0.016, m["yellow"], "charge")
    btn("Bouton_Choc", 0.11, 0.055, 0.021, m["orange"], "choc")
    btn("Bouton_Marche", -0.135, 0.06, 0.012, m["green"], "marche")
    # Éclair sur le bouton de choc
    bolt = [(-0.004, 0.009), (0.003, 0.001), (-0.001, 0.001), (0.004, -0.009), (-0.003, -0.001), (0.001, -0.001)]
    ob = bl.extrude_profile("eclair", bolt, 0.002, 0.0, m["white"])
    ob.rotation_euler = (D(90), 0, 0)
    ob.location = g(0.11, 0.055, Dp / 2 + 0.0215)
    nodes["Bouton_Choc"].append(ob)
    # Imprimante et sortie papier, haut-parleur
    b.append(bl.box("imprimante", (0.12, 0.012, 0.035), g(-0.06, 0.05, Dp / 2 + 0.006), m["dark"], bev=0.004))
    b.append(bl.box("papier", (0.08, 0.006, 0.002), g(-0.06, 0.068, Dp / 2 + 0.012), m["warm_white"]))
    for k in range(5):
        b.append(bl.cyl("hp", 0.003, 0.004, g(0.03 + k * 0.012, 0.035, Dp / 2 + 0.01), m["black_rubber"], rot=(D(90), 0, 0), verts=8))
    # Prise des électrodes (côté) et câble enroulé
    b.append(bl.box("prise", (0.03, 0.05, 0.04), g(W / 2 + 0.012, 0.09, 0.05), m["dark"], bev=0.006))
    coil = []
    for k in range(60):
        a = k / 59 * 2 * math.pi * 2.2
        coil.append(g(W / 2 + 0.03 + 0.035 * (1 - math.cos(a)) * 0.6, 0.1 - 0.0015 * k, 0.05 + 0.04 * math.sin(a)))
    b.append(bl.tube("cable", coil, 0.004, m["dark"], sides=8))
    return grouped(nodes)


# ---------------------------------------------------------------- Scope + bras plafonnier

def build_scope(m):
    """Moniteur de surveillance : boîtier, cadre, poignée, molette, étiquettes de paramètres.
    Écran (nœud « Ecran ») de 0,30 x 0,19 m centré en (0, 0, 0.006) ; face vers +Z."""
    nodes = {"scope": [], "Ecran": []}
    b = nodes["scope"]
    b.append(bl.box("boitier", (0.38, 0.09, 0.28), g(0, 0, -0.04), m["warm_white"], bev=0.02, seg=4))
    b.append(bl.box("dos", (0.28, 0.06, 0.2), g(0, 0, -0.1), m["warm_white"], bev=0.02))
    b.append(bl.box("cadre", (0.35, 0.01, 0.235), g(0, 0.006, 0.003), m["dark"], bev=0.008))
    nodes["Ecran"].append(bl.box("ecran", (0.31, 0.004, 0.195), g(0, 0.006, 0.008), m["screen"]))
    b.append(bl.cyl("molette", 0.014, 0.012, g(0.16, -0.12, 0.006), m["dark"], rot=(D(90), 0, 0), verts=24, bev=0.003))
    b.append(bl.box("voyant", (0.03, 0.006, 0.008), g(-0.15, 0.125, 0.006), m["red"], bev=0.002))
    h = bl.bezier_pts(g(-0.1, 0.13, -0.05), g(-0.1, 0.18, -0.05), g(0.1, 0.18, -0.05), g(0.1, 0.13, -0.05), 16)
    b.append(bl.tube("poignee", h, 0.011, m["warm_white"], sides=12))
    # Support et rotule à l'arrière
    b.append(bl.box("support", (0.1, 0.06, 0.1), g(0, -0.02, -0.15), m["grey"], bev=0.01))
    return grouped(nodes)


def build_bras_plafonnier(m):
    """Bras plafonnier de réanimation : colonne avec prises de gaz (O2 vert/blanc, air, vide), prises
    électriques, étagère et support du scope. Fixé au plafond (y = 3,0) ; la colonne descend jusqu'à
    1,25 m. Le scope se fixe sur l'étagère (repère : y = 1,55, face vers -X du jeu)."""
    p = []
    top = 3.0
    p.append(bl.cyl("platine", 0.22, 0.03, g(0, top - 0.015, 0), m["white"], verts=48, bev=0.008))
    p.append(bl.cyl_between("axe", g(0, top - 0.03, 0), g(0, top - 0.35, 0), 0.06, m["white"], verts=32))
    p.append(BM._beam("bras", g(0, top - 0.32, 0), g(0, top - 0.32, 0.55), 0.12, 0.1, m["white"], bev=0.03))
    p.append(bl.cyl_between("axe2", g(0, top - 0.3, 0.55), g(0, top - 0.42, 0.55), 0.07, m["white"], verts=32))
    # Colonne (tête)
    col_top, col_bot = top - 0.42, 1.25
    p.append(bl.extrude_profile("colonne", [(pp.x, pp.y - 0.55) for pp in bl.rounded_rect_path(0.24, 0.24, 0.05)], col_top - col_bot, col_bot, m["white"], bev=0.01))
    for (y, c) in ((1.35, "o2"), (1.43, "air"), (1.51, "vide")):
        for side in (-1, 1):
            col = {"o2": m["o2green"], "air": m["dark"], "vide": m["yellow"]}[c]
            x = side * 0.121
            p.append(bl.cyl_between("prise_" + c, g(x, y, 0.55), g(x + side * 0.02, y, 0.55), 0.016, col, verts=20))
            p.append(bl.cyl_between("prise_bague", g(x + side * 0.02, y, 0.55), g(x + side * 0.025, y, 0.55), 0.012, m["chrome"], verts=16))
    for k in range(3):
        p.append(bl.box("prise_elec", (0.005, 0.05, 0.04), g(0.122, 1.68 + k * 0.06, 0.55), m["warm_white"], bev=0.004))
    # Étagère et rail
    p.append(bl.box("etagere", (0.42, 0.34, 0.025), g(-0.2, 1.4, 0.55), m["warm_white"], bev=0.008))
    p.append(bl.box("rail", (0.02, 0.26, 0.03), g(-0.122, 1.8, 0.55), m["chrome"], bev=0.004))
    return grouped({"bras_plafonnier": p})


# ---------------------------------------------------------------- Rampe murale (O2, vide)

def build_rampe(m):
    """Rampe murale au chevet : gaine horizontale, débitmètre O2 (bille, molette), aspiration avec
    bocal, prises électriques, lampe d'examen. Contre le mur (face vers +Z du jeu), centre en x = 0,
    à 1,4 m du sol. Nœuds : « Debitmetre » (molette O2), « Aspiration »."""
    nodes = {"rampe": [], "Debitmetre": [], "Aspiration": []}
    r = nodes["rampe"]
    r.append(bl.box("gaine", (1.8, 0.08, 0.16), g(0, 1.4, 0.04), m["warm_white"], bev=0.02))
    r.append(bl.box("liseré", (1.8, 0.01, 0.02), g(0, 1.47, 0.08), m["blue"], bev=0.004))
    # Débitmètre O2 (gauche)
    d = nodes["Debitmetre"]
    x = -0.35
    d.append(bl.box("embase", (0.05, 0.04, 0.05), g(x, 1.4, 0.1), m["o2green"], bev=0.008))
    d.append(bl.cyl("tube", 0.018, 0.16, g(x, 1.52, 0.13), m["clear"], verts=20))
    d.append(bl.cyl("tube_cadre", 0.022, 0.012, g(x, 1.44, 0.13), m["o2green"], verts=20))
    d.append(bl.cyl("tube_cadre2", 0.022, 0.012, g(x, 1.6, 0.13), m["o2green"], verts=20))
    d.append(bl.sphere("bille", 0.007, g(x, 1.47, 0.13), m["chrome"]))
    d.append(bl.cyl_between("molette_o2", g(x, 1.63, 0.13), g(x, 1.66, 0.13), 0.016, m["o2green"], verts=20))
    d.append(bl.cyl_between("olive", g(x, 1.42, 0.13), g(x, 1.36, 0.16), 0.006, m["o2green"], verts=12))
    # Aspiration (droite) : vacuomètre et bocal
    a = nodes["Aspiration"]
    x = 0.3
    a.append(bl.box("embase", (0.05, 0.04, 0.05), g(x, 1.4, 0.1), m["yellow"], bev=0.008))
    a.append(bl.cyl_between("vacuo", g(x, 1.5, 0.11), g(x, 1.5, 0.15), 0.035, m["white"], verts=28))
    a.append(bl.cyl("vacuo_face", 0.03, 0.002, g(x, 1.5, 0.151), m["warm_white"], rot=(D(90), 0, 0), verts=28))
    a.append(bl.lathe("bocal", [(0.0, 0.0), (0.06, 0.0), (0.065, 0.02), (0.065, 0.2), (0.05, 0.215), (0.0, 0.22)], m["clear"], segments=32, loc=g(x + 0.12, 1.12, 0.12)))
    a.append(bl.cyl("couvercle", 0.055, 0.02, g(x + 0.12, 1.345, 0.12), m["blue"], verts=28))
    a.append(bl.box("rail_bocal", (0.04, 0.03, 0.3), g(x + 0.12, 1.25, 0.06), m["chrome"], bev=0.004))
    tub = bl.bezier_pts(g(x + 0.12, 1.355, 0.12), g(x + 0.12, 1.45, 0.16), g(x + 0.3, 1.45, 0.2), g(x + 0.35, 1.2, 0.22), 18)
    a.append(bl.tube("tuyau", tub, 0.006, m["clear"], sides=10))
    # Prises électriques
    for k in range(4):
        r.append(bl.box("prise", (0.06, 0.012, 0.06), g(0.65 + (k % 2) * 0.08, 1.37 + (k // 2) * 0.0, 0.085), m["white"] if k < 2 else m["red"], bev=0.006))
    # Lampe d'examen sur bras flexible
    arm = bl.bezier_pts(g(-0.75, 1.48, 0.08), g(-0.75, 1.75, 0.15), g(-0.6, 1.85, 0.3), g(-0.55, 1.78, 0.4), 22)
    r.append(bl.tube("col_lampe", arm, 0.007, m["dark"], sides=10))
    r.append(bl.lathe("tete_lampe", [(0.0, 0.0), (0.05, 0.0), (0.045, 0.05), (0.02, 0.07), (0.0, 0.07)], m["warm_white"], segments=24, loc=g(-0.55, 1.73, 0.4)))
    return grouped(nodes)


# ---------------------------------------------------------------- BAVU

def build_bavu(m):
    """Ballon autoremplisseur à valve unidirectionnelle : ballon silicone, valve patient, masque
    facial à coussinet, ballon réservoir et tubulure d'O2. Le masque est au bout (+Z), le ballon
    vers -Z ; centre du ballon à l'origine."""
    nodes = {"Ballon": [], "bavu": [], "Masque": []}
    prof = []
    for k in range(17):
        t = k / 16
        z = -0.13 + 0.26 * t
        rr = 0.064 * math.sin(math.pi * (0.05 + 0.9 * t)) ** 0.7 + 0.012
        prof.append((rr, z))
    ball = bl.lathe("ballon", prof, m["silicone"], segments=36)
    ball.rotation_euler = (D(90), 0, 0)
    nodes["Ballon"].append(ball)
    bv = nodes["bavu"]
    bv.append(bl.cyl_between("valve", g(0, 0, 0.13), g(0, 0, 0.19), 0.017, m["clear"], verts=20))
    bv.append(bl.cyl_between("valve_bleue", g(0, 0, 0.16), g(0, 0, 0.175), 0.02, m["blue"], verts=20))
    bv.append(bl.cyl_between("raccord", g(0, 0, 0.19), g(0, -0.03, 0.22), 0.012, m["clear"], verts=16))
    bv.append(bl.cyl_between("arriere", g(0, 0, -0.13), g(0, 0, -0.16), 0.02, m["clear"], verts=20))
    # Ballon réservoir
    res = bl.sphere("reservoir", 0.06, g(0, 0.0, -0.27), bl.mat("Réservoir", (0.85, 0.9, 0.95), 0.3, 0.0, 0.5, alpha=0.5), scale=(1.0, 1.4, 1.0))
    bv.append(res)
    tube = bl.bezier_pts(g(0.0, -0.01, -0.16), g(0.05, -0.04, -0.2), g(0.1, -0.06, -0.3), g(0.15, -0.08, -0.45), 16)
    bv.append(bl.tube("tubulure", tube, 0.004, bl.mat("Tubulure verte", (0.4, 0.75, 0.5), 0.3, 0.0, 0.5, alpha=0.7), sides=8))
    # Masque : dôme transparent, coussinet gonflé
    mask_c = g(0, -0.035, 0.24)
    dome = bl.lathe("dome", [(0.0, 0.045), (0.015, 0.044), (0.035, 0.03), (0.048, 0.01), (0.052, 0.0)], m["clear"], segments=32)
    dome.scale = (1.0, 1.25, 1.0)
    dome.rotation_euler = (D(180), 0, 0)
    dome.location = mask_c
    nodes["Masque"].append(dome)
    cush = bl.torus("coussinet", 0.05, 0.011, mask_c + Vector((0, 0, -0.045)), bl.mat("Coussinet", (0.9, 0.92, 0.95), 0.25, 0.0, 0.5, alpha=0.75), major=40, minor=12)
    cush.scale = (1.0, 1.25, 1.0)
    nodes["Masque"].append(cush)
    return grouped(nodes)


# ---------------------------------------------------------------- Mains (massage cardiaque)

def _hand(name, m, curls, thumb_curl=0.3, spread=0.0, mirror=False, forearm=0.24, wrist_up=0.0):
    """Main gantée modélisée à partir d'un squelette (modificateur Skin) puis lissée.
    Repère Blender : paume vers -Z, doigts vers +X, pouce vers +Y (main droite), poignet à
    l'origine. curls : flexion des 4 doigts (0 tendu, 1 replié)."""
    import bpy
    import bmesh
    bm = bmesh.new()
    bm.verts.layers.skin.verify()
    verts = []

    def add(co, r):
        v = bm.verts.new(co)
        verts.append(r)
        return v

    def edge(a, b):
        bm.edges.new((a, b))

    wrist = add((0.0, 0.0, 0.0), (0.03, 0.019))
    # Paume : éventail du poignet vers la base de chaque doigt (paume large et plate)
    fingers = [(0.026, [0.042, 0.025, 0.02], 0.0088), (0.009, [0.047, 0.028, 0.021], 0.009),
               (-0.008, [0.044, 0.026, 0.02], 0.0086), (-0.024, [0.034, 0.021, 0.018], 0.0076)]
    mids = []
    for i, (fy, segs, r) in enumerate(fingers):
        y = fy * (1.0 + spread * 0.4)
        mid = add((0.045, y * 0.85, 0.001), (0.013, 0.013))
        edge(wrist, mid)
        base = add((0.088, y, 0.0), (r * 1.1, r * 1.0))
        edge(mid, base)
        mids.append(mid)
        ang = 0.0
        p = Vector((0.088, y, 0.0))
        prev = base
        c = curls[i]
        for k, sl in enumerate(segs):
            ang += c * (0.85 if k == 0 else 1.2)
            d = Vector((math.cos(ang), spread * 0.1 * (i - 1.5) if k == 0 else 0.0, -math.sin(ang)))
            p = p + d.normalized() * sl
            v = add(p.copy(), (r * (0.96 - 0.08 * k), r * (0.9 - 0.08 * k)))
            edge(prev, v)
            prev = v
    # Pouce (éminence thénar puis trois segments)
    th0 = add((0.022, 0.022, -0.006), (0.016, 0.013))
    edge(wrist, th0)
    p = Vector((0.022, 0.022, -0.006))
    prev = th0
    ang = 0.0
    for k, sl in enumerate([0.03, 0.03, 0.024]):
        ang += thumb_curl * 0.7
        d = Vector((0.75 * math.cos(ang), 0.62, -0.25 - math.sin(ang)))
        p = p + d.normalized() * sl
        v = add(p.copy(), (0.0105 - 0.0008 * k, 0.0095 - 0.0008 * k))
        edge(prev, v)
        prev = v
    # Avant-bras
    if forearm > 0:
        dx, dz = -math.cos(wrist_up), math.sin(wrist_up)
        e1 = add((dx * forearm * 0.5, 0.0, dz * forearm * 0.5 + 0.004), (0.031, 0.026))
        e2 = add((dx * forearm, 0.0, dz * forearm + 0.01), (0.037, 0.034))
        edge(wrist, e1)
        edge(e1, e2)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for i, r in enumerate(verts):
        me.skin_vertices[0].data[i].radius = r
    me.skin_vertices[0].data[0].use_root = True
    ob.modifiers.new("Skin", "SKIN")
    bl.subsurf(ob, 2)
    bl.apply_all(ob)
    bl.smooth(ob, 80)
    bl.set_mat(ob, m["glove"])
    me = ob.data
    me.materials.append(m["skin"])
    for poly in me.polygons:
        c = sum((me.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        if c.dot(Vector((-math.cos(wrist_up), 0.0, math.sin(wrist_up)))) > 0.075:
            poly.material_index = 1
    if mirror:
        for v in me.vertices:
            v.co.y = -v.co.y
        me.flip_normals()
    return ob


def build_mains_rcp(m):
    """Deux mains gantées superposées, doigts croisés, talon de la main du bas à l'origine (posé sur
    le sternum), bras tendus vers le haut et vers le soignant (côté +Z du jeu). Les doigts pointent
    vers -Z du jeu (en travers du thorax)."""
    bottom = _hand("main_bas", m, [0.04, 0.03, 0.05, 0.08], 0.25, forearm=0.3, wrist_up=math.radians(72))
    top = _hand("main_haut", m, [0.55, 0.62, 0.62, 0.58], 0.35, mirror=True, forearm=0.3, wrist_up=math.radians(68))
    top.location = (0.004, 0.006, 0.024)
    top.rotation_euler = (0, 0, math.radians(-12))
    bl.bake_transforms(top)
    obj = bl.join([bottom, top], "mains_rcp")
    obj.location = (-0.035, 0, 0.012)
    obj.rotation_euler = (0, 0, math.radians(90))
    bl.bake_transforms(obj)
    return [obj]


def build_main_pouls(m):
    """Main droite, index et majeur tendus (prise de pouls, palpation), autres doigts repliés. Bout
    des doigts vers -Z du jeu, avant-bras vers le soignant."""
    ob = _hand("main_pouls", m, [0.12, 0.1, 1.3, 1.3], 1.0, forearm=0.3, wrist_up=math.radians(25))
    ob.rotation_euler = (0, 0, math.radians(90))
    bl.bake_transforms(ob)
    return [ob]


def build_main_plate(m):
    ob = _hand("main_plate", m, [0.12, 0.1, 0.12, 0.15], 0.25, forearm=0.3, wrist_up=math.radians(25))
    ob.rotation_euler = (0, 0, math.radians(90))
    bl.bake_transforms(ob)
    return [ob]


# ---------------------------------------------------------------- Électrocardiographe sur chariot

def build_ecg(m):
    """Électrocardiographe 12 dérivations sur petit chariot : appareil à clavier, sortie papier
    millimétré, faisceau de câbles. Nœud « Ecran »."""
    nodes = {"ecg": [], "Ecran": []}
    e = nodes["ecg"]
    e.append(bl.box("plateau", (0.45, 0.4, 0.02), g(0, 0.85, 0), m["warm_white"], bev=0.008))
    e.append(bl.cyl_between("mat", g(0, 0.1, 0), g(0, 0.84, 0), 0.025, m["grey"], verts=20))
    for k in range(5):
        a = 2 * math.pi * k / 5
        tip = g(math.cos(a) * 0.25, 0.06, math.sin(a) * 0.25)
        e.append(bl.cyl_between("pied", g(0, 0.1, 0), tip, 0.013, m["grey"], verts=10))
        e.append(bl.caster("roue", (tip.x, tip.y, 0.0), m["black_rubber"], m["grey"], r=0.025, yaw=a))
    e.append(bl.box("appareil", (0.36, 0.28, 0.07), g(0, 0.895, -0.02), m["warm_white"], bev=0.015))
    e.append(bl.box("clavier", (0.3, 0.1, 0.006), g(0, 0.932, 0.07), m["dark"], bev=0.003))
    for k in range(18):
        e.append(bl.box("touche", (0.022, 0.02, 0.004), g(-0.13 + (k % 9) * 0.032, 0.936, 0.045 + (k // 9) * 0.03), m["grey"], bev=0.002))
    sc = bl.box("cadre_ecran", (0.2, 0.012, 0.11), g(-0.04, 0.985, -0.1), m["dark"], bev=0.006)
    sc.rotation_euler = (D(-25), 0, 0)
    e.append(sc)
    ec = bl.box("ecran", (0.18, 0.004, 0.095), g(-0.04, 0.99, -0.093), m["screen"])
    ec.rotation_euler = (D(-25), 0, 0)
    nodes["Ecran"].append(ec)
    e.append(bl.box("papier", (0.2, 0.002, 0.15), g(0.1, 0.932, -0.17), bl.mat("Papier ECG", (0.97, 0.88, 0.86), 0.8), bev=0.0005))
    # Faisceau de câbles
    for k in range(10):
        a = k * 0.3
        pts = bl.bezier_pts(g(0.18, 0.89, 0.0), g(0.28, 0.85, 0.02 * k), g(0.25, 0.6, 0.05 + 0.01 * k), g(0.2 + 0.01 * k, 0.75, 0.1), 14)
        col = [m["white"], m["dark"], m["green"], m["red"], m["yellow"], m["blue"]][k % 6]
        e.append(bl.tube("fil", pts, 0.0025, col, sides=6))
    return grouped(nodes)


# ---------------------------------------------------------------- Poste informatique

def build_poste(m):
    """Poste informatique mural : tablette, écran, clavier, souris, lecteur de code-barres.
    Contre le mur (face vers +Z), plan à 1,05 m. Nœud « Ecran » (0,52 x 0,3 m)."""
    nodes = {"poste": [], "Ecran": []}
    p = nodes["poste"]
    p.append(bl.box("tablette", (0.9, 0.5, 0.03), g(0, 1.05, 0.25), m["warm_white"], bev=0.01))
    for x in (-0.4, 0.4):
        p.append(bl.box("console", (0.03, 0.4, 0.15), g(x, 0.97, 0.2), m["grey"], bev=0.008))
    p.append(bl.box("pied_ecran", (0.2, 0.15, 0.015), g(0, 1.072, 0.12), m["dark"], bev=0.005))
    p.append(bl.box("col_ecran", (0.05, 0.03, 0.3), g(0, 1.2, 0.08), m["dark"], bev=0.008))
    p.append(bl.box("ecran_boitier", (0.56, 0.035, 0.34), g(0, 1.35, 0.11), m["dark"], bev=0.008))
    nodes["Ecran"].append(bl.box("ecran", (0.52, 0.004, 0.3), g(0, 1.35, 0.129), m["screen"]))
    p.append(bl.box("clavier", (0.44, 0.15, 0.018), g(0, 1.075, 0.33), m["dark"], bev=0.004))
    p.append(bl.box("souris", (0.06, 0.1, 0.03), g(0.32, 1.078, 0.33), m["dark"], bev=0.013))
    p.append(bl.box("douchette", (0.05, 0.1, 0.06), g(-0.33, 1.09, 0.3), m["dark"], bev=0.012))
    return grouped(nodes)


# ---------------------------------------------------------------- Armoire murale de matériel

def build_armoire(m):
    """Armoire de matériel à paniers (casiers colorés) et portes vitrées, 1,2 m de large."""
    p = []
    W, H, Dp = 1.2, 1.9, 0.45
    p.append(bl.box("caisson", (W, Dp, H), g(0, H / 2, 0), m["warm_white"], bev=0.01))
    p.append(bl.box("fond", (W - 0.04, 0.01, H - 0.06), g(0, H / 2, Dp / 2 - 0.01), m["grey"]))
    cols = [(0.85, 0.2, 0.2), (0.2, 0.45, 0.85), (0.95, 0.75, 0.15), (0.2, 0.65, 0.35), (0.85, 0.85, 0.88)]
    for row in range(6):
        for col in range(4):
            c = cols[(row * 3 + col) % len(cols)]
            x = -W / 2 + 0.16 + col * 0.29
            y = 0.18 + row * 0.28
            p.append(bl.box("panier", (0.26, Dp - 0.08, 0.2), g(x, y + 0.1, 0.02), bl.mat("Panier %d" % ((row * 3 + col) % 5), c, 0.5, alpha=1.0), bev=0.01))
            p.append(bl.box("etiquette", (0.1, 0.004, 0.03), g(x, y + 0.15, Dp / 2 - 0.035), m["white"]))
    for x in (-W / 4, W / 4):
        p.append(bl.box("porte", (W / 2 - 0.02, 0.012, H - 0.06), g(x, H / 2, Dp / 2 + 0.008), bl.mat("Vitre", (0.75, 0.85, 0.9), 0.04, 0.0, 0.6, alpha=0.18), bev=0.004))
        p.append(bl.box("poignee", (0.015, 0.025, 0.25), g(x + (W / 4 - 0.05) * (-1 if x > 0 else 1), H / 2, Dp / 2 + 0.03), m["chrome"], bev=0.005))
    return grouped({"armoire": p})


# ---------------------------------------------------------------- Petit matériel (tenu en main)

def _set_origin(ob, p):
    """Déplace l'origine d'un objet (sans bouger sa géométrie) au point Blender p."""
    p = Vector(p)
    ob.data.transform(Matrix.Translation(-p))
    ob.location = p
    return ob


def _zlathe(name, profile, material, segments=32):
    """Révolution autour de l'axe +Z du jeu : profil [(rayon, z du jeu), ...]."""
    return bl.lathe(name, profile, material, segments=segments, rot=(D(90), 0, 0))


def build_seringue(m):
    """Seringue 10 mL graduée, type luer-lock : corps en polypropylène transparent (paroi épaisse),
    graduations imprimées tous les 0,5 mL et chiffres, collerette, embout luer avec bague filetée,
    piston blanc à section en croix et joint caoutchouc (nœud « Piston », position « pleine »),
    liquide (nœud « Liquide », origine à l'avant du corps : l'échelle Z vide la seringue), aiguille
    à embase colorée (nœud « Aiguille », pour l'IM ; retirée pour l'IV sur le robinet).
    Axe +Z du jeu vers l'embout ; origine au bout de l'embout luer.
    Matériaux volontairement peu brillants (rugosité >= 0,16, pas de spéculaire renforcé) : un
    plastique trop lisse donnait des reflets éblouissants sous la lampe d'examen."""
    nodes = {"seringue": [], "Piston": [], "Liquide": [], "Aiguille": []}
    s = nodes["seringue"]
    pp = bl.mat("Seringue PP", (0.93, 0.95, 0.97), 0.18, 0.0, 0.5, alpha=0.2)
    ink = bl.mat("Encre graduations", (0.03, 0.03, 0.035), 0.6)
    white = bl.mat("PP blanc", (0.94, 0.94, 0.92), 0.45)
    R, RI = 0.0082, 0.0073
    Z_FRONT, Z_BACK = -0.0135, -0.088
    # Corps : paroi extérieure et intérieure (un seul maillage fermé), épaulement, embout
    prof = [(0.0007, 0.0), (0.0019, 0.0), (0.0021, -0.0095), (0.0026, -0.0105), (R - 0.0008, -0.0125), (R, Z_FRONT),
            (R, Z_BACK + 0.001), (R + 0.0004, Z_BACK + 0.0005), (R + 0.0004, Z_BACK), (RI, Z_BACK), (RI, Z_FRONT + 0.0004),
            (RI - 0.0012, Z_FRONT + 0.0018), (0.0007, -0.0105), (0.0007, 0.0)]
    s.append(_zlathe("corps", prof, pp, 40))
    # Bague luer-lock autour de l'embout (filet suggéré par trois anneaux)
    s.append(_zlathe("bague", [(0.0042, -0.0012), (0.0048, -0.0012), (0.0048, -0.0115), (0.0042, -0.0115), (0.0042, -0.0012)], pp, 32))
    for k in range(3):
        s.append(bl.torus("filet", 0.0042, 0.00025, g(0, 0, -0.003 - k * 0.0025), pp, rot=(D(90), 0, 0), major=24, minor=5))
    # Collerette (appui des doigts)
    fl = [(pt.x, pt.y) for pt in bl.rounded_rect_path(0.034, 0.018, 0.0075, n=6)]
    col = bl.extrude_profile("collerette", fl, 0.0022, -0.0011, pp, bev=0.0005)
    col.rotation_euler = (D(90), 0, 0)
    col.location = g(0, 0, Z_BACK)
    s.append(col)
    # Graduations (0 à 10 mL, 6 mm par mL, traits tous les 0,5 mL) sur le dessus, chiffres tous les 2 mL
    for k in range(21):
        z = Z_FRONT - k * 0.003
        w = 0.0062 if k % 10 == 0 else (0.0046 if k % 2 == 0 else 0.0028)
        arc = w / R
        pts = [g(math.sin(a) * (R + 0.00006), math.cos(a) * (R + 0.00006), z) for a in [(-arc / 2) + arc * i / 6 for i in range(7)]]
        s.append(bl.tube("grad", pts, 0.00011, ink, sides=4, caps=True))
        if k % 4 == 0:
            s.append(bl.text("chiffre", str(k // 2), 0.0026, g(-0.0045, R + 0.00008, z), ink, rot=(0, 0, D(-90)), extrude=0.0))
    s.append(bl.text("marque", "10 mL", 0.0022, g(0.0042, R + 0.00008, -0.05), ink, rot=(0, 0, D(-90)), extrude=0.0))
    # Piston : joint caoutchouc à deux lèvres et pointe conique, tige en croix, poussoir
    pis = nodes["Piston"]
    z0 = Z_FRONT - 0.06  # joint en position « pleine » (10 mL)
    rub = m["black_rubber"]
    pis.append(_zlathe("joint", [(0.0, z0), (0.0035, z0 - 0.0002), (RI - 0.0002, z0 - 0.0016), (RI, z0 - 0.0022), (RI - 0.0006, z0 - 0.0036),
                                 (RI, z0 - 0.0052), (RI - 0.0004, z0 - 0.0072), (0.004, z0 - 0.0074), (0.0, z0 - 0.0074)], rub, 32))
    rod_a, rod_b = z0 - 0.0074, z0 - 0.058
    for rot in (0, 90):
        b = bl.box("tige", (0.0105, abs(rod_b - rod_a), 0.0011), g(0, 0, (rod_a + rod_b) / 2), white, bev=0.0002)
        b.rotation_euler = (0, D(rot), 0)
        pis.append(b)
    pis.append(bl.cyl_between("disque_avant", g(0, 0, rod_a - 0.0006), g(0, 0, rod_a), 0.0062, white, verts=28))
    pis.append(_zlathe("poussoir", [(0.0, rod_b - 0.0022), (0.0085, rod_b - 0.0022), (0.0089, rod_b - 0.0011), (0.0085, rod_b), (0.0, rod_b)], white, 32))
    # Liquide : de l'avant du corps au joint
    liq = _zlathe("liquide", [(0.0, Z_FRONT - 0.0002), (RI - 0.0012, Z_FRONT - 0.0004), (RI - 0.0001, Z_FRONT - 0.0018), (RI - 0.0001, z0), (0.0, z0)],
                  bl.mat("Liquide", (0.86, 0.92, 0.98), 0.14, 0.0, 0.5, alpha=0.3), 32)
    bl.finalize([liq])
    liq.name = "Liquide"
    nodes["Liquide"] = [_set_origin(liq, g(0, 0, Z_FRONT))]
    # Aiguille IM (embase verte 21G, 40 mm)
    ndl = nodes["Aiguille"]
    hub_col = bl.mat("Embase verte", (0.12, 0.6, 0.3), 0.4, alpha=0.85)
    ndl.append(_zlathe("embase", [(0.0021, -0.0085), (0.0034, -0.0085), (0.0034, -0.0035), (0.0028, 0.0), (0.0016, 0.004), (0.0009, 0.006),
                                  (0.0009, 0.0065), (0.0, 0.0065)], hub_col, 24))
    for k in range(4):
        a = k * math.pi / 2
        ndl.append(bl.box("ailette_embase", (0.0012, 0.0012, 0.005), g(math.cos(a) * 0.0036, math.sin(a) * 0.0036, -0.006), hub_col))
    ndl.append(bl.cyl_between("canule", g(0, 0, 0.006), g(0, 0, 0.044), 0.0004, m["chrome"], verts=10))
    ndl.append(bl.cyl_between("biseau", g(0, 0, 0.044), g(0, -0.0003, 0.0468), 0.0004, m["chrome"], verts=10, r2=0.00002))
    out = grouped({k: v for k, v in nodes.items() if k != "Liquide"})
    out.append(nodes["Liquide"][0])
    return out


def build_catheter(m, gauge="18"):
    """Cathéter veineux périphérique court (type Venflon) : canule souple translucide, embase
    transparente teintée, ailettes et bouchon du site d'injection à la couleur du calibre (18G vert,
    20G rose) ; mandrin : aiguille inox à biseau, chambre de reflux transparente, poignée blanche
    striée, bouchon filtre.
    Nœuds : « Catheter » (reste dans la veine), « Aiguille » (mandrin retiré après la pose),
    « Reflux » (sang de la chambre de reflux, origine à l'avant : échelle Z = remplissage ; suit
    l'aiguille), « Obturateur » (bouchon luer vissé après le retrait de l'aiguille).
    Axe +Z du jeu vers la pointe ; origine à la pointe de la canule."""
    L = 0.045 if gauge == "18" else 0.032
    rc = 0.00066 if gauge == "18" else 0.00055
    tint = (0.02, 0.55, 0.2) if gauge == "18" else (0.95, 0.32, 0.58)
    colour = bl.mat("Calibre %sG" % gauge, tint, 0.4)
    hub_tint = bl.mat("Embase %sG" % gauge, tuple(0.3 + 0.7 * c for c in tint), 0.22, 0.0, 0.5, alpha=0.55)
    clear = bl.mat("Chambre transparente", (0.95, 0.97, 0.98), 0.16, 0.0, 0.5, alpha=0.25)
    fep = bl.mat("Canule FEP", (0.92, 0.94, 0.95), 0.25, 0.0, 0.5, alpha=0.8)
    white = bl.mat("PP blanc", (0.94, 0.94, 0.92), 0.45)
    nodes = {"Catheter": [], "Aiguille": [], "Reflux": [], "Obturateur": []}
    c = nodes["Catheter"]
    # Canule (pointe effilée) et embase
    c.append(_zlathe("canule", [(0.0, 0.0), (rc * 0.75, -0.0002), (rc, -0.0016), (rc, -L + 0.002), (rc * 1.5, -L), (0.0, -L)], fep, 16))
    hz = -L
    c.append(_zlathe("embase", [(0.0013, hz + 0.0005), (0.0022, hz - 0.002), (0.0031, hz - 0.006), (0.0034, hz - 0.0075), (0.0034, hz - 0.016),
                                (0.0039, hz - 0.0165), (0.0039, hz - 0.0185), (0.0026, hz - 0.0185), (0.0026, hz - 0.006), (0.0009, hz - 0.002),
                                (0.0009, hz + 0.0005), (0.0013, hz + 0.0005)], hub_tint, 32))
    # Ailettes (posées à plat sur la peau)
    wing = [(0.0028, 0.0), (0.0125, -0.0015), (0.0135, -0.004), (0.0125, -0.0105), (0.0028, -0.013)]
    for sx in (-1, 1):
        pts = [(sx * x, -(hz - 0.003 + z)) for (x, z) in wing]
        c.append(bl.extrude_profile("ailette", pts, 0.0008, -0.0028, colour, bev=0.0002))
        for k in range(3):
            c.append(bl.box("strie", (0.006, 0.0004, 0.0005), g(sx * 0.0085, -0.0018, hz - 0.0055 - k * 0.0018), colour))
    # Site d'injection (dessus) et son bouchon à charnière, fermé
    pz = hz - 0.0085
    c.append(bl.cyl_between("site", g(0, 0.0025, pz), g(0, 0.0072, pz), 0.0024, hub_tint, verts=24))
    c.append(bl.cyl_between("bouchon", g(0, 0.0068, pz), g(0, 0.0088, pz), 0.0031, colour, verts=24))
    c.append(bl.box("charniere", (0.0028, 0.004, 0.0009), g(0, 0.0066, pz + 0.0042), colour))
    c.append(bl.box("languette", (0.003, 0.0028, 0.001), g(0, 0.0084, pz - 0.0038), colour))
    # Mandrin : aiguille à biseau, chambre de reflux, poignée striée, bouchon filtre
    a = nodes["Aiguille"]
    rn = rc * 0.7
    a.append(bl.cyl_between("aiguille", g(0, 0, -0.0005), g(0, 0, hz - 0.02), rn, m["chrome"], verts=12))
    a.append(bl.cyl_between("biseau", g(0, 0, -0.0005), g(0, -rn * 0.8, 0.0035), rn, m["chrome"], verts=12, r2=rn * 0.05))
    cz0, cz1 = hz - 0.019, hz - 0.034
    a.append(_zlathe("chambre", [(0.0012, cz0), (0.0033, cz0 - 0.001), (0.0033, cz1), (0.0012, cz1), (0.0012, cz0 - 0.0005), (0.0012, cz0)], clear, 32))
    a.append(_zlathe("poignee", [(0.0, cz1), (0.0036, cz1), (0.0036, cz1 - 0.016), (0.0, cz1 - 0.016)], white, 32))
    for k in range(5):
        a.append(bl.torus("strie_poignee", 0.0036, 0.00035, g(0, 0, cz1 - 0.003 - k * 0.0025), white, rot=(D(90), 0, 0), major=24, minor=5))
    a.append(bl.cyl_between("filtre", g(0, 0, cz1 - 0.016), g(0, 0, cz1 - 0.0195), 0.0026, colour, verts=20))
    # Sang de la chambre de reflux
    blood = _zlathe("sang", [(0.0, cz0 - 0.0012), (0.0029, cz0 - 0.0012), (0.0029, cz1 + 0.0004), (0.0, cz1 + 0.0004)],
                    bl.mat("Sang", (0.42, 0.02, 0.02), 0.3, 0.0, 0.5, alpha=0.92), 24)
    bl.finalize([blood])
    blood.name = "Reflux"
    nodes["Reflux"] = [_set_origin(blood, g(0, 0, cz0 - 0.0012))]
    # Obturateur luer (bouchon blanc vissé à l'arrière de l'embase)
    o = nodes["Obturateur"]
    o.append(_zlathe("obturateur", [(0.0, hz - 0.017), (0.0024, hz - 0.017), (0.0024, hz - 0.019), (0.0042, hz - 0.019), (0.0042, hz - 0.027),
                                    (0.0036, hz - 0.028), (0.0, hz - 0.028)], white, 24))
    for k in range(8):
        aa = k * math.pi / 4
        o.append(bl.box("cran", (0.0008, 0.0008, 0.007), g(math.cos(aa) * 0.0043, math.sin(aa) * 0.0043, hz - 0.0235), white))
    out = grouped({k: v for k, v in nodes.items() if k != "Reflux"})
    out.append(nodes["Reflux"][0])
    return out


def build_stethoscope(m):
    """Stéthoscope : pavillon double face (nœud « Pavillon » à l'origine), tubulure, lyre, embouts."""
    nodes = {"Pavillon": [], "stethoscope": []}
    pv = nodes["Pavillon"]
    pv.append(bl.lathe("pavillon", [(0.0, 0.0), (0.022, 0.0), (0.023, 0.004), (0.02, 0.01), (0.008, 0.013), (0.0, 0.013)], m["chrome"], segments=36))
    pv.append(bl.cyl("membrane", 0.021, 0.0015, g(0, 0.0005, 0), m["dark"], verts=36))
    pv.append(bl.cyl_between("tige", g(0, 0.012, 0), g(0, 0.02, -0.03), 0.004, m["chrome"], verts=10))
    st = nodes["stethoscope"]
    tube = bl.bezier_pts(g(0, 0.02, -0.03), g(0, 0.06, -0.15), g(0.1, 0.2, -0.25), g(0.05, 0.35, -0.3), 26)
    st.append(bl.tube("tubulure", tube, 0.004, m["dark"], sides=10))
    for s in (-1, 1):
        lyre = bl.bezier_pts(g(0.05, 0.35, -0.3), g(0.05 + s * 0.03, 0.4, -0.3), g(0.05 + s * 0.06, 0.48, -0.31), g(0.05 + s * 0.045, 0.52, -0.3), 14)
        st.append(bl.tube("lyre", lyre, 0.0022, m["chrome"], sides=8))
        st.append(bl.sphere("embout", 0.006, lyre[-1], m["black_rubber"]))
    return grouped(nodes)


def build_glucometre(m):
    nodes = {"glucometre": [], "Ecran": []}
    gl = nodes["glucometre"]
    gl.append(bl.box("corps", (0.055, 0.02, 0.09), g(0, 0, 0), m["white"], bev=0.009))
    nodes["Ecran"].append(bl.box("ecran", (0.04, 0.003, 0.03), g(0, 0.0, 0.018), m["screen"]))
    gl.append(bl.box("bandelette", (0.008, 0.001, 0.03), g(0, 0, 0.058), bl.mat("Bandelette", (0.95, 0.9, 0.5), 0.6)))
    gl.append(bl.cyl("bouton", 0.006, 0.003, g(0, 0.0, -0.025), m["blue"], rot=(D(90), 0, 0), verts=16))
    return grouped(nodes)


def build_ampoule(m):
    """Ampoule de verre (sérum, médicament)."""
    a = bl.lathe("ampoule", [(0.0, 0.0), (0.0065, 0.0), (0.0068, 0.004), (0.0068, 0.04), (0.0035, 0.047), (0.0028, 0.05),
                             (0.0045, 0.056), (0.004, 0.062), (0.0, 0.064)], bl.mat("Verre ampoule", (0.9, 0.93, 0.95), 0.03, 0.0, 0.6, alpha=0.4), segments=24, rot=(D(-90), 0, 0))
    lab = bl.lathe("etiquette", [(0.0071, 0.012), (0.0071, 0.03)], m["white"], segments=24, rot=(D(-90), 0, 0))
    return grouped({"ampoule": [a, lab]})


def build_electrodes_defib(m):
    """Électrode de défibrillation adulte (patch) : mousse blanche, gel, connecteur et fil."""
    pad = bl.box("patch", (0.12, 0.09, 0.004), (0, 0, 0.002), m["white"], bev=0.0018)
    gel = bl.box("gel", (0.1, 0.07, 0.001), (0, 0, -0.0005), bl.mat("Gel", (0.35, 0.45, 0.6), 0.2, 0.0, 0.5, alpha=0.8), bev=0.0004)
    logo = bl.box("logo", (0.03, 0.03, 0.0008), (0.02, 0.0, 0.0042), m["red"])
    return grouped({"electrode_defib": [pad, gel, logo]})


def build_garrot(m):
    band = bl.box("bande", (0.35, 0.025, 0.002), g(0, 0, 0), bl.mat("Garrot", (0.25, 0.45, 0.8), 0.6), bev=0.0009)
    clip = bl.box("boucle", (0.04, 0.03, 0.014), g(0.0, 0.007, 0), m["dark"], bev=0.004)
    return grouped({"garrot": [band, clip]})


def build_lampe(m):
    body = bl.cyl_between("corps", g(0, 0, -0.065), g(0, 0, 0.065), 0.0055, m["chrome"], verts=16)
    clip = bl.box("clip", (0.004, 0.003, 0.05), g(0, 0.006, -0.02), m["chrome"], bev=0.001)
    tip = bl.cyl_between("verre", g(0, 0, 0.065), g(0, 0, 0.068), 0.005, m["led"], verts=16)
    return grouped({"lampe": [body, clip, tip]})


def build_thermometre(m):
    body = bl.box("corps", (0.035, 0.03, 0.12), g(0, 0, 0), m["white"], bev=0.012)
    tip = bl.cyl_between("sonde", g(0, 0.0, 0.06), g(0, 0.0, 0.085), 0.006, m["white"], verts=16, r2=0.004)
    scr = bl.box("Ecran", (0.022, 0.004, 0.016), g(0, 0.016, 0.01), m["screen"])
    return grouped({"thermometre": [body, tip], "Ecran": [scr]})


def build_poche(m):
    """Poche de soluté (500 mL) avec tubulure et chambre compte-gouttes, accrochée par l'œillet en
    (0, 0, 0)."""
    p = []
    bag = bl.box("poche", (0.11, 0.03, 0.2), g(0, -0.12, 0), bl.mat("Poche", (0.9, 0.94, 0.97), 0.1, 0.0, 0.5, alpha=0.35), bev=0.012)
    p.append(bag)
    p.append(bl.box("liquide", (0.1, 0.022, 0.15), g(0, -0.145, 0), bl.mat("Soluté", (0.82, 0.88, 0.95), 0.05, 0.0, 0.5, alpha=0.3), bev=0.008))
    p.append(bl.box("etiquette", (0.07, 0.032, 0.06), g(0, -0.1, 0), m["white"]))
    p.append(bl.torus("oeillet", 0.008, 0.002, g(0, -0.01, 0), m["clear"], rot=(D(90), 0, 0), major=16, minor=6))
    p.append(bl.cyl_between("embout", g(0, -0.22, 0), g(0, -0.25, 0), 0.005, m["clear"], verts=12))
    p.append(bl.cyl_between("chambre", g(0, -0.25, 0), g(0, -0.31, 0), 0.009, m["clear"], verts=16))
    return grouped({"poche": p})


BUILDERS = {
    "brancard": (build_brancard, ((1.4, -2.3, 1.7), (-0.4, 0.0, 0.6))),
    "defibrillateur": (build_defibrillateur, ((0.35, -0.6, 0.45), (0.0, 0.0, 0.13))),
    "scope": (build_scope, ((0.3, -0.6, 0.2), (0.0, 0.0, 0.0))),
    "bras_plafonnier": (build_bras_plafonnier, ((1.6, -2.4, 2.0), (0.0, -0.5, 1.9))),
    "rampe": (build_rampe, ((0.8, -1.6, 1.6), (0.0, 0.0, 1.45))),
    "bavu": (build_bavu, ((0.35, -0.5, 0.3), (0.0, 0.0, 0.0))),
    "mains_rcp": (build_mains_rcp, ((0.45, -0.55, 0.35), (0.0, 0.0, 0.1))),
    "main_pouls": (build_main_pouls, ((0.35, -0.4, 0.3), (0.0, 0.0, 0.03))),
    "main_plate": (build_main_plate, ((0.15, -0.3, 0.2), (0.0, 0.0, 0.0))),
    "ecg": (build_ecg, ((0.9, -1.2, 1.4), (0.0, 0.0, 0.8))),
    "poste": (build_poste, ((0.9, -1.6, 1.6), (0.0, 0.0, 1.15))),
    "armoire": (build_armoire, ((1.5, -2.6, 1.6), (0.0, 0.0, 0.95))),
    "seringue": (build_seringue, ((0.09, -0.07, 0.05), (0.0, -0.035, 0.0))),
    "catheter18": (lambda m: build_catheter(m, "18"), ((0.07, -0.05, 0.04), (0.0, -0.035, 0.0))),
    "catheter20": (lambda m: build_catheter(m, "20"), ((0.07, -0.05, 0.04), (0.0, -0.03, 0.0))),
    "stethoscope": (build_stethoscope, ((0.5, -0.6, 0.4), (0.05, 0.2, 0.2))),
    "glucometre": (build_glucometre, ((0.12, -0.15, 0.1), (0.0, 0.0, 0.0))),
    "ampoule": (build_ampoule, ((0.06, -0.08, 0.05), (0.0, 0.0, 0.0))),
    "electrode_defib": (build_electrodes_defib, ((0.12, -0.15, 0.12), (0.0, 0.0, 0.0))),
    "garrot": (build_garrot, ((0.2, -0.3, 0.2), (0.0, 0.0, 0.0))),
    "lampe": (build_lampe, ((0.1, -0.15, 0.08), (0.0, 0.0, 0.0))),
    "thermometre": (build_thermometre, ((0.1, -0.15, 0.1), (0.0, 0.0, 0.0))),
    "poche": (build_poche, ((0.25, -0.4, 0.0), (0.0, 0.0, -0.15))),
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
            bl.preview(os.path.join(PREVIEW_DIR, name + ".png"), cam[0], cam[1], floor=name not in ("bras_plafonnier",))


if __name__ == "__main__":
    main()
