"""Humains réalistes à partir du maillage de base MakeHuman (hm08, CC0) et des données MPFB2 (CC0) :
lecture du maillage et de ses UV, cibles de morphologie (homme adulte...), squelette « game_engine »
et poids de peau, yeux haute définition (ajustés comme un vêtement .mhclo), pose des os.

Repère : le maillage MakeHuman est en décimètres, Y vers le haut, face vers +Z, gauche du personnage
vers +X — c'est exactement le repère du jeu (à l'échelle 0,1 près). Dans Blender (Z vers le haut),
un point du jeu (x, y, z) devient (x, -z, y) : voir bl.g().
"""
import gzip
import json
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

MPFB = "/home/user/ext/mpfb2/src/mpfb/data"
MHDATA = "/home/user/ext/mh/makehuman/data"
SCALE = 0.1


class Base:
    """Maillage de base : sommets, UV, faces (avec leur groupe)."""

    def __init__(self):
        self.v = []
        self.vt = []
        self.faces = []  # (indices sommets, indices uv, groupe)
        group = ""
        with open(os.path.join(MPFB, "3dobjs", "base.obj")) as f:
            for line in f:
                if line.startswith("v "):
                    p = line.split()
                    self.v.append((float(p[1]), float(p[2]), float(p[3])))
                elif line.startswith("vt "):
                    p = line.split()
                    self.vt.append((float(p[1]), float(p[2])))
                elif line.startswith("g "):
                    group = line[2:].strip()
                elif line.startswith("f "):
                    vi = []
                    ti = []
                    for tok in line.split()[1:]:
                        a = tok.split("/")
                        vi.append(int(a[0]) - 1)
                        ti.append(int(a[1]) - 1 if len(a) > 1 and a[1] else -1)
                    self.faces.append((vi, ti, group))
        self.v = np.array(self.v, dtype=np.float64)
        self.groups = {}
        for vi, ti, g in self.faces:
            self.groups.setdefault(g, set()).update(vi)

    def apply_target(self, name, w):
        path = os.path.join(MPFB, "targets", name + ".target.gz")
        with gzip.open(path, "rt") as f:
            for line in f:
                p = line.split()
                if len(p) == 4 and not line.startswith("#"):
                    self.v[int(p[0])] += w * np.array([float(p[1]), float(p[2]), float(p[3])])

    def joint(self, name):
        idx = list(self.groups.get(name, []))
        if not idx:
            return None
        return self.v[idx].mean(axis=0)


def to_bl(p):
    """Point MakeHuman (décimètres, repère du jeu) -> Blender (mètres)."""
    return Vector((p[0] * SCALE, -p[2] * SCALE, p[1] * SCALE))


def build_mesh(base, groups, name, material=None):
    """Objet Blender avec les faces des groupes donnés (tous les sommets gardés : indices identiques
    au maillage de base, pour les poids et les cibles ; les sommets isolés sont retirés à la fin)."""
    bm = bmesh.new()
    verts = [bm.verts.new(to_bl(p)) for p in base.v]
    bm.verts.ensure_lookup_table()
    uv = bm.loops.layers.uv.new("UVMap")
    for vi, ti, g in base.faces:
        if g not in groups:
            continue
        try:
            f = bm.faces.new([verts[i] for i in vi])
        except ValueError:
            continue
        for loop, t in zip(f.loops, ti):
            if t >= 0:
                loop[uv].uv = base.vt[t]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    if material:
        me.materials.append(material)
    return ob


def build_armature(base, rig="game_engine", name="Squelette"):
    rd = json.load(open(os.path.join(MPFB, "rigs", "standard", "rig.%s.json" % rig)))
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")

    def pos(spec):
        if spec.get("strategy") == "CUBE":
            j = base.joint(spec["cube_name"])
            if j is not None:
                return to_bl(j)
        dp = spec.get("default_position", [0, 0, 0])
        # Positions par défaut de MPFB : mètres, repère Blender
        return Vector(dp)

    bones = {}
    for bname, b in rd.items():
        eb = arm.edit_bones.new(bname)
        eb.head = pos(b["head"])
        eb.tail = pos(b["tail"])
        if (eb.tail - eb.head).length < 1e-4:
            eb.tail = eb.head + Vector((0, 0, 0.01))
        eb.roll = b.get("roll", 0.0)
        bones[bname] = eb
    for bname, b in rd.items():
        par = b.get("parent")
        if par and par in bones:
            bones[bname].parent = bones[par]
            bones[bname].use_connect = bool(b.get("use_connect", False))
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def skin(ob, arm_ob, rig="game_engine"):
    wd = json.load(open(os.path.join(MPFB, "rigs", "standard", "weights.%s.json" % rig)))["weights"]
    for bname, lst in wd.items():
        vg = ob.vertex_groups.new(name=bname)
        for vi, w in lst:
            vg.add([vi], w, "REPLACE")
    mod = ob.modifiers.new("Squelette", "ARMATURE")
    mod.object = arm_ob
    ob.parent = arm_ob


