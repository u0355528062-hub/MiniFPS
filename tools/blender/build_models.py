"""Modèles du bloc (mobilier, appareils), construits dans Blender et exportés en .glb.

    /home/user/bpyenv/bin/python tools/blender/build_models.py scialytique table_operation ...
    /home/user/bpyenv/bin/python tools/blender/build_models.py --preview scialytique

Coordonnées : voir bl.py (g(x, y, z) convertit un point du jeu en point Blender).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
from bl import g  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402

PREVIEW_DIR = os.environ.get("APERCU", "/tmp/apercus")
D = math.radians

# ---------------------------------------------------------------- Matériaux communs


def M():
    return {
        "white": bl.mat("Laque blanche", (0.86, 0.87, 0.88), 0.32, 0.0, 0.5, clearcoat=0.25),
        "warm_white": bl.mat("Laque ivoire", (0.83, 0.83, 0.81), 0.38),
        "grey": bl.mat("Gris moyen", (0.42, 0.44, 0.46), 0.42),
        "dark": bl.mat("Gris anthracite", (0.07, 0.075, 0.085), 0.45),
        "black_rubber": bl.mat("Caoutchouc", (0.025, 0.025, 0.028), 0.75),
        "steel": bl.mat("Inox brossé", (0.72, 0.73, 0.74), 0.28, 1.0),
        "chrome": bl.mat("Chrome", (0.86, 0.87, 0.88), 0.08, 1.0),
        "alu": bl.mat("Aluminium", (0.78, 0.79, 0.8), 0.35, 1.0),
        "blue": bl.mat("Bleu médical", (0.05, 0.22, 0.45), 0.4),
        "led": bl.mat("Lentille LED", (0.95, 0.95, 0.92), 0.05, 0.0, emission=(1.0, 0.97, 0.9), emission_strength=6.0),
        "glass": bl.mat("Verre fumé", (0.08, 0.1, 0.11), 0.03, 0.0, 0.6),
        "screen": bl.mat("Écran", (0.01, 0.012, 0.015), 0.08, 0.0, 0.6),
        "mattress": bl.mat("Matelas vinyle", (0.035, 0.04, 0.05), 0.48, 0.0, 0.4, clearcoat=0.15, coat_rough=0.3),
        "foam_blue": bl.mat("Gel bleu", (0.12, 0.36, 0.58), 0.3, clearcoat=0.5),
    }


# ---------------------------------------------------------------- Scialytique

HEADS = [  # (centre de la coupole, point visé) en coordonnées du jeu : mêmes que les projecteurs de room.gd
    ((-0.05, 2.25, 0.35), (0.0, 1.3, 0.0), 0.33),
    ((0.40, 2.20, -0.30), (0.0, 1.3, 0.0), 0.28),
]
MOUNT = (0.15, 3.0, 0.02)


def _beam(name, a, b, w, h, material, up=Vector((0, 0, 1)), bev=0.012):
    """Poutre de section rectangulaire arrondie de a à b (points Blender), largeur horizontale."""
    a = Vector(a)
    b = Vector(b)
    d = b - a
    x = d.normalized()
    side = x.cross(up).normalized()
    z = side.cross(x).normalized()
    ob = bl.box(name, (d.length + w * 0.2, w, h), (0, 0, 0), material, bev=min(bev, w * 0.45, h * 0.45), seg=4)
    rot = Matrix((x, side, z)).transposed().to_4x4()
    ob.matrix_world = Matrix.Translation((a + b) / 2) @ rot
    return ob


def _light_head(name, c, n, R, m):
    """Coupole LED : boîtier lenticulaire, anneau de poignées, lentilles, poignée stérile."""
    parts = []
    # Repère local : Z le long de n (vers le patient)
    rot = Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
    T = Matrix.Translation(c) @ rot

    def place(ob):
        bl.apply_all(ob)
        ob.data.transform(T @ ob.matrix_world)
        ob.matrix_world = Matrix.Identity(4)
        parts.append(ob)
        return ob

    # Boîtier : face plate côté patient (z = 0), bord arrondi, dos bombé
    prof = [(0.0, -0.0), (R * 0.97, 0.0), (R * 1.0, -0.006), (R * 1.02, -0.02), (R * 1.02, -0.045), (R * 0.98, -0.06),
            (R * 0.86, -0.085), (R * 0.6, -0.105), (R * 0.3, -0.118), (R * 0.14, -0.13), (0.0, -0.132)]
    shell = bl.lathe(name + "_coque", list(reversed(prof)), m["white"], segments=72)
    place(shell)
    # Bandeau gris du pourtour
    band = bl.lathe(name + "_bandeau", [(R * 1.025, -0.022), (R * 1.03, -0.033), (R * 1.025, -0.044)], m["grey"], segments=72)
    place(band)
    # Face : disque gris foncé légèrement en retrait, lentilles en anneaux
    face = bl.cyl(name + "_face", R * 0.95, 0.004, (0, 0, 0.001), m["dark"], verts=72)
    place(face)
    rings = [(0.0, 1), (R * 0.2, 8), (R * 0.36, 14), (R * 0.52, 20), (R * 0.68, 26), (R * 0.83, 32)]
    for k, (rr, cnt) in enumerate(rings):
        if rr == 0.0:
            continue
        for i in range(cnt):
            a = 2 * math.pi * (i + 0.5 * (k % 2)) / cnt
            lr = 0.0135 if k < 4 else 0.012
            lens = bl.cyl(name + "_lentille", lr, 0.006, (math.cos(a) * rr, math.sin(a) * rr, 0.004), m["led"], verts=14)
            place(lens)
            rim = bl.torus(name + "_serti", lr + 0.002, 0.0018, (math.cos(a) * rr, math.sin(a) * rr, 0.0045), m["chrome"], major=14, minor=5)
            place(rim)
    # Poignée stérile au centre
    handle = bl.lathe(name + "_poignee", [(0.0, 0.0), (0.03, 0.0), (0.032, 0.012), (0.019, 0.02), (0.017, 0.1), (0.022, 0.11),
                                          (0.02, 0.122), (0.0, 0.125)], m["warm_white"], segments=32)
    place(handle)
    # Poignées latérales (anneau tubulaire autour de la coupole, deux ponts)
    for s in (-1, 1):
        pts = bl.arc_pts((0, 0, -0.03), R + 0.06, math.radians(90 * s - 38), math.radians(90 * s + 38), 18)
        h = bl.tube(name + "_anse", pts, 0.012, m["grey"], sides=14)
        place(h)
        for a in (math.radians(90 * s - 38), math.radians(90 * s + 38)):
            p0 = Vector((math.cos(a) * (R + 0.06), math.sin(a) * (R + 0.06), -0.03))
            p1 = Vector((math.cos(a) * (R + 0.005), math.sin(a) * (R + 0.005), -0.03))
            place(bl.cyl_between(name + "_pont", p0, p1, 0.011, m["grey"], verts=12))
    # Logo / afficheur sur le bord
    place(bl.box(name + "_clavier", (0.07, 0.008, 0.022), (0, -R * 1.02 - 0.002, -0.033), m["dark"], bev=0.003))
    return parts


def build_scialytique(m):
    """Bras de suspension et deux coupoles LED, posés pour éclairer le champ opératoire."""
    parts = []
    mount = g(*MOUNT)
    ceil_y = MOUNT[1]
    # Platine de plafond, cache et axe central
    parts.append(bl.cyl("platine", 0.24, 0.02, mount + Vector((0, 0, -0.01)), m["white"], verts=64, bev=0.006))
    parts.append(bl.lathe("cache", [(0.2, -0.02), (0.19, -0.07), (0.11, -0.1), (0.07, -0.11)], m["white"], segments=48, loc=mount))
    axis_bot = ceil_y - 0.55
    parts.append(bl.cyl_between("axe", mount + Vector((0, 0, -0.1)), g(MOUNT[0], axis_bot, MOUNT[2]), 0.055, m["white"], verts=40))
    hubs = []
    for i, (c, t, R) in enumerate(HEADS):
        hy = axis_bot + 0.16 - i * 0.11
        hub = bl.cyl("moyeu%d" % i, 0.075, 0.07, g(MOUNT[0], hy, MOUNT[2]), m["white"], verts=48, bev=0.008)
        parts.append(hub)
        parts.append(bl.cyl("bague%d" % i, 0.078, 0.008, g(MOUNT[0], hy - 0.039, MOUNT[2]), m["grey"], verts=48))
        hubs.append(hy)
    parts.append(bl.cyl("bouchon", 0.05, 0.03, g(MOUNT[0], axis_bot - 0.015, MOUNT[2]), m["white"], verts=40, bev=0.01))

    for i, (c, t, R) in enumerate(HEADS):
        C = g(*c)
        T = g(*t)
        n = (T - C).normalized()
        up = Vector((0, 0, 1))
        hy = hubs[i]
        A = g(MOUNT[0], hy, MOUNT[2])
        # Côté de l'étrier : horizontal, perpendiculaire à la direction mur -> coupole
        horiz = Vector((C.x - A.x, C.y - A.y, 0))
        u = horiz.cross(up).normalized()
        if u.dot(n.cross(up)) < 0:
            u = -u
        # u : perpendiculaire à n dans le plan horizontal
        u = (u - n * u.dot(n)).normalized()
        pivot = C + u * (R + 0.035) - n * 0.035
        S = pivot + up * 0.30 + u * 0.03  # haut de l'étrier (bout du bras à ressort)
        # Bras à ressort : de E (au bout du bras d'extension) jusqu'à S, incliné vers le bas
        L = 0.78
        dz = hy - S.z
        span = math.sqrt(max(L * L - dz * dz, 0.04))
        dirh = Vector((S.x - A.x, S.y - A.y, 0))
        dist = dirh.length
        dirh.normalize()
        ext = max(dist - span, 0.18)
        E = A + dirh * ext
        E.z = A.z
        parts.append(_beam("extension%d" % i, A + dirh * 0.06, E, 0.07, 0.06, m["white"]))
        parts.append(bl.cyl("articulation%d" % i, 0.05, 0.11, E + Vector((0, 0, -0.01)), m["white"], verts=40, bev=0.01))
        parts.append(bl.cyl("bague_art%d" % i, 0.052, 0.008, E + Vector((0, 0, -0.06)), m["grey"], verts=40))
        top = E + Vector((0, 0, -0.04))
        parts.append(_beam("ressort%d" % i, top, S + Vector((0, 0, 0.03)), 0.065, 0.085, m["white"], bev=0.02))
        # Rotule et étrier courbe jusqu'au pivot de la coupole
        parts.append(bl.sphere("rotule%d" % i, 0.04, S + Vector((0, 0, 0.02)), m["white"], seg=24, rings=12))
        yoke = bl.bezier_pts(S, S - up * 0.16, pivot + u * 0.12 + up * 0.04, pivot, 24)
        parts.append(bl.tube("etrier%d" % i, yoke, 0.022, m["white"], sides=20))
        parts.append(bl.cyl_between("pivot%d" % i, pivot, pivot - u * 0.03, 0.026, m["grey"], verts=24))
        parts.extend(_light_head("coupole%d" % i, C, n, R, m))
    return parts


# ---------------------------------------------------------------- Table d'opération

TABLE_TOP = 0.80  # Patient.TABLE_TOP


def build_table_operation(m):
    """Table d'opération : socle, colonne télescopique, plateau articulé (dos, siège, jambes, têtière),
    matelas, rails latéraux. Centrée en (0, 0) ; tête vers +X. Dessus du matelas à 0,80 m."""
    parts = []
    top = TABLE_TOP
    pad_t = 0.07
    plate_z = top - pad_t  # dessus du plateau métallique
    # Socle en T arrondi
    base_pts = bl.rounded_rect_path(0.98, 0.56, 0.12)
    base = bl.extrude_profile("socle", [(p.x - 0.12, p.y) for p in base_pts], 0.1, 0.02, m["white"], bev=0.02)
    parts.append(base)
    parts.append(bl.extrude_profile("plinthe_socle", [(p.x * 0.99 - 0.12, p.y * 0.99) for p in base_pts], 0.02, 0.0, m["dark"], bev=0.004))
    # Pédale et voyant
    parts.append(bl.box("pedale", (0.12, 0.06, 0.02), g(-0.55, 0.1, 0.22), m["dark"], bev=0.006))
    # Colonne : soufflet + fût
    col = bl.extrude_profile("colonne", bl.rounded_rect_path(0.36, 0.26, 0.06), 0.36, 0.12, m["white"], bev=0.01)
    parts.append(col)
    for k in range(6):
        parts.append(bl.extrude_profile("soufflet%d" % k, bl.rounded_rect_path(0.33, 0.23, 0.05), 0.012, 0.49 + k * 0.022, m["grey"], bev=0.004))
    parts.append(bl.extrude_profile("tete_colonne", bl.rounded_rect_path(0.42, 0.3, 0.05), 0.07, plate_z - 0.12, m["white"], bev=0.012))
    # Plateau : sections (jambes, siège, dos, têtière) avec jointures
    sections = [(-1.40, -0.72, "jambes"), (-0.70, -0.12, "siege"), (-0.10, 0.48, "dos"), (0.50, 0.69, "tetiere")]
    for (x0, x1, nm) in sections:
        w = 0.5 if nm != "tetiere" else 0.3
        cx = (x0 + x1) / 2
        # Châssis métallique
        parts.append(bl.box("chassis_" + nm, (x1 - x0 - 0.01, w - 0.02, 0.035), g(cx, plate_z - 0.02, 0), m["alu"], bev=0.006))
        # Matelas (bords très arrondis)
        pad = bl.box("matelas_" + nm, (x1 - x0 - 0.012, w, pad_t), g(cx, plate_z + pad_t / 2, 0), m["mattress"], bev=0.028, seg=5)
        parts.append(pad)
        # Rails latéraux (inox) sur les sections principales
        if nm != "tetiere":
            for s in (-1, 1):
                rz = s * (w / 2 + 0.025)
                parts.append(bl.box("rail_" + nm, (x1 - x0 - 0.03, 0.01, 0.03), g(cx, plate_z - 0.02, rz), m["chrome"], bev=0.003))
                for xx in (x0 + 0.05, x1 - 0.05):
                    parts.append(bl.box("patte_" + nm, (0.02, 0.025, 0.02), g(xx, plate_z - 0.02, s * (w / 2 + 0.012)), m["chrome"], bev=0.002))
    # Articulations entre sections
    for xj in (-0.71, -0.11, 0.49):
        parts.append(bl.cyl("charniere", 0.018, 0.5, g(xj, plate_z - 0.02, 0), m["grey"], rot=(D(90), 0, 0), verts=20))
    # Carter sous le plateau
    parts.append(bl.box("carter", (1.1, 0.4, 0.06), g(-0.25, plate_z - 0.075, 0), m["white"], bev=0.015))
    return parts


# ---------------------------------------------------------------- Table de Mayo

def build_table_mayo(m):
    """Table de Mayo : plateau inox (centré sur l'origine, dessus à 0,995 m), bras, colonne, base en U
    à roulettes."""
    parts = []
    tray_y = 0.995
    tw, td = 0.48, 0.36
    # Plateau embouti avec rebord
    outer = bl.rounded_rect_path(tw, td, 0.03, 6)
    parts.append(bl.extrude_profile("plateau", [(p.x, p.y) for p in outer], 0.006, tray_y - 0.006, m["steel"], bev=0.002))
    rim_pts = [g(p.x, tray_y + 0.008, -p.y) for p in outer]
    parts.append(bl.tube("rebord", rim_pts, 0.006, m["steel"], sides=10, closed=True))
    # Bras horizontal (sous le plateau) vers la colonne, décalée sur un côté (-X)
    post_x = -0.3
    parts.append(bl.box("support", (0.36, 0.05, 0.02), g(-0.1, tray_y - 0.02, 0), m["steel"], bev=0.004))
    parts.append(bl.cyl_between("bras", g(post_x, tray_y - 0.03, 0), g(-0.05, tray_y - 0.03, 0), 0.018, m["steel"], verts=20))
    # Colonne télescopique + molette
    parts.append(bl.cyl_between("tube_haut", g(post_x, tray_y - 0.02, 0), g(post_x, 0.55, 0), 0.016, m["chrome"], verts=24))
    parts.append(bl.cyl_between("tube_bas", g(post_x, 0.6, 0), g(post_x, 0.1, 0), 0.024, m["steel"], verts=24))
    parts.append(bl.cyl("bague", 0.03, 0.04, g(post_x, 0.6, 0), m["dark"], verts=24, bev=0.006))
    parts.append(bl.cyl_between("molette", g(post_x, 0.6, 0), g(post_x - 0.05, 0.6, 0), 0.008, m["dark"], verts=12))
    parts.append(bl.sphere("bouton", 0.016, g(post_x - 0.055, 0.6, 0), m["dark"]))
    # Base en U (s'enfile sous la table d'opération)
    leg_y = 0.075
    pts = [g(0.25, leg_y, -0.24), g(post_x, leg_y, -0.24), g(post_x, leg_y, 0.24), g(0.25, leg_y, 0.24)]
    # coins arrondis
    path = []
    path += bl.bezier_pts(pts[0], pts[0] + (pts[1] - pts[0]) * 0.5, pts[1] + Vector((0.0, 0.0, 0)), pts[1] + (pts[2] - pts[1]) * 0.15, 14)
    path += bl.bezier_pts(pts[1] + (pts[2] - pts[1]) * 0.15, pts[1] + (pts[2] - pts[1]) * 0.5, pts[2] + (pts[1] - pts[2]) * 0.5, pts[2] + (pts[1] - pts[2]) * 0.15, 10)[1:]
    path += bl.bezier_pts(pts[2] + (pts[1] - pts[2]) * 0.15, pts[2], pts[2] + (pts[3] - pts[2]) * 0.5, pts[3], 14)[1:]
    parts.append(bl.tube("base", path, 0.02, m["steel"], sides=16))
    for p in (pts[0], pts[3], g(post_x, 0, -0.24), g(post_x, 0, 0.24)):
        parts.append(bl.caster("roulette", (p.x, p.y, 0.0), m["black_rubber"], m["steel"], r=0.025))
    return parts


# ---------------------------------------------------------------- Pied à perfusion

def build_perfusion(m):
    """Pied à perfusion : base à 5 branches et roulettes, mât télescopique, 4 crochets."""
    parts = []
    parts.append(bl.cyl("noyau", 0.04, 0.05, g(0, 0.08, 0), m["steel"], verts=24, bev=0.008))
    for k in range(5):
        a = 2 * math.pi * k / 5
        tip = g(math.cos(a) * 0.3, 0.06, math.sin(a) * 0.3)
        parts.append(bl.cyl_between("branche", g(0, 0.085, 0), tip, 0.014, m["steel"], verts=14, r2=0.011))
        parts.append(bl.caster("roulette", (tip.x, tip.y, 0.0), m["black_rubber"], m["steel"], r=0.025, yaw=a))
    parts.append(bl.cyl_between("mat_bas", g(0, 0.1, 0), g(0, 1.25, 0), 0.0135, m["chrome"], verts=20))
    parts.append(bl.cyl("serrage", 0.02, 0.05, g(0, 1.25, 0), m["dark"], verts=20, bev=0.005))
    parts.append(bl.cyl_between("vis", g(0, 1.25, 0), g(0.04, 1.25, 0), 0.006, m["dark"], verts=10))
    parts.append(bl.sphere("vis_bouton", 0.012, g(0.045, 1.25, 0), m["dark"]))
    parts.append(bl.cyl_between("mat_haut", g(0, 1.27, 0), g(0, 1.86, 0), 0.0095, m["chrome"], verts=20))
    parts.append(bl.sphere("tete", 0.015, g(0, 1.865, 0), m["steel"]))
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        d = Vector((math.cos(a), -math.sin(a), 0))
        base = g(0, 1.84, 0)
        hook = [base, base + d * 0.08 + Vector((0, 0, 0.02)), base + d * 0.12 + Vector((0, 0, 0.0)),
                base + d * 0.13 + Vector((0, 0, 0.03))]
        hook = bl.bezier_pts(hook[0], hook[1], hook[2], hook[3], 14)
        parts.append(bl.tube("crochet", hook, 0.004, m["chrome"], sides=8))
        parts.append(bl.sphere("bout", 0.006, hook[-1], m["chrome"], seg=10, rings=6))
    return parts


# ---------------------------------------------------------------- Tabouret

def build_tabouret(m):
    parts = []
    parts.append(bl.lathe("assise", [(0.0, 0.56), (0.17, 0.56), (0.185, 0.575), (0.185, 0.6), (0.17, 0.618), (0.0, 0.62)],
                          m["mattress"], segments=48))
    parts.append(bl.cyl("sous_assise", 0.15, 0.02, g(0, 0.55, 0), m["dark"], verts=32))
    parts.append(bl.cyl_between("verin", g(0, 0.12, 0), g(0, 0.54, 0), 0.025, m["chrome"], verts=24))
    parts.append(bl.cyl_between("gaine", g(0, 0.12, 0), g(0, 0.32, 0), 0.032, m["dark"], verts=24))
    parts.append(bl.torus("repose_pied", 0.2, 0.01, g(0, 0.28, 0), m["chrome"], major=40, minor=8))
    for k in range(5):
        a = 2 * math.pi * k / 5
        tip = g(math.cos(a) * 0.26, 0.06, math.sin(a) * 0.26)
        parts.append(bl.cyl_between("pied", g(0, 0.12, 0), tip, 0.018, m["dark"], verts=12, r2=0.013))
        rs = g(math.cos(a) * 0.2, 0.28, math.sin(a) * 0.2)
        parts.append(bl.cyl_between("rayon", g(0, 0.28, 0) + (rs - g(0, 0.28, 0)) * 0.15, rs, 0.006, m["chrome"], verts=8))
        parts.append(bl.caster("roulette", (tip.x, tip.y, 0.0), m["black_rubber"], m["dark"], r=0.022, yaw=a))
    return parts



# ---------------------------------------------------------------- Machine d'anesthésie

def _flex_hose(name, pts, r, material, sides=14, ribs=True):
    """Tuyau annelé (circuit respiratoire) le long d'une courbe."""
    pts = [Vector(p) for p in pts]
    # rééchantillonnage régulier
    L = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))
    n = max(8, int(L / 0.006))
    out = []
    acc = [0.0]
    for i in range(len(pts) - 1):
        acc.append(acc[-1] + (pts[i + 1] - pts[i]).length)
    for k in range(n + 1):
        d = L * k / n
        j = 0
        while j < len(pts) - 2 and acc[j + 1] < d:
            j += 1
        t = (d - acc[j]) / max(acc[j + 1] - acc[j], 1e-9)
        out.append(pts[j].lerp(pts[j + 1], t))
    radii = [r * (1.0 + (0.12 if (ribs and k % 2 == 0) else 0.0)) for k in range(len(out))]
    return bl.tube(name, out, radii, material, sides=sides)


