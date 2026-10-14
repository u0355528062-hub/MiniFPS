"""Petite bibliothèque de modélisation pour Blender (module bpy) : primitives biseautées, tubes,
matériaux PBR, export glTF (.glb) et aperçu rendu (Cycles, CPU).

Repère : Blender Z vers le haut ; l'export glTF passe en Y vers le haut (Godot) :
    Godot (x, y, z) = Blender (x, z, -y)
Les fonctions acceptent des coordonnées Godot via `g(x, y, z)` pour éviter les erreurs.

Usage : /home/user/bpyenv/bin/python tools/blender/build_models.py [nom ...]
"""
import math
import os

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.environ.get("MODELS_OUT", os.path.join(ROOT, "assets", "models"))


def g(x, y, z):
    """Point Godot -> point Blender."""
    return Vector((x, -z, y))


# ---------------------------------------------------------------- Scène

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.curves, bpy.data.images):
        for b in list(c):
            c.remove(b)


_MATS = {}


def mat(name, color, rough=0.5, metal=0.0, spec=0.5, clearcoat=0.0, alpha=1.0, emission=None, emission_strength=1.0,
        transmission=0.0, coat_rough=0.05):
    """Matériau principled (exporté tel quel en glTF : couleur, rugosité, métal, émission)."""
    key = name
    if key in _MATS and _MATS[key].name in bpy.data.materials:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if len(color) == 3:
        color = (*color, 1.0)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if clearcoat > 0:
        bsdf.inputs["Coat Weight"].default_value = clearcoat
        bsdf.inputs["Coat Roughness"].default_value = coat_rough
    if transmission > 0:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    _MATS[key] = m
    return m


