class_name CaseAnaphylaxie
extends Case
## Choc anaphylactique après une piqûre de guêpe : urticaire géante, lèvres gonflées, voix rauque,
## sibilants, tension effondrée. Attendu : adrénaline 0,5 mg IM tout de suite (cuisse), à refaire
## à 5 minutes si besoin, oxygène, remplissage (NaCl), salbutamol si les bronches restent serrées,
## corticoïdes ensuite ; surveillance (réaction biphasique). L'adrénaline IV en bolus est dangereuse.

var shock := 0.8  ## 0 : guéri, 1 : collapsus


func _init() -> void:
	id = "anaphylaxie"
	name = "Choc anaphylactique"
	profile = {"name": "Thomas G.", "age": 34, "skin": Color(1.0, 0.94, 0.92), "hair": Color(0.45, 0.3, 0.15), "bald": 0.0, "stubble": 0.2, "collar": false,
		"reply": "J'ai… la gorge qui serre… ça gratte partout…"}
	arrival = "Thomas, 34 ans, a été piqué par une guêpe au cou il y a quinze minutes en déjeunant en terrasse. Très vite : plaques rouges partout, lèvres qui gonflent, gêne pour respirer, malaise.\n\nIl est allongé, très rouge, couvert de plaques, il parle d'une voix rauque."
	arrival_vitals = "Ambulance : FC 135 · PA 72/40 · SpO2 91 % · FR 28"
	lines = ["Ça gratte partout…", "J'ai la gorge… qui gonfle…", "Je me sens pas bien… la tête tourne…"]
	diag_ok = "Choc anaphylactique"
	orient_ok = "Unité d'hospitalisation de courte durée (surveillance)"
	summary_good = "Les plaques s'effacent, la tension est remontée. Thomas reste surveillé 24 heures (une seconde réaction peut survenir) et repartira avec deux stylos d'adrénaline et un rendez-vous d'allergologie."
	summary_bad = "Le choc n'a pas été contrôlé à temps."


func setup() -> void:
	physio.set_rhythm("sinus")
	physio.hr = 135.0
	physio.sys = 72.0
	physio.dia = 40.0
	physio.spo2 = 91.0
	physio.rr = 28.0
	physio.temp = 37.0
	physio.glyc = 1.2
	_apply()
	physio.signs = physio.sign_base.duplicate()


func _apply() -> void:
	var s := shock
	var fluid := clampf(physio.fluids_ml / 1000.0, 0.0, 1.0) * 0.35
	var collapse := clampf((s - 0.9) / 0.1, 0.0, 1.0)
	physio.base = {"hr": lerpf(84.0, 140.0, s) - collapse * 30.0, "sys": lerpf(122.0, 70.0, s) + fluid * 30.0 - collapse * 25.0,
		"dia": lerpf(76.0, 38.0, s) + fluid * 15.0, "spo2": lerpf(98.0, 89.0, s), "rr": lerpf(16.0, 30.0, s), "temp": 37.0,
		"gcs": 15 - int(collapse * 6.0), "pain": 0.0, "o2_response": 0.8}
	var lung := "sibilants" if s > 0.35 else "normal"
	for k in physio.lungs:
		physio.lungs[k] = lung
	physio.sign_base = {"pallor": 0.0, "cyanosis": 0.0, "sweat": 0.4 * s, "mottling": collapse * 0.6, "urticaria": clampf(s * 1.2, 0.0, 1.0), "flush": clampf(s * 1.1, 0.0, 1.0)}
	profile["reply"] = "J'ai… la gorge qui serre… ça gratte partout…" if s > 0.5 else "Ça va mieux… ça gratte encore un peu."
	lines = ["Ça gratte partout…", "J'ai la gorge… qui gonfle…", "Je me sens pas bien… la tête tourne…"] if s > 0.45 else []


func tick(delta: float) -> void:
	var p: Patient = game.get("patient")
	if physio.in_arrest():
		p.resp_rate = 0.0
		return
	var adr := float(physio.levels["adrenaline"])
	var cortico := clampf(float(physio.levels["methylpred"]) / 60.0, 0.0, 1.0)
	var trend := 0.0012 - adr * 0.012 - cortico * 0.0003
	shock = clampf(shock + trend * delta, 0.0, 1.0)
	_apply()
	if shock >= 0.999 and physio.sys < 45.0:
		physio.set_rhythm("aesp")
		game.call("event", "acr", "Arrêt cardiaque (activité électrique sans pouls)")
	p.resp_rate = physio.rr
	p.tidal = 0.8
	p.set_eyes_open(1.0 if physio.gcs >= 13 else 0.0)
	if shock < 0.4 and questions.is_empty():
		questions = [
			["Êtes-vous allergique à quelque chose ?", "Je savais pas… j'avais déjà eu une grosse plaque après une piqûre, l'an dernier."],
			["Avez-vous des maladies, des traitements ?", "Rien du tout."],
			["Avez-vous encore du mal à respirer ?", "Beaucoup moins."],
			["Avez-vous mal au ventre, des nausées ?", "J'ai eu envie de vomir au début, ça passe."],
		]


func on_drug(drug: String, dose: float, route: String) -> void:
	match drug:
		"adrenaline":
			if route == "IV" and not physio.in_arrest() and dose >= 0.5:
				fault("Adrénaline 0,5-1 mg en bolus IV chez un patient qui a un pouls : risque de trouble du rythme mortel", 15.0)
				physio.give(drug, dose * 0.3, route)
				physio.set_rhythm("tv")
				physio.hr = 190.0
				game.call("get_tree").create_timer(8.0).timeout.connect(func() -> void:
					if physio.rhythm == "tv":
						physio.set_rhythm("sinus"))
				return
			physio.give(drug, dose, route)
		"salbutamol":
			physio.give(drug, dose, route)
			shock = maxf(0.0, shock - 0.05)
		"midazolam", "morphine":
			physio.give(drug, dose, route)
			fault("Sédation dans un choc anaphylactique", 8.0)
		_:
			physio.give(drug, dose, route)


func lab(exam: String) -> String:
	match exam:
		"lact":
			return "Lactates : 3,9 mmol/L"
		"nfs":
			return "Hb 16,0 g/dL (hémoconcentration) · leucocytes 11,2 G/L · plaquettes 300 G/L"
		"tryptase":
			return "Tryptase sérique : 48 µg/L (N < 11,4) : dégranulation des mastocytes"
	return super.lab(exam)


func objectives() -> Array:
	var adr_t := when("drug:adrenaline")
	var first_im := false
	for e in journal().all("drug:adrenaline"):
		if e["data"].get("route", "") == "IM":
			first_im = true
	return [
		["Adrénaline dans les 5 premières minutes", 25.0, adr_t < 300.0],
		["Adrénaline par voie IM (0,5 mg)", 10.0, first_im],
		["Oxygène", 8.0, did("o2_masque") or did("o2_nebu")],
		["Tension surveillée (brassard)", 6.0, did("brassard")],
		["Voie veineuse + remplissage", 12.0, did("perfusion")],
		["Corticoïdes", 4.0, did("drug:methylpred")],
		["Choc contrôlé", 15.0, shock < 0.35],
		["Diagnostic juste", 10.0, did("diag_ok")],
		["Surveillance prolongée (UHCD)", 10.0, did("orient_ok")],
	]
