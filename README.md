# URGENCES — Emergency Simulator

Jeu PC (Godot 4.7, Forward+) : tu es l'urgentiste de garde. Un patient t'attend au déchocage ; tu
le prends en charge **comme dans la vraie vie** : tu l'examines, tu le branches au scope, tu poses
une voie veineuse, tu prépares et injectes les médicaments, tu masses, tu défibrilles, tu demandes
les examens, tu poses le diagnostic et tu l'orientes. Sa physiologie évolue en continu : il
s'améliore si tu fais ce qu'il faut… ou s'aggrave, jusqu'à mourir.

**Deux vues :**
- **à la première personne** pour circuler dans la salle (brancard, chariot d'urgence,
  défibrillateur, scope plafonnier, électrocardiographe, débitmètre d'oxygène, armoire, poste
  informatique, lavabo, gants) ;
- **caméra libre sur la zone du geste** dès qu'il faut être précis (thorax, tête, cou, bras, main,
  cuisse, défibrillateur, scope, ECG, débitmètre) : la souris est libre pour viser au millimètre
  sur la peau, on tourne autour de la zone (clic droit), on zoome (molette), on se décale (ZQSD).

## Histoire : « Première garde »

Tu es un jeune interne qui fait sa toute première nuit aux urgences, avec **Sophie** (infirmière) et
le **Dr Marchand** (médecin sénior). Trois patients à la suite, entre des dialogues (portrait, texte
qui s'écrit, choix de réponse) :

1. **Patrick, hypoglycémie — tutoriel.** Sophie guide chaque geste pas à pas (regarder, marcher,
   gants, vue rapprochée, appeler, respiration, pouls, glycémie, scope, voie veineuse — ou elle la pose
   pour toi —, seringue de sucre, injection, interrogatoire, conclusion), avec consignes, touches,
   flèches dans la salle et cadres lumineux sur les boutons. On ne peut pas échouer gravement.
2. **Thomas, choc anaphylactique.** Plus de guidage pas à pas : le chef et l'infirmière donnent des
   conseils si tu traînes ; Sophie peut proposer de poser la voie veineuse.
3. **Michel, arrêt cardiaque en fibrillation** : l'apothéose.

Après chaque patient : bilan (note, objectifs atteints ou manqués expliqués simplement, erreurs) et
avis du chef ; transition, puis la fin de la garde. La progression est sauvegardée
(`user://records.cfg`). L'**entraînement libre** donne accès aux 6 cas depuis le menu principal.

Les termes médicaux sont expliqués partout : « Oxygène (SpO2) », « Tension (PNI) », « dans la veine
(IV) », « ballon d'oxygène (BAVU) »… La liste **À faire** (en haut à gauche, touche O pour la
masquer) montre ce qui est attendu et se coche au fur et à mesure ; les constantes passent du vert à
l'orange puis au rouge selon la gravité.

## Les cas

| Cas | Patient | Ce qu'il faut faire |
|---|---|---|
| **Arrêt cardiaque** | Michel, 58 ans — s'effondre devant toi (FV) | reconnaître l'arrêt, masser, électrodes, analyse et chocs, BAVU 30:2, voie veineuse, adrénaline et amiodarone après le 3e choc, ECG après la reprise, coronarographie |
| **Douleur thoracique** | Jean-Pierre, 62 ans — infarctus antérieur | scope, ECG 12 dérivations en moins de 10 min, interrogatoire, aspirine, héparine, morphine titrée, pas d'O2 inutile, coronarographie ; il peut fibriller si tu traînes |
| **Inconscient, respire mal** | Kevin, 26 ans — overdose d'héroïne | voies aériennes, ballon, glycémie, pupilles (myosis), naloxone titrée sans sevrage brutal, surveillance |
| **Coma chez un diabétique** | Patrick, 47 ans — hypoglycémie | glycémie capillaire d'emblée, glucosé 30 % IV (ou glucagon IM), contrôle, interrogatoire au réveil |
| **Crise d'asthme grave** | Yanis, 23 ans — asthme aigu grave | O2, nébulisations salbutamol + ipratropium sous 6-8 L/min, corticoïdes IV, gaz du sang, jamais de sédation |
| **Choc anaphylactique** | Thomas, 34 ans — piqûre de guêpe | adrénaline 0,5 mg IM tout de suite, O2, remplissage, corticoïdes ; l'adrénaline en bolus IV est dangereuse |

## Les gestes (vue rapprochée, objet en main 1 à 9)

- **Mains** : pouls carotidien ou radial (clic maintenu), appel et stimulation, bascule de la tête et
  « regarder, écouter, sentir » (menton), palpation de l'abdomen, temps de recoloration (ongle),
  desserrer le garrot.
- **Massage cardiaque** : talon de la main sur la moitié inférieure du sternum, clic maintenu ; tu
  **pousses la souris vers le bas** pour enfoncer le thorax et tu remontes pour le relâcher. Le
  thorax s'enfonce vraiment sous les mains ; le défibrillateur affiche la profondeur (5-6 cm), la
  fréquence (100-120/min) et le relâchement. Le **LUCAS** (massage automatique) libère les mains.
- **BAVU** : masque sur le visage (tête basculée), clic sur le ballon pour insuffler : le thorax se
  soulève.
- **Défibrillateur** : électrodes sous la clavicule droite et sous l'aisselle gauche, puis Marche,
  Analyse (mode DSA) ou molette (mode manuel 150 / 200 / 360 J), Charge, **Choc** — refusé si tu
  touches encore le patient.