def build_anesthesie(m):
    """Station d'anesthésie (type Dräger) : chariot à tiroirs, plan de travail, débitmètres,
    évaporateurs, soufflet sous cloche, écran sur bras, circuit annelé. Face avant vers +Z (jeu)."""
    parts = []
    body = m["white"]
    W, Dp = 0.7, 0.55
    # Chariot : socle à roulettes, caisson, tiroirs
    parts.append(bl.box("socle", (W + 0.04, Dp + 0.02, 0.06), g(0, 0.1, 0), m["grey"], bev=0.012))
    for x in (-W / 2 + 0.06, W / 2 - 0.06):
        for z in (-Dp / 2 + 0.06, Dp / 2 - 0.06):
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["grey"], r=0.03))
    parts.append(bl.box("caisson", (W, Dp, 0.55), g(0, 0.41, 0), body, bev=0.015))
    for i in range(3):
        y = 0.22 + i * 0.16
        parts.append(bl.box("tiroir%d" % i, (W - 0.06, 0.012, 0.14), g(0, y, Dp / 2 + 0.003), body, bev=0.008))
        parts.append(bl.box("poignee%d" % i, (0.22, 0.02, 0.018), g(0, y + 0.045, Dp / 2 + 0.014), m["grey"], bev=0.006))
    # Plan de travail
    parts.append(bl.box("plan", (W + 0.1, Dp + 0.1, 0.035), g(0, 0.71, 0.02), m["warm_white"], bev=0.012))
    parts.append(bl.box("chant", (W + 0.1, 0.012, 0.03), g(0, 0.712, Dp / 2 + 0.075), m["grey"], bev=0.004))
    # Bloc respiratoire (tour arrière) et panneau gaz
    tower_z = -0.08
    parts.append(bl.box("tour", (W - 0.04, 0.32, 0.62), g(0, 1.04, tower_z), body, bev=0.02))
    parts.append(bl.box("panneau", (0.3, 0.012, 0.26), g(-0.15, 1.1, tower_z + 0.165), m["dark"], bev=0.004))
    # Débitmètres (tubes verticaux avec billes)
    cols = [(0.2, 0.75, 0.25), (0.25, 0.4, 0.9), (0.9, 0.9, 0.9)]
    for k, c in enumerate(cols):
        x = -0.24 + k * 0.045
        parts.append(bl.cyl("debit%d" % k, 0.011, 0.19, g(x, 1.1, tower_z + 0.175), bl.mat("Verre clair", (0.85, 0.9, 0.95), 0.05, 0.0, 0.7, alpha=0.35), verts=16))
        parts.append(bl.sphere("bille%d" % k, 0.007, g(x, 1.06 + 0.03 * k, tower_z + 0.175), bl.mat("Bille %d" % k, c, 0.3)))
        parts.append(bl.cyl_between("molette_gaz%d" % k, g(x, 0.99, tower_z + 0.17), g(x, 0.99, tower_z + 0.2), 0.011, bl.mat("Molette %d" % k, c, 0.4), verts=16))
    # Évaporateurs (sévoflurane jaune, desflurane bleu)
    for k, c in enumerate([(0.9, 0.75, 0.1), (0.15, 0.35, 0.75)]):
        x = 0.12 + k * 0.13
        parts.append(bl.box("evap%d" % k, (0.11, 0.13, 0.2), g(x, 0.87, tower_z + 0.22), body, bev=0.012))
        parts.append(bl.cyl_between("cadran%d" % k, g(x, 0.94, tower_z + 0.27), g(x, 0.94, tower_z + 0.30), 0.04, bl.mat("Évaporateur %d" % k, c, 0.35), verts=32))
        parts.append(bl.box("fenetre%d" % k, (0.03, 0.006, 0.07), g(x + 0.035, 0.84, tower_z + 0.286), m["glass"], bev=0.003))
    # Soufflet sous cloche transparente (côté gauche)
    bx, bz = -0.2, 0.17
    parts.append(bl.cyl("socle_soufflet", 0.085, 0.03, g(bx, 0.745, bz), m["grey"], verts=32, bev=0.006))
    bel = []
    for k in range(10):
        rr = 0.06 if k % 2 == 0 else 0.066
        bel.append((rr, 0.76 + k * 0.016))
    sb = bl.lathe("soufflet", bel, bl.mat("Soufflet", (0.35, 0.55, 0.75), 0.4), segments=28)
    parts.append(sb)
    for o in [sb]:
        o.location = g(bx, 0.0, bz)
    parts.append(bl.lathe("cloche", [(0.078, 0.76), (0.078, 0.95), (0.07, 0.965), (0.0, 0.97)], bl.mat("Cloche", (0.9, 0.95, 1.0), 0.05, 0.0, 0.8, alpha=0.18), segments=36, loc=g(bx, 0.0, bz)))
    # Absorbeur de CO2 (bidon violet clair)
    parts.append(bl.cyl("absorbeur", 0.055, 0.16, g(0.27, 0.62, Dp / 2 + 0.06), bl.mat("Chaux sodée", (0.85, 0.82, 0.95), 0.3), verts=28, bev=0.01))
    # Mât et écran de l'appareil sur bras
    parts.append(bl.cyl_between("mat", g(0.25, 1.33, tower_z - 0.05), g(0.25, 1.58, tower_z - 0.05), 0.02, m["grey"], verts=20))
    scr_c = g(0.15, 1.62, tower_z + 0.02)
    sc = bl.box("ecran_boitier", (0.42, 0.045, 0.3), scr_c, m["dark"], bev=0.014)
    sc.rotation_euler = (D(-12), 0, 0)
    parts.append(sc)
    face = bl.box("ecran_face", (0.38, 0.005, 0.26), scr_c + Vector((0, -0.024, 0)), m["screen"], bev=0.002)
    face.rotation_euler = (D(-12), 0, 0)
    parts.append(face)
    # Circuit respiratoire annelé (vers le patient : -X local = vers la tête) et ballon
    a = g(-0.32, 0.86, 0.24)
    hose1 = [a, a + Vector((-0.08, 0, 0.0)), a + Vector((-0.25, -0.06, 0.08)), a + Vector((-0.42, -0.15, 0.25)), a + Vector((-0.55, -0.12, 0.35))]
    parts.append(_flex_hose("circuit_insp", bl.bezier_pts(*hose1[:4], 20) + [hose1[4]], 0.011, bl.mat("Circuit bleu", (0.45, 0.65, 0.85), 0.35, 0.0, alpha=0.85)))
    b = g(-0.32, 0.86, 0.17)
    hose2 = bl.bezier_pts(b, b + Vector((-0.15, 0.04, 0.0)), b + Vector((-0.38, -0.05, 0.12)), b + Vector((-0.53, -0.1, 0.33)), 20)
    parts.append(_flex_hose("circuit_exp", hose2, 0.011, bl.mat("Circuit bleu", (0.45, 0.65, 0.85), 0.35, 0.0, alpha=0.85)))
    parts.append(bl.sphere("ballon", 0.06, g(-0.36, 0.78, 0.33), bl.mat("Ballon", (0.08, 0.08, 0.09), 0.6), scale=(1.0, 0.8, 1.5)))
    parts.append(bl.cyl_between("col_ballon", g(-0.33, 0.86, 0.29), g(-0.36, 0.84, 0.31), 0.012, m["grey"], verts=12))
    # Bouteilles de secours à l'arrière
    for k in range(2):
        parts.append(bl.cyl("bouteille%d" % k, 0.05, 0.6, g(-0.15 + k * 0.3, 0.55, -Dp / 2 - 0.06), bl.mat("Bouteille O2", (0.92, 0.92, 0.92), 0.4), verts=24, bev=0.03))
        parts.append(bl.cyl("ogive%d" % k, 0.03, 0.06, g(-0.15 + k * 0.3, 0.88, -Dp / 2 - 0.06), m["chrome"], verts=16))
    return parts


