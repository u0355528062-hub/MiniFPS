# Blouse Blanche

Prototype de **simulateur médical** à la première personne, réalisé avec **Unity 6 (URP)**. Le projet est
**entièrement procédural** : le décor, les personnages, les textures, les sons et la musique sont générés
par le code au chargement. Le dépôt ne contient aucun modèle 3D, aucune image et aucun fichier audio,
seulement des scripts, une feuille de style et des polices.

> Contenu pédagogique de jeu : il ne remplace pas un avis médical.

## Les trois prototypes jouables

| Prototype | Lieu | Cas | Principe |
|---|---|---|---|
| **Cabinet de médecine générale** | Cabinet des Tilleuls | 19 | Un patient vous attend, assis face au bureau. Lavez-vous les mains, interrogez, examinez avec la roue des outils (12 instruments), posez un diagnostic, prescrivez et orientez. |
| **SAMU · intervention à domicile** | Salon d'un particulier | 6 | Arrivée avec le SMUR. Dès la prise en charge, le temps s'écoule en continu et l'état du patient évolue : bilan, massage cardiaque, défibrillation, oxygène, perfusion, médicaments, puis transport vers le bon service. |
| **Urgences · box de soins** | Box 3 des urgences | 6 | Patient installé par l'infirmière d'accueil. Les résultats de biologie et d'imagerie arrivent avec un délai : il faut hiérarchiser, traiter et décider de l'orientation. |

Le menu principal affiche les cas sans dévoiler le diagnostic (motif, témoignage, difficulté). Chaque cas
se termine par un **bilan** : note sur 100, critères détaillés, retours, point pédagogique « À retenir ».
Depuis le bilan, on peut passer au cas suivant, rejouer le même cas ou choisir un autre cas.

Pendant une intervention SAMU ou aux urgences :

- le scope du décor (défibrillateur au salon, moniteur du box) s'allume et trace l'ECG, la
  pléthysmographie et la respiration ; le même tracé est affiché dans l'interface ;
- les bips suivent le cœur et deviennent plus graves quand la saturation baisse ; l'alarme se
  déclenche en cas de constantes critiques ;
- massage cardiaque, ventilation au ballon et choc électrique sont visibles et audibles ;
- ouvrir la roue du matériel ralentit le temps.

## Démarrer

1. Installer **Unity 6** : le projet déclare la version 6000.6.4f1 (`ProjectSettings/ProjectVersion.txt`).
   Une autre version 6000.x convient aussi : Hub propose alors de convertir le projet. Les paquets
   intégrés à l'éditeur (URP, uGUI) s'alignent automatiquement sur sa version.
2. Dans Unity Hub : **Add › Add project from disk**. Choisir le dossier qui contient directement
   `Assets`, `Packages` et `ProjectSettings`. Attention : après « Extraire tout » sous Windows, ce dossier
   se trouve souvent un niveau plus bas (`BlouseBlanche\BlouseBlanche`). Au premier lancement, Unity
   complète `ProjectSettings/` et importe les paquets.
3. Une fenêtre propose de **configurer le projet** : accepter. On peut aussi utiliser le menu
   **Blouse Blanche › Configurer le projet**, qui fait les étapes suivantes (on peut le relancer sans
   risque) :
   - crée et assigne un pipeline **URP** (Forward+, ombres douces, HDR) dans `Assets/BlouseBlanche/Settings/` ;
   - crée les **matériaux modèles** (`Resources/BlouseBlanche/Materials`) qui garantissent les variantes
     de shader dans les builds ;
   - crée le **PanelSettings** de l'interface UI Toolkit ;
   - crée la scène `Assets/BlouseBlanche/Scenes/BlouseBlanche.unity` et l'ajoute au build ;
   - règle le lecteur : espace colorimétrique linéaire, 1920×1080, gestion des entrées sur **Both**
     (Input System + Input Manager). Un redémarrage de l'éditeur est proposé si ce réglage change.