- **Scope** : 3 électrodes (sous les clavicules, flanc gauche), pince de SpO2 au doigt, brassard
  (PNI toutes les 3 min ou à la demande). Le scope n'affiche que ce que mesurent les capteurs posés.
- **ECG 12 dérivations** : 10 électrodes jugées sur les vraies côtes du patient (V1/V2 au 4e espace
  intercostal, V4 au 5e sur la ligne médio-claviculaire…), enregistrement, tracé sur papier
  millimétré avec interprétation.
- **Voie veineuse** (clic sur le bras avec le garrot, l'antiseptique ou un cathéter : la caméra se
  rapproche du pli du coude), 7 étapes dans l'ordre : 1. garrot au-dessus du coude (on tire la
  souris pour serrer, les veines se gonflent) ; 2. désinfection en frottant (l'antiseptique colore
  la peau) ; 3. choix de la veine en la palpant (une veine fine ou qui roule peut faire rater la
  ponction : hématome) ; 4. ponction à angle faible en glissant dans le sens de l'aiguille, reflux de
  sang dans la chambre, on avance le cathéter puis on retire l'aiguille ; 5. desserrer le garrot ;
  6. pansement transparent ; 7. brancher la perfusion (tubulure jusqu'à la poche sur la potence) ou
  injecter. Les tubes se prélèvent sur le cathéter.
- **Médicaments** : préparés au chariot (produit, dose, voie) puis injectés IV sur le bouchon du
  cathéter (le piston descend) ou IM dans le deltoïde ou la cuisse ; nébulisation au masque.
- **Examen** : stéthoscope (bruits du cœur, murmure vésiculaire, sibilants, crépitants, silence), lampe
  (pupilles), thermomètre tympanique, glycémie capillaire.
- **Oxygène** : lunettes, masque à haute concentration, débitmètre mural (0 à 15 L/min).
- **Poste informatique** (Tab) : dossier (transmission, observations horodatées), biologie
  (après prélèvement), radio du thorax au lit, résultats, conclusion (diagnostic et orientation).
- **Interrogatoire** (T) quand le patient peut parler.

## Note

Chaque cas a sa grille (objectifs pondérés, délais), les erreurs retirent des points (geste
dangereux, médicament contre-indiqué, oubli d'hygiène…) et un patient décédé plafonne la note.
**S** : parfait · **A** ≥ 80 · **B** ≥ 65 · **C** ≥ 45 · **D**. Le compte rendu de fin liste les
objectifs atteints ou manqués et les erreurs ; le meilleur résultat de chaque cas est gardé.

## Télécharger et jouer (Windows)

1. Télécharge `telechargement/Urgences-Windows.zip`.
2. Décompresse-le, puis lance `Urgences.exe` (aucune installation).

Carte graphique compatible Vulkan conseillée ; la qualité se règle dans **Options**.

## Commandes

| Action | Touche |
|---|---|
| Marcher / regarder | ZQSD (ou WASD, flèches) / souris — Maj : plus vite, Ctrl : se pencher |
| Utiliser ce que vise le viseur | Clic gauche ou E |
| Objet en main | 1 à 9 (ou clic sur la barre) |
| Vue rapprochée | clic gauche : geste · clic droit maintenu : tourner · molette : zoom · ZQSD : décaler · Échap : revenir |
| Parler au patient / dossier | T / Tab |
| Pause, options | Échap |

## Graphismes et modèles

- Équipement modélisé dans Blender (`tools/blender/`) : brancard, défibrillateur, scope et bras
  plafonnier, rampe murale (O2, vide), chariot d'urgence, électrocardiographe, poste informatique,
  armoires, BAVU, mains gantées, seringue graduée, cathéters type Venflon 18G / 20G, poche de
  soluté, stéthoscope, glucomètre, électrodes… et le décor de la salle (`build_salle.py`) :
  échographe, pousse-seringues, étagère à bacs colorés, poubelles DASRI, fauteuil roulant, rideau,
  horloge, panneau Sortie, distributeurs de gel et de gants, prises ; affiches (`tools/build_affiches.py`).
- Patient : peau de l'atlas **Z-Anatomy** (CC BY-SA 4.0), signes cliniques dessinés en temps réel
  (pâleur, cyanose, sueurs, marbrures, urticaire, rougeur, veines sous garrot), respiration, thorax
  qui s'enfonce sous le massage.
- Radio du thorax **calculée sur l'anatomie** : rayons lancés à travers le corps, les poumons et les
  os de l'atlas (`tools/blender/build_xray.py`).
- Éclairage de salle (dalles, lampe d'examen), occlusion ambiante, réflexions, illumination globale
  (qualité Ultra), brouillard léger, profondeur de champ en vue rapprochée.

## Tests automatiques

```
godot --headless --path . -- --case=acr_fv --autotest      # un robot joue le cas idéalement
godot --headless --path . -- --story --autotest            # l'histoire : intro, 3 patients (robot), fin
godot --path . -- --case=sca_st --shot=f.png --view=zone:thorax   # capture (menu, training, story_intro,
#   card, dialogue, tutorial, cart, constantes, briefing, player, pause, options, bilan, story_end, zone:…)
#   avec --story --chapter=N --step=N --line=N --tab=Examen pour les écrans de l'histoire
```

## Crédits

Anatomie : Z-Anatomy (Gauthier Kervyn, CC BY-SA 4.0), d'après BodyParts3D (DBCLS, CC BY-SA).
Police : Inter (SIL OFL). Moteur : Godot Engine (MIT).
