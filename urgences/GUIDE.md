# GUIDE — installer, lancer et régler URGENCES

Ce guide s'adresse à un débutant. Il explique pas à pas comment jouer, puis (facultatif)
comment ouvrir le projet dans Godot et régénérer les ressources.

---

## 1. Jouer (version Windows prête à l'emploi)

1. Ouvre le dossier `telechargement/urgences/` du dépôt GitHub.
2. Télécharge **tous** les fichiers `Urgences-Windows-partieN.zip` (chacun fait moins de 30 Mo).
3. Crée un dossier vide, par exemple `C:\Jeux\Urgences`.
4. Décompresse **chaque** zip dans ce même dossier (clic droit → « Extraire tout… » → choisir
   `C:\Jeux\Urgences`). Les fichiers se complètent : il ne faut rien renommer.
5. Lance `Urgences.exe`.

Configuration conseillée : carte graphique compatible Vulkan (RTX 2000/3000/4000, Radeon RX 5000+).
Sur Shadow PC Neo, le préréglage **Ultra** est sélectionné par défaut.

> Si Windows affiche « Windows a protégé votre ordinateur », clique sur **Informations
> complémentaires** puis **Exécuter quand même** (le jeu n'est pas signé numériquement).

---

## 2. Commandes

| Action | Touche |
|---|---|
| Se déplacer | Z Q S D (ou W A S D, ou flèches) |
| Courir | Maj |
| S'accroupir | Ctrl |
| Regarder | Souris |
| Interagir / examiner | E ou clic gauche |
| Vue 1re / 3e personne | V |
| Dossier du patient | Tab |
| Compteur de performances | F3 |
| Pause et réglages | Échap |

Les touches de déplacement sont lues « physiquement » : sur un clavier AZERTY, c'est bien ZQSD.

---

## 3. Déroulement d'une prise en charge (étape actuelle du jeu)

1. Entre dans le box 3 : Gérard Martin, 67 ans, se plaint d'une douleur thoracique.
2. Vise le patient et appuie sur **E** : un menu s'ouvre.
3. **Interroge-le** (motif, début, irradiation, antécédents, traitement, allergies).
4. **Prends les constantes** : scope (ECG + SpO₂ + fréquence respiratoire), tension au brassard,
   température, glycémie capillaire, douleur (EVA). Le moniteur affiche les courbes en temps réel.
5. Ouvre le **dossier** (Tab) : chaque mesure y est notée avec l'heure.
6. **Attribue un niveau de tri** (échelle FRENCH, 1 à 5). Le jeu commente ta décision.

---

## 4. Réglages graphiques

Échap → onglet **Graphismes** :

- **Préréglages** : Bas, Moyen, Élevé, Ultra (Ultra par défaut).
- **Résolution de rendu** + **mise à l'échelle** AMD FSR 2.2 (recommandé), FSR 1.0 ou bilinéaire.
  Si les images par seconde baissent, descends la résolution de rendu à 77 % avec FSR 2.2 :
  la différence est presque invisible.
- **Anticrénelage** : TAA (par défaut), FXAA, MSAA 2x/4x.
- **Ombres**, **illumination globale** (VoxelGI pour les intérieurs, SDFGI), **sondes de reflets**,
  **SSAO**, **SSIL**, **SSR** (reflets du sol), **brume volumétrique**, **bloom**,
  **profondeur de champ**, **diffusion sous-cutanée** (peau réaliste).
- Onglet **Jeu** : champ de vision, sensibilité de la souris, volume, synchronisation verticale,
  limite d'images par seconde, compteur de performances.

Les réglages sont enregistrés automatiquement (`%APPDATA%\Godot\app_userdata\Urgences\reglages.cfg`).

---

## 5. Ouvrir le projet dans Godot (pour modifier le jeu)

1. Télécharge **Godot 4.4.1** (version standard, pas « .NET ») :
   <https://github.com/godotengine/godot/releases/tag/4.4.1-stable>
   - Windows : `Godot_v4.4.1-stable_win64.exe.zip`
   - Linux : `Godot_v4.4.1-stable_linux.x86_64.zip`
2. Clone ou télécharge le dépôt, puis dans Godot : **Importer** → choisir `urgences/project.godot`.
3. Le premier import prend quelques minutes (textures et modèles). Appuie ensuite sur **F5**.

### Commandes utiles (terminal, depuis le dossier `urgences/`)

```bash
# Importer / réimporter toutes les ressources
godot --headless --path . --import

# Test automatique de la boucle de jeu (toute ligne « SCRIPT ERROR » = bug)
godot --headless --path . -s res://tools/tests/test_jeu.gd

# Test de performance (appels de dessin, objets, coût des systèmes)
xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/tests/perf.gd

# Captures d'écran (une image par point de vue défini par la scène)
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
    -s res://tools/tests/capture.gd -- --scene res://scenes/jeu.tscn --sortie /tmp/captures
```

---

## 6. Régénérer les ressources (facultatif)

Toutes les ressources sont produites par des scripts (dossier `tools/`) :

| Ressource | Commande | Besoin |
|---|---|---|
| Textures PBR (sols, murs, plafond, inox, tissus…) | `python3 tools/textures/gen_textures.py` | Python 3 + numpy + Pillow |
| Matériaux Godot (`assets/materials/*.tres`) | `godot --headless --path . -s res://tools/gen_materiaux.gd` | Godot |
| Mobilier 3D (brancard, moniteur, perfusion…) | `python tools/modeles/accessoires.py` | module `bpy` (Blender 5) |
| Personnages | `python tools/humains/construire.py [id] [--apercu]` | `bpy`, scipy, données MakeHuman |
| Animations | `python tools/humains/animations.py [--apercu]` | `bpy`, BVH CMU |
| Options d'import des textures | `python3 tools/regler_imports.py` puis réimport | — |

Installation de `bpy` (Blender en module Python, Python 3.13) :

```bash
python3 -m venv /opt/bpyenv
/opt/bpyenv/bin/pip install bpy numpy pillow scipy
```

Données externes (licences libres) :

- **MakeHuman** (maillage, morphoses, squelette, poids — CC0) :
  `git clone --depth 1 https://github.com/makehumancommunity/makehuman.git` puis
  `export MH_DATA=<dossier>/makehuman/data`
- **CMU Motion Capture Database** (conversion BVH de B. Hahne, libre d'utilisation) :
  `git clone --filter=blob:none https://github.com/una-dinosauria/cmu-mocap.git` puis
  `export CMU_BVH=<dossier>/data`

---

## 7. Dépannage

- **Écran noir ou plantage au lancement** : mets à jour le pilote graphique (Vulkan requis).
- **Saccades** : Échap → Graphismes → préréglage Élevé, ou résolution de rendu 77 % + FSR 2.2.
- **La souris ne tourne pas la caméra** : clique une fois dans la fenêtre du jeu.
