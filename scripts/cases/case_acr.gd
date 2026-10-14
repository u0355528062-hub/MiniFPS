class_name CaseACR
extends Case
## Arrêt cardiaque en fibrillation ventriculaire (sur infarctus) devant le soignant. Chaîne de survie :
## reconnaître l'arrêt (ne répond pas, ne respire pas normalement, pas de pouls) en moins de 10 s,
## masser tout de suite, coller les électrodes, analyser et choquer, masser 2 min entre les
## analyses, ventiler (30:2), voie veineuse, adrénaline 1 mg et amiodarone 300 mg après le 3e choc.
## Le cœur repart (RACS) si le massage est bon et le traitement complet ; puis ECG : infarctus
## antérieur, direction la salle de coronarographie.

var _gasps := 60.0
var _last_shock_t := -1000.0
var _cpr_since_shock := 0.0
var _rosc_t := -1.0


func _init() -> void:
	id = "acr_fv"
	name = "Arrêt cardiaque"
	profile = {"name": "Michel R.", "age": 58, "skin": Color(1.0, 0.95, 0.93), "hair": Color(0.35, 0.33, 0.32), "bald": 0.6, "stubble": 0.45, "collar": false,
		"reply": "…"}
	arrival = "Michel, 58 ans, est installé au déchocage pour une douleur dans la poitrine depuis 40 minutes. Vous entrez dans la salle : il pousse un râle, son regard se fige, il ne répond plus.\n\nVous êtes seul dans la salle pour l'instant. Le scope n'est pas encore branché ; le chariot d'urgence et le défibrillateur sont à côté du brancard."
	arrival_vitals = "Avant le malaise (IAO) : FC 96 · PA 145/90 · SpO2 96 % · douleur 7/10"
	diag_ok = "Arrêt cardiaque sur fibrillation ventriculaire"
	orient_ok = "Salle de coronarographie (cardiologue appelé)"
	summary_good = "Le cœur a repris une activité efficace. Michel part en salle de coronarographie : son artère interventriculaire antérieure est débouchée. La réanimation commence."
	summary_bad = "Malgré la réanimation, le cœur n'est pas reparti."


func setup() -> void:
	physio.set_rhythm("fv")
	physio.hr = 0.0
	physio.sys = 0.0
	physio.dia = 0.0
	physio.spo2 = 92.0
	physio.rr = 0.0
	physio.sign_base = {"pallor": 0.7, "cyanosis": 0.6, "sweat": 0.3, "mottling": 0.2, "urticaria": 0.0, "flush": 0.0}
	physio.signs = {"pallor": 0.5, "cyanosis": 0.2, "sweat": 0.5, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.lungs = {"apex_d": "normal", "apex_g": "normal", "base_d": "normal", "base_g": "normal"}
	physio.pupils = {"size": 4.0, "reactive": false}
	physio.glyc = 1.35
	physio.temp = 36.6


func tick(delta: float) -> void:
	var p: Patient = game.get("patient")
	# Gasps les premières secondes (ce n'est pas une respiration normale)
	if _gasps > 0.0 and physio.in_arrest():
		_gasps -= delta
		p.gasping = true
		p.resp_rate = 5.0
		p.tidal = 0.6
	elif physio.in_arrest():
		p.gasping = false
		p.resp_rate = 0.0
	if physio.cpr_running():
		_cpr_since_shock += delta
	# Sans massage pendant trop longtemps, la fibrillation s'épuise en asystolie
	if physio.rhythm == "fv" and physio.no_flow > 300.0:
		physio.set_rhythm("asystolie")
		game.call("toast", "Le tracé s'aplatit : asystolie", false)
	if physio.rosc and _rosc_t < 0.0:
		_rosc_t = t()
	if physio.rosc and not physio.in_arrest():
		# Après la reprise : tachycardie, tension basse qui remonte, encore inconscient
		physio.base = {"hr": 108.0, "sys": 98.0, "dia": 58.0, "spo2": 94.0, "rr": 14.0, "temp": 36.4, "gcs": 5, "pain": 0.0, "o2_response": 0.9}
		physio.sign_base = {"pallor": 0.4, "cyanosis": 0.0, "sweat": 0.3, "mottling": 0.1, "urticaria": 0.0, "flush": 0.0}
		physio.stemi = "anterieur"
		physio.pupils = {"size": 3.0, "reactive": true}
		p.resp_rate = 14.0
		p.tidal = 0.8


func on_shock(_energy: int) -> void:
	var n: int = journal().count("choc")
	if n >= 2 and t() - _last_shock_t < 60.0 and _cpr_since_shock < 30.0:
		fault("Chocs rapprochés sans massage entre eux (2 min de massage après chaque choc)", 4.0)
	_last_shock_t = t()
	_cpr_since_shock = 0.0
	if not physio.shockable():
		fault("Choc délivré sur un rythme non choquable", 10.0)
		return
	var adr := float(physio.totals.get("adrenaline", 0.0))
	var amio := float(physio.totals.get("amiodarone", 0.0))
	var pads_ok: bool = not game.get("flags").get("pads_bad", false)
	var good_cpr := physio.low_flow > 45.0
	var success := false
	if pads_ok and good_cpr:
		if n >= 3 and adr >= 1.0 and amio >= 150.0:
			success = true
		elif n >= 5 and adr >= 1.0:
			success = true
	if success:
		physio.set_rhythm("sinus")
		physio.hr = 120.0
		physio.sys = 80.0
		physio.dia = 45.0
		physio.spo2 = 85.0
		game.call("event", "racs", "Reprise d'une activité cardiaque spontanée (pouls carotidien présent)")
		game.call("toast", "Le rythme change… un pouls ? Vérifie !", true)


func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)
	var shocks: int = journal().count("choc")
	match drug:
		"adrenaline":
			if route == "IV" and physio.in_arrest() and shocks < 2:
				fault("Adrénaline trop tôt (dans une FV : après le 3e choc)", 3.0)
			if not physio.in_arrest():
				fault("Adrénaline en bolus alors que le cœur est reparti", 8.0)
		"amiodarone":
			if shocks < 3:
				fault("Amiodarone trop tôt (après le 3e choc)", 3.0)
		"atropine":
			fault("Atropine : inutile dans l'arrêt cardiaque", 3.0)


