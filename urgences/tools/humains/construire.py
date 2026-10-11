"""Construit un personnage complet dans Blender (bpy) et l'exporte en GLB.

Usage : /opt/bpyenv/bin/python tools/humains/construire.py <id> [--apercu]
Les personnages sont décrits dans tools/humains/personnages.py.

Repère : MakeHuman (dm, Y haut, regarde +Z) → Blender (m, Z haut, regarde -Y) → glTF/Godot
(m, Y haut, regarde +Z). Toutes les orientations d'os sont CANONIQUES (calculées sur l'humain
neutre) : seules les positions des articulations changent d'un personnage à l'autre, si bien
qu'une même animation s'applique à tous.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import mh_donnees as mh  # noqa: E402
from vetements import Habilleur  # noqa: E402

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(RACINE, "assets", "personnages")

EXPRESSIONS = {
    "clignement": {"expression/units/caucasian/eye-left-closure": 1.0, "expression/units/caucasian/eye-right-closure": 1.0},
    "bouche_ouverte": {"expression/units/caucasian/mouth-open": 0.6},
    "douleur": {"expression/units/caucasian/eyebrows-left-inner-up": 0.8,
                "expression/units/caucasian/eyebrows-right-inner-up": 0.8,
                "expression/units/caucasian/eye-left-slit": 0.5, "expression/units/caucasian/eye-right-slit": 0.5,
                "expression/units/caucasian/mouth-retraction": 0.4, "expression/units/caucasian/nose-compression": 0.4},
    "sourire": {"expression/units/caucasian/mouth-corner-puller": 0.7, "expression/units/caucasian/eye-left-slit": 0.2,
                "expression/units/caucasian/eye-right-slit": 0.2},
}


def vers_blender(co_dm, decal_y):
    """MakeHuman (dm) → Blender (m)."""
    c = np.asarray(co_dm) * 0.1
    return np.stack([c[..., 0], -c[..., 2], c[..., 1] - decal_y], axis=-1)


def vider():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images, bpy.data.cameras,
                 bpy.data.lights):
        for d in list(coll):
            coll.remove(d)


# ---------------------------------------------------------------------------------------------
def os_canoniques():
    """Directions et normales de roulis des os pour l'humain neutre (repère Blender)."""
    co = mh.morpher({})
    res = {}
    for nom, parent, tete, queue, normale in mh.os_squelette(co):
        t = vers_blender(tete, 0)
        q = vers_blender(queue, 0)
        d = q - t
        n = None if normale is None else vers_blender(normale * 10.0, 0) - vers_blender(np.zeros(3), 0)
        res[nom] = (d / max(np.linalg.norm(d), 1e-9), n)
    return res