# ---------------------------------------------------------------- Chariots

def _drawer_cabinet(parts, m, w, d, h, x0, z0, n_drawers, color_mat, handle_mat, y0=0.12):
    parts.append(bl.box("caisson", (w, d, h), g(x0, y0 + h / 2, z0), m["white"], bev=0.012))
    gap = 0.008
    dh = (h - gap * (n_drawers + 1)) / n_drawers
    for i in range(n_drawers):
        cy = y0 + gap + dh / 2 + i * (dh + gap)
        parts.append(bl.box("tiroir", (w - 0.03, 0.014, dh), g(x0, cy, z0 + d / 2 + 0.004), color_mat, bev=0.006))
        parts.append(bl.box("poignee", (w * 0.5, 0.016, 0.014), g(x0, cy + dh * 0.32, z0 + d / 2 + 0.016), handle_mat, bev=0.005))
        parts.append(bl.box("etiquette", (0.07, 0.003, 0.022), g(x0 - w * 0.33, cy, z0 + d / 2 + 0.012), m["warm_white"], bev=0.001))


def build_chariot_pharmacie(m):
    """Chariot d'urgence (rouge) : tiroirs, plateau, planche à masser, bouteille d'O2, poubelle."""
    parts = []
    w, d, h = 0.78, 0.5, 0.86
    red = bl.mat("Rouge urgence", (0.62, 0.04, 0.04), 0.35, clearcoat=0.3)
    parts.append(bl.box("socle", (w + 0.03, d + 0.03, 0.06), g(0, 0.09, 0), m["grey"], bev=0.01))
    for x in (-w / 2 + 0.06, w / 2 - 0.06):
        for z in (-d / 2 + 0.06, d / 2 - 0.06):
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["grey"], r=0.035))
    _drawer_cabinet(parts, m, w, d, h, 0, 0, 5, red, m["white"])
    parts.append(bl.box("plateau", (w + 0.08, d + 0.06, 0.04), g(0, 0.12 + h + 0.02, 0), m["grey"], bev=0.012))
    rim = [g(p.x, 0.12 + h + 0.06, -p.y) for p in bl.rounded_rect_path(w + 0.06, d + 0.04, 0.03, 5)]
    parts.append(bl.tube("galerie", rim, 0.008, m["grey"], sides=10, closed=True))
    # Planche à masser sur le côté
    parts.append(bl.box("planche", (0.012, 0.42, 0.6), g(-w / 2 - 0.02, 0.55, 0), bl.mat("Planche", (0.95, 0.75, 0.1), 0.45), bev=0.006))
    # Bouteille d'oxygène (support à l'arrière)
    parts.append(bl.cyl("o2", 0.055, 0.62, g(w / 2 - 0.1, 0.58, -d / 2 - 0.07), bl.mat("Bouteille O2", (0.92, 0.92, 0.92), 0.4), verts=24, bev=0.03))
    parts.append(bl.cyl("o2_epaule", 0.04, 0.05, g(w / 2 - 0.1, 0.915, -d / 2 - 0.07), m["chrome"], verts=16))
    parts.append(bl.box("o2_mano", (0.06, 0.04, 0.06), g(w / 2 - 0.1, 0.96, -d / 2 - 0.07), m["dark"], bev=0.01))
    # Poubelle d'aiguilles jaune
    parts.append(bl.box("collecteur", (0.12, 0.1, 0.16), g(w / 2 + 0.07, 0.86, 0.1), bl.mat("Collecteur", (0.95, 0.8, 0.05), 0.4), bev=0.01))
    parts.append(bl.box("collecteur_cap", (0.13, 0.11, 0.025), g(w / 2 + 0.07, 0.95, 0.1), bl.mat("Rouge urgence", (0.62, 0.04, 0.04), 0.35), bev=0.006))
    # Gants et petit matériel sur le plateau
    parts.append(bl.box("gants", (0.24, 0.12, 0.08), g(-0.22, 1.06, -0.1), bl.mat("Boîte gants", (0.25, 0.45, 0.85), 0.5), bev=0.004))
    parts.append(bl.box("compresses", (0.18, 0.12, 0.05), g(0.05, 1.045, -0.12), bl.mat("Paquet compresses", (0.96, 0.96, 0.96), 0.7), bev=0.008))
    return parts


