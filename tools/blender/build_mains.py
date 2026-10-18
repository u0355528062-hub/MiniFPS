"""Mains gantées du soignant (gants nitrile) aux vraies proportions, à partir de la main du maillage
MakeHuman (CC0) et de son squelette « game_engine » : doigts posés pour chaque geste, avant-bras nu
(peau texturée dans le jeu) et bas de la manche courte de la tunique.

    /home/user/bpyenv/bin/python tools/blender/build_mains.py [--preview] [nom ...]

Écrit assets/models/<nom>.glb ; « medecin » : le corps de l'urgentiste (tunique, pantalon, sabots)
vu en baissant la tête. Repère de chaque modèle (jeu, Y vers le haut) : origine au point de
contact du geste (pulpe de l'index et du majeur, paume, talon de la main, pince pouce-index), dos de
la main vers +Y, doigts vers -Z, avant-bras vers +Z (vers le soignant).
Surfaces : « Gant », « Peau medecin » (texture de peau du jeu), « Tunique ».
"""
import math
import os
import sys

import bpy
import bmesh  # noqa: E402 (après bpy)
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
import mh  # noqa: E402

PREVIEW_DIR = os.environ.get("APERCU", "/tmp/apercus")
FINGERS = ("index", "middle", "ring", "pinky")
CUFF = 0.065  # haut du gant au-dessus du pli du poignet (m)
SLEEVE = 0.45  # longueur du bras gardée au-dessus du coude (m) : tout le bras, il sort de l'écran
HEM = 0.07  # bas de la manche courte au-dessus du coude (m)


def materials():
    return {
        "glove": bl.mat("Gant", (0.24, 0.27, 0.78), 0.38, 0.0, 0.5),
        "skin": bl.mat("Peau medecin", (0.75, 0.55, 0.45), 0.5),
        "scrub": bl.mat("Tunique", (0.1, 0.36, 0.44), 0.85),
    }


def doctor_base():
    """Urgentiste : homme adulte de corpulence moyenne."""
    b = mh.Base()
    b.apply_target("macrodetails/caucasian-male-young", 1.0)
    b.apply_target("macrodetails/universal-male-young-averagemuscle-averageweight", 1.0)
    b.v[:, 1] -= b.v[list(b.groups["body"]), 1].min()
    return b


def bone_set(side, arm=True):
    names = ["hand_" + side] + ["%s_%02d_%s" % (f, k, side) for f in FINGERS + ("thumb",) for k in (1, 2, 3)]
    if arm:
        names += ["lowerarm_" + side, "upperarm_" + side]
    return names