def _link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def _obj_from_bm(bm, name, material=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    _link(ob)
    if material is not None:
        me.materials.append(material)
    return ob


def set_mat(ob, material):
    ob.data.materials.clear()
    ob.data.materials.append(material)
    return ob


def smooth(ob, angle=35.0):
    """Lissage des normales jusqu'à `angle` degrés (arêtes vives au-delà)."""
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    mod = ob.modifiers.new("Lissage", "NODES")
    try:
        bpy.context.view_layer.objects.active = ob
        ob.modifiers.remove(mod)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        try:
            me.set_sharp_from_angle(angle=math.radians(angle))
        except Exception:
            pass
    return ob


def flat(ob):
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def bevel(ob, width, segments=3, angle=40.0):
    m = ob.modifiers.new("Biseau", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.harden_normals = False
    return ob


def subsurf(ob, levels=2):
    m = ob.modifiers.new("Subdiv", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return ob


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for m in list(ob.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e:
            print("modifier", m.name, e)
    return ob


# ---------------------------------------------------------------- Primitives (coordonnées Blender)

def box(name, size, loc, material=None, bev=0.0, seg=3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    if bev > 0:
        bevel(ob, bev, seg)
        smooth(ob, 40)
    else:
        flat(ob)
    return ob


def cyl(name, r, depth, loc, material=None, rot=(0, 0, 0), verts=32, bev=0.0, seg=2, r2=None, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    if bev > 0:
        bevel(ob, bev, seg, angle=50)
    smooth(ob, 50)
    return ob


def cyl_between(name, a, b, r, material=None, verts=24, bev=0.0, r2=None):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    ob = cyl(name, r, d.length, (a + b) / 2, material, verts=verts, bev=bev, r2=r2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def sphere(name, r, loc, material=None, seg=24, rings=12, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.scale = scale
    smooth(ob, 80)
    return ob


def torus(name, R, r, loc, material=None, rot=(0, 0, 0), major=48, minor=12):
    bm = bmesh.new()
    verts = []
    for i in range(major):
        a = 2 * math.pi * i / major
        ring = []
        for j in range(minor):
            b = 2 * math.pi * j / minor
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        verts.append(ring)
    for i in range(major):
        for j in range(minor):
            a = verts[i][j]
            b = verts[(i + 1) % major][j]
            c = verts[(i + 1) % major][(j + 1) % minor]
            d = verts[i][(j + 1) % minor]
            bm.faces.new((a, b, c, d))
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    smooth(ob, 80)
    return ob


def tube(name, pts, r, material=None, sides=16, closed=False, caps=True):
    """Tube le long d'une polyligne (points Blender), rayon constant ou liste."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    radii = r if isinstance(r, (list, tuple)) else [r] * n
    bm = bmesh.new()
    rings = []
    # repères par transport parallèle
    t0 = (pts[1] - pts[0]).normalized()
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = t0.cross(ref).normalized()
    for i in range(n):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        elif i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == n - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (pts[i + 1] - pts[i - 1]).normalized()
        nrm = (nrm - t * nrm.dot(t)).normalized()
        bn = t.cross(nrm)
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            ring.append(bm.verts.new(pts[i] + (nrm * math.cos(a) + bn * math.sin(a)) * radii[i]))
        rings.append(ring)
    m = n if closed else n - 1
    for i in range(m):
        r0 = rings[i]
        r1 = rings[(i + 1) % n]
        for s in range(sides):
            bm.faces.new((r0[s], r0[(s + 1) % sides], r1[(s + 1) % sides], r1[s]))
    if caps and not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    ob = _obj_from_bm(bm, name, material)
    smooth(ob, 60)
    return ob


def bezier_pts(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        out.append(Vector(p0) * u ** 3 + Vector(p1) * 3 * u * u * t + Vector(p2) * 3 * u * t * t + Vector(p3) * t ** 3)
    return out


def arc_pts(c, R, a0, a1, n=16, plane="xy"):
    out = []
    for i in range(n):
        a = a0 + (a1 - a0) * i / (n - 1)
        if plane == "xy":
            out.append(Vector(c) + Vector((math.cos(a) * R, math.sin(a) * R, 0)))
        elif plane == "xz":
            out.append(Vector(c) + Vector((math.cos(a) * R, 0, math.sin(a) * R)))
        else:
            out.append(Vector(c) + Vector((0, math.cos(a) * R, math.sin(a) * R)))
    return out


def rounded_rect_path(w, d, r, n=6, z=0.0):
    """Contour d'un rectangle arrondi (plan XY), sens trigonométrique."""
    pts = []
    cs = [(w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)]
    for cx, cy, a0 in cs:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append(Vector((cx + r * math.cos(a), cy + r * math.sin(a), z)))
    return pts


def extrude_profile(name, pts2d, height, z0=0.0, material=None, bev=0.0, seg=3):
    """Prisme : contour (x, y) extrudé de z0 à z0 + height."""
    bm = bmesh.new()
    bot = [bm.verts.new((p[0], p[1], z0)) for p in pts2d]
    top = [bm.verts.new((p[0], p[1], z0 + height)) for p in pts2d]
    n = len(pts2d)
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(bm, name, material)
    if bev > 0:
        bevel(ob, bev, seg)
    smooth(ob, 40)
    return ob


def lathe(name, profile, material=None, segments=48, loc=(0, 0, 0), rot=(0, 0, 0), cap_top=False, cap_bottom=False):
    """Révolution autour de Z d'un profil [(rayon, z), ...]."""
    bm = bmesh.new()
    rings = []
    for (rr, zz) in profile:
        ring = []
        for s in range(segments):
            a = 2 * math.pi * s / segments
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(segments):
            a = rings[i][s]
            b = rings[i][(s + 1) % segments]
            c = rings[i + 1][(s + 1) % segments]
            d = rings[i + 1][s]
            bm.faces.new((a, b, c, d))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    smooth(ob, 50)
    return ob


def text(name, body, size, loc, material=None, rot=(math.radians(90), 0, 0), extrude=0.0005, align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new(name, cu)
    _link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    if material:
        set_mat(ob, material)
    return ob


def caster(name, loc, material_wheel, material_metal, r=0.05, yaw=0.0):
    """Roulette pivotante (chape, roue, axe)."""
    x, y, z = loc
    parts = []
    parts.append(cyl(name + "_pivot", 0.012, 0.03, (x, y, z + 2 * r + 0.02), material_metal, verts=16))
    parts.append(box(name + "_chape", (0.012, 0.045, 0.012), (x, y, z + 2 * r + 0.004), material_metal, bev=0.003))
    for sx in (-1, 1):
        parts.append(box(name + "_flasque%d" % sx, (0.004, 0.04, r * 1.4), (x + sx * 0.017, y - 0.012, z + r + 0.008), material_metal, bev=0.0015))
    w = cyl(name + "_roue", r, 0.026, (x, y - 0.015, z + r), material_wheel, rot=(0, math.radians(90), 0), verts=28, bev=0.006, seg=3)
    parts.append(w)
    parts.append(cyl(name + "_moyeu", r * 0.45, 0.03, (x, y - 0.015, z + r), material_metal, rot=(0, math.radians(90), 0), verts=16))
    ob = join(parts, name)
    if yaw:
        rotate_about(ob, (x, y, z), yaw)
    return ob


def rotate_about(ob, pivot, yaw):
    apply_all(ob)
    pv = Vector(pivot)
    M = Matrix.Translation(pv) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Translation(-pv)
    ob.data.transform(M @ ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in objs:
        apply_all(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def bake_transforms(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def finalize(objs=None):
    """Applique modificateurs et transformations de tout ce qui est dans la scène."""
    objs = objs or [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        apply_all(o)
        bake_transforms(o)


def merge_by_material(name):
    """Fusionne tous les maillages en un seul objet (un sous-maillage par matériau à l'export)."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    finalize(objs)
    return join(objs, name)


def tri_count():
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            n += sum(len(p.vertices) - 2 for p in me.polygons)
    return n


def export(name, objs=None):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    sel = objs or [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in sel:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
    print("EXPORT", path, "triangles", tri_count())
    return path


# ---------------------------------------------------------------- Aperçu

def preview(path, cam_loc, target, size=(800, 600), samples=24, lens=40, floor=True):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("Monde")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.6, 0.62, 1)
    bg.inputs[1].default_value = 0.6
    sc.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("Cam", cam_data)
    _link(cam)
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    for (loc, en, sz) in [((2, -2, 4), 600, 2.0), ((-3, -1, 2.5), 250, 3.0), ((0, 3, 3), 200, 3.0)]:
        ld = bpy.data.lights.new("L", "AREA")
        ld.energy = en
        ld.size = sz
        lo = bpy.data.objects.new("L", ld)
        _link(lo)
        lo.location = loc
        dd = Vector(target) - Vector(loc)
        lo.rotation_euler = dd.to_track_quat("-Z", "Y").to_euler()
    if floor:
        f = box("_sol", (20, 20, 0.01), (0, 0, -0.005), mat("_sol", (0.35, 0.38, 0.38), 0.6))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if floor:
        bpy.data.objects.remove(f)
    print("APERCU", path)