def build_chariot(m):
    """Chariot de soins inox à deux plateaux, montants tubulaires et poignée."""
    parts = []
    w, d = 1.0, 0.55
    for yy in (0.3, 0.86):
        outer = bl.rounded_rect_path(w, d, 0.03, 5)
        parts.append(bl.extrude_profile("plateau", [(p.x, p.y) for p in outer], 0.008, yy - 0.008, m["steel"], bev=0.002))
        rim = [g(p.x, yy + 0.02, -p.y) for p in outer]
        parts.append(bl.tube("rebord", rim, 0.007, m["steel"], sides=10, closed=True))
    for x in (-w / 2 + 0.02, w / 2 - 0.02):
        for z in (-d / 2 + 0.02, d / 2 - 0.02):
            parts.append(bl.cyl_between("montant", g(x, 0.1, z), g(x, 0.9, z), 0.0125, m["steel"], verts=16))
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["steel"], r=0.04))
    handle = [g(-w / 2 - 0.0, 0.9, -d / 2 + 0.02), g(-w / 2 - 0.08, 0.95, -d / 2 + 0.02), g(-w / 2 - 0.08, 0.95, d / 2 - 0.02), g(-w / 2, 0.9, d / 2 - 0.02)]
    parts.append(bl.tube("poignee", bl.bezier_pts(handle[0], handle[1], handle[2], handle[3], 20), 0.011, m["steel"], sides=12))
    # Contenu : bassines, boîte d'instruments, paquets
    parts.append(bl.lathe("bassine", [(0.0, 0.0), (0.12, 0.0), (0.15, 0.07), (0.155, 0.075)], m["steel"], segments=40, loc=g(0.25, 0.87, 0)))
    parts.append(bl.box("boite", (0.4, 0.22, 0.09), g(-0.18, 0.915, 0.05), m["alu"], bev=0.01))
    parts.append(bl.box("couvercle", (0.41, 0.23, 0.02), g(-0.18, 0.965, 0.05), m["steel"], bev=0.006))
    parts.append(bl.box("paquet", (0.3, 0.25, 0.08), g(0.1, 0.34, 0.05), bl.mat("Emballage bleu", (0.2, 0.42, 0.62), 0.75), bev=0.02))
    parts.append(bl.box("paquet2", (0.25, 0.2, 0.07), g(-0.3, 0.335, -0.05), bl.mat("Emballage vert", (0.25, 0.5, 0.4), 0.75), bev=0.02))
    return parts