4. Ouvrir la scène (**Blouse Blanche › Ouvrir la scène du jeu**) et appuyer sur **Lecture**.

Le jeu se lance aussi dans n'importe quelle autre scène : un `GameRoot` est créé automatiquement. La
caméra et la lumière d'une scène par défaut sont alors désactivées, car le jeu fournit les siennes.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD sur AZERTY, WASD sur QWERTY (position physique des touches), flèches | Stick gauche |
| Regarder | Souris | Stick droit |
| Courir | Maj | Clic du stick gauche |
| Interagir | E ou clic gauche | A / Croix |
| Roue des outils | Clic droit maintenu, viser, relâcher | Gâchette gauche |
| Outil direct | 1 à 9, 0, -, = | — |
| Pause | Échap | Start |

En consultation et en intervention, la souris est libre : tout se joue dans l'interface (onglets, listes,
roue des outils).

## Mode histoire (en pause)

Le projet contient aussi un **mode histoire** : des journées au cabinet avec agenda, salle d'attente,
patients sans rendez-vous, urgences, réputation et sauvegarde. Il est mis de côté pendant la phase de
prototypes. Pour le réactiver, ajouter le symbole `BB_STORY_MODE` dans
**Project Settings › Player › Scripting Define Symbols**. Une entrée « Mode histoire » apparaît alors
dans le menu principal.

## Organisation du code

```
Assets/BlouseBlanche/
  Scripts/Runtime/
    GameRoot*.cs   boucle principale : chargement, états, pause, réglages, prototypes, mode histoire
    Core/          entrées, caméra, audio et synthèse sonore, post-traitement, horloge, réglages, sauvegarde
    World/         construction procédurale du cabinet, du salon et du box ; textures, matériaux, navigation
    Characters/    personnages articulés, apparence, animation (marche, assis, allongé, respiration, massage…)
    Medical/       cas de médecine générale, examens, traitements, évaluation des consultations
    Emergency/     cas SAMU / urgences, physiologie en temps réel, tracés du scope, évaluation
    Gameplay/      contrôleurs : joueur, consultation, intervention d'urgence, patients, secrétaire
    UI/            interface UI Toolkit : menu, HUD, consultation, intervention, roue, bilan, réglages
  Scripts/Editor/  configuration du projet (menu « Blouse Blanche »)
  Resources/       feuille de style et thème de l'interface (+ matériaux et PanelSettings générés)
  Fonts/           Inter et JetBrains Mono (licence OFL)
Tools/CompileCheck/  vérification de compilation hors de Unity
```

## Vérifier la compilation sans Unity

`Tools/CompileCheck` compile tous les scripts avec le SDK .NET. Il utilise les assemblies de référence
UnityEngine (paquet NuGet `UnityEngine.Modules` 2021.3), UnityEditor (`Unity3D.SDK` 2021.1) et de
petits stubs pour les paquets URP et Input System.

```bash
# prérequis : SDK .NET 8 et accès à nuget.org
Tools/CompileCheck/check.sh
```

Quatre configurations sont vérifiées :

- jeu avec Input System ;
- jeu avec l'ancien Input Manager ;
- mode histoire ;
- éditeur.

Ce contrôle détecte les erreurs de syntaxe, de types et d'API, mais pas les particularités propres à
Unity 6 : il ne remplace pas une ouverture du projet dans l'éditeur.

## État du projet

- Les trois prototypes, le menu, le bilan, la pause et les réglages sont en place. Le code compile sans
  erreur dans les quatre configurations ci-dessus.
- Le projet n'a pas encore été ouvert dans l'éditeur Unity 6 après ces derniers ajouts. Les réglages
  visuels (cadrages, éclairage, mise en page de l'interface) et l'équilibrage des cas restent à ajuster
  en jeu.
- Les fichiers `.meta` ne sont pas versionnés : Unity les génère à la première ouverture.