func lab(exam: String) -> String:
	match exam:
		"trop":
			return "Troponine Hs : 486 ng/L (N < 14)"
		"lact":
			return "Lactates : 7,8 mmol/L"
		"gds":
			return "pH 7,08 · PaCO2 58 mmHg · PaO2 71 mmHg · HCO3- 16 mmol/L (acidose mixte)"
		"iono":
			return "Na 138 · K 4,6 · Cl 104 mmol/L · créatinine 104 µmol/L"
	return super.lab(exam)


func ecg12() -> Dictionary:
	if physio.in_arrest():
		return {"rhythm": physio.rhythm, "rate": 0, "st": "", "text": "Fibrillation ventriculaire." if physio.rhythm == "fv" else "Asystolie."}
	return {"rhythm": "sinus", "rate": physio.hr, "st": "anterieur",
		"text": "Tachycardie sinusale. Sus-décalage du ST de V1 à V4 (territoire antérieur), miroir en inférieur : infarctus antérieur."}


func objectives() -> Array:
	var arrest_t := 0.0
	var reco := minf(when("pouls"), when("respiration"))
	var cpr := when("rcp")
	var shock1 := when("choc")
	var shocks: int = journal().count("choc")
	var vent := journal().has("bavu")
	var adr := journal().has("drug:adrenaline")
	var amio := journal().has("drug:amiodarone")
	var rosc := journal().has("racs")
	return [
		["Arrêt reconnu (absence de réponse / respiration / pouls)", 10.0, reco < 30.0],
		["Massage débuté dans la première minute", 15.0, cpr - arrest_t < 60.0],
		["Électrodes de défibrillation collées", 5.0, journal().has("pads")],
		["Premier choc en moins de 3 minutes", 15.0, shock1 < 180.0],
		["Ventilation au ballon (30:2)", 5.0, vent],
		["Voie veineuse posée", 5.0, journal().has("vvp")],
		["Adrénaline 1 mg IV", 8.0, adr],
		["Amiodarone 300 mg IV après le 3e choc", 8.0, amio],
		["Reprise d'activité cardiaque (RACS)", 15.0, rosc],
		["ECG 12 dérivations après la reprise", 6.0, journal().has("ecg12") and journal().first("ecg12") > journal().first("racs")],
		["Diagnostic juste", 4.0, journal().has("diag_ok")],
		["Orientation juste (coronarographie)", 4.0, journal().has("orient_ok")],
	]
