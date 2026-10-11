"""Animations des personnages : reciblage de captures de mouvement CMU (BVH) sur le squelette
MakeHuman, poses construites (allongé, semi-assis) et respiration. Export d'un GLB unique
(squelette + toutes les actions) que le jeu charge comme bibliothèque d'animations partagée.

Usage : /opt/bpyenv/bin/python tools/humains/animations.py [clip ...]
Données CMU : Carnegie Mellon University Graphics Lab Motion Capture Database (conversion BVH
de B. Hahne), libre d'utilisation. Chemin : CMU_BVH ou /tmp/dl/cmu/data.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import mh_donnees as mh  # noqa: E402
from construire import creer_armature, vider, RACINE  # noqa: E402

CMU = os.environ.get("CMU_BVH", "/tmp/dl/cmu/data")
FPS = 30

CORRESP = {
    "Hips": "root", "LowerBack": "spine04", "Spine": "spine02", "Spine1": "spine01", "Neck": "neck01",
    "Neck1": "neck02", "Head": "head",
    "LeftShoulder": "clavicle.L", "LeftArm": "upperarm01.L", "LeftForeArm": "lowerarm01.L", "LeftHand": "wrist.L",
    "RightShoulder": "clavicle.R", "RightArm": "upperarm01.R", "RightForeArm": "lowerarm01.R", "RightHand": "wrist.R",
    "LeftUpLeg": "upperleg01.L", "LeftLeg": "lowerleg01.L", "LeftFoot": "foot.L",
    "RightUpLeg": "upperleg01.R", "RightLeg": "lowerleg01.R", "RightFoot": "foot.R",
}

# nom : (fichier, première image, dernière image (120 i/s), boucle, sur place)
CLIPS = {
    "marche": ("007/07_01.bvh", 40, 300, "cycle", True),
    "marche_lente": ("008/08_04.bvh", 60, 400, "cycle", True),
    "boiter": ("077/77_19.bvh", 100, 700, "cycle", True),
    "attente": ("040/40_10.bvh", 200, 1400, "plage", True),
    "debout": ("077/77_02.bvh", 60, 900, "plage", True),
    "assis": ("075/75_17.bvh", 500, 1100, "plage", True),
    "assis_tete_mains": ("022/22_03.bvh", 700, 1500, "plage", True),
    "parler": ("018/18_08.bvh", 300, 1500, "plage", True),
    "ramasser": ("069/69_73.bvh", 100, 700, False, False),
}


# Main détendue : flexion (axe X local, positif = vers la paume) des doigts non suivis par la capture.
IDENT = Matrix.Identity(3)
DETENTE = {}
for _c in "LR":
    for _i in range(1, 6):
        for _j in range(1, 4):
            DETENTE["finger%d-%d.%s" % (_i, _j, _c)] = Matrix.Rotation(math.radians(8 if _i == 1 else 14 + 3 * _j), 3, "X")


# ---------------------------------------------------------------------------------------------
def rot_minimale(a, b):
    a = Vector(a).normalized()
    b = Vector(b).normalized()
    return a.rotation_difference(b).to_matrix()


def bvh_importer(chemin):
    avant = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=chemin, global_scale=1.0, rotate_mode="NATIVE", axis_forward="-Z", axis_up="Y",
                            update_scene_fps=False, update_scene_duration=True)
    obj = [o for o in bpy.data.objects if o not in avant][0]
    return obj


def orienter_source(src, image):
    """Tourne l'armature BVH autour de Z pour qu'à l'image de référence elle regarde -Y (comme MakeHuman)."""
    sc = bpy.context.scene
    sc.frame_set(image)
    pb = src.pose.bones
    g = (src.matrix_world @ pb["LeftUpLeg"].matrix).translation
    d = (src.matrix_world @ pb["RightUpLeg"].matrix).translation
    gauche = (g - d)
    gauche.z = 0
    avant = gauche.normalized().cross(Vector((0, 0, 1)))
    lacet = math.atan2(avant.x, -avant.y)  # angle de avant vers -Y
    src.rotation_euler.z -= lacet
    bpy.context.view_layer.update()


def monde(obj, pb):
    return (obj.matrix_world @ pb.matrix)