def creer_armature(co_dm, decal_y, nom="Squelette"):
    canon = os_canoniques()
    arm = bpy.data.armatures.new(nom)
    obj = bpy.data.objects.new(nom, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    liste = mh.os_squelette(co_dm)
    for nom_os, parent, tete, queue, _ in liste:
        eb = arm.edit_bones.new(nom_os)
        t = vers_blender(tete, decal_y)
        q = vers_blender(queue, decal_y)
        lg = max(np.linalg.norm(q - t), 0.005)
        d, n = canon[nom_os]
        eb.head = Vector(t)
        eb.tail = Vector(t + d * lg)
        if n is not None:
            eb.align_roll(Vector(n))
    for nom_os, parent, *_ in liste:
        if parent:
            arm.edit_bones[nom_os].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def materiau(nom, couleur=(0.8, 0.8, 0.8), textures=None, sss=0.0, alpha=None, rug=0.6):
    m = bpy.data.materials.get(nom)
    if m:
        return m
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*couleur, 1.0)
    bsdf.inputs["Roughness"].default_value = rug
    if sss > 0:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
        bsdf.inputs["Subsurface Scale"].default_value = 0.01
    if textures:
        if "albedo" in textures:
            im = nt.nodes.new("ShaderNodeTexImage")
            im.image = bpy.data.images.load(textures["albedo"])
            nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
            if alpha:
                nt.links.new(im.outputs["Alpha"], bsdf.inputs["Alpha"])
        if "normal" in textures:
            im = nt.nodes.new("ShaderNodeTexImage")
            im.image = bpy.data.images.load(textures["normal"])
            im.image.colorspace_settings.name = "Non-Color"
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(im.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        if "orm" in textures:
            im = nt.nodes.new("ShaderNodeTexImage")
            im.image = bpy.data.images.load(textures["orm"])
            im.image.colorspace_settings.name = "Non-Color"
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(im.outputs["Color"], sep.inputs["Color"])
            nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    return m


def creer_maillage(nom, co_b, faces, uvs_par_coin, mat, arm_obj, poids_src, origine):
    """co_b : sommets (Blender), faces : liste de quads (indices locaux), uvs_par_coin : (F, 4, 2)."""
    me = bpy.data.meshes.new(nom)
    me.from_pydata(co_b.tolist(), [], [list(f) for f in faces])
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    flat = np.asarray(uvs_par_coin).reshape(-1, 2)
    uv.data.foreach_set("uv", flat.ravel())
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    # Poids de peau.
    for os_, w in poids_src.items():
        ws = w[origine]
        nz = np.nonzero(ws > 1e-4)[0]
        if len(nz) == 0:
            continue
        vg = obj.vertex_groups.new(name=os_)
        for i in nz:
            vg.add([int(i)], float(ws[i]), "REPLACE")
    mod = obj.modifiers.new("Squelette", "ARMATURE")
    mod.object = arm_obj
    obj.parent = arm_obj
    return obj


# ---------------------------------------------------------------------------------------------
def construire(p, apercu=False):
    from personnages import textures_peau, textures_tenue, textures_cheveux
    vider()
    pid = p["id"]
    co_dm = mh.morpher(p["morpho"])
    b = mh.base()
    decal_y = co_dm[:13380, 1].min() * 0.1
    art_dm = mh.articulations(co_dm)
    co_mh_m = co_dm * 0.1
    art_m = {k: v * 0.1 for k, v in art_dm.items()}
    arm = creer_armature(co_dm, decal_y)
    hab = Habilleur(co_mh_m, art_m)
    poids = hab.poids

    # Vêtements (avant le corps : ils décident des faces de peau cachées).
    vets = []
    tenue = p.get("tenue", {})
    for piece in tenue.get("pieces", []):
        genre_piece = piece["type"]
        args = {k: v for k, v in piece.items() if k not in ("type",)}
        vets.append(getattr(hab, genre_piece)(**args))
    if p.get("cheveux"):
        ch = p["cheveux"]
        vets.append(hab.cheveux("cheveux_" + ch["couleur"], ch.get("coupe", "court"), ch.get("volume", 0.012)))

    # Corps + dents + langue + cils.
    f_vis = hab.faces_corps_visibles()
    tex_peau = textures_peau(p)
    mat_peau = materiau("peau_" + tex_peau["cle"], (0.8, 0.6, 0.5), tex_peau, sss=0.25, rug=0.5)
    objets = []
    for nom_obj, fidx, mat in (
        ("Corps", f_vis, mat_peau),
        ("Dents", b.faces_groupe("helper-upper-teeth", "helper-lower-teeth"), materiau("dents", (0.85, 0.82, 0.74), rug=0.3)),
        ("Langue", b.faces_groupe("helper-tongue"), materiau("langue", (0.6, 0.25, 0.25), rug=0.4)),
    ):
        faces = b.faces[fidx]
        used = np.unique(faces.ravel())
        remap = -np.ones(len(b.v), dtype=np.int64)
        remap[used] = np.arange(len(used))
        o = creer_maillage(nom_obj, vers_blender(co_dm[used], decal_y), remap[faces], b.vt[b.fuv[fidx]], mat, arm,
                           poids, used)
        objets.append((o, used))
    corps, corps_used = objets[0]

    # Expressions faciales (clés de forme) sur le corps.
    corps.shape_key_add(name="Basis", from_mix=False)
    for nom_k, cibles in EXPRESSIONS.items():
        delta = np.zeros_like(co_dm)
        for c, k in cibles.items():
            t = mh.cible(c)
            if t is not None:
                delta[t[0]] += k * t[1]
        sk = corps.shape_key_add(name=nom_k, from_mix=False)
        sk.value = 0.0
        cible_b = vers_blender(co_dm[corps_used] + delta[corps_used], decal_y)
        sk.data.foreach_set("co", cible_b.astype(np.float32).ravel())

    # Yeux (proxy haute définition).
    pr = mh.Proxy(os.path.join(mh.MH, "eyes", "high-poly", "high-poly.mhclo"))
    yeux_co = pr.ajuster(co_dm)
    mat_oeil = materiau("oeil_" + p.get("yeux", "marron"), (0.4, 0.25, 0.1),
                        {"albedo": os.path.join(mh.MH, "eyes", "materials", "brown_eye.png")}, rug=0.05)
    f_y = [f if len(f) == 4 else [f[0], f[1], f[2], f[2]] for f in pr.faces]
    fuv_y = [f if len(f) == 4 else [f[0], f[1], f[2], f[2]] for f in pr.fuv]
    poids_yeux = {}
    for os_, w in poids.items():
        wy = (w[pr.refs[:, 0]] * pr.poids[:, 0] + w[pr.refs[:, 1]] * pr.poids[:, 1] + w[pr.refs[:, 2]] * pr.poids[:, 2])
        if wy.max() > 1e-4:
            poids_yeux[os_] = wy
    creer_maillage("Yeux", vers_blender(yeux_co, decal_y), f_y, pr.vt[np.array(fuv_y)], mat_oeil, arm,
                   poids_yeux, np.arange(len(yeux_co)))

    # Vêtements et cheveux.
    for v in vets:
        if v.materiau.startswith("cheveux_"):
            tex = textures_cheveux(v.materiau[8:])
            mat = materiau(v.materiau, (0.1, 0.07, 0.05), tex, rug=0.45, alpha=True)
            mat.blend_method = "HASHED" if hasattr(mat, "blend_method") else None
        else:
            tex = textures_tenue(v.materiau.replace("tenue_", "", 1))
            mat = materiau(v.materiau, (0.3, 0.5, 0.7), tex, rug=0.85)
        uvs = b.vt[v.fuv]
        if v.nom.endswith("Bas"):
            # Les aides (jupe) ont leurs propres UV hors de l'atlas du corps : projection
            # cylindrique dans l'îlot du dos (grand et continu) pour garder le tissage.
            c = v.co[v.faces]
            ang = np.arctan2(c[..., 0], c[..., 2])
            hy = c[..., 1]
            uvs = np.stack([0.28 + 0.30 * (ang + np.pi) / (2 * np.pi),
                            0.40 + 0.30 * (hy - hy.min()) / max(np.ptp(hy), 1e-6)], -1)
        creer_maillage(v.nom, vers_blender(v.co * 10.0, decal_y), v.faces, uvs, mat, arm, poids, v.origine)

    os.makedirs(os.path.join(SORTIE, "modeles"), exist_ok=True)
    chemin = os.path.join(SORTIE, "modeles", pid + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", use_selection=True, export_skins=True,
                              export_morph=True, export_morph_normal=False, export_animations=False,
                              export_apply=False, export_yup=True, export_image_format="NONE",
                              export_materials="EXPORT")
    print("export", chemin)
    if apercu:
        rendre_apercu(pid, arm)
    return arm


# ---------------------------------------------------------------------------------------------
def rendre_apercu(pid, arm, chemin=None, pose=None):
    """Rendu Cycles (CPU) : vue de face en pied + gros plan du visage."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("monde") if not bpy.data.worlds else bpy.data.worlds[0]
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.4, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    for nom, loc, e, taille in (("cle", (2.0, -3.0, 2.6), 900, 1.5), ("contre", (-2.5, -1.0, 2.0), 350, 2.0),
                                ("dos", (0.5, 3.0, 2.5), 500, 1.0)):
        ld = bpy.data.lights.new(nom, "AREA")
        ld.energy = e
        ld.size = taille
        lo = bpy.data.objects.new(nom, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
        d = Vector((0, 0, 1.2)) - lo.location
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.cameras.new("cam")
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    tete = arm.data.bones["head"].head_local
    sortie = os.path.join(SORTIE, "apercus")
    os.makedirs(sortie, exist_ok=True)
    for nom, loc, cible, lens in (("pied", (0.0, -4.2, 1.0), (0, 0, 0.9), 50),
                                  ("visage", (0.25, -0.75, tete.z + 0.12), (0, 0, tete.z + 0.1), 85)):
        co.location = loc
        d = Vector(cible) - Vector(loc)
        co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.lens = lens
        sc.render.filepath = os.path.join(sortie, "%s_%s.png" % (pid, nom))
        bpy.ops.render.render(write_still=True)
        print("apercu", sc.render.filepath)


if __name__ == "__main__":
    from personnages import PERSONNAGES
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for pid in args or list(PERSONNAGES):
        construire(PERSONNAGES[pid], apercu="--apercu" in sys.argv)
