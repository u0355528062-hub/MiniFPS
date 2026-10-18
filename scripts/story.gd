class_name Story
extends RefCounted
## Histoire « Première garde » : tu es un jeune interne qui fait sa première nuit aux urgences, avec
## Sophie (infirmière) et le Dr Marchand (médecin sénior). Trois patients à la suite :
##   1. Patrick, hypoglycémie : TUTORIEL, Sophie guide chaque geste (on ne peut pas échouer gravement) ;
##   2. Thomas, choc anaphylactique : le chef donne des conseils si on traîne ;
##   3. Michel, arrêt cardiaque en fibrillation : l'apothéose.
## Entre les patients : bilan, avis du chef, transition. La progression est sauvegardée (Records).
## L'état de l'histoire survit aux rechargements de scène (variables statiques).

const CHAPTERS := [
	{"case": "hypoglycemie", "title": "Il ne se réveille pas", "time": "20 h 15", "tutorial": true},
	{"case": "anaphylaxie", "title": "Une piqûre de guêpe", "time": "22 h 40"},
	{"case": "acr_fv", "title": "Le cœur s'arrête", "time": "03 h 12"},
]

static var active := false
static var chapter := 0
static var results := {}  ## chapitre (int) -> {grade, score, alive}
static var _testing := false


static func current() -> Dictionary:
	return CHAPTERS[clampi(chapter, 0, CHAPTERS.size() - 1)]


static func is_tutorial() -> bool:
	return active and bool(current().get("tutorial", false))


## Commence (ou reprend) l'histoire.
static func begin(fresh: bool, testing := false) -> void:
	active = true
	_testing = testing
	if fresh or testing:
		chapter = 0
		results = {}
	else:
		var s := Records.story()
		chapter = clampi(int(s["chapter"]), 0, CHAPTERS.size() - 1)
		results = s["results"]
	_save()


static func record(res: Dictionary) -> void:
	results[chapter] = {"grade": res["grade"], "score": res["score"], "alive": res["alive"]}
	_save()


## Passe au patient suivant ; faux quand l'histoire est finie.
static func advance() -> bool:
	chapter += 1
	if chapter >= CHAPTERS.size():
		chapter = CHAPTERS.size()
		if not _testing:
			Records.save_story(0, results, true)
		return false
	_save()
	return true


static func _save() -> void:
	if not _testing:
		Records.save_story(chapter, results)


static func stop() -> void:
	active = false


# ---------------------------------------------------------------- Dialogues

static func L(who: String, text: String) -> Dictionary:
	return {"who": who, "text": text}


static func C(text: String, reply: Array, id := "") -> Dictionary:
	return {"text": text, "reply": reply, "id": id}


## Arrivée à l'hôpital (sur le fond du menu).
static func intro_lines() -> Array:
	return [
		L("narrateur", "Hôpital Saint-Roch, service des urgences. Vendredi soir, 20 h. C'est ta toute première garde d'interne."),
		L("sophie", "Ah, c'est toi le nouvel interne ? Bienvenue ! Moi c'est Sophie, je suis l'infirmière du déchocage cette nuit."),
		{"who": "sophie", "text": "Tu as l'air un peu stressé, non ?", "choices": [
			C("Un peu… c'est ma toute première garde.", [L("sophie", "Ça se voit : tu serres ton stéthoscope comme une bouée. T'inquiète pas, on va bien s'occuper de toi.")], "stresse"),
			C("Le déchocage, c'est quoi exactement ?", [L("sophie", "La salle des urgences vitales : les patients les plus graves arrivent ici. Tout le matériel est à portée de main.")], "dechocage"),
		]},
		L("marchand", "Bonsoir. Dr Marchand, médecin sénior de garde. C'est moi qui supervise tes décisions cette nuit."),
		L("marchand", "Règle numéro un : un patient grave, on l'examine dans l'ordre. Est-ce qu'il répond ? Est-ce qu'il respire ? Est-ce que son cœur bat ? Ensuite seulement, on cherche pourquoi."),
		L("marchand", "Règle numéro deux : si tu as un doute, tu demandes. Personne ne t'en voudra."),
		L("sophie", "Et justement… le SAMU nous amène quelqu'un. Un diabétique qui ne se réveille pas."),
		L("marchand", "Parfait pour commencer. Sophie va te montrer chaque geste, pas à pas. Je reste à côté."),
	]


