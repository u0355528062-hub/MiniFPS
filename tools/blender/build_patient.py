"""Patient des urgences : peau seule (l'anatomie interne de l'atlas n'est pas affichée), extraite de
patient_dos.glb (pose sur le dos, Z-Anatomy CC BY-SA 4.0).
    /home/user/bpyenv/bin/python tools/blender/build_patient.py"""
import os
import sys
import bpy
sys.path.insert(0, os.path.dirname(__file__))
import bl  # noqa: E402

bl.reset()
bpy.ops.import_scene.gltf(filepath=os.path.join(bl.ROOT, "assets", "models", "patient_dos.glb"))
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name != "Peau":
        bpy.data.objects.remove(o)
skin = bpy.data.objects["Peau"]
print("Peau", len(skin.data.vertices), "sommets")
bl.export("patient_urg", [skin])