def build_chariot_inox(m):
    """Petit chariot inox à tiroir et deux plateaux."""
    parts = []
    w, d = 0.66, 0.4
    for yy in (0.35, 0.9):
        outer = bl.rounded_rect_path(w, d, 0.02, 5)
        parts.append(bl.extrude_profile("plateau", [(p.x, p.y) for p in outer], 0.008, yy - 0.008, m["steel"], bev=0.002))
        rim = [g(p.x, yy + 0.018, -p.y) for p in outer]
        parts.append(bl.tube("rebord", rim, 0.006, m["steel"], sides=10, closed=True))
    parts.append(bl.box("tiroir", (w - 0.04, d - 0.04, 0.1), g(0, 0.83, 0), m["steel"], bev=0.004))
    parts.append(bl.box("tiroir_poignee", (0.12, 0.02, 0.012), g(0, 0.83, d / 2 - 0.01), m["chrome"], bev=0.004))
    for x in (-w / 2 + 0.015, w / 2 - 0.015):
        for z in (-d / 2 + 0.015, d / 2 - 0.015):
            parts.append(bl.cyl_between("montant", g(x, 0.08, z), g(x, 0.92, z), 0.011, m["steel"], verts=16))
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["steel"], r=0.03))
    parts.append(bl.box("flacon", (0.06, 0.06, 0.14), g(0.2, 0.97, 0.08), bl.mat("Flacon Bétadine", (0.4, 0.15, 0.04), 0.3), bev=0.01))
    parts.append(bl.cyl("flacon2", 0.03, 0.16, g(0.1, 0.98, 0.1), bl.mat("Flacon alcool", (0.85, 0.9, 0.95), 0.2), verts=20, bev=0.008))
    parts.append(bl.box("champs_plies", (0.28, 0.22, 0.06), g(-0.12, 0.93, 0), bl.mat("Champ plié", (0.17, 0.42, 0.53), 0.85), bev=0.015))
    return parts


