# Bloc Urgences — simulateur chirurgical à la première personne

Jeu PC (Godot 4.7, Forward+) : en salle de déchocage, tu poses un **drain thoracique** à Karim,
31 ans, victime d'un accident de moto (pneumothorax droit compressif). Vue à la première personne,
clavier et souris, anatomie réelle.

## Télécharger et jouer (Windows)

1. Télécharge `telechargement/BlocUrgences-Windows.zip`.
2. Décompresse-le, puis lance `BlocUrgences.exe` (aucune installation).

Configuration conseillée : carte graphique compatible Vulkan. La qualité graphique se règle dans
**Options** (Bas, Moyen, Élevé, Ultra) avec la résolution de rendu.

## Commandes

| Action | Touche |
|---|---|
| Marcher | ZQSD (ou WASD, flèches) — Maj : plus vite |
| Regarder | Souris |
| Prendre un instrument | Viser + clic gauche (ou E), ou touches 1 à 7 près de la table |
| Appuyer / serrer / pousser le piston | Clic gauche maintenu |
| Précision (zoom, souris ralentie) | Clic droit maintenu |
| Lever / baisser l'instrument | Molette |
| Reposer l'instrument | R (ou clic molette) |
| Se pencher | Ctrl |
| Vue anatomique (muscles, puis côtes / poumons / cœur) | V |
| Masquer le texte de l'étape / l'aide | H / F1 |
| Pause, options | Échap |

## L'intervention

1. **Repérage** — trouver le 5e espace intercostal dans le triangle de sécurité (ligne axillaire
   moyenne) et le marquer au feutre. Le point est jugé sur l'anatomie réelle : trop bas (foie,
   diaphragme), trop haut (aisselle), trop en avant (grand pectoral) ou en arrière (grand dorsal).
2. **Désinfection** — badigeon de bétadine qui se dépose là où la compresse frotte.
3. **Anesthésie locale** — l'aiguille pique, le piston descend, un bouton gonfle et blanchit ;
   il faut attendre que la lidocaïne agisse (sinon le patient sent la lame).
4. **Incision** — 2,5 cm le long de la 6e côte, la lame coupe là où elle entre dans la peau.
5. **Dissection** — pince de Kelly au ras du bord supérieur de la côte (le paquet
   vasculo-nerveux passe sous chaque côte) : muscle grand dentelé, intercostaux, puis la plèvre
   cède et l'air s'échappe. Le trajet se creuse vraiment dans les tissus.
6. **Pose du drain** — le drain remonte vers l'apex, le poumon se regonfle, l'oxygène remonte.
7. **Fixation** — trois points au porte-aiguille.

Bilan final : note (S à D), temps, erreurs, précision du repère et de l'incision, compte rendu.

## Anatomie et graphismes

- Corps et organes issus de l'atlas **Z-Anatomy** (CC BY-SA 4.0, dérivé de BodyParts3D) :
  peau remaillée, côtes, cartilages, sternum, vertèbres, muscles du thorax, intercostaux,
  plèvre, poumons, cœur, gros vaisseaux, nerfs, diaphragme, foie. Patient posé dans Blender
  (décubitus latéral gauche, bras droit levé), champ opératoire simulé en tissu.
- Les tissus internes n'apparaissent que dans la plaie ; la vue anatomique (V) les montre tous.
  Le poumon droit est affaissé vers son hile et se regonfle quand le drain est posé ; le cœur bat.
- Peau avec diffusion sous la surface, badigeon, plaie dont les bords s'écartent et se
  détendent, parois de la plaie (derme, graisse), sang qui perle derrière la lame.
- Éclairage de bloc (scialytiques, plafond soufflant), occlusion ambiante, éclairage indirect,
  réflexions, brouillard volumétrique léger, profondeur de champ en mode précision.

## Tests automatiques

```
godot --headless --path . -- --autotest      # un robot fait toute l'opération
godot --headless --path . -- --desktest      # un robot joue au clavier et à la souris
godot --headless --path . -- --chaos=3       # actions au hasard, puis le robot termine
godot --headless --path . -- --restarttest   # fin de partie → rejouer
```

Captures : `--shot=fichier.png --view=menu|briefing|player|field|overview|xray|end`.

## Crédits

Anatomie : Z-Anatomy (Gauthier Kervyn, CC BY-SA 4.0), d'après BodyParts3D (DBCLS, CC BY-SA).
Police : Inter (SIL OFL). Moteur : Godot Engine (MIT).