def recibler(nom, spec, dst):
    fichier, i0, i1, boucle, sur_place = spec
    src = bvh_importer(os.path.join(CMU, fichier))
    sc = bpy.context.scene
    orienter_source(src, 1)
    sc.frame_set(1)
    spb = src.pose.bones
    arm = dst.data
    # Repos de la cible (espace armature = monde, l'objet cible est à l'identité).
    R = {b.name: b.matrix_local.to_3x3() for b in arm.bones}
    T = {b.name: b.matrix_local.translation.copy() for b in arm.bones}
    parents = {b.name: (b.parent.name if b.parent else None) for b in arm.bones}
    ordre = [b.name for b in arm.bones]  # Blender liste les parents avant les enfants
    # Références : image 1 de la source ; cible = repos tourné pour aligner chaque os sur la source.
    ref_src = {}
    ref_dst = {}
    for s_nom, d_nom in CORRESP.items():
        if s_nom not in spb:
            continue
        m = monde(src, spb[s_nom])
        ref_src[s_nom] = m.to_3x3().normalized()
        if d_nom == "root":
            ref_dst[d_nom] = R[d_nom]
        else:
            enfants = spb[s_nom].children
            if enfants:
                fin = monde(src, enfants[0]).translation
            else:
                fin = (src.matrix_world @ spb[s_nom].tail.to_4d()).to_3d()
            d_src = fin - m.translation
            if d_src.length < 1e-4:
                ref_dst[d_nom] = R[d_nom]
            else:
                d_dst = R[d_nom].col[1]
                ref_dst[d_nom] = rot_minimale(d_dst, d_src) @ R[d_nom]
    hanche_src0 = monde(src, spb["Hips"]).translation.copy()
    k = T["root"].z / max(hanche_src0.z, 1e-6)
    # Lecture de toutes les images utiles (120 i/s → 30 i/s).
    pas = 4
    images = list(range(i0, min(i1, sc.frame_end) + 1, pas))
    poses = []
    for f in images:
        sc.frame_set(f)
        W = {}
        for s_nom, d_nom in CORRESP.items():
            if s_nom in spb:
                W[d_nom] = monde(src, spb[s_nom]).to_3x3().normalized() @ ref_src[s_nom].inverted() @ ref_dst[d_nom]
        h = monde(src, spb["Hips"]).translation
        poses.append((W, (h - hanche_src0) * k))
    if boucle == "cycle":
        poses = boucler(poses)
    elif boucle == "plage":
        poses = boucler(poses, fondu=15, chercher=False)
    # Conversion en rotations locales.
    pistes = {n: [] for n in ordre}
    pos_racine = []
    for W, dep in poses:
        M = {}
        for n in ordre:
            p = parents[n]
            base = R[n] if p is None else M[p] @ (R[p].inverted() @ R[n])
            if n in W:
                M[n] = W[n]
                L = base.inverted() @ W[n]
            else:
                L = DETENTE.get(n, IDENT)
                M[n] = base @ L
            pistes[n].append(L.to_quaternion())
        if sur_place:
            dep = Vector((0.0, 0.0, dep.z))
        pos_racine.append(R["root"].inverted() @ dep)
    bpy.data.objects.remove(src, do_unlink=True)
    return pistes, pos_racine


def boucler(poses, fondu=6, chercher=True):
    """Cherche le cycle le plus propre (période entre 0,8 et 1,6 s pour la marche, sinon toute
    la plage) puis fond les dernières images vers la première."""
    n = len(poses)

    def caract(i):
        W = poses[i][0]
        v = []
        for b in ("upperleg01.L", "upperleg01.R", "lowerleg01.L", "lowerleg01.R", "upperarm01.L", "upperarm01.R",
                  "spine02", "head"):
            if b in W:
                q = W[b].to_quaternion()
                v.extend(q[:] if q.w >= 0 else (-q)[:])
        return np.array(v)

    F = np.array([caract(i) for i in range(n)])
    meilleur = (1e9, 0, n - 1)
    pmin, pmax = int(0.8 * FPS), min(n - 1, int(1.6 * FPS))
    if chercher and n > pmax + 2:
        for a in range(0, min(n - pmax - 1, 2 * FPS)):
            for P in range(pmin, pmax + 1):
                if a + P + 1 >= n:
                    break
                c = np.linalg.norm(F[a] - F[a + P]) + 0.5 * np.linalg.norm((F[a + 1] - F[a]) - (F[a + P + 1] - F[a + P]))
                if c < meilleur[0]:
                    meilleur = (c, a, a + P)
    _, a, b = meilleur
    seg = poses[a:b + 1]
    if len(seg) < 4:
        seg = poses
    # Fondu : les dernières images rejoignent la première (boucle sans saut).
    W0, d0 = seg[0]
    m = len(seg)
    for j in range(1, min(fondu, m - 1) + 1):
        i = m - j
        t = 1.0 - (j - 1) / fondu  # 1 à la dernière image
        Wi, di = seg[i]
        W = {}
        for bn in Wi:
            qa = Wi[bn].to_quaternion()
            qb = W0[bn].to_quaternion()
            W[bn] = qa.slerp(qb, t).to_matrix()
        seg[i] = (W, di.lerp(d0, t))
    return seg


