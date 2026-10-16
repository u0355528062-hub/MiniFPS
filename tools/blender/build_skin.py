"""Textures de peau du patient (UV du maillage MakeHuman, CC0) cuites dans Blender (Cycles) :
  - peau_albedo.png : teint irrégulier, rougeurs (oreilles, joues, nez), lèvres, aréoles, ongles,
    paupières, grain ;
  - peau_normal.png : pores et grain de la peau (relief) ;
  - peau_masques.png : R lèvres, G ongles, B visage (cyanose, rougeur) ;
  - peau_poils.png : R cheveux courts, G sourcils, B barbe naissante (couleur choisie par le jeu).
Masques de régions : textures MPFB2 (CC0) et zones calculées sur la tête du modèle.

    /home/user/bpyenv/bin/python tools/blender/build_skin.py
"""
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402
import mh  # noqa: E402

OUT = os.path.join(bl.ROOT, "assets", "textures")
RES = 2048
MASKS = os.path.join(mh.MPFB, "textures")


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def hair_weights(b):
    """Poids par sommet (décimètres, repère MakeHuman) : cuir chevelu, sourcils, barbe."""
    v = b.v
    el = b.joint("joint-l-eye")
    er = b.joint("joint-r-eye")
    e = (el + er) * 0.5
    n = len(v)
    brows = np.zeros(n)
    for eye in (el, er):
        s = 1.0 if eye[0] > 0 else -1.0
        dx = (v[:, 0] - eye[0]) * s
        dy = v[:, 1] - eye[1]
        yc = 0.16 + 0.035 * dx - 0.12 * dx * dx
        thick = 0.045 * (1.0 - smooth(0.1, 0.32, dx) * 0.6)
        w = (1 - smooth(thick * 0.55, thick, np.abs(dy - yc))) * smooth(-0.16, -0.1, dx) * (1 - smooth(0.26, 0.34, dx))
        w *= (v[:, 2] > eye[2] - 0.12)
        brows = np.maximum(brows, w)
    # Cuir chevelu : au-dessus d'une ligne de cheveux qui descend du front vers la nuque
    hc = e + np.array([0.0, 0.15, -0.55])
    d = v - hc
    horiz = np.stack([d[:, 0], d[:, 2]], 1)
    hn = np.linalg.norm(horiz, axis=1) + 1e-6
    front = d[:, 2] / hn
    side = np.abs(d[:, 0]) / hn
    line = np.where(front > 0, 0.62 * front ** 0.7 + 0.32 * (1 - front ** 0.7), 0.32 + (front) * 0.85)
    line = np.where((side > 0.75) & (front > -0.3) & (front < 0.4), 0.38, line)
    scalp = smooth(-0.02, 0.05, v[:, 1] - e[1] - line) * (np.linalg.norm(d, axis=1) < 1.6)
    # Barbe naissante : bas du visage (sous le nez), joues, menton, mâchoire
    rel = v - e
    beard = smooth(-0.95, -0.85, rel[:, 1]) * (1 - smooth(-0.42, -0.34, rel[:, 1]))
    beard *= smooth(-0.55, -0.35, rel[:, 2])
    cheek = (np.abs(rel[:, 0]) > 0.25) * smooth(-0.42, -0.2, rel[:, 1]) * (1 - smooth(-0.2, -0.12, rel[:, 1]))
    beard = np.maximum(beard, cheek * smooth(-0.4, -0.25, rel[:, 2]))
    beard *= (np.abs(rel[:, 0]) < 0.62)
    return scalp, brows, beard


