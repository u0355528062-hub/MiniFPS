class_name CaseOverdose
extends Case
## Overdose d'héroïne : coma calme, respiration très lente, pupilles en tête d'épingle, cyanose.
## Attendu : libérer les voies aériennes, ventiler au ballon ou oxygéner, glycémie capillaire,
## pupilles, naloxone titrée (0,04 à 0,1 mg IV, ou 0,4 mg IM) jusqu'à une respiration correcte —
## sans le réveiller brutalement (syndrome de sevrage) ; surveillance prolongée (la naloxone agit
## moins longtemps que l'héroïne).

var _woke := false


func _init() -> void:
	id = "overdose"
	name = "Inconscient, respire mal"
	profile = {"name": "Kevin L.", "age": 26, "skin": Color(0.98, 0.93, 0.9), "hair": Color(0.12, 0.08, 0.05), "bald": 0.0, "stubble": 0.55, "collar": false,
		"reply": "Mmh…"}
	arrival = "Kevin, 26 ans, a été retrouvé inconscient dans les toilettes d'une gare, une seringue au sol. Les pompiers l'ont ventilé un peu au ballon pendant le transport.\n\nIl ne répond pas, respire à peine, ses lèvres sont bleues."
	arrival_vitals = "Pompiers : cœur 58/min (FC) · tension 105/65 (PA) · oxygène 80 %, très bas (SpO2) · respiration 5/min, très lente (FR) · conscience 6/15 (Glasgow)"
	questions = []
	diag_ok = "Intoxication aux opiacés"
	orient_ok = "Unité d'hospitalisation de courte durée (surveillance)"
	summary_good = "Kevin respire bien. Il reste surveillé plusieurs heures : l'héroïne agit plus longtemps que la naloxone. L'équipe d'addictologie passe le voir."
	summary_bad = "Le cerveau a manqué d'oxygène trop longtemps."