## Transmission du patient (et transition depuis le patient précédent).
static func briefing_lines(ch: int) -> Array:
	match ch:
		0:
			return [
				L("sophie", "Voici Patrick, 47 ans. Son collègue l'a trouvé à son bureau : d'abord confus et agressif, puis il s'est endormi. Il ne répond plus."),
				L("sophie", "Il est diabétique, il fait de l'insuline. Et il n'aurait pas mangé ce midi. Regarde : il est trempé de sueur."),
				{"who": "sophie", "text": "Une question avant d'y aller ?", "choices": [
					C("C'est quoi, l'insuline ?", [L("sophie", "Un médicament qui fait baisser le sucre dans le sang. Trop d'insuline sans manger… et le sucre s'effondre. Le cerveau, lui, ne fonctionne qu'avec du sucre.")], "insuline"),
					C("Non, on y va !", [L("sophie", "J'aime cet enthousiasme !")], "go"),
				]},
				L("sophie", "Je te guide étape par étape. En haut à gauche, il y a ce qu'il faut faire maintenant ; les flèches te montrent où aller. Pas de panique : tu ne peux rien casser."),
			]
		1:
			return [
				L("marchand", "Patrick dort tranquillement en surveillance, il a mangé un plateau-repas. Joli travail pour un premier patient."),
				L("sophie", "Docteur ! L'ambulance arrive : un homme piqué par une guêpe, il est tout rouge et il respire mal !"),
				L("marchand", "Cette fois, Sophie ne te montrera pas chaque geste. Je te donnerai des conseils si tu traînes. Écoute bien la transmission."),
				L("sophie", "Thomas, 34 ans. Piqué au cou il y a quinze minutes, en terrasse. Plaques rouges partout, lèvres qui gonflent, il a du mal à respirer et il a fait un malaise."),
				L("sophie", "Sa tension est effondrée : 7 (72/40). Son cœur bat à 135. L'oxygène dans le sang est à 91 % : c'est bas."),
				L("marchand", "C'est une allergie grave : un choc anaphylactique. Les vaisseaux se dilatent, la tension chute, la gorge gonfle. Il peut mourir en quelques minutes."),
				{"who": "marchand", "text": "Qu'est-ce que tu veux savoir ?", "choices": [
					C("Qu'est-ce qu'on lui donne ?", [L("marchand", "De l'adrénaline : 0,5 mg dans le muscle de la cuisse, tout de suite. C'est LE médicament qui le sauve. Ensuite : oxygène, sérum dans la veine, cortisone.")], "quoi"),
					C("Je peux injecter l'adrénaline dans la veine ?", [L("marchand", "Surtout pas d'un coup dans la veine ! Ça peut déclencher un trouble du rythme mortel. Dans le muscle de la cuisse : 0,5 mg.")], "iv"),
				]},
				L("marchand", "Ta liste de tâches est en haut à gauche. Vas-y, je te regarde."),
			]
		2:
			return [
				L("narrateur", "La nuit avance. Les couloirs se sont calmés. Tu as mangé un sandwich debout, entre deux dossiers."),
				L("marchand", "Thomas va bien, ses plaques ont disparu. Tu tiens le coup ?"),
				L("marchand", "Michel, 58 ans, est installé au déchocage pour une douleur dans la poitrine. Je finis un appel avec le cardiologue et je te rejoins."),
				L("marchand", "Rappelle-toi : si quelqu'un s'effondre, qu'il ne répond pas et ne respire pas normalement, c'est un arrêt cardiaque."),
				{"who": "marchand", "text": "Tu sais ce qu'il faut faire ?", "choices": [
					C("Pas vraiment… qu'est-ce que je fais ?", [L("marchand", "Tu masses tout de suite : au milieu de la poitrine, fort et vite. Tu colles les électrodes du défibrillateur et tu laisses l'appareil analyser. S'il dit « choc », tu choques.")], "aide"),
					C("Massage, électrodes, choc.", [L("marchand", "Exactement. Et tu n'arrêtes jamais de masser plus de quelques secondes.")], "ok"),
				]},
				L("sophie", "Je vais chercher le chariot de l'autre box, je reviens tout de suite !"),
				L("narrateur", "Tu entres dans la salle. Michel pousse un râle. Son regard se fige. Il ne répond plus."),
			]
	return []


