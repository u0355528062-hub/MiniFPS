"""Règle les options d'import des textures (compression VRAM, mipmaps, cartes de normales).

À lancer après un premier `godot --headless --import`, puis réimporter.
"""
import glob
import os
import re

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))


def regler(chemin, options):
    s = open(chemin).read()
    for cle, val in options.items():
        motif = re.compile(r"^%s=.*$" % re.escape(cle), re.M)
        if motif.search(s):
            s = motif.sub("%s=%s" % (cle, val), s)
        else:
            s = s.replace("[params]\n", "[params]\n\n%s=%s\n" % (cle, val), 1)
    open(chemin, "w").write(s)


for imp in glob.glob(os.path.join(RACINE, "assets", "textures", "**", "*.import"), recursive=True) + glob.glob(os.path.join(RACINE, "assets", "personnages", "textures", "**", "*.import"), recursive=True):
    opts = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
            "compress/high_quality": "false"}
    if os.path.basename(imp).startswith("normal."):
        opts["compress/normal_map"] = "1"
    regler(imp, opts)
print("imports réglés")