func setup() -> void:
	physio.set_rhythm("brady")
	physio.hr = 58.0
	physio.sys = 105.0
	physio.dia = 65.0
	physio.spo2 = 80.0
	physio.rr = 5.0
	physio.temp = 35.8
	physio.glyc = 0.96
	physio.base = {"hr": 58.0, "sys": 105.0, "dia": 65.0, "spo2": 96.0, "rr": 5.0, "temp": 35.8, "gcs": 6, "pain": 0.0, "o2_response": 0.85}
	physio.sign_base = {"pallor": 0.35, "cyanosis": 0.0, "sweat": 0.0, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.signs = {"pallor": 0.35, "cyanosis": 0.6, "sweat": 0.0, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.pupils = {"size": 1.0, "reactive": true}
	physio.lungs = {"apex_d": "diminue", "apex_g": "diminue", "base_d": "diminue", "base_g": "diminue"}
	physio.breath_noise = "ronflement"


func _recovery() -> float:
	# Effet de la naloxone contre les opiacés (0 : aucun, 1 : réveillé)
	return clampf(float(physio.levels["naloxone"]) / 0.12, 0.0, 1.0)


func tick(_delta: float) -> void:
	var p: Patient = game.get("patient")
	var r := _recovery()
	physio.base["rr"] = lerpf(5.0, 16.0, r)
	physio.base["gcs"] = int(round(lerpf(6.0, 15.0, r)))
	physio.base["hr"] = lerpf(58.0, 88.0, r) + (25.0 if float(physio.levels["naloxone"]) > 0.6 else 0.0)
	physio.base["sys"] = lerpf(105.0, 128.0, r)
	physio.pupils["size"] = lerpf(1.0, 3.0, r)
	physio.rhythm = "sinus" if r > 0.5 else "brady"
	var lung := "normal" if r > 0.6 else "diminue"
	for k in physio.lungs:
		physio.lungs[k] = lung
	physio.breath_noise = "" if r > 0.5 or game.get("gestures").get("airway_open") else "ronflement"
	p.resp_rate = physio.rr
	p.tidal = lerpf(0.35, 0.9, r)
	if r > 0.75 and not _woke:
		_woke = true
		p.set_eyes_open(1.0)
		game.call("event", "reveil", "Il se réveille, respire normalement")
		if float(physio.levels["naloxone"]) > 0.6:
			game.call("say", "Putain mais vous avez fait quoi ?! J'ai mal partout, j'ai froid, laissez-moi !", "patient")
			fault("Trop d'antidote (naloxone) : manque brutal ; il fallait de petites doses (0,04 à 0,1 mg)", 6.0)
			physio.sign_base["sweat"] = 0.7
		else:
			game.call("say", "Hein… où je suis… ?", "patient")
		questions = [
			["Qu'avez-vous pris ?", "De l'héro… j'avais arrêté depuis deux mois, j'ai repris la même dose qu'avant."],
			["Avez-vous pris autre chose ?", "Un peu de bière. C'est tout, je vous jure."],
			["Avez-vous mal quelque part ?", "Non… j'ai juste froid."],
			["Avez-vous des maladies ?", "Hépatite C, traitée l'an dernier."],
		]
	if _woke:
		p.set_eyes_open(1.0)


func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)
	match drug:
		"naloxone":
			if route == "IV" and dose >= 0.4:
				fault("0,4 mg de naloxone d'un coup : il fallait commencer petit", 3.0)
			if not did("glycemie"):
				fault("Sucre non vérifié avant de conclure à l'overdose", 2.0)
		"midazolam":
			fault("Calmant chez un patient qui respire déjà trop peu", 10.0)
			physio.base["rr"] = 2.0
		"morphine":
			fault("Morphine dans une overdose d'opiacés !", 12.0)
		"adrenaline":
			fault("Adrénaline non indiquée (il a un pouls)", 6.0)


func lab(exam: String) -> String:
	match exam:
		"gds":
			return "pH 7,21 · PaCO2 68 mmHg · PaO2 54 mmHg · HCO3- 26 mmol/L (acidose respiratoire : hypoventilation)"
		"tox":
			return "Toxiques urinaires : opiacés POSITIFS · cannabis positif · benzodiazépines négatives"
		"alcool":
			return "Alcoolémie : 0,4 g/L"
		"lact":
			return "Lactates : 2,1 mmol/L"
	return super.lab(exam)


func ecg12() -> Dictionary:
	return {"rhythm": physio.rhythm, "rate": physio.hr, "st": "", "text": "Bradycardie sinusale %d/min, pas d'anomalie de la repolarisation." % int(physio.hr) if physio.hr < 60.0 else "Rythme sinusal %d/min, normal." % int(physio.hr)}


func objectives() -> Array:
	var oxy := did("bavu") or did("o2_masque")
	return [
		["Vérifier s'il répond et s'il respire", 8.0, did("stimulation") and did("respiration"), "Le b.a.-ba : conscience, respiration, pouls."],
		["Lui donner de l'oxygène (ballon ou masque)", 15.0, oxy, "Il respire trop lentement : il faut l'aider tout de suite."],
		["Surveiller l'oxygène (pince SpO2)", 6.0, did("spo2"), "Pour voir si l'oxygène remonte."],
		["Mesurer le sucre (glycémie)", 10.0, did("glycemie"), "Un manque de sucre peut ressembler à une overdose."],
		["Regarder les pupilles (lampe)", 8.0, did("pupilles"), "Toutes petites (myosis) : signe typique de l'héroïne."],
		["Donner l'antidote (naloxone)", 18.0, did("drug:naloxone"), "Elle chasse l'héroïne et il se remet à respirer."],
		["Le réveiller en douceur (petites doses)", 10.0, _woke and float(physio.totals.get("naloxone", 0.0)) <= 0.5, "Trop d'antidote d'un coup provoque un manque brutal : agitation, vomissements."],
		["Rechercher les drogues (prise de sang)", 3.0, did("exam:tox"), "Pour confirmer ce qu'il a pris."],
		["Diagnostic : overdose d'opiacés", 10.0, did("diag_ok"), "Dans le dossier (Tab), onglet Conclusion."],
		["Le garder en surveillance (UHCD)", 12.0, did("orient_ok"), "L'héroïne agit plus longtemps que l'antidote : il peut se rendormir."],
	]