## Ce que le chef pense du patient qui vient d'être pris en charge.
static func debrief(ch: int, res: Dictionary) -> String:
	var g: String = res.get("grade", "D")
	var alive: bool = res.get("alive", true)
	var good := g in ["S", "A"]
	var mid := g in ["B", "C"]
	match ch:
		0:
			if good:
				return "Très bien. Devant quelqu'un qui ne se réveille pas, on vérifie toujours le sucre : c'est rapide, et ça se soigne en une minute. Tu viens de protéger le cerveau de Patrick."
			if mid:
				return "Patrick va bien, c'est l'essentiel. Regarde ce que tu as oublié : la prochaine fois, ça doit devenir un réflexe."
			return "Patrick a souffert. Pour un premier patient, ce n'est pas grave : on apprend. Relis le bilan, et recommence si tu veux."
		1:
			if not alive:
				return "On l'a perdu. Dans un choc allergique, chaque minute sans adrénaline compte. On en reparlera calmement… tu veux réessayer ?"
			if good:
				return "Excellent. L'adrénaline dans la cuisse, vite : c'est ce qui sauve dans l'anaphylaxie. Thomas repartira avec deux stylos d'adrénaline sur lui."
			if mid:
				return "Thomas s'en sort. Retiens surtout : l'adrénaline d'abord, et dans le muscle. Le reste vient après."
			return "C'était juste. L'adrénaline doit partir dans les toutes premières minutes. Relis le bilan."
		2:
			if not alive:
				return "On n'a pas pu le ramener. Ça arrive, même aux meilleurs. Ce qui compte : masser vite et fort, choquer tôt. Tu veux réessayer ?"
			if good:
				return "Tu as ramené Michel. Massage, choc, adrénaline : tout dans l'ordre. Ça, c'est une vraie nuit d'urgentiste."
			if mid:
				return "Michel est vivant, et c'est grâce à ton massage. Quelques points à revoir, mais je suis fier de toi."
			return "Michel est vivant, mais de justesse. Revois l'enchaînement : massage, électrodes, choc, et on ne s'arrête pas."
	return ""


## Fin de la garde.
static func ending_lines() -> Array:
	var michel_ok: bool = results.get(2, {}).get("alive", true)
	var lines := [
		L("narrateur", "7 h 58. Le jour se lève sur le parking des urgences. L'équipe du matin arrive, un café à la main."),
		L("sophie", "Alors, cette première garde ? Trois patients, et pas des plus simples !"),
		L("marchand", "Patrick est rentré chez lui en promettant de manger à midi. Thomas a ses stylos d'adrénaline. " +
			("Et Michel s'est réveillé en réanimation il y a une heure. Il a demandé qui l'avait massé." if michel_ok else "Michel… on a tout tenté. Ça fait partie du métier, et on en parlera.")),
		{"who": "marchand", "text": "Alors ?", "choices": [
			C("Merci de m'avoir guidé.", [L("marchand", "Tu as fait le travail. Moi, j'ai surtout regardé.")], "merci"),
			C("J'étais terrifié.", [L("sophie", "Tout le monde l'est la première fois. C'est bon signe : ça veut dire que tu prends ça au sérieux.")], "peur"),
		]},
		L("marchand", "Va dormir. Ta prochaine garde est dans trois jours… d'ici là, tu peux t'entraîner sur d'autres patients."),
		L("narrateur", "Fin de la première garde. L'entraînement libre est débloqué : six patients t'attendent."),
	]
	return lines


# ---------------------------------------------------------------- Conseils pendant la prise en charge

static func _did(g: ERGame, kind: String) -> bool:
	return g.journal.has(kind)


static func _since(g: ERGame, kind: String) -> float:
	var t0 := g.journal.first(kind)
	return INF if t0 == INF else g.physio.time - t0


static func _since_last(g: ERGame, kind: String) -> float:
	var e := g.journal.last(kind)
	return INF if e.is_empty() else g.physio.time - float(e["t"])


static func _has_syringe(g: ERGame, drug: String) -> bool:
	for it in g.inv.items:
		if it["id"] == "seringue" and it["data"].get("drug", "") == drug:
			return true
	return false