def node(nt, kind, loc, **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, val in inputs.items():
        n.inputs[k].default_value = val
    return n


def img_node(nt, path, loc, color=False):
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(path)
    if not color:
        n.image.colorspace_settings.name = "Non-Color"
    n.location = loc
    return n


def bake(ob, mat_builder, name, kind="EMIT", res=RES, colorspace="sRGB"):
    img = bpy.data.images.new(name, res, res, alpha=False, float_buffer=False)
    img.colorspace_settings.name = colorspace
    mat = bpy.data.materials.new("bake_" + name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    shader = mat_builder(nt)
    nt.links.new(shader.outputs[0], out.inputs[0])
    tgt = nt.nodes.new("ShaderNodeTexImage")
    tgt.image = img
    nt.nodes.active = tgt
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 4
    sc.render.bake.margin = 8
    if kind == "NORMAL":
        sc.render.bake.normal_space = "TANGENT"
        bpy.ops.object.bake(type="NORMAL")
    else:
        bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("TEXTURE", img.filepath_raw)


def main():
    bl.reset()
    b = mh.Base()
    b.apply_target("macrodetails/caucasian-male-young", 0.55)
    b.apply_target("macrodetails/caucasian-male-old", 0.45)
    scalp, brows, beard = hair_weights(b)
    ob = mh.build_mesh(b, {"body"}, "Peau")
    attr = ob.data.color_attributes.new("poils", "FLOAT_COLOR", "POINT")
    for i in range(len(b.v)):
        attr.data[i].color = (float(scalp[i]), float(brows[i]), float(beard[i]), 1.0)
    mh.remove_loose(ob)

    def tex(nt, f, loc):
        return img_node(nt, os.path.join(MASKS, f), loc)

    def albedo(nt):
        tc = node(nt, "ShaderNodeTexCoord", (-1400, 0))
        n1 = node(nt, "ShaderNodeTexNoise", (-1200, 300), Scale=6.0, Detail=4.0)
        nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
        n2 = node(nt, "ShaderNodeTexNoise", (-1200, 0), Scale=900.0, Detail=2.0)
        nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
        base = node(nt, "ShaderNodeRGB", (-1000, 400))
        base.outputs[0].default_value = (0.60, 0.33, 0.235, 1)
        warm = node(nt, "ShaderNodeRGB", (-1000, 250))
        warm.outputs[0].default_value = (0.66, 0.30, 0.22, 1)
        mix1 = node(nt, "ShaderNodeMix", (-800, 300))
        mix1.data_type = "RGBA"
        nt.links.new(n1.outputs["Fac"], mix1.inputs["Factor"])
        nt.links.new(base.outputs[0], mix1.inputs[6])
        nt.links.new(warm.outputs[0], mix1.inputs[7])
        # Grain : léger assombrissement aléatoire
        grain = node(nt, "ShaderNodeMath", (-800, 0))
        grain.operation = "MULTIPLY_ADD"
        nt.links.new(n2.outputs["Fac"], grain.inputs[0])
        grain.inputs[1].default_value = 0.08
        grain.inputs[2].default_value = 0.96
        mul = node(nt, "ShaderNodeMix", (-600, 200))
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        nt.links.new(mix1.outputs[2], mul.inputs[6])
        nt.links.new(grain.outputs[0], mul.inputs[7])
        col = mul.outputs[2]

        def overlay(col, mask_file, rgb, strength, loc):
            m = tex(nt, mask_file, (loc[0] - 200, loc[1] - 150))
            c = node(nt, "ShaderNodeRGB", (loc[0] - 200, loc[1] + 100))
            c.outputs[0].default_value = (*rgb, 1)
            f = node(nt, "ShaderNodeMath", (loc[0] - 100, loc[1] - 150))
            f.operation = "MULTIPLY"
            nt.links.new(m.outputs[0], f.inputs[0])
            f.inputs[1].default_value = strength
            mx = node(nt, "ShaderNodeMix", loc)
            mx.data_type = "RGBA"
            nt.links.new(f.outputs[0], mx.inputs["Factor"])
            nt.links.new(col, mx.inputs[6])
            nt.links.new(c.outputs[0], mx.inputs[7])
            return mx.outputs[2]

        col = overlay(col, "mpfb_face.jpg", (0.66, 0.27, 0.21), 0.25, (-300, 300))
        col = overlay(col, "mpfb_ears.jpg", (0.62, 0.24, 0.19), 0.45, (-100, 300))
        col = overlay(col, "mpfb_eyelids.jpg", (0.46, 0.22, 0.19), 0.35, (100, 300))
        col = overlay(col, "mpfb_aureolae.jpg", (0.33, 0.15, 0.11), 0.85, (300, 300))
        col = overlay(col, "mpfb_lips.jpg", (0.42, 0.13, 0.12), 0.85, (500, 300))
        col = overlay(col, "mpfb_fingernails.jpg", (0.72, 0.48, 0.42), 0.8, (700, 300))
        col = overlay(col, "mpfb_toenails.jpg", (0.72, 0.48, 0.42), 0.8, (900, 300))
        em = node(nt, "ShaderNodeEmission", (1100, 300))
        nt.links.new(col, em.inputs["Color"])
        return em

    bake(ob, albedo, "peau_albedo")

    def masks(nt):
        lips = tex(nt, "mpfb_lips.jpg", (-600, 300))
        nails = tex(nt, "mpfb_fingernails.jpg", (-600, 0))
        toes = tex(nt, "mpfb_toenails.jpg", (-600, -150))
        face = tex(nt, "mpfb_face.jpg", (-600, -300))
        mx = node(nt, "ShaderNodeMath", (-400, 0))
        mx.operation = "MAXIMUM"
        nt.links.new(nails.outputs[0], mx.inputs[0])
        nt.links.new(toes.outputs[0], mx.inputs[1])
        comb = node(nt, "ShaderNodeCombineColor", (-200, 0))
        nt.links.new(lips.outputs[0], comb.inputs[0])
        nt.links.new(mx.outputs[0], comb.inputs[1])
        nt.links.new(face.outputs[0], comb.inputs[2])
        em = node(nt, "ShaderNodeEmission", (0, 0))
        nt.links.new(comb.outputs[0], em.inputs["Color"])
        return em

    bake(ob, masks, "peau_masques", res=1024, colorspace="Non-Color")

    def hairmask(nt):
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "poils"
        em = node(nt, "ShaderNodeEmission", (200, 0))
        nt.links.new(a.outputs["Color"], em.inputs["Color"])
        return em

    bake(ob, hairmask, "peau_poils", res=1024, colorspace="Non-Color")

    def normal(nt):
        tc = node(nt, "ShaderNodeTexCoord", (-800, 0))
        pores = node(nt, "ShaderNodeTexVoronoi", (-600, 0), Scale=2200.0)
        nt.links.new(tc.outputs["Object"], pores.inputs["Vector"])
        fine = node(nt, "ShaderNodeTexNoise", (-600, -250), Scale=700.0, Detail=6.0)
        nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
        add = node(nt, "ShaderNodeMath", (-400, -100))
        add.operation = "MULTIPLY_ADD"
        nt.links.new(fine.outputs["Fac"], add.inputs[0])
        add.inputs[1].default_value = 0.6
        nt.links.new(pores.outputs["Distance"], add.inputs[2])
        bump = node(nt, "ShaderNodeBump", (-200, 0), Strength=0.35, Distance=0.0006)
        nt.links.new(add.outputs[0], bump.inputs["Height"])
        bsdf = node(nt, "ShaderNodeBsdfPrincipled", (0, 0))
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
        return bsdf

    bake(ob, normal, "peau_normal", kind="NORMAL", colorspace="Non-Color")


main()
