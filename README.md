# Bloc VR — Appendicectomie

Prototype de chirurgie en réalité virtuelle (Godot 4.7). Tu fais une appendicectomie complète par
voie de McBurney, en 9 étapes très guidées : un panneau te dit quoi faire, l'instrument à prendre
brille sur la table, un anneau lumineux montre où agir.

Ça marche **avec le Quest 3 en Air Link / Quest Link**, ou **sans casque** à la souris et au clavier.

---

## Lancer le jeu (le plus simple)

1. Télécharge `BlocVR-Windows.zip`, puis dézippe-le.
2. **Avec le casque** :
   - ouvre l'application **Meta Quest Link** sur le PC ;
   - dans le casque, active **Air Link** (ou branche le câble Link) ;
   - sur le PC, double-clique sur `BlocVR.exe`. Le jeu s'ouvre directement dans le casque.
3. **Sans casque** : double-clique sur `BlocVR.exe` avec Quest Link fermé. Le jeu s'ouvre à l'écran.

> Si le jeu s'ouvre à l'écran alors que le casque est branché : dans l'application Meta Quest Link
> sur le PC, va dans **Paramètres → Général** et clique sur **« Définir Meta Quest Link comme
> environnement d'exécution OpenXR actif »**. Puis relance `BlocVR.exe`.

## Ouvrir le projet dans Godot (pour modifier)

1. Installe **Godot 4.7.2** (version standard, pas « .NET ») depuis godotengine.org.
2. Dans Godot : **Importer** → choisis le fichier `project.godot` de ce dossier → **Importer et modifier**.
3. Le premier import prend une minute. Ensuite, appuie sur **F5** pour jouer.

---

## Commandes

### Casque (manettes Quest)

| Bouton | Action |
|---|---|
| **Grip** (bouton sous le majeur) | prendre l'instrument près de ta main **ou** visé avec le rayon / le reposer |
| **Gâchette** (index) | agir : badigeonner, inciser, poser, saisir, ligaturer, couper, suturer |
| **A** ou **X** | commencer / recommencer |
| **B** ou **Y** | te replacer face au patient |
| Stick gauche | te déplacer doucement |
| Stick droit | tourner par crans |

Tu peux tenir un instrument dans chaque main.

### Souris et clavier

| Touche | Action |
|---|---|
| **Clic gauche** | prendre l'instrument visé |
| **Clic gauche maintenu** | agir |
| **Molette** | lever / baisser l'instrument |
| **R** ou **clic droit bref** | reposer l'instrument |
| **1 à 8** | prendre directement un instrument |
| **Clic droit glissé** | regarder autour |
| **ZQSD** (ou flèches) | se déplacer, **E / C** monter / descendre |
| **Espace** | commencer / recommencer |

---

## Les 9 étapes

1. **Désinfection** — pince à badigeon, frotter la peau jusqu'à 100 %.
2. **Incision** — bistouri, suivre le pointillé violet de « DÉPART » à « ARRIVÉE ».
3. **Écarteur 1** — Langenbeck sur le repère.
4. **Écarteur 2** — Roux sur l'autre bord ; la plaie s'ouvre.
5. **Sortir l'appendice** — pince De Bakey, saisir la pointe et la soulever.
6. **Ligature** — Overholt + fil à la base.
7. **Section** — ciseaux au-dessus de la ligature.
8. **Retrait** — déposer l'appendice dans le haricot.
9. **Suture** — porte-aiguille, 4 points.

Fin : temps, erreurs et étoiles. Prendre le mauvais instrument compte une erreur (une fois par étape).

---

## Options de lancement (tests)

Après `--` sur la ligne de commande :

- `--desktop` : forcer le mode écran.
- `--step=N` : commencer directement à l'étape N (0 à 8).
- `--autotest` : un robot fait toute l'opération et affiche `AUTOTEST OK` si tout s'enchaîne.

---

## Crédits et licences

Les modèles 3D restent la propriété de leurs auteurs, selon leur licence :

| Modèle | Auteur | Licence |
|---|---|---|
| Instruments chirurgicaux, tables d'instruments | Digital Surgery (Sketchfab) | CC BY-NC 4.0 |
| Paravent (« Curtain ») | Mehdi Shahsavan | CC BY 4.0 |
| Masque chirurgical | Paul Subert | CC BY 4.0 |
| Lavabo chirurgical | miraclejudy3 | CC BY 4.0 |
| Chariot médical | Chenchanchong | CC BY 4.0 |
| Chariot (« Hospital Trolley ») | creative_beast | CC BY 4.0 |
| Tabouret | krio302 | CC BY 4.0 |
| Haricot | aizad_musafir77 | CC BY 4.0 |
| Chariot de pharmacie (« Medical Props ») | coa white | CC BY 4.0 |
| Seringue | stfuaahil | CC BY 4.0 |
| Pied à perfusion | Somar52 | CC BY 4.0 |
| Table d'opération, scialytique, table de Mayo | générés par IA (fournis par le propriétaire du projet) | — |
| Appendice, cæcum, intestin grêle, méso, artères | Z-Anatomy (d'après BodyParts3D, © DBCLS) | CC BY-SA 4.0 |
| Mains gantées, outils VR | Godot XR Tools | MIT |
| Police Inter | Rasmus Andersson | SIL OFL 1.1 |

Tout le reste a été fait pour ce projet : salle, champs, peau, plaie, shaders, sons synthétisés,
interface et code.

Attention : à cause de la licence **CC BY-NC** des instruments, ce prototype ne peut pas être vendu.