def pose_hand(arm, side, curls, thumb, spread=0.0, wrist=(0.0, 0.0), pal=None):
    """curls : {doigt: (p1, p2, p3)} en degrés ; thumb : (rx, rz) de la base puis flexion (p2, p3) ;
    spread : écartement des doigts (degrés) ; wrist : (extension, inclinaison) du poignet en degrés
    (extension > 0 : dos de la main vers l'avant-bras ; il faut alors pal, direction de la paume)."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    hb = arm.pose.bones["hand_" + side]
    hb.rotation_euler = (0.0, 0.0, 0.0)
    sgn = 1.0 if side == "l" else -1.0
    for i, f in enumerate(FINGERS):
        a = curls.get(f, (0, 0, 0))
        for k in range(3):
            pb = arm.pose.bones["%s_%02d_%s" % (f, k + 1, side)]
            z = math.radians(spread * (i - 1.2) * 0.5 * sgn) if k == 0 else 0.0
            pb.rotation_euler = (math.radians(a[k]), 0.0, z)
    t = arm.pose.bones["thumb_01_" + side]
    t.rotation_euler = (math.radians(thumb[0]), 0.0, math.radians(thumb[1] * sgn))
    arm.pose.bones["thumb_02_" + side].rotation_euler = (math.radians(thumb[2]), 0.0, 0.0)
    arm.pose.bones["thumb_03_" + side].rotation_euler = (math.radians(thumb[3]), 0.0, 0.0)
    bpy.context.view_layer.update()
    if pal is not None and (wrist[0] or wrist[1]):
        # Le poignet plie autour de l'axe index-auriculaire (les axes locaux de l'os sont tournés)
        h = hb.head.copy()
        f = (arm.pose.bones["middle_01_" + side].head - h).normalized()
        p = (pal - f * pal.dot(f)).normalized()
        ext = Matrix.Rotation(math.radians(wrist[0]), 4, f.cross(-p).normalized())
        dev = Matrix.Rotation(math.radians(wrist[1]), 4, p)
        hb.matrix = Matrix.Translation(h) @ dev @ ext @ Matrix.Translation(-h) @ hb.matrix
        bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def joints(arm, side):
    j = {}
    for n in ["hand", "lowerarm", "upperarm"] + ["%s_%02d" % (f, k) for f in FINGERS + ("thumb",) for k in (1, 2, 3)]:
        pb = arm.pose.bones["%s_%s" % (n, side)]
        j[n] = (arm.matrix_world @ pb.head, arm.matrix_world @ pb.tail)
    return j


def palmar(arm, side):
    """Direction de la paume (côté vers lequel les doigts se plient), mesurée en pliant un peu l'annulaire à sa base
    (le bout du doigt part perpendiculairement au doigt, vers la paume)."""
    pose_hand(arm, side, {}, (0, 0, 0, 0))
    a = joints(arm, side)["ring_03"][1].copy()
    pose_hand(arm, side, {"ring": (10, 0, 0)}, (0, 0, 0, 0))
    b = joints(arm, side)["ring_03"][1].copy()
    pose_hand(arm, side, {}, (0, 0, 0, 0))
    return (b - a).normalized()


def extract(base, side, pose, contact, m, name):
    """Main posée -> objet dans le repère du geste. contact(j, f, lat, pal) -> point de contact."""
    body = mh.build_mesh(base, {"body"}, name)
    arm = mh.build_armature(base)
    mh.skin(body, arm)
    pal0 = palmar(arm, side)
    # La direction de la paume suit l'os de la main
    hb = arm.pose.bones["hand_" + side]
    pal_local = hb.matrix.to_3x3().inverted() @ pal0
    pose_hand(arm, side, *pose, pal=pal0)
    pal0 = (arm.matrix_world.to_3x3() @ hb.matrix.to_3x3() @ pal_local).normalized()
    j = joints(arm, side)
    mh.bake_pose([body])
    bpy.data.objects.remove(arm)
    wrist = j["hand"][0]
    f = (j["middle_01"][0] - wrist).normalized()
    lat = j["index_01"][0] - j["pinky_01"][0]
    lat = (lat - f * lat.dot(f)).normalized()
    pal = f.cross(lat)
    if pal.dot(pal0 - f * pal0.dot(f)) < 0:
        pal = -pal
    c = contact(j, f, lat, pal)
    # Sommets gardés : main, avant-bras, bras jusqu'à l'épaule (manche courte de la tunique)
    names = set(bone_set(side))
    groups = {g.index: g.name for g in body.vertex_groups}
    elbow = j["lowerarm"][0]
    up_dir = (j["upperarm"][0] - elbow).normalized()
    keep = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if groups[g.group] in names)
        if w > 0.5 and (v.co - elbow).dot(up_dir) < SLEEVE:
            keep.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    # Bord coupé du bras : bouché
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.normal_update()
    # Gant légèrement plus épais que la peau, revers roulé au bord ; manche plus large que le bras
    fore = (elbow - wrist).normalized()
    for v in bm.verts:
        d = (v.co - wrist).dot(fore)
        if d < CUFF:
            v.co += v.normal * (0.0006 + 0.0011 * math.exp(-((d - CUFF + 0.003) / 0.004) ** 2))
        elif (v.co - elbow).dot(up_dir) > HEM - 0.015:
            k = min(1.0, ((v.co - elbow).dot(up_dir) - HEM + 0.015) / 0.02)
            v.co += v.normal * 0.009 * k
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    body.data = me
    me.materials.clear()
    for k in ("glove", "skin", "scrub"):
        me.materials.append(m[k])
    for p in me.polygons:
        cc = p.center
        if (cc - wrist).dot(fore) < CUFF:
            p.material_index = 0
        elif (cc - elbow).dot(up_dir) > HEM - 0.008:
            p.material_index = 2
        else:
            p.material_index = 1
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    # Repère du geste : dos de la main vers +Y (jeu), doigts vers -Z
    y = -pal
    z = -f
    x = y.cross(z).normalized()
    z = x.cross(y).normalized()
    # Jeu (x, y, z) = Blender (x, -z, y) : les axes du jeu en coordonnées Blender
    gx, gy, gz = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
    R = Matrix((x, y, z)).transposed()  # colonnes = axes de la main
    G = Matrix((gx, gy, gz)).transposed()
    M = (G @ R.inverted()).to_4x4() @ Matrix.Translation(-c)
    body.data.transform(M)
    bl.smooth(body, 70)
    return body


def pulp(j, f, lat, pal, fingers=("index", "middle")):
    tips = [j[n + "_03"][1] for n in fingers]
    return sum(tips, Vector()) / len(tips) - f * 0.007 + pal * 0.006


POSES = {
    # Pouls, palpation fine : index et majeur tendus (pulpe sur la peau), annulaire et auriculaire repliés
    "main_pouls": ("r", ({"index": (22, 12, 6), "middle": (24, 12, 6), "ring": (65, 85, 45), "pinky": (70, 85, 45)}, (-30, 0, 15, 10), 4.0, (8.0, 0.0)),
                   lambda j, f, lat, pal: pulp(j, f, lat, pal)),
    # Main à plat (stimulation, palpation de l'abdomen) : paume sur la peau
    "main_plate": ("r", ({"index": (8, 6, 4), "middle": (8, 6, 4), "ring": (10, 8, 4), "pinky": (12, 8, 4)}, (-30, 0, 8, 5), 3.0, (6.0, 0.0)),
                   lambda j, f, lat, pal: (j["hand"][0] + j["middle_01"][0]) * 0.5 + pal * 0.014),
    # Pince pouce-index (lampe, thermomètre, glucomètre) : objet tenu au point de pince
    "main_pince": ("r", ({"index": (35, 40, 20), "middle": (45, 50, 25), "ring": (60, 65, 35), "pinky": (65, 70, 40)}, (30, 40, 25, 20), 0.0, (10.0, 0.0)),
                   lambda j, f, lat, pal: (j["thumb_03"][1] + j["index_03"][1]) * 0.5 + pal * 0.004),
}


def build_rcp(base, m):
    """Massage cardiaque : talon de la main droite sur le sternum (origine), doigts relevés ; main
    gauche par-dessus, doigts crochetés entre ceux de la main du bas. Poignets en extension : les
    avant-bras montent vers le soignant."""
    heel = lambda j, f, lat, pal: j["hand"][0] + f * 0.022 + pal * 0.016  # noqa: E731
    bottom = extract(base, "r", ({"index": (-12, 4, 2), "middle": (-12, 4, 2), "ring": (-10, 4, 2), "pinky": (-8, 4, 2)}, (5, 20, 10, 5), 6.0, (70.0, 0.0)), heel, m, "main_bas")
    top = extract(base, "l", ({"index": (55, 45, 25), "middle": (55, 45, 25), "ring": (55, 45, 25), "pinky": (55, 45, 25)}, (10, 20, 15, 10), 6.0, (66.0, 0.0)), heel, m, "main_haut")
    # La main du haut repose sur le dos de celle du bas, légèrement tournée
    top.data.transform(Matrix.Translation(bl.g(0.0, 0.028, 0.004)) @ Matrix.Rotation(math.radians(-8), 4, "Z"))
    return [bl.join([bottom, top], "mains_rcp")]


EYE = 1.66  # hauteur des yeux du joueur (scripts/player.gd)


def build_medecin(base, m):
    """Corps de l'urgentiste vu à la première personne (sans tête ni cou : la caméra est à la place
    des yeux) : tunique et pantalon de pyjama de bloc, sabots, avant-bras nus, mains (gantées ou non
    dans le jeu). Deux nœuds : « Buste » (pivot aux hanches, se penche avec le joueur) et « Jambes ».
    Repère du joueur : pieds en (0, 0, 0), yeux à la verticale de l'origine, regard vers -Z."""
    m = dict(m)
    m["pants"] = bl.mat("Pantalon", (0.08, 0.3, 0.37), 0.9)
    m["shoes"] = bl.mat("Chaussures", (0.86, 0.87, 0.88), 0.45)
    m["hand"] = bl.mat("Main", (0.75, 0.55, 0.45), 0.5)
    eye = (base.joint("joint-l-eye") + base.joint("joint-r-eye")) * 0.5
    body = mh.build_mesh(base, {"body"}, "Medecin")
    arm = mh.build_armature(base)
    mh.skin(body, arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    # Bras détendus, avant-bras un peu en avant : les mains se voient devant le ventre
    for s, sx in (("l", 1), ("r", -1)):
        mh.aim(arm, "upperarm_" + s, Vector((0.16 * sx, -0.12, -1)))
        mh.aim(arm, "lowerarm_" + s, Vector((-0.12 * sx, -0.75, -0.75)))
        mh.aim(arm, "hand_" + s, Vector((-0.2 * sx, -0.7, -0.75)))
        mh.curl(arm, s, {"index": (18, 22, 10), "middle": (22, 26, 12), "ring": (26, 28, 12), "pinky": (30, 30, 14)}, (10, 15, 10))
    bpy.ops.object.mode_set(mode="OBJECT")
    hip = (mh.bone_head(arm, "thigh_l") + mh.bone_head(arm, "thigh_r")) * 0.5
    sh = {s: mh.bone_head(arm, "upperarm_" + s).copy() for s in "lr"}
    el = {s: mh.bone_head(arm, "lowerarm_" + s).copy() for s in "lr"}
    mh.bake_pose([body])
    bpy.data.objects.remove(arm)
    groups = {g.index: g.name for g in body.vertex_groups}

    def w(v, keys):
        return sum(g.weight for g in v.groups if any(k in groups[g.group] for k in keys))

    head_ids = {v.index for v in body.data.vertices if w(v, ("head", "neck")) > 0.35}
    hand_ids = {v.index for v in body.data.vertices if w(v, ("hand", "index", "middle", "ring", "pinky", "thumb")) > 0.5}
    fore_ids = {v.index for v in body.data.vertices if w(v, ("lowerarm",)) > 0.5}
    # Haut du bras : manche courte jusqu'à 60 % de l'épaule au coude
    sleeve_ids = set()
    for v in body.data.vertices:
        if w(v, ("upperarm",)) > 0.4:
            s = "l" if v.co.x > 0 else "r"
            a = el[s] - sh[s]
            if (v.co - sh[s]).dot(a) / a.length_squared < 0.6:
                sleeve_ids.add(v.index)
    hem = hip.z - 0.12  # bas de la tunique
    ankle = 0.1
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in head_ids], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    kind = {}
    # Les indices ont changé après la suppression de la tête : on retrouve les sommets par position
    pos_kind = {}
    for v in body.data.vertices:
        key = (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
        if v.index in hand_ids:
            pos_kind[key] = "hand"
        elif v.index in fore_ids or (w(v, ("upperarm",)) > 0.4 and v.index not in sleeve_ids):
            pos_kind[key] = "skin"
        elif v.index in sleeve_ids:
            pos_kind[key] = "sleeve"
    for v in bm.verts:
        key = (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
        k = pos_kind.get(key)
        if k is None:
            if v.co.z < ankle:
                k = "shoes"
            elif v.co.z < hem:
                k = "pants"
            else:
                k = "tunic"
        kind[v.index] = k
    # Vêtements amples : décalage le long des normales (bas de tunique évasé, jambes de pantalon larges)
    for v in bm.verts:
        k = kind[v.index]
        n = v.normal
        if k == "tunic":
            v.co += n * (0.01 + 0.012 * max(0.0, min(1.0, (hem + 0.15 - v.co.z) / 0.15)))
        elif k == "sleeve":
            v.co += n * 0.012
        elif k == "pants":
            v.co += n * (0.012 + 0.014 * max(0.0, min(1.0, (0.6 - v.co.z) / 0.5)))
        elif k == "shoes":
            v.co += n * 0.01
            v.co.z = max(v.co.z, 0.0)
    for v in bm.verts:
        if kind[v.index] == "shoes" and v.co.z < 0.012:
            v.co.z = 0.0
    me = bpy.data.meshes.new("Medecin")
    bm.to_mesh(me)
    bm.free()
    body.data = me
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    order = ["tunic", "pants", "shoes", "skin", "hand"]
    mats = {"tunic": m["scrub"], "pants": m["pants"], "shoes": m["shoes"], "skin": m["skin"], "hand": m["hand"]}
    for k in order:
        me.materials.append(mats[k])
    for p in me.polygons:
        ks = [kind[i] for i in p.vertices]
        ks = ["tunic" if k == "sleeve" else k for k in ks]
        # Une face prend la matière majoritaire de ses sommets
        k = max(set(ks), key=ks.count)
        p.material_index = order.index(k)
    # Repère du joueur : yeux à la verticale de l'origine, à la hauteur EYE, regard vers -Z (jeu)
    eye_bl = mh.to_bl(eye)
    sc = EYE / eye_bl.z
    # MakeHuman regarde vers -Y (Blender) = +Z du jeu : demi-tour
    M = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(sc, 4) @ Matrix.Translation(Vector((-eye_bl.x, -eye_bl.y, 0.0)))
    body.data.transform(M)
    hip_g = M @ hip
    bl.smooth(body, 70)
    # Buste et jambes séparés au bas de la tunique
    bm = bmesh.new()
    bm.from_mesh(body.data)
    legs_faces = [f for f in bm.faces if f.calc_center_median().z < hip_g.z - 0.02]
    out = []
    for name, keep_legs in (("Jambes", True), ("Buste", False)):
        b2 = bm.copy()
        b2.faces.ensure_lookup_table()
        drop = [f for f in b2.faces if (f.calc_center_median().z < hip_g.z - 0.02) != keep_legs]
        bmesh.ops.delete(b2, geom=drop, context="FACES")
        me2 = bpy.data.meshes.new(name)
        b2.to_mesh(me2)
        b2.free()
        for mt in me.materials:
            me2.materials.append(mt)
        ob = bpy.data.objects.new(name, me2)
        bpy.context.scene.collection.objects.link(ob)
        for p in me2.polygons:
            p.use_smooth = True
        out.append(ob)
    bm.free()
    bpy.data.objects.remove(body)
    # Pivot du buste aux hanches (le joueur se penche en avant)
    buste = out[1]
    buste.data.transform(Matrix.Translation(-hip_g))
    buste.location = hip_g
    print("hanches", tuple(round(c, 3) for c in hip_g), "échelle", round(sc, 3))
    return out


def main():
    args = sys.argv[1:]
    names = [a for a in args if not a.startswith("--")] or list(POSES) + ["mains_rcp", "medecin"]
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        bl.reset()
        bl._MATS.clear()
        m = materials()
        base = doctor_base()
        if name == "mains_rcp":
            objs = build_rcp(base, m)
        elif name == "medecin":
            objs = build_medecin(base, m)
        else:
            side, pose, contact = POSES[name]
            objs = [extract(base, side, pose, contact, m, name)]
        bl.export(name, objs)
        if "--preview" in args:
            bl.preview(os.path.join(PREVIEW_DIR, name + ".png"), bl.g(0.25, 0.22, 0.3), bl.g(0.0, 0.02, 0.05), size=(640, 480), samples=12, lens=45, floor=False)


if __name__ == "__main__":
    main()