# ---------------------------------------------------------------------------------------------
def pose_directions(dst, inclinaison, directions, duree=4.0, respiration=1.0, doigts=12.0):
    """Pose construite en espace monde : le bassin est basculé de « inclinaison » degrés vers
    l'arrière (rotation autour de X), chaque os listé est orienté vers la direction voulue
    (rotation minimale depuis le repos), les autres suivent leur parent. Respiration en boucle."""
    arm = dst.data
    R = {b.name: b.matrix_local.to_3x3() for b in arm.bones}
    parents = {b.name: (b.parent.name if b.parent else None) for b in arm.bones}
    ordre = [b.name for b in arm.bones]
    W = {"root": Matrix.Rotation(math.radians(-inclinaison), 3, "X") @ R["root"]}
    for bn, d in directions.items():
        W[bn] = rot_minimale(R[bn].col[1], Vector(d)) @ R[bn]
    n = int(duree * FPS) + 1
    pistes = {b: [] for b in ordre}
    pos = []
    for i in range(n):
        t = i / (n - 1)
        resp = math.sin(2 * math.pi * t) * respiration
        M = {}
        for b in ordre:
            p = parents[b]
            base = R[b] if p is None else M[p] @ (R[p].inverted() @ R[b])
            if b in W:
                M[b] = W[b]
                L = base.inverted() @ W[b]
            else:
                L = DETENTE.get(b, IDENT)
                M[b] = base @ L
            q = L.to_quaternion()
            if b in ("spine02", "spine01"):
                q = q @ Quaternion(Vector((1, 0, 0)), math.radians(-1.5 * resp))
            pistes[b].append(q)
        pos.append(Vector((0, 0, 0.0)))
    return pistes, pos


def poses_allongees():
    """Directions monde (Blender : le personnage regarde -Y, sa gauche est +X, Z en haut)."""
    def n(v):
        v = Vector(v)
        return v.normalized()
    semi = {}
    for c, s in (("L", 1), ("R", -1)):
        semi["upperleg01." + c] = n((0.06 * s, -1.0, -0.06))
        semi["lowerleg01." + c] = n((0.0, -1.0, -0.10))
        semi["foot." + c] = n((0.05 * s, -0.40, 0.92))
        semi["upperarm01." + c] = n((0.30 * s, -0.78, -0.55))
        semi["lowerarm01." + c] = n((0.10 * s, -0.97, -0.20))
        semi["wrist." + c] = n((0.08 * s, -0.97, -0.25))
    semi["head"] = n((0.0, 0.55, 0.83))
    allonge = {}
    for c, s in (("L", 1), ("R", -1)):
        allonge["upperleg01." + c] = n((0.07 * s, -1.0, 0.0))
        allonge["lowerleg01." + c] = n((0.02 * s, -1.0, 0.02))
        allonge["foot." + c] = n((0.08 * s, -0.35, 0.93))
        allonge["upperarm01." + c] = n((0.22 * s, -1.0, -0.05))
        allonge["lowerarm01." + c] = n((0.10 * s, -1.0, 0.10))
        allonge["wrist." + c] = n((0.08 * s, -1.0, 0.05))
    allonge["head"] = n((0.0, 1.0, 0.12))
    return {"allonge": (90.0, allonge), "semi_assis": (55.0, semi)}


