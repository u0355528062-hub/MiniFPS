"""Patient des urgences (homme d'une cinquantaine d'années) à partir du maillage MakeHuman (CC0) :
morphologie, pose (couché sur le dos, bras le long du corps posés sur le drap, mains à plat),
yeux, alignement sur l'anatomie de l'atlas Z-Anatomy (côtes, sternum, cœur du jeu), drap simulé
sur les jambes, cartes de hauteur (peau, drap) et repères (bras, cou, visage).

    /home/user/bpyenv/bin/python tools/blender/build_patient.py
Écrit assets/models/patient_urg.glb, assets/models/drap_dos.glb, assets/data/peau_dos_hauteur.bin,
assets/data/drap_dos_hauteur.bin et met à jour assets/data/patient_dos.json.
"""
import json
import math
import os
import struct
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
import mh  # noqa: E402

DATA = os.path.join(bl.ROOT, "assets", "data")
TABLE = 0.80
OLD_SHOULDER_X = 0.121  # repère de l'atlas (clavicule, extrémité latérale)


def game(v):
    """Point Blender -> jeu."""
    return (v.x, v.z, -v.y)


def build_body():
    b = mh.Base()
    b.apply_target("macrodetails/caucasian-male-young", 0.55)
    b.apply_target("macrodetails/caucasian-male-old", 0.45)
    b.apply_target("macrodetails/universal-male-old-averagemuscle-maxweight", 0.3)
    b.v[:, 1] -= b.v[list(b.groups["body"]), 1].min()
    skin = bl.mat("Peau", (0.75, 0.55, 0.45), 0.5)
    body = mh.build_mesh(b, {"body"}, "Peau", skin)
    arm = mh.build_armature(b)
    mh.skin(body, arm)
    eyes = mh.fit_proxy(b, mh.MHDATA + "/eyes/high-poly/high-poly.mhclo", "Yeux", bl.mat("Oeil", (0.9, 0.9, 0.9), 0.1))
    mh.rigid_to_bone(eyes, arm, "head")
    # Pose couchée : bras le long du corps, un peu écartés, paumes contre le matelas (vers l'arrière),
    # doigts détendus ; pieds en légère flexion plantaire
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    # Tête posée en arrière sur l'oreiller (cou en légère extension)
    mh.aim(arm, "neck_01", Vector((0, 0.22, 1)))
    mh.aim(arm, "head", Vector((0, 0.28, 1)))
    for s, sx in (("l", 1), ("r", -1)):
        mh.aim(arm, "upperarm_" + s, Vector((0.22 * sx, 0.1, -1)))
        mh.aim(arm, "lowerarm_" + s, Vector((0.14 * sx, 0.1, -1)))
        mh.aim(arm, "hand_" + s, Vector((0.08 * sx, 0.12, -1)))
        mh.twist(arm, "hand_" + s, 0.0)
        mh.curl(arm, s, {"index": (8, 10, 6), "middle": (10, 12, 8), "ring": (12, 14, 8), "pinky": (14, 15, 10)}, (4, 8, 4))
        mh.aim(arm, "thigh_" + s, Vector((0.025 * sx, 0.0, -1)))
        mh.aim(arm, "calf_" + s, Vector((0.01 * sx, 0.03, -1)))
        mh.aim(arm, "foot_" + s, Vector((0.12 * sx, -1.0, -0.9)))
    bpy.ops.object.mode_set(mode="OBJECT")
    joints = {}
    for bn in ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "head", "neck_01", "spine_03", "pelvis"]:
        joints[bn] = (mh.bone_head(arm, bn).copy(), mh.bone_tail(arm, bn).copy())
    for s in "lr":
        joints["tip_" + s] = (mh.bone_tail(arm, "middle_03_" + s).copy(), None)
    mh.bake_pose([body, eyes])
    bpy.data.objects.remove(arm)
    mh.remove_loose(body)
    return body, eyes, joints


