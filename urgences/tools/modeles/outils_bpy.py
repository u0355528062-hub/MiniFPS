"""Outils de modélisation procédurale pour Blender (module bpy).

Chaque objet reçoit des matériaux nommés (« inox », « skai_bleu », « ecran »…) : le jeu remplace
ces matériaux à l'import par ceux de assets/materials/ (même nom), ce qui évite de dupliquer
les textures dans chaque modèle.
"""
import math
import bmesh
import bpy
from mathutils import Vector, Matrix


def vider_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for d in list(coll):
            coll.remove(d)


def materiau(nom, couleur=(0.8, 0.8, 0.8, 1.0), metal=0.0, rugosite=0.5, emission=None):
    m = bpy.data.materials.get(nom)
    if m is None:
        m = bpy.data.materials.new(nom)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = couleur
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rugosite
        if emission:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = 1.0
    return m


def _objet(nom, bm, mat, parent=None, lisse=True, angle=40.0):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    if lisse:
        for p in me.polygons:
            p.use_smooth = True
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    if mat is not None:
        o.data.materials.append(materiau(mat) if isinstance(mat, str) else mat)
    if parent is not None:
        o.parent = parent
    if lisse:
        _auto_lisse(o, angle)
    return o


def _auto_lisse(o, angle):
    """Lissage par angle : les arêtes vives restent nettes (équivalent de l'auto-smooth)."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    lim = math.radians(angle)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            if e.link_faces[0].normal.angle(e.link_faces[1].normal, 0) > lim:
                e.smooth = False
        else:
            e.smooth = False
    bm.to_mesh(me)
    bm.free()
    if hasattr(me, "set_sharp_from_angle"):
        me.set_sharp_from_angle(angle=lim)


def biseau(o, largeur=0.004, segments=2):
    """Ajoute un modificateur de biseau (appliqué à l'export) pour capter les reflets."""
    mod = o.modifiers.new("biseau", "BEVEL")
    mod.width = largeur
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(35)
    mod.harden_normals = True
    return o


def boite(nom, taille, pos=(0, 0, 0), mat=None, parent=None, arrondi=0.0, segments=3, rot=(0, 0, 0)):
    """Boîte centrée en pos (x, y, z en mètres, Z vers le haut comme dans Blender)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * taille[0], v.co.y * taille[1], v.co.z * taille[2]))
    o = _objet(nom, bm, mat, parent, lisse=False)
    o.location = pos
    o.rotation_euler = rot
    if arrondi > 0:
        biseau(o, arrondi, segments)
    return o


def cylindre(nom, rayon, hauteur, pos=(0, 0, 0), mat=None, segments=24, rot=(0, 0, 0),
             rayon2=None, biseau_l=0.0, ferme=True, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=ferme, cap_tris=False, segments=segments,
                          radius1=rayon, radius2=rayon if rayon2 is None else rayon2, depth=hauteur)
    o = _objet(nom, bm, mat, parent)
    o.location = pos
    o.rotation_euler = rot
    if biseau_l > 0:
        biseau(o, biseau_l, 2)
    return o


def sphere(nom, rayon, pos=(0, 0, 0), mat=None, parent=None, seg=24, anneaux=12, echelle=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=anneaux, radius=rayon)
    for v in bm.verts:
        v.co = Vector((v.co.x * echelle[0], v.co.y * echelle[1], v.co.z * echelle[2]))
    o = _objet(nom, bm, mat, parent, angle=80)
    o.location = pos
    return o


def tore(nom, R, r, pos=(0, 0, 0), mat=None, parent=None, seg=32, seg2=12, rot=(0, 0, 0), arc=2 * math.pi):
    bm = bmesh.new()
    verts = []
    n = seg if arc >= 2 * math.pi - 1e-4 else seg + 1
    for i in range(n):
        a = arc * i / seg
        anneau = []
        for j in range(seg2):
            b = 2 * math.pi * j / seg2
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            anneau.append(bm.verts.new((x, y, z)))
        verts.append(anneau)
    nb = n if arc >= 2 * math.pi - 1e-4 else n - 1
    for i in range(nb):
        a1 = verts[i]
        a2 = verts[(i + 1) % n]
        for j in range(seg2):
            bm.faces.new((a1[j], a2[j], a2[(j + 1) % seg2], a1[(j + 1) % seg2]))
    o = _objet(nom, bm, mat, parent, angle=80)
    o.location = pos
    o.rotation_euler = rot
    return o


def tube(nom, points, rayon, mat=None, parent=None, seg=12, bouts=True, rayons=None):
    """Tube le long d'une polyligne (points en mètres) ; rayons optionnels par point."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    anneaux = []
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        r = rayon if rayons is None else rayons[i]
        anneau = [bm.verts.new(p + (u * math.cos(2 * math.pi * k / seg) + v * math.sin(2 * math.pi * k / seg)) * r)
                  for k in range(seg)]
        anneaux.append(anneau)
    for i in range(len(anneaux) - 1):
        a, b = anneaux[i], anneaux[i + 1]
        for k in range(seg):
            bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    if bouts:
        bm.faces.new(list(reversed(anneaux[0])))
        bm.faces.new(anneaux[-1])
    o = _objet(nom, bm, mat, parent, angle=70)
    return o


def courbe_lisse(points, n=8):
    """Catmull-Rom : renvoie une polyligne lissée passant par les points."""
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1 = pts[i]
        p2 = pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tour(nom, profil, pos=(0, 0, 0), mat=None, parent=None, seg=32, rot=(0, 0, 0)):
    """Solide de révolution autour de Z ; profil = [(rayon, z), ...]."""
    bm = bmesh.new()
    anneaux = []
    for (r, z) in profil:
        if r < 1e-6:
            anneaux.append([bm.verts.new((0, 0, z))])
        else:
            anneaux.append([bm.verts.new((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z))
                            for k in range(seg)])
    for i in range(len(anneaux) - 1):
        a, b = anneaux[i], anneaux[i + 1]
        if len(a) == 1 and len(b) > 1:
            for k in range(seg):
                bm.faces.new((a[0], b[k], b[(k + 1) % seg]))
        elif len(b) == 1 and len(a) > 1:
            for k in range(seg):
                bm.faces.new((a[k], a[(k + 1) % seg], b[0]))
        elif len(a) > 1:
            for k in range(seg):
                bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _objet(nom, bm, mat, parent, angle=50)
    o.location = pos
    o.rotation_euler = rot
    return o


def extrusion(nom, contour, epaisseur, pos=(0, 0, 0), mat=None, parent=None, rot=(0, 0, 0)):
    """Extrude un contour 2D (x, y) sur Z (épaisseur centrée)."""
    bm = bmesh.new()
    bas = [bm.verts.new((x, y, -epaisseur / 2)) for (x, y) in contour]
    f = bm.faces.new(bas)
    res = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += epaisseur
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _objet(nom, bm, mat, parent, lisse=False)
    o.location = pos
    o.rotation_euler = rot
    return o


def roulette(nom, pos, parent=None, rayon=0.05, mat_roue="caoutchouc_noir", mat_fourche="plastique_gris"):
    """Roulette pivotante de mobilier hospitalier."""
    x, y, z = pos
    cylindre(nom + "_roue", rayon, 0.032, (x, y + 0.025, z + rayon), mat_roue, 20,
             (math.pi / 2, 0, 0), biseau_l=0.006, parent=parent)
    boite(nom + "_fourche", (0.045, 0.05, rayon * 1.3), (x, y + 0.012, z + rayon * 1.25), mat_fourche, parent,
          arrondi=0.008)
    cylindre(nom + "_pivot", 0.012, 0.05, (x, y, z + rayon * 2 + 0.03), "inox", 12, parent=parent)


def uv_cube(o, echelle=1.0):
    """Projection cubique en coordonnées monde (1 unité UV = 1 m / échelle) : textures à la bonne taille."""
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    mw = o.matrix_world
    for p in me.polygons:
        n = (mw.to_3x3() @ p.normal)
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u / echelle, v / echelle)


def finaliser_uv(echelle=1.0):
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            uv_cube(o, echelle)


def exporter(chemin, racine_nom="racine"):
    """Applique les modificateurs, regroupe par matériau, exporte en GLB (Y vers le haut)."""
    import os
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="PLACEHOLDER" if False else "EXPORT",
                              export_image_format="NONE")
    print("export", chemin)


def fusionner_tout(nom):
    """Fusionne tous les objets maillage en un seul (un appel de dessin par matériau)."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nom
    o.data.name = nom
    return o