# ---------------------------------------------------------------- Tables arrière drapées (tissu simulé)

def _draped_table(m, w, d, h, items):
    """Table inox recouverte d'un grand champ stérile simulé (Blender cloth), avec du matériel."""
    import bpy
    parts = []
    top = bl.box("dessus", (w, d, 0.03), g(0, h - 0.015, 0), m["steel"], bev=0.006)
    parts.append(top)
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        for z in (-d / 2 + 0.03, d / 2 - 0.03):
            parts.append(bl.cyl_between("pied", g(x, 0.08, z), g(x, h - 0.03, z), 0.014, m["steel"], verts=16))
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["steel"], r=0.03))
    parts.append(bl.box("entretoise", (w - 0.06, d - 0.06, 0.012), g(0, 0.25, 0), m["steel"], bev=0.004))
    # Champ : plan subdivisé au-dessus, collision avec le plateau
    collider = bl.box("_collision", (w + 0.002, d + 0.002, 0.05), g(0, h - 0.025, 0), None)
    col = collider.modifiers.new("Collision", "COLLISION")
    collider.collision.thickness_outer = 0.004
    collider.collision.cloth_friction = 15.0
    cw, cd = w + 0.75, d + 0.75
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=int(cw / 0.02), y_subdivisions=int(cd / 0.02), size=1.0, location=g(0, h + 0.02, 0))
    cloth = bpy.context.view_layer.objects.active
    cloth.name = "champ"
    cloth.scale = (cw, cd, 1)
    bl.bake_transforms(cloth)
    # Petite irrégularité pour que les plis ne soient pas symétriques
    import random
    random.seed(7)
    for v in cloth.data.vertices:
        v.co.z += random.uniform(-0.002, 0.002)
        v.co.x += random.uniform(-0.002, 0.002)
    cm = cloth.modifiers.new("Tissu", "CLOTH")
    cm.settings.quality = 6
    cm.settings.mass = 0.25
    cm.settings.tension_stiffness = 12
    cm.settings.compression_stiffness = 12
    cm.settings.bending_stiffness = 0.3
    cm.settings.air_damping = 1.5
    cm.collision_settings.distance_min = 0.004
    cm.collision_settings.use_self_collision = False
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = 60
    cm.point_cache.frame_start = 1
    cm.point_cache.frame_end = 60
    for f in range(1, 61):
        sc.frame_set(f)
    bl.apply_all(cloth)
    bpy.data.objects.remove(collider)
    sol = cloth.modifiers.new("Epaisseur", "SOLIDIFY")
    sol.thickness = 0.002
    sol.offset = 1.0
    bl.subsurf(cloth, 1)
    bl.set_mat(cloth, bl.mat("Champ stérile", (0.16, 0.40, 0.50), 0.88, 0.0, 0.25))
    bl.smooth(cloth, 80)
    parts.append(cloth)
    for it in items:
        parts.extend(it(m, h + 0.004))
    return parts