def lay_down(objs, joints):
    """Debout -> couché sur le dos, tête vers +X (jeu), face vers le haut, gauche vers +Z."""
    M = Matrix(((0, 0, 1, 0), (-1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
    for ob in objs:
        ob.data.transform(M)
    for k in joints:
        h, t = joints[k]
        joints[k] = (M @ h, (M @ t) if t is not None else None)
    # Couché bien à plat : le dos et les talons touchent le même plan
    vs = objs[0].data.vertices
    xmax = max(v.co.x for v in vs)
    back = min((v.co for v in vs if xmax - 0.75 < v.co.x < xmax - 0.3 and abs(v.co.y) < 0.12), key=lambda c: c.z)
    heel = min((v.co for v in vs if v.co.x < min(w.co.x for w in vs) + 0.12), key=lambda c: c.z)
    th = math.atan((heel.z - back.z) / (heel.x - back.x))
    R = Matrix.Translation(back) @ Matrix.Rotation(th, 4, "Y") @ Matrix.Translation(-back)
    for ob in objs:
        ob.data.transform(R)
    for k in joints:
        h, t = joints[k]
        joints[k] = (R @ h, (R @ t) if t is not None else None)
    print("redressé de %.1f°" % math.degrees(th))
    # Échelle et position : épaules sur celles de l'atlas, dos posé sur le matelas
    sh = (joints["upperarm_l"][0] + joints["upperarm_r"][0]) * 0.5
    # Le dos (tronc, près de l'axe) repose sur le matelas
    zmin = min(v.co.z for v in objs[0].data.vertices if abs(v.co.y) < 0.12 and v.co.x > -0.9)
    T = Matrix.Translation(Vector((OLD_SHOULDER_X + 0.02 - sh.x, -sh.y, TABLE - zmin - 0.006)))
    for ob in objs:
        ob.data.transform(T)
    for k in joints:
        h, t = joints[k]
        joints[k] = (T @ h, (T @ t) if t is not None else None)


def tree(objs):
    verts = []
    polys = []
    for o in objs:
        off = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[off + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def top_hit(t, x, z, y0=3.0):
    loc, n, i, d = t.ray_cast(Vector((x, -z, y0)), Vector((0, 0, -1)))
    return loc.z if loc is not None else -1.0


def height_map(objs, path, like):
    """Carte de hauteur (même grille que la précédente) : dessus de l'objet en chaque point, -1 hors."""
    hdr = open(like, "rb").read(24)
    nx, nz = struct.unpack("ii", hdr[:8])
    x0, z0, step = struct.unpack("fff", hdr[8:20])
    t = tree(objs)
    out = np.full((nz, nx), -1.0, np.float32)
    for j in range(nz):
        z = z0 + j * step
        for i in range(nx):
            out[j, i] = top_hit(t, x0 + i * step, z)
    with open(path, "wb") as f:
        f.write(struct.pack("iifff", nx, nz, x0, z0, step) + b"\0\0\0\0")
        f.write(out.astype(np.float32).tobytes())
    print("carte", path, nx, nz)
    return t


def sheet(body):
    """Drap blanc sur le bassin et les jambes, calculé sur la carte de hauteur du corps (sans les
    bras : ils restent posés dessus) : le tissu fait pont entre les jambes, retombe sur les côtés du
    brancard et au bout, ourlet replié en haut, quelques plis."""
    from scipy import ndimage
    # Sommets des bras : repérés par leurs os (groupes de sommets gardés après la pose)
    arm_groups = {g.index for g in body.vertex_groups if any(k in g.name for k in ("upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb"))}
    arm_ids = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if g.group in arm_groups)
        if w > 0.5:
            arm_ids.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    arms = [bm.verts[i] for i in arm_ids]
    bmesh.ops.delete(bm, geom=arms, context="VERTS")
    me = bpy.data.meshes.new("_sansbras")
    bm.to_mesh(me)
    bm.free()
    tmp = bpy.data.objects.new("_sansbras", me)
    bpy.context.scene.collection.objects.link(tmp)
    t = tree([tmp])
    step = 0.01
    x0, x1 = -1.62, -0.30
    z0, z1 = -0.42, 0.42
    nx = int(round((x1 - x0) / step)) + 1
    nz = int(round((z1 - z0) / step)) + 1
    h = np.zeros((nz, nx))
    for j in range(nz):
        z = z0 + j * step
        for i in range(nx):
            x = x0 + i * step
            y = top_hit(t, x, z)
            h[j, i] = y if y > 0 else TABLE
    bpy.data.objects.remove(tmp)
    # Le tissu fait pont : fermeture morphologique puis lissage
    r = 11
    disk = np.hypot(*np.mgrid[-r:r + 1, -r:r + 1]) <= r
    hc = ndimage.grey_closing(h, footprint=disk)
    hc = ndimage.gaussian_filter(hc, 2.0)
    # Jamais sous la peau (le drap repose dessus)
    hc = np.maximum(hc, ndimage.grey_dilation(h, size=(3, 3)) + 0.009) + 0.003
    rng = np.random.default_rng(4)
    folds = ndimage.gaussian_filter(rng.normal(0, 1, (nz, nx)), (2.0, 6.0))
    hc += folds * 0.006
    # Bords : le drap tombe du brancard sur les côtés et au bout des pieds
    for j in range(nz):
        z = z0 + j * step
        for i in range(nx):
            x = x0 + i * step
            out = max(abs(z) - 0.31, (-1.44) - x, 0.0)
            if out > 0:
                hc[j, i] = min(hc[j, i], TABLE + 0.012 - out * 7.0)
    hc = np.maximum(hc, 0.42)
    # Ourlet replié en haut (côté du ventre)
    hem = np.clip(1.0 - (x1 - (x0 + np.arange(nx) * step)) / 0.04, 0, 1)
    hc += hem[None, :] * 0.004
    bm = bmesh.new()
    vv = [[bm.verts.new(bl.g(x0 + i * step, hc[j, i], z0 + j * step)) for i in range(nx)] for j in range(nz)]
    uv = bm.loops.layers.uv.new("UVMap")
    for j in range(nz - 1):
        for i in range(nx - 1):
            f = bm.faces.new((vv[j][i], vv[j][i + 1], vv[j + 1][i + 1], vv[j + 1][i]))
            for loop in f.loops:
                co = loop.vert.co
                loop[uv].uv = (co.x * 3.0, co.y * 3.0)
    me = bpy.data.meshes.new("Drap")
    bm.to_mesh(me)
    bm.free()
    cloth = bpy.data.objects.new("Drap", me)
    bpy.context.scene.collection.objects.link(cloth)
    sol = cloth.modifiers.new("Epaisseur", "SOLIDIFY")
    sol.thickness = 0.002
    bl.apply_all(cloth)
    bl.set_mat(cloth, bl.mat("Drap", (0.86, 0.89, 0.92), 0.9))
    bl.smooth(cloth, 80)
    return cloth


def landmarks(t_body, joints, path):
    lm = json.load(open(path))

    def bh(x, z):
        return top_hit(t_body, x, z)

    for s, side in (("l", "L"), ("r", "R")):
        chain = [joints["tip_" + s][0], joints["hand_" + s][0], joints["lowerarm_" + s][0], joints["upperarm_" + s][0]]
        pts = []
        for k in range(len(chain) - 1):
            for i in range(10):
                p = chain[k].lerp(chain[k + 1], i / 10.0)
                pts.append(p)
        pts.append(chain[-1])
        line = []
        for p in pts:
            g = game(p)
            top = bh(g[0], g[2])
            r = max(0.012, (top - TABLE) * 0.5) if top > 0 else 0.03
            line.append([round(g[0], 4), round(TABLE + r, 4), round(g[2], 4), round(r, 4)])
        lm["arm_" + side] = line
        tip = game(joints["tip_" + s][0])
        lm["fingertip_" + side] = [tip[0], bh(tip[0], tip[2]), tip[2]]
        lm["arm_top_y_" + side] = max(l[1] + l[3] for l in line)
    hd = game(joints["head"][0])
    ht = game(joints["head"][1])
    nk = game(joints["neck_01"][0])
    # Sommet du crâne : dernier point du corps sur l'axe
    x = ht[0]
    while bh(x + 0.002, 0.0) > 0:
        x += 0.002
    lm["head_top_x"] = x
    # Nez : point le plus haut du visage
    best = (0, -1)
    for i in range(80):
        xx = hd[0] + i * 0.002
        y = bh(xx, 0.0)
        if y > best[1]:
            best = (xx, y)
    lm["nose_tip"] = [best[0], best[1], 0.0]
    lm["chin"] = [best[0] - 0.05, bh(best[0] - 0.05, 0.0), 0.0]
    occ_x = (hd[0] + ht[0]) * 0.5
    lm["occiput"] = [occ_x, TABLE + 0.04, 0.0]
    lm["occiput_low_y"] = TABLE + 0.04
    neck_x = (nk[0] + hd[0]) * 0.5
    hw = 0.02
    while bh(neck_x, hw) > TABLE + 0.03 and hw < 0.12:
        hw += 0.002
    lm["neck"] = {"x": neck_x, "y_front": bh(neck_x, 0.0), "y_back": TABLE + 0.01, "half_width": hw}
    lm["shoulder_L"] = list(game(joints["upperarm_l"][0]))
    json.dump(lm, open(path, "w"), indent=1)
    print("repères", path)


def main():
    bl.reset()
    body, eyes, joints = build_body()
    lay_down([body, eyes], joints)
    for ob in (body, eyes):
        bl.bake_transforms(ob)
    t_body = height_map([body], os.path.join(DATA, "peau_dos_hauteur.bin"), os.path.join(DATA, "peau_dos_hauteur.bin"))
    landmarks(t_body, joints, os.path.join(DATA, "patient_dos.json"))
    cl = sheet(body)
    height_map([cl], os.path.join(DATA, "drap_dos_hauteur.bin"), os.path.join(DATA, "drap_dos_hauteur.bin"))
    bl.export("drap_dos", [cl])
    bpy.data.objects.remove(cl)
    bl.export("patient_urg", [body, eyes])
    if "--preview" in sys.argv:
        bl.preview("/tmp/apercus/patient_couche.png", bl.g(-0.2, 2.0, 1.4), bl.g(-0.3, 0.9, 0.0), size=(900, 600), lens=35)


main()
