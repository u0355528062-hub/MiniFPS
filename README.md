# Bloc VR — Chirurgie en réalité virtuelle

Simulateur de chirurgie en réalité virtuelle (Godot 4.7), jouable aux mains nues. Quatre opérations
guidées : appendicectomie, drain thoracique, laparotomie pour plaie au couteau, drainage d'abcès.
Un panneau te dit quoi faire, l'instrument à prendre brille sur la table (son nom s'affiche quand ta
main s'en approche), un anneau lumineux montre où agir.

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

Tout se fait avec de **vrais gestes** : la lame coupe quand elle entre dans la peau, la compresse
badigeonne là où elle frotte, l'écarteur étire le bord qu'il accroche (et le bord se détend si on
lâche), les ciseaux et les pinces s'ouvrent et se ferment avec tes doigts, le piston de la seringue
avance quand tu serres. Les instruments ne traversent ni la peau ni les objets.

### Casque SANS manettes (mains nues) — recommandé

| Geste | Action |
|---|---|
| **Pincer pouce + index** près d'un instrument | le prendre : il se tient entre le pouce et l'index, comme un crayon |
| **Serrer / desserrer le pouce** contre l'index | fermer / ouvrir les ciseaux et les pinces, pousser le piston de la seringue (relâche d'abord, puis serre) |
| **Ouvrir grand la main** (doigts tendus) | lâcher l'instrument : il retourne sur la table |
| Pincer en visant de loin | un rayon discret attrape l'instrument visé |
| **Toucher un bouton du bout de l'index** | menu : choisir l'opération, Commencer, Recommencer, Recentrer |

Si tes mains n'apparaissent pas :
1. dans le casque : **Paramètres → Mouvements → Suivi des mains** activé ;
2. sur le PC, application **Meta Quest Link → Paramètres → Bêta** : active
   **« Fonctionnalités d'exécution pour les développeurs »** (nécessaire au suivi des mains via Link).

### Casque (manettes Quest)

| Bouton | Action |
|---|---|
| **Grip** | prendre l'instrument près de ta main ou visé par le rayon / le reposer |
| **Gâchette** | serrer (mâchoires, piston) |
| **A** ou **X** | commencer / recommencer |
| **B** ou **Y** | te replacer face au patient |
| Stick gauche / droit | te déplacer / tourner par crans |

**Fluidité** : la résolution s'ajuste toute seule pour garder la cadence du casque (une image en
retard fait trembler la vue). Pour Air Link, préfère un Wi-Fi 5/6 GHz proche, ou le câble Link.

### Souris et clavier

| Touche | Action |
|---|---|
| **Clic gauche** | prendre l'instrument visé |
| **Clic gauche maintenu** | appuyer (la lame, l'aiguille, le drain s'enfoncent) et serrer (mâchoires, piston) |
| **Molette** | lever / baisser l'instrument |
| **R** ou **clic droit bref** | reposer l'instrument |
| **1 à 8** | prendre directement un instrument |
| **Clic droit glissé** | regarder autour |
| **ZQSD** (ou flèches) | se déplacer, **E / C** monter / descendre |
| **Espace** | commencer / recommencer |

---

## Opérations

- **Appendicectomie** (9 étapes, ci-dessous).
- **Drain thoracique** (6 étapes) : désinfection du flanc, anesthésie locale (on pique, on pousse le
  piston, le bouton gonfle et blanchit : il faut **attendre qu'elle agisse**, sinon le patient sent la
  lame), incision le long de la côte, dissection à la pince de Kelly (pousser, ouvrir, pousser...)
  jusqu'à la plèvre, pose du drain (l'oxygène remonte, bulles dans le bocal, le tuyau s'embue),
  fixation par 3 points. Le thorax respire sous tes mains.
- **Laparotomie** (10 étapes) : plaie au couteau, ventre plein de sang. Grande incision médiane,
  écarteur de Gosset qu'on ouvre en écartant les doigts, aspiration du sang à la canule, anse
  d'intestin perforée sortie à la pince, clampée, recousue, lavage au sérum, fermeture de
  l'aponévrose puis de la peau.
- **Drainage d'abcès** (6 étapes) : abcès rouge, gonflé et tendu. Désinfection, anesthésie locale
  (attendre), incision au sommet (le pus sort et coule), logettes cassées à la Kelly, lavage au
  sérum à la seringue, mèche de gaze laissée dans la cavité.

## Les 9 étapes de l'appendicectomie

1. **Désinfection** — frotter la compresse de la pince à badigeon sur toute la zone.
2. **Incision** — poser la lame sur « DÉPART », appuyer, la glisser jusqu'à « ARRIVÉE ».
3. **Écarteur 1** — accrocher un bord avec le Langenbeck et tirer ; tenu bien ouvert, l'aide le prend.
4. **Écarteur 2** — même geste avec le Roux sur l'autre bord.
5. **Sortir l'appendice** — mors de la pince De Bakey autour de la pointe, serrer, soulever.
6. **Ligature** — serrer l'Overholt sur le fil à la base, puis tirer pour serrer le nœud.
7. **Section** — ouvrir les ciseaux autour de l'appendice, les refermer.
8. **Retrait** — saisir l'appendice, le lâcher au-dessus du haricot (il tombe vraiment).
9. **Suture** — pour chaque point : piquer à l'entrée, ressortir sur l'autre bord ; 4 points.

Fin : temps, erreurs et étoiles. Prendre le mauvais instrument compte une erreur (une fois par étape).

---

## Options de lancement (tests)

Après `--` sur la ligne de commande :

- `--desktop` : forcer le mode écran.
- `--step=N` : commencer directement à l'étape N (0 à 8).
- `--autotest` : un robot fait toute l'opération et affiche `AUTOTEST OK` si tout s'enchaîne.
- `--vrtest` : un robot fait toute l'opération **avec les mains VR** (grip, gâchette, rayon, deux
  mains, maladresses volontaires) et affiche `VRTEST OK`.
- `--desktest` : un robot fait toute l'opération **à la souris et au clavier** (vrais événements).
- `--chaos=vr` ou `--chaos=desk` avec `--seed=N` : à chaque étape, des centaines d'actions au hasard,
  puis le robot doit pouvoir finir l'étape depuis l'état laissé. Des règles sont vérifiées à chaque
  image (un instrument jamais dans deux mains, rien ne sort de la salle, l'étape ne recule jamais…).
- `--restarttest` : vérifie que « recommencer » en fin de partie fonctionne.
- `--handtest` : partie complète **aux mains nues** (faux suivi des mains : 26 articulations par main,
  pincement et poing), menu compris. `--chaos=vr --hands` : chaos aux mains nues.
- `--op=drain`, `--op=laparotomie`, `--op=abces` : choisit l'opération pour les tests.
- `--perf` : affiche le temps de calcul par image à chaque étape.
- `--pose=id --vrmock [--handmock] --tipat=x,y,z --sq=0..1 --shot=...` : capture d'une main qui tient un instrument.

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
| Tête du patient (scan « Lee Perry-Smith ») | Infinite-Realities (via three.js) | CC BY 3.0 |
| Mains gantées, outils VR | Godot XR Tools | MIT |
| Police Inter | Rasmus Andersson | SIL OFL 1.1 |

Tout le reste a été fait pour ce projet : salle, champs, peau, plaie, textures procédurales
(`tools/gen_textures.py`), shaders, sons synthétisés, interface et code.

Attention : à cause de la licence **CC BY-NC** des instruments, ce prototype ne peut pas être vendu.
