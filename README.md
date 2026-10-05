# Bloc Urgences — simulateur chirurgical à la première personne

Jeu PC (Godot 4.7, Forward+) : gestes d'urgence et de chirurgie du thorax en salle de
déchocage, vue à la première personne, clavier et souris, anatomie réelle. Le menu propose les
interventions :

| Intervention | Patient | État |
|---|---|---|
| **Drain thoracique** | Karim, 31 ans, moto — pneumothorax droit compressif | jouable |
| **Exsufflation à l'aiguille** | Thomas, 24 ans, voiture — pneumothorax suffocant gauche | jouable |
| **Péricardiocentèse** | Sofiane, 28 ans, couteau — tamponnade, sous échographie | jouable |
| **Voie veineuse centrale** | Lucas, 35 ans, chute de 6 m — choc, sous-clavière gauche (Seldinger) | jouable |
| **Thoracotomie de sauvetage** | Kevin, 22 ans, couteau — arrêt cardiaque par tamponnade | jouable |
| **Pontage coronarien** | Gérard, 64 ans — angor instable, IVA bouchée à 95 % (cœur arrêté sous CEC) | jouable |

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
| Prendre un instrument | Viser + clic gauche (ou E), ou touches 1 à 9 et 0 près de la table |
| Appuyer / serrer / pousser le piston | Clic gauche maintenu |
| Précision (zoom, souris ralentie) | Clic droit maintenu |
| Lever / baisser l'instrument | Molette |
| Reposer l'instrument | R (ou clic molette) |
| Se pencher | Ctrl |
| Vue anatomique (muscles, puis côtes / poumons / cœur) | V |
| Masquer le texte de l'étape / l'aide | H / F1 |
| Pause, options | Échap |

## Drain thoracique

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

## Exsufflation à l'aiguille

Patient couché sur le dos, collier cervical, masque à haute concentration, scope ; la marque de
la ceinture de sécurité barre le thorax.

1. **Repérage** — côté gauche : 2e espace intercostal sur la ligne médio-claviculaire (ou 4e-5e
   espace sur la ligne axillaire), juste au-dessus de la côte du dessous. Le point est jugé sur
   les vraies côtes du patient (côté, espace, distance au sternum et à la côte).
2. **Désinfection** — chlorhexidine sur le point marqué.
3. **Ponction** — aiguille-cathéter 14G sur seringue de sérum : on avance perpendiculairement
   à la peau en tirant le piston (clic maintenu) ; des bulles d'air remontent dans la seringue
   quand la plèvre est franchie, l'air sort en sifflant, le poumon se regonfle, la saturation et
   la tension remontent. Trop profond : erreur.
4. **Laisser le cathéter** — on retire l'aiguille, le cathéter souple reste en place.

## Péricardiocentèse sous échographie

Coup de couteau à gauche du sternum : le sang remplit le péricarde et comprime le cœur (tension
basse et pincée, veines du cou gonflées ; au scope, microvoltage et alternance électrique).

1. **Échographie** — sonde posée sous la pointe du sternum, faisceau vers l'épaule gauche. L'image
   est calculée en direct dans le volume anatomique du patient : foie en haut, péricarde brillant,
   liquide noir, parois du cœur qui battent, cœur qui se balance dans l'épanchement, ombres des
   côtes. Elle s'affiche dans le coin de l'écran et sur l'échographe ; l'aide garde ensuite la
   sonde en place.
2. **Désinfection** — sous la pointe du sternum.
3. **Ponction** — aiguille longue sur seringue, sous le rebord costal gauche, vers le haut et la
   gauche, en aspirant ; l'aiguille brille à l'échographie. Le sang revient quand la pointe entre
   dans le péricarde ; plus loin, l'aiguille touche le cœur (extrasystoles au scope).
4. **Aspiration** — 20 mL : l'épanchement diminue à l'image, la tension remonte.
5. **Laisser le cathéter** — pour ré-aspirer en attendant le bloc.

## Voie veineuse centrale (technique de Seldinger)

Choc hémorragique, veines des bras collabées, collier cervical : cathéter dans la veine
sous-clavière gauche.

1. **Repérage** — sous le milieu de la clavicule, à 1-2 cm de l'os. Le point est jugé sur la
   clavicule et les vaisseaux de l'atlas : sur l'os, trop bas, trop en dedans (l'aiguille
   plongerait vers le poumon), trajet qui croiserait l'artère…