def fit_proxy(base, mhclo, name, material=None):
    """Vêtement / œil MakeHuman (.mhclo) ajusté sur le maillage de base modifié."""
    folder = os.path.dirname(mhclo)
    obj_file = None
    scales = {}
    refs = []
    mode = ""
    for line in open(mhclo):
        p = line.split()
        if not p or line.startswith("#"):
            continue
        if p[0] == "obj_file":
            obj_file = os.path.join(folder, p[1])
        elif p[0] in ("x_scale", "y_scale", "z_scale"):
            scales[p[0][0]] = (int(p[1]), int(p[2]), float(p[3]))
        elif p[0] == "verts":
            mode = "verts"
        elif p[0] in ("weights", "delete_verts"):
            mode = p[0]
        elif mode == "verts" and len(p) >= 9:
            refs.append(([int(p[0]), int(p[1]), int(p[2])], [float(p[3]), float(p[4]), float(p[5])], [float(p[6]), float(p[7]), float(p[8])]))
        elif mode == "verts" and len(p) == 1:
            refs.append(([int(p[0])], [1.0], [0, 0, 0]))
    sc = []
    for ax, i in (("x", 0), ("y", 1), ("z", 2)):
        a, b, ref = scales[ax]
        sc.append(abs(base.v[a][i] - base.v[b][i]) / ref)
    pts = []
    for idx, w, d in refs:
        q = np.zeros(3)
        for k, wk in zip(idx, w):
            q += wk * base.v[k]
        q += np.array([d[0] * sc[0], d[1] * sc[1], d[2] * sc[2]])
        pts.append(q)
    # Faces et UV du proxy
    vt = []
    faces = []
    for line in open(obj_file):
        if line.startswith("vt "):
            p = line.split()
            vt.append((float(p[1]), float(p[2])))
        elif line.startswith("f "):
            vi, ti = [], []
            for tok in line.split()[1:]:
                a = tok.split("/")
                vi.append(int(a[0]) - 1)
                ti.append(int(a[1]) - 1 if len(a) > 1 and a[1] else -1)
            faces.append((vi, ti))
    bm = bmesh.new()
    verts = [bm.verts.new(to_bl(p)) for p in pts]
    uv = bm.loops.layers.uv.new("UVMap")
    for vi, ti in faces:
        try:
            f = bm.faces.new([verts[i] for i in vi])
        except ValueError:
            continue
        for loop, t in zip(f.loops, ti):
            if t >= 0:
                loop[uv].uv = vt[t]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    if material:
        me.materials.append(material)
    return ob


def rigid_to_bone(ob, arm_ob, bone):
    """Le proxy suit un seul os (yeux -> tête)."""
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    mod = ob.modifiers.new("Squelette", "ARMATURE")
    mod.object = arm_ob
    ob.parent = arm_ob


def pose(arm_ob, rots):
    """rots : {os: (rx, ry, rz) en degrés, repère local de l'os}."""
    bpy.context.view_layer.objects.active = arm_ob
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm_ob.pose.bones:
        pb.rotation_mode = "XYZ"
    for bname, r in rots.items():
        pb = arm_ob.pose.bones.get(bname)
        if pb is None:
            print("os inconnu", bname)
            continue
        pb.rotation_euler = (math.radians(r[0]), math.radians(r[1]), math.radians(r[2]))
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def bake_pose(objs):
    """Applique le squelette (la pose devient la forme du maillage)."""
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        for m in list(ob.modifiers):
            if m.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=m.name)
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw


def remove_loose(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def bone_head(arm_ob, name):
    return arm_ob.matrix_world @ arm_ob.pose.bones[name].head


def bone_tail(arm_ob, name):
    return arm_ob.matrix_world @ arm_ob.pose.bones[name].tail


def aim(arm_ob, bone, direction):
    """Oriente l'os (son axe Y) vers une direction (repère Blender), sans le faire tourner sur lui-même
    plus que nécessaire. À appeler du parent vers les enfants."""
    bpy.context.view_layer.update()
    pb = arm_ob.pose.bones[bone]
    cur = pb.matrix.copy()
    y_cur = cur.to_3x3().col[1].normalized()
    q = y_cur.rotation_difference(Vector(direction).normalized())
    rot = q.to_matrix() @ cur.to_3x3()
    m = rot.to_4x4()
    m.translation = cur.translation
    pb.matrix = m
    bpy.context.view_layer.update()


def twist(arm_ob, bone, degrees):
    """Rotation de l'os autour de son propre axe (pronation, supination)."""
    pb = arm_ob.pose.bones[bone]
    pb.rotation_mode = "XYZ"
    e = pb.rotation_euler
    pb.rotation_euler = (e[0], e[1] + math.radians(degrees), e[2])
    bpy.context.view_layer.update()


def curl(arm_ob, side, amounts, thumb=(0.0, 0.0, 0.0)):
    """Flexion des doigts (degrés par phalange) : amounts = {doigt: (p1, p2, p3)}."""
    for f, a in amounts.items():
        for k, deg in zip(["01", "02", "03"], a):
            pb = arm_ob.pose.bones.get("%s_%s_%s" % (f, k, side))
            if pb:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (math.radians(deg), 0.0, 0.0)
    for k, deg in zip(["01", "02", "03"], thumb):
        pb = arm_ob.pose.bones.get("thumb_%s_%s" % (k, side))
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (math.radians(deg), 0.0, 0.0)
    bpy.context.view_layer.update()


def eye_centers(base, eyes_ob):
    """Centre et rayon de chaque globe oculaire (repère MakeHuman, décimètres) : {+1: (c, r), -1: ...}
    (+1 : œil gauche du personnage, côté +X)."""
    pts = np.array([(v.co.x / SCALE, v.co.z / SCALE, -v.co.y / SCALE) for v in eyes_ob.data.vertices])
    out = {}
    for s in (1, -1):
        e = pts[pts[:, 0] * s > 0]
        # Le globe est une sphère dont dépasse un rebord plat (la profondeur donne le rayon)
        c = (e.max(axis=0) + e.min(axis=0)) * 0.5
        out[s] = (c, float(e[:, 2].max() - e[:, 2].min()) * 0.5)
    return out


def close_eyelids(base, eyes, lid=0.012, close_at=0.3, reach_up=0.6, reach_down=0.45):
    """Positions des sommets paupières fermées (pour une cible de forme) : la paupière supérieure
    descend sur le globe jusqu'à la ligne de fermeture (au tiers inférieur de la fente), l'inférieure
    remonte un peu ; la peau suit en s'amortissant vers le sourcil et la joue. Calcul en coordonnées
    sphériques autour du centre de chaque œil (phi : azimut, theta : hauteur). La fente palpébrale est
    mesurée par des rayons lancés du centre de l'œil : là où ils ne rencontrent pas la peau, l'œil est
    visible."""
    from mathutils.bvhtree import BVHTree
    v = base.v.copy()
    polys = [vi for vi, ti, g in base.faces if g == "body"]
    tree = BVHTree.FromPolygons([Vector(p) for p in base.v], polys)
    bodyv = np.array(sorted(base.groups["body"]))

    def fall(t):
        t = np.clip(t, 0.0, 1.0)
        return 1.0 - t * t * (3 - 2 * t)

    for s, (c, R) in eyes.items():
        # Fente : pour chaque azimut, bornes haute et basse des directions sans peau devant l'œil
        phis = np.radians(np.arange(-80, 81, 2.0))
        ths = np.radians(np.arange(-60, 61, 1.0))
        cols = []
        for ph in phis:
            open_th = []
            for th in ths:
                d = Vector((math.cos(th) * math.sin(ph), math.sin(th), math.cos(th) * math.cos(ph)))
                hit = tree.ray_cast(Vector(c), d, R * 1.8)
                if hit[0] is None:
                    open_th.append(th)
            if open_th:
                cols.append((ph, max(open_th), min(open_th)))
        cols = np.array(cols)
        pa, pb = cols[0, 0], cols[-1, 0]
        q = base.v[bodyv] - c
        rr = np.linalg.norm(q, axis=1)
        sel = (rr < R * 3.2) & (q[:, 2] > -R * 0.2)
        idx = bodyv[sel]
        q = q[sel]
        r = rr[sel]
        phi = np.arctan2(q[:, 0], q[:, 2])
        th = np.arctan2(q[:, 1], np.hypot(q[:, 0], q[:, 2]))
        pc = np.clip(phi, pa, pb)
        th_u = np.interp(pc, cols[:, 0], cols[:, 1])
        th_l = np.interp(pc, cols[:, 0], cols[:, 2])
        th_c = th_l + close_at * (th_u - th_l)
        mid = (th_u + th_l) * 0.5
        # Au-delà des coins : la peau ne bouge plus
        wphi = 1.0 - np.clip(np.abs(phi - pc) / 0.12, 0.0, 1.0)
        wphi = wphi * wphi * (3 - 2 * wphi)
        upper = th >= mid
        shift = np.where(upper, (th_c - th_u) * fall((th - th_u) / reach_up), (th_c - th_l) * fall((th_l - th) / reach_down))
        shift *= wphi
        th2 = th + shift
        # Rebord replié sous le globe : reste de son côté de la ligne de fermeture
        th2 = np.where(upper, np.maximum(th2, th_c), np.minimum(th2, th_c))
        inside = r < R * 0.995
        moved = np.abs(th2 - th) > 1e-6
        # La paupière glisse sur le globe : jamais à moins d'une épaisseur de sa surface
        r2 = np.where(moved & ~inside, np.maximum(r, R + lid), r)
        newp = c + np.stack([r2 * np.cos(th2) * np.sin(phi), r2 * np.sin(th2), r2 * np.cos(th2) * np.cos(phi)], 1)
        v[idx] = np.where(moved[:, None], newp, base.v[idx])
        print("paupière", s, "sommets déplacés", int(moved.sum()),
              "fente %.0f..%.0f°, hauteur max %.0f°, R %.3f" % (math.degrees(pa), math.degrees(pb), math.degrees((cols[:, 1] - cols[:, 2]).max()), R))
    return v
