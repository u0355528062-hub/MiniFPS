"""Radiographies du thorax de face calculées sur l'atlas (patient_dos.glb, Z-Anatomy CC BY-SA 4.0).
Comme un vrai faisceau de rayons X, on lance un rayon vertical par point du film à travers le patient
couché : épaisseur de corps traversée, épaisseur d'air des poumons, nombre de corticales osseuses
traversées. L'atténuation (tissus mous − air + os) donne l'image après la courbe du film
(tools/xray_post.py).
    /home/user/bpyenv/bin/python tools/blender/build_xray.py [variante]
Variantes : normale (défaut). Écrit /tmp/xray_mu.npy."""
import os
import sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402

W, H = 450, 500
X_TOP, X_BOT = 0.31, -0.31  # jeu : tête en haut de l'image
Z_LEFT, Z_RIGHT = -0.279, 0.279  # côté droit du patient à gauche de l'image


def tree(names):
    dg = bpy.context.evaluated_depsgraph_get()
    verts = []
    polys = []
    for n in names:
        o = bpy.data.objects.get(n)
        if o is None:
            continue
        me = o.evaluated_get(dg).to_mesh()
        off = len(verts)
        mw = o.matrix_world
        verts += [mw @ v.co for v in me.vertices]
        polys += [[off + i for i in p.vertices] for p in me.polygons]
    return BVHTree.FromPolygons(verts, polys)


def hits(t, x, z):
    out = []
    o = Vector((x, -z, 3.0))
    d = Vector((0, 0, -1))
    for _ in range(64):
        loc, nrm, idx, dist = t.ray_cast(o, d)
        if loc is None:
            break
        out.append(loc.z)
        o = loc + d * 1e-5
    return out


def thickness(h):
    s = 0.0
    for k in range(0, len(h) - 1, 2):
        s += h[k] - h[k + 1]
    return s


def main():
    bl.reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(bl.ROOT, "assets", "models", "patient_dos.glb"))
    body = tree(["Peau"])
    lung_g = tree(["PoumonG"])
    lung_d = tree(["PoumonD"])
    bones = tree(["Os"])
    heart = tree(["Coeur"])
    mu = np.zeros((H, W), np.float32)
    for i in range(H):
        x = X_TOP + (X_BOT - X_TOP) * (i + 0.5) / H
        for j in range(W):
            z = Z_LEFT + (Z_RIGHT - Z_LEFT) * (j + 0.5) / W
            hb = hits(body, x, z)
            if not hb:
                continue
            tb = hb[0] - hb[-1]
            tl = 0.0
            for lt in (lung_g, lung_d):
                hl = hits(lt, x, z)
                if len(hl) >= 2:
                    tl += hl[0] - hl[-1]
            nb = len(hits(bones, x, z))
            th = thickness(hits(heart, x, z))
            mu[i, j] = tb - 1.05 * tl + 0.018 * nb + 0.1 * th
        if i % 50 == 0:
            print("ligne", i)
    np.save("/tmp/xray_mu.npy", mu)
    print("RENDU rayons", float(mu.max()))


main()