2. **Désinfection**, 3. **anesthésie locale** — il faut attendre qu'elle agisse avant de piquer.
4. **Ponction** — l'aiguille glisse sous la clavicule vers le creux sus-sternal en aspirant ; le
   sang veineux sombre revient dans la seringue. Trop profond : artère et sommet du poumon.
5. **Guide** — poussé dans l'aiguille (clic maintenu), 15 à 20 cm ; trop loin, il touche le
   cœur (extrasystoles). En vue anatomique (V), on le voit suivre la veine jusqu'au cœur.
6. **Dilatateur**, 7. **cathéter** glissé sur le guide jusqu'à 16-19 cm (pointe dans la veine
   cave supérieure), 8. **fixation** par deux points.

## Thoracotomie de sauvetage

Coup de couteau sous le mamelon gauche ; à l'arrivée, plus de pouls : le scope montre encore une
activité électrique (alarme, « PAS DE POULS », pas de saturation ni de tension), mais le sang
accumulé dans le péricarde empêche le cœur de pomper. Il est intubé et ventilé.

1. **Incision** — sous le mamelon, du bord du sternum à la ligne axillaire antérieure, d'un seul
   trait jusqu'aux muscles (pas d'anesthésie : il est en arrêt).
2. **Intercostaux et plèvre** — ciseaux au fond de l'incision, clic maintenu en avançant le long
   du 5e espace intercostal (son vrai tracé courbe, mesuré entre la 5e et la 6e côte de
   l'atlas) : la paroi s'ouvre au fur et à mesure, le poumon s'affaisse, du sang au fond.
3. **Écarteur de Finochietto** — les valves dans la brèche, sous les côtes, puis la manivelle
   (clic maintenu) : toute la paroi s'écarte de 8 cm (côtes, muscles, plèvre glissent le long de
   la peau).
4. **Péricarde** — tendu et violacé par le sang ; ouvert aux ciseaux de la pointe vers la base,
   en avant du nerf phrénique : les caillots sortent, le cœur se remet à battre faiblement et la
   plaie du ventricule saigne à chaque battement.
5. **Plaie du ventricule** — deux points en U appuyés sur des feutres de Téflon, entre deux
   battements ; le saignement diminue puis s'arrête.
6. **Massage cardiaque interne** — mains nues (R pour reposer l'instrument), un clic par
   compression en visant le cœur, environ 100 par minute (rythme affiché) : la main gantée
   comprime le cœur, l'onde de pression apparaît au scope, puis le cœur repart (118/min).

## Pontage coronarien

Gérard, 64 ans : douleurs dans la poitrine au moindre effort, l'artère interventriculaire
antérieure (IVA) est bouchée à 95 % à son origine. Bloc de chirurgie cardiaque : il est endormi,
intubé, sous les champs (fenêtre sur le sternum, film iodé, champ de tête sur l'arceau
d'anesthésie) ; la machine de circulation extracorporelle (CEC) attend à sa gauche. On branche
l'artère mammaire interne gauche sur l'IVA, cœur arrêté.

1. **Incision** — sur la ligne médiane, du creux sus-sternal à l'appendice xiphoïde, jusqu'à l'os.
2. **Sternotomie** — scie sternale (bruit de scie, lame qui va et vient) : le sabot passe sous le
   haut du sternum, puis on descend tout droit, clic maintenu ; le trait de scie s'ouvre au fur et
   à mesure.
3. **Écarteur sternal** — valves entre les deux moitiés du sternum, crémaillère vers les pieds,
   puis la manivelle : le sternum s'écarte de 9 cm, les bords des poumons suivent, le péricarde
   apparaît.
4. **Artère mammaire** — l'aide soulève le bord gauche du sternum (la valve gauche se relève) ;
   au bistouri électrique (fumée), l'artère est décollée de haut en bas avec ses veines et sa
   graisse : c'est le greffon, coupé et clippé en bas.
5. **Péricarde** — ouvert aux ciseaux de l'aorte au diaphragme, largement (toute la face avant
   du cœur, graisse dans les sillons des coronaires) ; quatre fils de suspension tirent ses bords
   vers la peau : le cœur bat dans son berceau.
6. **Canule aortique**, puis 7. **canule veineuse** dans l'oreillette droite — les tubulures
   souples, rouge vif et sombre, sortent vers le haut du champ, passent sur l'épaule gauche et
   pendent jusqu'à la machine : départ de la CEC (pompes à galets qui tournent, débit
   4,8 L/min ; le scope affiche la pression de la machine, on arrête de ventiler).