def _basin(x, z, r, depth):
    def f(m, y):
        return [bl.lathe("bassine", [(0.0, 0.0), (r * 0.75, 0.0), (r, depth * 0.85), (r * 1.04, depth), (r * 1.06, depth)], m["steel"], segments=40, loc=g(x, y, z))]
    return f


def _kidney(x, z, yaw):
    def f(m, y):
        pts = []
        for i in range(40):
            a = 2 * math.pi * i / 40
            rr = 0.11 * (1 - 0.28 * math.cos(a) ** 8 if False else 1.0)
            px = math.cos(a) * 0.12
            py = math.sin(a) * 0.055 + 0.03 * math.cos(a) ** 2
            pts.append((px, py))
        ob = bl.extrude_profile("haricot", pts, 0.035, 0.0, m["steel"], bev=0.004)
        ob.location = g(x, y, z)
        ob.rotation_euler = (0, 0, yaw)
        return [ob]
    return f


def _pack(x, z, sx, sz, h, color, yaw=0.0):
    def f(m, y):
        ob = bl.box("paquet", (sx, sz, h), g(x, y + h / 2, z), bl.mat("Paquet %s" % str(color), color, 0.8), bev=min(0.02, h * 0.4))
        ob.rotation_euler = (0, 0, yaw)
        return [ob]
    return f


def _gauze(x, z, n=4):
    def f(m, y):
        out = []
        for i in range(n):
            ob = bl.box("compresse", (0.1, 0.1, 0.008), g(x + 0.004 * i, y + 0.004 + i * 0.008, z - 0.003 * i), bl.mat("Compresse", (0.95, 0.95, 0.94), 0.95), bev=0.003)
            ob.rotation_euler = (0, 0, 0.1 * i)
            out.append(ob)
        return out
    return f


def _tray_instruments(x, z):
    """Boîte d'instruments ouverte : bac perforé, pinces alignées (silhouettes simples)."""
    def f(m, y):
        out = [bl.box("bac", (0.42, 0.24, 0.05), g(x, y + 0.025, z), m["alu"], bev=0.006)]
        for i in range(7):
            xx = x - 0.16 + i * 0.05
            out.append(bl.box("instr", (0.008, 0.16, 0.006), g(xx, y + 0.053, z), m["chrome"], bev=0.002))
            for s in (-1, 1):
                out.append(bl.torus("anneau", 0.009, 0.0022, g(xx + s * 0.009, y + 0.053, z + 0.09), m["chrome"], rot=(0, 0, 0), major=14, minor=5))
        return out
    return f


def build_table_sterile_1(m):
    return _draped_table(m, 0.55, 0.85, 0.92, [_basin(0.0, 0.18, 0.11, 0.06), _gauze(0.05, -0.15), _kidney(-0.05, -0.32, 0.4)])


