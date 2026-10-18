"""Mains gantées du soignant (gants nitrile) aux vraies proportions, à partir de la main du maillage
MakeHuman (CC0) et de son squelette « game_engine » : doigts posés pour chaque geste, avant-bras nu
(peau texturée dans le jeu) et bas de la manche courte de la tunique.

    /home/user/bpyenv/bin/python tools/blender/build_mains.py [--preview] [nom ...]

Écrit assets/models/<nom>.glb. Repère de chaque modèle (jeu, Y vers le haut) : origine au point de
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
SLEEVE = 0.11  # longueur du bras gardée au-dessus du coude (m)


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


def pose_hand(arm, side, curls, thumb, spread=0.0, wrist=(0.0, 0.0)):
    """curls : {doigt: (p1, p2, p3)} en degrés ; thumb : (rx, rz) de la base puis flexion (p2, p3) ;
    spread : écartement des doigts (degrés) ; wrist : (flexion, inclinaison) du poignet."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    hb = arm.pose.bones["hand_" + side]
    hb.rotation_euler = (math.radians(wrist[0]), 0.0, math.radians(wrist[1]))
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
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def joints(arm, side):
    j = {}
    for n in ["hand", "lowerarm", "upperarm"] + ["%s_%02d" % (f, k) for f in FINGERS + ("thumb",) for k in (1, 2, 3)]:
        pb = arm.pose.bones["%s_%s" % (n, side)]
        j[n] = (arm.matrix_world @ pb.head, arm.matrix_world @ pb.tail)
    return j


def palmar(arm, side):
    """Direction de la paume (côté vers lequel les doigts se plient), mesurée en pliant l'annulaire à sa base."""
    pose_hand(arm, side, {}, (0, 0, 0, 0))
    a = joints(arm, side)["ring_03"][1].copy()
    pose_hand(arm, side, {"ring": (90, 0, 0)}, (0, 0, 0, 0))
    b = joints(arm, side)["ring_03"][1].copy()
    pose_hand(arm, side, {}, (0, 0, 0, 0))
    return (b - a).normalized()


def extract(base, side, pose, contact, m, name):
    """Main posée -> objet dans le repère du geste. contact(j, f, lat, pal) -> point de contact."""
    body = mh.build_mesh(base, {"body"}, name)
    arm = mh.build_armature(base)
    mh.skin(body, arm)
    pal0 = palmar(arm, side)
    pose_hand(arm, side, *pose)
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
    # Sommets gardés : main, avant-bras, bas du bras jusqu'à SLEEVE au-dessus du coude
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
        elif (v.co - elbow).dot(up_dir) > -0.015:
            k = min(1.0, ((v.co - elbow).dot(up_dir) + 0.015) / 0.02)
            v.co += v.normal * 0.007 * k
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
        elif (cc - elbow).dot(up_dir) > -0.008:
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


def main():
    args = sys.argv[1:]
    names = [a for a in args if not a.startswith("--")] or list(POSES) + ["mains_rcp"]
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        bl.reset()
        bl._MATS.clear()
        m = materials()
        base = doctor_base()
        if name == "mains_rcp":
            objs = build_rcp(base, m)
        else:
            side, pose, contact = POSES[name]
            objs = [extract(base, side, pose, contact, m, name)]
        bl.export(name, objs)
        if "--preview" in args:
            bl.preview(os.path.join(PREVIEW_DIR, name + ".png"), bl.g(0.25, 0.22, 0.3), bl.g(0.0, 0.02, 0.05), size=(640, 480), samples=12, lens=45, floor=False)


if __name__ == "__main__":
    main()