## Conseils du chef et de l'infirmière : une réplique quand la condition devient vraie (une fois, ou
## toutes les « repeat » secondes). « offer_iv » : Sophie propose de poser la voie veineuse.
static func coach_rules(ch: int) -> Array:
	match ch:
		1:
			return [
				{"who": "marchand", "text": "L'adrénaline, maintenant ! Chariot → Médicaments → Adrénaline 0,5 mg, « Dans le muscle (IM) ». Puis sur le côté de la cuisse.",
					"when": func(g: ERGame) -> bool: return g.physio.time > 40.0 and not Story._did(g, "drug:adrenaline") and not Story._has_syringe(g, "adrenaline"), "repeat": 60.0},
				{"who": "sophie", "text": "Tu as la seringue d'adrénaline : vue rapprochée sur les jambes, clic maintenu sur le côté de la cuisse.",
					"when": func(g: ERGame) -> bool: return Story._has_syringe(g, "adrenaline") and not Story._did(g, "drug:adrenaline") and g.physio.time > 30.0, "repeat": 45.0},
				{"who": "sophie", "text": "Il respire mal : le masque à oxygène est dans le chariot (onglet Respiration). Ensuite, ouvre l'oxygène au mur, à 15 L/min.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "drug:adrenaline") > 20.0 and not Story._did(g, "o2_masque") and not Story._did(g, "o2_nebu")},
				{"who": "sophie", "text": "Le masque est posé, mais l'oxygène est fermé ! Le débitmètre est au mur, à droite du brancard : monte à 15 L/min.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "o2_masque") > 12.0 and g.physio.o2_flow <= 0.0, "repeat": 50.0},
				{"who": "marchand", "text": "Pose le brassard à tension : il faut voir si la tension remonte.",
					"when": func(g: ERGame) -> bool: return g.physio.time > 110.0 and not Story._did(g, "brassard")},
				{"who": "sophie", "text": "Il lui faut du liquide dans la veine. Tu poses la voie veineuse, ou je m'en occupe ?", "offer_iv": true,
					"when": func(g: ERGame) -> bool: return g.physio.time > 150.0 and not Story._did(g, "vvp")},
				{"who": "sophie", "text": "La voie est posée : branche la poche de sérum (chariot → Perfusion) sur le robinet du cathéter.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "vvp") > 20.0 and not Story._did(g, "perfusion"), "repeat": 60.0},
				{"who": "marchand", "text": "Ajoute la cortisone : méthylprednisolone 80 mg dans la veine. Elle évite que la réaction revienne cette nuit.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "perfusion") > 30.0 and not Story._did(g, "drug:methylpred")},
				{"who": "marchand", "text": "Ça ne s'améliore pas assez : refais 0,5 mg d'adrénaline dans la cuisse.",
					"when": func(g: ERGame) -> bool: return Story._since_last(g, "drug:adrenaline") > 300.0 and (g.case as CaseAnaphylaxie).shock > 0.5, "repeat": 240.0},
				{"who": "marchand", "text": "Il va beaucoup mieux. Quand tu es prêt, conclus dans le dossier : touche Tab, onglet Conclusion.",
					"when": func(g: ERGame) -> bool: return (g.case as CaseAnaphylaxie).shock < 0.35 and Story._did(g, "perfusion"), "repeat": 120.0},
			]
		2:
			return [
				{"who": "sophie", "text": "Docteur ? Il ne bouge plus ! Vérifie : est-ce qu'il respire ? Est-ce qu'il a un pouls au cou ?",
					"when": func(g: ERGame) -> bool: return g.physio.time > 8.0 and not (Story._did(g, "pouls") or Story._did(g, "respiration") or Story._did(g, "rcp"))},
				{"who": "marchand", "text": "Pas de pouls : massage ! Vue rapprochée sur le thorax, les Mains : clic maintenu au milieu de la poitrine, et pousse la souris vers le bas en rythme.",
					"when": func(g: ERGame) -> bool: return (Story._did(g, "pouls") or Story._did(g, "respiration") or g.physio.time > 30.0) and not Story._did(g, "rcp"), "repeat": 30.0},
				{"who": "sophie", "text": "Le chariot est là ! Prends les électrodes du défibrillateur (onglet Surveillance) : une sous la clavicule droite, une sous l'aisselle gauche.",
					"when": func(g: ERGame) -> bool: return g.physio.time > 40.0 and not Story._did(g, "pads"), "repeat": 50.0},
				{"who": "marchand", "text": "Électrodes collées : allume le défibrillateur (Marche), puis Analyse. S'il recommande un choc : Charge, on s'écarte, Choc.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "pads") > 15.0 and not Story._did(g, "choc") and g.physio.shockable(), "repeat": 40.0},
				{"who": "marchand", "text": "Choc délivré : reprends le massage tout de suite ! Deux minutes, puis on analyse à nouveau.",
					"when": func(g: ERGame) -> bool: return Story._since_last(g, "choc") > 6.0 and Story._since_last(g, "choc") < 30.0 and g.physio.in_arrest() and not g.physio.cpr_running(), "repeat": 25.0},
				{"who": "sophie", "text": "Il faut aussi lui donner de l'air : le ballon (BAVU) sur le visage, 2 insufflations toutes les 30 compressions.",
					"when": func(g: ERGame) -> bool: return Story._since(g, "choc") > 30.0 and not Story._did(g, "bavu") and g.physio.in_arrest()},
				{"who": "sophie", "text": "Il va lui falloir des médicaments dans la veine. Je te pose la voie veineuse pendant que tu masses ?", "offer_iv": true,
					"when": func(g: ERGame) -> bool: return Story._since(g, "choc") > 45.0 and not Story._did(g, "vvp") and g.physio.in_arrest()},
				{"who": "marchand", "text": "Troisième choc : adrénaline 1 mg et amiodarone 300 mg, dans la veine. Prépare-les au chariot.",
					"when": func(g: ERGame) -> bool: return g.journal.count("choc") >= 3 and not Story._did(g, "drug:adrenaline") and g.physio.in_arrest(), "repeat": 60.0},
				{"who": "marchand", "text": "Il a un pouls ! Le cœur est reparti. Vérifie ses constantes, fais un ECG si tu peux, puis conclus : arrêt cardiaque, direction la coronarographie.",
					"when": func(g: ERGame) -> bool: return g.physio.rosc and not g.physio.in_arrest()},
			]
	return []
