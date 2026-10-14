class_name CaseHypo
extends Case
## Hypoglycémie sévère chez un diabétique sous insuline : coma, sueurs profuses, agitation.
## Attendu : glycémie capillaire d'emblée, voie veineuse, glucosé 30 % (30 mL = 9 g) IV, ou glucagon
## 1 mg IM sans voie veineuse ; contrôle de la glycémie après ; surveillance.

var _woke := false
var _rechecked := false


func _init() -> void:
	id = "hypoglycemie"
	name = "Coma chez un diabétique"
	profile = {"name": "Patrick B.", "age": 47, "skin": Color(0.98, 0.92, 0.88), "hair": Color(0.2, 0.14, 0.09), "bald": 0.1, "stubble": 0.3, "collar": false,
		"reply": "Hmmm… laissez…"}
	arrival = "Patrick, 47 ans, diabétique sous insuline, a été retrouvé par un collègue à son bureau, confus et agressif, puis il s'est endormi. Il n'a pas mangé à midi.\n\nIl est trempé de sueur et ne répond plus aux questions."
	arrival_vitals = "SMUR : FC 108 · PA 138/82 · SpO2 97 % · FR 16 · Glasgow 8"
	diag_ok = "Hypoglycémie sévère"
	orient_ok = "Unité d'hospitalisation de courte durée (surveillance)"
	summary_good = "Patrick s'est réveillé, a mangé un plateau-repas et sa glycémie reste stable. On revoit avec lui ses doses d'insuline avant sa sortie."
	summary_bad = "Le cerveau est resté trop longtemps sans sucre."


func setup() -> void:
	physio.set_rhythm("sinus")
	physio.hr = 108.0
	physio.sys = 138.0
	physio.dia = 82.0
	physio.spo2 = 97.0
	physio.rr = 16.0
	physio.glyc = 0.32
	physio.temp = 36.3
	physio.base = {"hr": 108.0, "sys": 138.0, "dia": 82.0, "spo2": 97.0, "rr": 16.0, "temp": 36.3, "gcs": 8, "pain": 0.0, "o2_response": 0.9}
	physio.sign_base = {"pallor": 0.45, "cyanosis": 0.0, "sweat": 1.0, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.signs = physio.sign_base.duplicate()
	physio.pupils = {"size": 4.5, "reactive": true}


func tick(delta: float) -> void:
	var p: Patient = game.get("patient")
	# Le glucosé remonte la glycémie aussitôt ; le glucagon en quelques minutes ; puis elle redescend
	# doucement (l'insuline agit encore) tant qu'il n'a pas mangé
	var gluca := float(physio.levels["glucagon"])
	physio.glyc += gluca * 0.004 * delta
	physio.glyc = maxf(0.25, physio.glyc - delta * 0.0006)
	var g := physio.glyc
	var awake := clampf((g - 0.45) / 0.3, 0.0, 1.0)
	physio.base["gcs"] = int(round(lerpf(8.0, 15.0, awake)))
	physio.base["hr"] = lerpf(108.0, 82.0, awake)
	physio.sign_base["sweat"] = lerpf(1.0, 0.2, awake)
	physio.sign_base["pallor"] = lerpf(0.45, 0.1, awake)
	if g < 0.3 and t() > 480.0:
		physio.base["gcs"] = 5
	p.resp_rate = physio.rr
	if awake > 0.9 and not _woke:
		_woke = true
		p.set_eyes_open(1.0)
		game.call("event", "reveil", "Il se réveille, cohérent")
		game.call("say", "Oh non… j'ai encore fait une hypo, c'est ça ?", "patient")
		questions = [
			["Qu'avez-vous mangé aujourd'hui ?", "Rien depuis ce matin… réunion à midi, j'ai sauté le repas."],
			["Quelle insuline faites-vous ?", "Lantus le soir, et de la NovoRapid avant les repas. J'en ai fait ce midi par habitude…"],
			["Ça vous arrive souvent ?", "Une fois par mois à peu près, mais jamais comme ça."],
			["Avez-vous bu de l'alcool ?", "Non."],
			["Avez-vous mal quelque part ?", "Un peu mal à la tête, c'est tout."],
		]
	if _woke:
		p.set_eyes_open(1.0)
	if _woke and did("glycemie") and journal().last("glycemie").get("t", 0.0) > journal().first("reveil") - 60.0:
		_rechecked = true


func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)
	match drug:
		"glucose30":
			if not did("glycemie"):
				fault("Sucre injecté sans glycémie capillaire préalable", 3.0)
		"naloxone":
			fault("Naloxone : pas d'argument pour une overdose (glycémie !)", 2.0)
		"midazolam":
			fault("Sédation d'un patient agité par une hypoglycémie : il faut du sucre", 8.0)
		"adrenaline":
			fault("Adrénaline non indiquée", 6.0)


func lab(exam: String) -> String:
	match exam:
		"iono":
			return "Na 139 · K 3,6 · Cl 102 mmol/L · créatinine 76 µmol/L · glycémie veineuse %s g/L" % ("%.2f" % physio.glyc).replace(".", ",")
		"alcool":
			return "Alcoolémie : 0 g/L"
	return super.lab(exam)


func objectives() -> Array:
	var sugar := did("drug:glucose30") or did("drug:glucagon")
	return [
		["Glycémie capillaire dans les 3 premières minutes", 20.0, when("glycemie") < 180.0],
		["Resucrage (glucosé 30 % IV ou glucagon IM)", 25.0, sugar],
		["Voie veineuse", 8.0, did("vvp")],
		["Glycémie contrôlée après le resucrage", 12.0, _rechecked],
		["Patient réveillé", 10.0, _woke],
		["Interrogatoire au réveil", 5.0, journal().count("question") >= 2],
		["Diagnostic juste", 10.0, did("diag_ok")],
		["Orientation (surveillance)", 10.0, did("orient_ok")],
	]