# ---------------------------------------------------------------------------------------------
def ecrire_action(dst, nom, pistes, pos_racine):
    act = bpy.data.actions.new(nom)
    act.use_fake_user = True
    dst.animation_data_create()
    dst.animation_data.action = act
    for b, qs in pistes.items():
        pb = dst.pose.bones[b]
        pb.rotation_mode = "QUATERNION"
        prec = None
        for i, q in enumerate(qs):
            if prec is not None and prec.dot(q) < 0:
                q = -q
            prec = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=i + 1)
    pr = dst.pose.bones["root"]
    for i, p in enumerate(pos_racine):
        pr.location = p
        pr.keyframe_insert("location", frame=i + 1)
    # Réinitialise la pose (sinon elle se propage à l'action suivante).
    for pb in dst.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    track = dst.animation_data.nla_tracks.new()
    track.name = nom
    track.strips.new(nom, 1, act)
    dst.animation_data.action = None
    print("action", nom, len(pos_racine), "images")


def main(noms):
    vider()
    bpy.context.scene.render.fps = FPS
    co = mh.morpher({})
    dst = creer_armature(co, co[:13380, 1].min() * 0.1)
    for n in noms:
        if n in CLIPS:
            pistes, pos = recibler(n, CLIPS[n], dst)
            ecrire_action(dst, n, pistes, pos)
    poses = poses_allongees()
    for n in ("allonge", "semi_assis"):
        if not noms or n in noms or "tout" in noms:
            incl, dirs = poses[n]
            pistes, pos = pose_directions(dst, incl, dirs)
            ecrire_action(dst, n, pistes, pos)
    # Petit triangle lié au squelette : force l'export d'une « peau » glTF, donc un
    # Skeleton3D à l'import dans Godot (sinon les os deviennent de simples nœuds).
    me = bpy.data.meshes.new("Ancre")
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    ancre = bpy.data.objects.new("Ancre", me)
    bpy.context.scene.collection.objects.link(ancre)
    ancre.vertex_groups.new(name="root").add([0, 1, 2], 1.0, "REPLACE")
    ancre.modifiers.new("Squelette", "ARMATURE").object = dst
    ancre.parent = dst
    if "--apercu" in sys.argv:
        apercu(dst)
    chemin = os.path.join(RACINE, "assets", "personnages", "animations.glb")
    bpy.ops.object.select_all(action="DESELECT")
    dst.select_set(True)
    ancre.select_set(True)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.name.startswith("Apercu"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_skins=True,
                              export_yup=True, export_def_bones=False, export_anim_single_armature=True)
    print("export", chemin)


def apercu(dst):
    """Planche de contrôle : corps neutre lié au squelette, 4 images par action (Cycles)."""
    from construire import creer_maillage, materiau
    from vetements import matrice_poids
    b = mh.base()
    co = mh.morpher({})
    fidx = b.faces_groupe("body")
    faces = b.faces[fidx]
    used = np.unique(faces.ravel())
    remap = -np.ones(len(b.v), dtype=np.int64)
    remap[used] = np.arange(len(used))
    from construire import vers_blender
    creer_maillage("Apercu", vers_blender(co[used], co[:13380, 1].min() * 0.1), remap[faces], b.vt[b.fuv[fidx]],
                   materiau("gris", (0.7, 0.7, 0.7)), dst, matrice_poids(len(b.v)), used)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = 320
    sc.render.resolution_y = 420
    sc.display.shading.light = "STUDIO"
    cam = bpy.data.cameras.new("cam")
    co_cam = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co_cam)
    sc.camera = co_cam
    sortie = os.path.join(RACINE, "assets", "personnages", "apercus", "anim")
    os.makedirs(sortie, exist_ok=True)
    from PIL import Image
    for tr in dst.animation_data.nla_tracks:
        act = tr.strips[0].action
        for t2 in dst.animation_data.nla_tracks:
            t2.mute = t2 != tr
        n = int(act.frame_range[1])
        vues = []
        for k, f in enumerate((1, max(1, n // 4), max(1, n // 2), max(1, 3 * n // 4))):
            sc.frame_set(f)
            ang = math.radians(-35 if k % 2 == 0 else 55)
            co_cam.location = (3.6 * math.sin(ang), -3.6 * math.cos(ang), 1.1)
            d = Vector((0, 0, 0.85)) - co_cam.location
            co_cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = "/tmp/claude-0/scratch/_v.png"
            bpy.ops.render.render(write_still=True)
            vues.append(Image.open(sc.render.filepath).convert("RGB"))
        planche = Image.new("RGB", (320 * 4, 420))
        for i, v in enumerate(vues):
            planche.paste(v, (i * 320, 0))
        planche.save(os.path.join(sortie, tr.name + ".png"))
    for t2 in dst.animation_data.nla_tracks:
        t2.mute = False


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args or list(CLIPS) + ["tout"])
