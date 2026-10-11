"""Export Windows découpé en zips de moins de 30 Mo, qui se décompressent dans le même dossier.

Contenu livré :
- Urgences.exe   : modèle d'exécution Godot 4.4.1 compressé avec UPX (zip ≈ 29,99 Mo) ;
- Urgences.pck   : scripts, scènes, matériaux, polices (paquet principal) ;
- donnees_NN.pck : textures et modèles, répartis en paquets d'environ 25 Mo, montés au
                   démarrage par l'autoload « Paquets ».

Usage : python3 tools/exporter.py   (sortie : ../telechargement/urgences/*.zip)
Prérequis : modèles d'export 4.4.1 installés, /opt/godot/tpl/windows_release_upx.exe.
"""
import glob
import os
import re
import shutil
import subprocess
import zipfile

RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
BUILD = os.path.join(RACINE, "build", "windows")
SORTIE = os.path.normpath(os.path.join(RACINE, "..", "telechargement", "urgences"))
MODELE_UPX = "/opt/godot/tpl/windows_release_upx.exe"
LOURDS = ["assets/textures", "assets/personnages", "assets/models"]
TAILLE_PAQUET = 44 * 1024 * 1024


def taille_importee(res):
    """Taille des fichiers importés (.ctex, .scn…) d'une ressource."""
    imp = os.path.join(RACINE, res + ".import")
    if not os.path.exists(imp):
        return os.path.getsize(os.path.join(RACINE, res))
    s = open(imp).read()
    m = re.search(r'dest_files=\[(.*?)\]', s)
    total = 0
    if m:
        for p in re.findall(r'"res://(.*?)"', m.group(1)):
            f = os.path.join(RACINE, p)
            if os.path.exists(f):
                total += os.path.getsize(f)
    return total


def lister_lourds():
    res = []
    for d in LOURDS:
        for f in sorted(glob.glob(os.path.join(RACINE, d, "**", "*"), recursive=True)):
            if os.path.isdir(f) or f.endswith(".import") or "/apercus/" in f or f.endswith(".gdignore"):
                continue
            rel = os.path.relpath(f, RACINE)
            if not os.path.exists(f + ".import"):
                continue  # seules les ressources importées vont dans les paquets
            res.append((rel, taille_importee(rel)))
    return res


def paquets(ressources):
    groupes, courant, taille = [], [], 0
    for rel, t in ressources:
        if courant and taille + t > TAILLE_PAQUET:
            groupes.append(courant)
            courant, taille = [], 0
        courant.append(rel)
        taille += t
    if courant:
        groupes.append(courant)
    return groupes


def ecrire_presets(groupes):
    commun_options = """
custom_template/debug=""
custom_template/release="%s"
debug/export_console_wrapper=0
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=false
application/product_name="Urgences"
application/file_description="Urgences - simulateur de service d'urgences"
""" % MODELE_UPX
    exclus = ", ".join(d + "/*" for d in LOURDS) + ", tools/*, build/*, *.md"
    txt = """[preset.0]

name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="%s"
export_path="build/windows/Urgences.exe"
script_export_mode=2

[preset.0.options]
%s""" % (exclus, commun_options)
    for i, g in enumerate(groupes, 1):
        fichiers = ", ".join('"res://%s"' % f for f in g)
        txt += """
[preset.%d]

name="Donnees %02d"
platform="Windows Desktop"
runnable=false
export_filter="resources"
export_files=PackedStringArray(%s)
include_filter=""
exclude_filter=""
export_path="build/windows/donnees_%02d.pck"
script_export_mode=2

[preset.%d.options]
%s""" % (i, i, fichiers, i, i, commun_options)
    open(os.path.join(RACINE, "export_presets.cfg"), "w").write(txt)


def godot(*args):
    r = subprocess.run(["godot", "--headless", "--path", RACINE] + list(args), capture_output=True, text=True)
    erreurs = [l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l or "SCRIPT" in l]
    for e in erreurs[:10]:
        print("  ", e)
    return r.returncode


def main():
    shutil.rmtree(BUILD, ignore_errors=True)
    os.makedirs(BUILD, exist_ok=True)
    groupes = paquets(lister_lourds())
    ecrire_presets(groupes)
    print("paquets de données :", len(groupes))
    godot("--export-release", "Windows", os.path.join(BUILD, "Urgences.exe"))
    for i in range(1, len(groupes) + 1):
        godot("--export-pack", "Donnees %02d" % i, os.path.join(BUILD, "donnees_%02d.pck" % i))
    # Zips : un par fichier lourd (chacun < 30 Mo), le reste avec le paquet principal.
    shutil.rmtree(SORTIE, ignore_errors=True)
    os.makedirs(SORTIE, exist_ok=True)
    fichiers = sorted(os.listdir(BUILD))
    n = 0
    for f in fichiers:
        n += 1
        z = os.path.join(SORTIE, "Urgences-Windows-partie%02d.zip" % n)
        with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            zf.write(os.path.join(BUILD, f), f)
            if f == "Urgences.pck":
                zf.writestr("LISEZMOI.txt", "Décompressez TOUS les zips Urgences-Windows-partieNN dans le même "
                            "dossier, puis lancez Urgences.exe.\n")
        mo = os.path.getsize(z) / 1048576
        print("%-32s %6.1f Mo %s" % (os.path.basename(z), mo, "TROP GROS" if mo >= 30 else ""))


if __name__ == "__main__":
    main()
