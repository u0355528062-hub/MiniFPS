# URGENCES — simulateur de service d'urgences (Godot 4.4)

Simulation à la première personne (ou troisième personne) d'un service d'urgences français :
accueil et tri, examen clinique, examens complémentaires, traitements et orientation.
Rendu Forward+ (Vulkan) poussé au maximum, ciblant 60 i/s en 1080p sur une RTX 4060.

**Installation, commandes et réglages : voir [`GUIDE.md`](GUIDE.md).**

## État d'avancement

| Étape | Contenu | État |
|---|---|---|
| 1. Prototype | Déplacement 1re/3e personne, box d'examen détaillé, patient animé, prise de constantes, moniteur ECG, tri, réglages graphiques, test de performance | ✅ jouable |
| 2. Service complet | Accueil, salle d'attente, box, déchocage, plâtre, radiologie, scanner, sas ambulances ; boucle tri → diagnostic → traitement → sortie | à venir |
| 3. Médecine | Pathologies, examens, mini-jeux (sutures, massage cardiaque, défibrillation), collègues, ambulances | à venir |
| 4. Interface et sons | Interface diégétique, bips, ambiance, voix | à venir |
| 5. Finitions | Passe graphique et optimisation, sauvegarde, menus, écran titre | à venir |

## Technique

- **Rendu** : AgX, SSAO, SSIL, SSR, brume volumétrique, bloom, VoxelGI cuite au chargement,
  sondes de reflets à projection en boîte, ombres douces (PCSS), diffusion sous-cutanée pour
  la peau, TAA ou AMD FSR 2.2.
- **Performances** : géométrie statique fusionnée par matériau (`scripts/monde/fusion.gd`),
  occulteurs générés avec les murs, animations exclusivement via `AnimationPlayer` (aucun os
  animé en GDScript), physique bornée à 2 pas par image avec interpolation (Jolt), moniteur
  redessiné à 30 Hz et seulement s'il est visible, profileur par système (`Profileur`) et test
  de performance (`tools/tests/perf.gd`, historique dans `tools/tests/perf_historique.txt`).
- **Ressources générées par script** (`tools/`) :
  - textures PBR procédurales (numpy) : vinyle moucheté avec soudures et traces, dalles de
    plafond, peinture, inox brossé, tissus, similicuir, carrelage, béton… ;
  - mobilier modélisé avec Blender en module Python (`bpy`) : brancard, moniteur, pied à
    perfusion, bandeau de gaz médicaux, lave-mains, chariot de soins, armoire, portes… ;
  - personnages à partir des données **MakeHuman** (CC0) : morphoses âge/sexe/corpulence/origine,
    squelette à orientations canoniques (une seule bibliothèque d'animations pour tous), peau
    peinte en espace UV (rides, barbe, sourcils, lèvres), vêtements dérivés du corps (pyjamas de
    bloc, blouse patient), cheveux, expressions faciales (clignement, douleur, parole) ;
  - animations reciblées depuis la **CMU Motion Capture Database** (marche, boiterie, attente,
    assis, conversation) et poses construites (allongé, semi-assis avec respiration).

## Structure

```
scenes/           scènes Godot (jeu.tscn = partie, box_examen.tscn = décor)
scripts/          code GDScript (jeu, joueur, monde, personnages, médical, interface, système)
assets/           textures, matériaux, modèles, personnages, polices
tools/            générateurs de ressources (Python/Blender) et tests (tools/tests/)
```

## Crédits

- Données humaines : MakeHuman (CC0), <https://github.com/makehumancommunity/makehuman>
- Captures de mouvement : Carnegie Mellon University Graphics Lab Motion Capture Database,
  <http://mocap.cs.cmu.edu> (conversion BVH de Bruce Hahne)
- Police : Inter (SIL Open Font License)
