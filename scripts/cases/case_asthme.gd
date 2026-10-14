class_name CaseAsthme
extends Case
## Asthme aigu grave : parle par mots, polypnée, tirage, sibilants (puis silence auscultatoire),
## tachycardie, saturation basse. Attendu : oxygène, nébulisations de salbutamol (+ ipratropium)
## sous 6 à 8 L/min d'O2, corticoïdes IV, gaz du sang ; jamais de sédation. Sans traitement il
## s'épuise : la respiration ralentit, il s'endort… jusqu'à l'arrêt.

var severity := 0.75  ## 0 : bien, 1 : épuisé
var _neb := 0


func _init() -> void:
	id = "asthme"
	name = "Crise d'asthme grave"
	profile = {"name": "Yanis K.", "age": 23, "skin": Color(0.86, 0.72, 0.6), "hair": Color(0.04, 0.03, 0.025), "bald": 0.0, "stubble": 0.4, "collar": false,
		"reply": "J'peux… pas… respirer…"}
	arrival = "Yanis, 23 ans, asthmatique depuis l'enfance, arrive en ambulance : crise depuis six heures, une dizaine de bouffées de Ventoline sans effet. Il est assis, penché en avant, parle mot par mot.\n\nOn l'a allongé, dossier relevé : il tire sur son cou à chaque inspiration."
	arrival_vitals = "Ambulance : FC 128 · PA 135/80 · SpO2 88 % (air) · FR 34 · DEP impossible"
	lines = ["J'peux… pas… respirer…", "Aidez… moi…", "Ça… siffle…"]
	diag_ok = "Asthme aigu grave"
	orient_ok = "Hospitalisation en pneumologie"
	summary_good = "La crise cède : Yanis respire mieux, parle normalement. Il est hospitalisé pour poursuivre le traitement et revoir son traitement de fond."
	summary_bad = "Il s'est épuisé avant que les bronches ne s'ouvrent."


func setup() -> void:
	physio.set_rhythm("sinus")
	physio.hr = 128.0
	physio.sys = 135.0
	physio.dia = 80.0
	physio.spo2 = 88.0
	physio.rr = 34.0
	physio.temp = 37.2
	physio.glyc = 1.1
	physio.breath_noise = "tirage"
	physio.pupils = {"size": 3.5, "reactive": true}
	_apply(0.0)
	physio.signs = physio.sign_base.duplicate()


func _apply(_delta: float) -> void:
	var s := severity
	var exhausted := clampf((s - 0.85) / 0.15, 0.0, 1.0)
	physio.base = {"hr": lerpf(88.0, 138.0, minf(s / 0.85, 1.0)) - exhausted * 40.0, "sys": 125.0 + 10.0 * s, "dia": 78.0,
		"spo2": lerpf(97.0, 86.0, minf(s / 0.85, 1.0)) - exhausted * 18.0, "rr": lerpf(16.0, 36.0, minf(s / 0.85, 1.0)) - exhausted * 26.0,
		"temp": 37.2, "gcs": 15 - int(exhausted * 7.0), "pain": 0.0, "o2_response": 0.7}
	var lung := "normal"
	if s > 0.85:
		lung = "absent"
	elif s > 0.65:
		lung = "diminue"
	elif s > 0.2:
		lung = "sibilants"
	if s > 0.4 and s <= 0.85:
		lung = "sibilants"
	for k in physio.lungs:
		physio.lungs[k] = lung
	physio.sign_base = {"pallor": 0.2 + 0.3 * s, "cyanosis": 0.0, "sweat": 0.8 * s, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.breath_noise = "tirage" if s > 0.4 else ""
	profile["reply"] = "J'peux… pas… respirer…" if s > 0.5 else "Ça va un peu mieux…"
	lines = ["J'peux… pas… respirer…", "Aidez… moi…", "Ça… siffle…"] if s > 0.45 else []


func tick(delta: float) -> void:
	var p: Patient = game.get("patient")
	if physio.in_arrest():
		p.resp_rate = 0.0
		return
	# Évolution : s'aggrave doucement ; salbutamol, corticoïdes et oxygène font reculer la crise
	var salbu := float(physio.levels["salbutamol"])
	var cortico := clampf(float(physio.levels["methylpred"]) / 60.0, 0.0, 1.0)
	var trend := 0.0010 - salbu * 0.0004 - cortico * 0.0003 - physio.o2_support() * 0.0002
	severity = clampf(severity + trend * delta, 0.05, 1.0)
	_apply(delta)
	if severity >= 0.999 and physio.spo2 < 60.0 and not physio.in_arrest():
		physio.set_rhythm("asystolie")
		game.call("event", "acr", "Arrêt cardiaque hypoxique")
	p.resp_rate = physio.rr
	p.tidal = lerpf(0.9, 0.45, severity)
	p.set_eyes_open(1.0 if physio.gcs >= 13 else 0.0)
	if severity < 0.35 and questions.is_empty():
		questions = [
			["Depuis quand êtes-vous gêné ?", "Depuis ce matin… je suis enrhumé depuis trois jours."],
			["Quel est votre traitement de fond ?", "Je devais prendre du Symbicort… mais je l'oublie souvent."],
			["Avez-vous déjà été en réanimation ?", "Une fois, à quinze ans."],
			["Fumez-vous ?", "Un peu… et du cannabis le week-end."],
			["Avez-vous des allergies ?", "Les chats, les acariens."],
		]


func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)
	match drug:
		"salbutamol":
			_neb += 1
			severity = maxf(0.05, severity - 0.08)
		"midazolam", "morphine":
			fault("Sédation dans un asthme aigu grave : il risque l'arrêt respiratoire", 12.0)
			severity = minf(1.0, severity + 0.3)
		"adrenaline":
			if route == "IV":
				fault("Adrénaline IV en bolus : pas en première intention", 6.0)


func lab(exam: String) -> String:
	match exam:
		"gds":
			if severity > 0.8:
				return "pH 7,24 · PaCO2 58 mmHg · PaO2 52 mmHg (hypercapnie : signe d'épuisement !)"
			return "pH 7,46 · PaCO2 31 mmHg · PaO2 62 mmHg · HCO3- 22 mmol/L (hypoxémie, hypocapnie)"
		"nfs":
			return "Hb 15,1 g/dL · leucocytes 12,4 G/L (éosinophiles 0,6) · plaquettes 280 G/L"
		"iono":
			return "Na 140 · K 3,2 mmol/L (hypokaliémie du salbutamol) · créatinine 70 µmol/L"
	return super.lab(exam)


func xray() -> Dictionary:
	return {"tex": "res://assets/textures/radio_normale.png", "text": "Radio du thorax : distension (poumons hyperclairs), pas de pneumothorax, pas de foyer."}


func objectives() -> Array:
	return [
		["Saturation surveillée (capteur SpO2)", 6.0, did("spo2")],
		["Auscultation des poumons", 8.0, did("auscultation")],
		["Oxygène", 10.0, did("o2_masque") or did("o2_nebu") or did("o2_lunettes")],
		["Nébulisation de salbutamol", 22.0, did("drug:salbutamol")],
		["Nébulisations répétées (2 ou plus)", 8.0, _neb >= 2],
		["Ipratropium associé", 5.0, did("drug:ipratropium")],
		["Corticoïdes IV", 12.0, did("drug:methylpred")],
		["Gaz du sang", 5.0, did("exam:gds")],
		["Crise contrôlée", 10.0, severity < 0.4],
		["Diagnostic juste", 7.0, did("diag_ok")],
		["Orientation juste", 7.0, did("orient_ok")],
	]