def build_table_sterile_2(m):
    return _draped_table(m, 0.68, 1.18, 0.92, [_tray_instruments(0.0, -0.28), _basin(0.15, 0.3, 0.09, 0.05), _basin(-0.14, 0.33, 0.06, 0.04),
                                               _gauze(-0.18, 0.05), _pack(0.15, 0.03, 0.18, 0.12, 0.04, (0.2, 0.42, 0.62), 0.2)])


def build_table_sterile_3(m):
    return _draped_table(m, 0.78, 0.86, 0.92, [_tray_instruments(0.0, 0.15), _kidney(0.2, -0.2, -0.3), _gauze(-0.2, -0.2, 6)])


# ---------------------------------------------------------------- Lavabo chirurgical, écran plombé

def build_lavabo(m):
    """Auge de lavage chirurgical inox deux postes, robinets à cellule, distributeurs de savon."""
    parts = []
    w, d = 1.5, 0.6
    # Cuve : profil extrudé en creux (approximation : caisson + cuvette)
    parts.append(bl.box("habillage", (w, d, 0.45), g(0, 0.62, -0.02), m["steel"], bev=0.01))
    parts.append(bl.box("tablier", (w - 0.02, 0.02, 0.55), g(0, 0.3, d / 2 - 0.03), m["steel"], bev=0.006))
    basin = bl.lathe("cuve", [(0.0, 0.0), (0.18, 0.0), (0.26, 0.12), (0.3, 0.22)], m["steel"], segments=48)
    basin.scale = (2.2, 0.85, 1.0)
    basin.location = g(0, 0.68, 0.0)
    parts.append(basin)
    parts.append(bl.box("dosseret", (w, 0.04, 0.5), g(0, 1.08, -d / 2 + 0.02), m["steel"], bev=0.008))
    for x in (-0.38, 0.38):
        # Col de cygne
        base = g(x, 0.95, -d / 2 + 0.06)
        neck = bl.bezier_pts(base, base + Vector((0, 0, 0.32)), base + Vector((0, 0.22, 0.32)), base + Vector((0, 0.2, 0.16)), 22)
        parts.append(bl.tube("col", neck, 0.012, m["chrome"], sides=14))
        parts.append(bl.cyl("cellule", 0.022, 0.03, g(x, 1.18, -d / 2 + 0.05), m["dark"], rot=(D(90), 0, 0), verts=20))
        # Distributeur de savon
        parts.append(bl.box("distributeur", (0.1, 0.09, 0.22), g(x + 0.2, 1.42, -d / 2 + 0.07), m["white"], bev=0.012))
        parts.append(bl.box("levier", (0.06, 0.12, 0.012), g(x + 0.2, 1.3, -d / 2 + 0.11), m["steel"], bev=0.004))
    return parts


def build_paravent(m):
    """Écran plombé mobile (radioprotection) : panneau à hublot sur roulettes."""
    parts = []
    w, h = 0.75, 1.6
    parts.append(bl.box("panneau", (w, 0.05, h - 0.2), g(0, 0.2 + (h - 0.2) / 2, 0), bl.mat("Panneau plombé", (0.55, 0.62, 0.66), 0.5), bev=0.015))
    parts.append(bl.box("cadre_hublot", (0.5, 0.06, 0.4), g(0, 1.35, 0), m["grey"], bev=0.01))
    parts.append(bl.box("hublot", (0.44, 0.065, 0.34), g(0, 1.35, 0), bl.mat("Verre plombé", (0.55, 0.58, 0.45), 0.04, 0.0, 0.7, alpha=0.45), bev=0.004))
    parts.append(bl.box("base", (w + 0.1, 0.45, 0.05), g(0, 0.1, 0), m["grey"], bev=0.012))
    for x in (-w / 2, w / 2):
        for z in (-0.18, 0.18):
            parts.append(bl.caster("roue", (x, -z, 0.0), m["black_rubber"], m["grey"], r=0.035))
    parts.append(bl.cyl_between("poignee", g(-w / 2 - 0.03, 0.9, 0.05), g(-w / 2 - 0.03, 1.2, 0.05), 0.012, m["chrome"], verts=14))
    return parts


BUILDERS = {
    "scialytique": (build_scialytique, ((2.4, -2.6, 1.6), (0.15, 0.0, 2.3))),
    "table_operation": (build_table_operation, ((1.6, -2.2, 1.6), (-0.3, 0.0, 0.5))),
    "table_mayo": (build_table_mayo, ((1.0, -1.3, 1.4), (0.0, 0.0, 0.6))),
    "perfusion": (build_perfusion, ((1.2, -1.8, 1.4), (0.0, 0.0, 0.9))),
    "tabouret": (build_tabouret, ((0.8, -1.0, 0.9), (0.0, 0.0, 0.35))),
    "anesthesie": (build_anesthesie, ((1.4, -1.8, 1.6), (0.0, 0.0, 0.9))),
    "chariot_pharmacie": (build_chariot_pharmacie, ((1.3, -1.8, 1.5), (0.0, 0.0, 0.6))),
    "chariot": (build_chariot, ((1.4, -1.8, 1.5), (0.0, 0.0, 0.6))),
    "chariot_inox": (build_chariot_inox, ((1.0, -1.5, 1.4), (0.0, 0.0, 0.6))),
    "table_sterile_1": (build_table_sterile_1, ((1.3, -1.6, 1.7), (0.0, 0.0, 0.7))),
    "table_sterile_2": (build_table_sterile_2, ((1.5, -1.8, 1.8), (0.0, 0.0, 0.7))),
    "table_sterile_3": (build_table_sterile_3, ((1.4, -1.6, 1.7), (0.0, 0.0, 0.7))),
    "lavabo": (build_lavabo, ((1.4, -2.0, 1.6), (0.0, 0.0, 0.9))),
    "paravent": (build_paravent, ((1.4, -2.0, 1.5), (0.0, 0.0, 0.9))),
}


def main():
    args = [a for a in sys.argv[1:]]
    do_prev = "--preview" in args
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS.keys())
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        fn, cam = BUILDERS[name]
        bl.reset()
        bl._MATS.clear()
        m = M()
        parts = fn(m)
        obj = bl.merge_by_material(name)
        bl.export(name, [obj])
        if do_prev:
            bl.preview(os.path.join(PREVIEW_DIR, name + ".png"), cam[0], cam[1])


if __name__ == "__main__":
    main()