8. **Clampage** — clamp en travers de l'aorte, cardioplégie froide : le cœur ralentit, pâlit et
   s'arrête (asystolie au scope).
9. **Artériotomie** — l'IVA ouverte au bistouri sur 6 mm, dans sa longueur.
10. **Anastomose** — l'aide amène le greffon, couché sur la face avant du cœur ; surjet au fil
    8/0, six points entre le bout de la mammaire et les bords de l'IVA.
11. **Déclampage** — main nue sur le clamp : le sang chaud revient, le cœur se réchauffe… et
    fibrille (fibrillation ventriculaire au scope, le cœur tremble).
12. **Choc interne** — palettes de part et d'autre du cœur, un clic : il repart en rythme régulier.
13. **Décanulation** — la machine ralentit puis s'arrête, le cœur reprend la main ; les canules
    sont retirées.
14. **Fermeture** — l'écarteur est retiré, la peau revient sur le sternum ; cinq fils d'acier
    passent autour des deux moitiés, puis sont serrés et torsadés : le sternum se referme, la
    peau est agrafée.

Quand le repère de l'étape sort de l'écran, une flèche au bord de l'image indique où regarder.

## Anatomie et graphismes

- Corps et organes issus de l'atlas **Z-Anatomy** (CC BY-SA 4.0, dérivé de BodyParts3D) :
  peau remaillée, côtes, cartilages, sternum, vertèbres, muscles du thorax, intercostaux,
  plèvre, poumons, cœur, gros vaisseaux, nerfs, diaphragme, foie. Deux positions posées dans
  Blender : décubitus latéral gauche, bras droit levé, sur un matelas à dépression (drain) ; sur
  le dos, bras le long du corps, tête sur un anneau de gel (autres gestes). Repères mesurés sur
  l'atlas : côtes et espaces intercostaux, plèvre, sternum, clavicules, vaisseaux.
- Champ opératoire et drap simulés en tissu ; le bord adhésif colle le champ à plat autour de la
  fenêtre. Pontage : grand drap simulé sur tout le corps, collé autour de la fenêtre sternale, et
  champ de tête jeté sur l'arceau d'anesthésie. Câbles du scope, tuyau d'oxygène, tubulure de perfusion et tuyau du brassard simulés
  comme des cordes : ils reposent sur le patient, pendent au bord de la table, traînent au sol.
- Les tissus internes n'apparaissent que dans la plaie ; la vue anatomique (V) les montre tous.
  Le poumon droit est affaissé vers son hile et se regonfle quand le drain est posé ; le cœur bat.
- Peau avec diffusion sous la surface (mode peau), grain et teint irrégulier, aréoles,
  ecchymose de la ceinture, cheveux, sourcils et paupières dessinés sur l'atlas, badigeon, plaie
  dont les bords s'écartent et se détendent, parois de la plaie (derme, graisse), sang qui perle
  derrière la lame.
- Éclairage de bloc (scialytiques, plafond soufflant), occlusion ambiante, éclairage indirect,
  réflexions, brouillard volumétrique léger, profondeur de champ en mode précision.

## Tests automatiques

```
godot --headless --path . -- --autotest      # un robot fait toute l'opération
godot --headless --path . -- --desktest      # un robot joue au clavier et à la souris
godot --headless --path . -- --chaos=3       # actions au hasard, puis le robot termine
godot --headless --path . -- --restarttest   # fin de partie → rejouer
godot --headless --path . -- --op=exsufflation --autotest   # même chose pour une autre intervention
```

Captures : `--shot=fichier.png --view=menu|briefing|player|field|overview|xray|end`.

## Crédits

Anatomie : Z-Anatomy (Gauthier Kervyn, CC BY-SA 4.0), d'après BodyParts3D (DBCLS, CC BY-SA).
Police : Inter (SIL OFL). Moteur : Godot Engine (MIT).
