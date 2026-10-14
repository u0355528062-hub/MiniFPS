class_name Physio
extends Node
## Physiologie du patient : constantes qui vont vers des cibles (fixées par la maladie du cas, puis
## modifiées par les traitements), rythme cardiaque, oxygénation, conscience, douleur, signes visibles.
## Arrêt cardiaque : sans massage le cerveau souffre (« no-flow »), le massage de bonne qualité
## apporte un peu de débit (« low-flow ») et du CO2 expiré ; les insufflations au ballon oxygènent.

signal rhythm_changed(r: String)
signal died

const SHOCKABLE := ["fv", "tvsp"]
const NO_PULSE := ["fv", "tvsp", "asystolie", "aesp"]

# ---- Constantes affichées (valeurs du moment)
var hr := 80.0
var sys := 120.0
var dia := 75.0
var spo2 := 98.0
var rr := 14.0
var temp := 37.0
var glyc := 1.0  ## g/L
var etco2 := 36.0
var gcs := 15
var pain := 0.0  ## 0..10
## Cibles fixées par la maladie (le cas les met à jour), avant les effets des traitements
var base := {"hr": 80.0, "sys": 120.0, "dia": 75.0, "spo2": 98.0, "rr": 14.0, "temp": 37.0, "gcs": 15, "pain": 0.0}
var rhythm := "sinus"  ## sinus, brady, tv, fv, tvsp, asystolie, aesp
var stemi := ""  ## "", "anterieur", "inferieur"
var qrs_wide := false
var pupils := {"size": 3.0, "reactive": true}  ## diamètre (mm), réactivité
var lungs := {"apex_d": "normal", "apex_g": "normal", "base_d": "normal", "base_g": "normal"}
var heart_sound := "normal"  ## normal, assourdi, galop, souffle
var abdomen := "souple"  ## souple, douloureux, defense
var breath_noise := ""  ## "", sifflement, ronflement, tirage
var conscious := true
var speaks := true
var dead := false
var rosc := false
## Signes visibles (0..1)
var signs := {"pallor": 0.0, "cyanosis": 0.0, "sweat": 0.0, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
var sign_base := {"pallor": 0.0, "cyanosis": 0.0, "sweat": 0.0, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}

# ---- Soins en cours
var o2_flow := 0.0  ## L/min au débitmètre
var o2_device := ""  ## lunettes, masque, nebu (posé sur le visage)
var bavu_times: Array[float] = []  ## instants des insufflations efficaces
var cpr_active := false
var cpr_quality := 0.0  ## 0..1 (profondeur, fréquence, relâchement)
var _last_comp := -10.0

# ---- Médicaments (niveaux qui décroissent) et doses totales
var levels := {"adrenaline": 0.0, "atropine": 0.0, "naloxone": 0.0, "morphine": 0.0, "salbutamol": 0.0, "midazolam": 0.0, "methylpred": 0.0, "glucagon": 0.0}
const HALF_LIFE := {"adrenaline": 150.0, "atropine": 600.0, "naloxone": 420.0, "morphine": 900.0, "salbutamol": 600.0, "midazolam": 600.0, "methylpred": 3600.0, "glucagon": 900.0}
var totals := {}  ## id -> dose totale donnée
var fluids_ml := 0.0
var _fluid_rate := 0.0  ## mL/s en cours (perfusion qui coule)
var _fluid_left := 0.0

# ---- Pronostic
var no_flow := 0.0  ## secondes d'arrêt sans massage
var low_flow := 0.0
var brain := 0.0  ## souffrance cérébrale cumulée (secondes-équivalent)
var oxy := 1.0  ## réserve d'oxygène du sang (0..1), utile en arrêt et en apnée
var time := 0.0
var arrest_since := -1.0


func pulse() -> bool:
	return not rhythm in NO_PULSE and sys > 45.0


func in_arrest() -> bool:
	return rhythm in NO_PULSE


func shockable() -> bool:
	return rhythm in SHOCKABLE


func set_rhythm(r: String) -> void:
	if r == rhythm:
		return
	var was_arrest := in_arrest()
	rhythm = r
	if in_arrest() and not was_arrest:
		arrest_since = time
		conscious = false
		speaks = false
	if not in_arrest() and was_arrest:
		rosc = true
		arrest_since = -1.0
	rhythm_changed.emit(r)


## Un médicament injecté (dose dans l'unité de Drugs.LIST).
func give(drug: String, dose: float, _route: String) -> void:
	totals[drug] = float(totals.get(drug, 0.0)) + dose
	match drug:
		"glucose30":
			glyc += dose * 0.07
		"nacl":
			_fluid_left += dose
			_fluid_rate = 500.0 / 300.0  # 500 mL en 5 min (débit libre)
		"paracetamol":
			pass
		_:
			if levels.has(drug):
				levels[drug] = float(levels[drug]) + dose


## Une compression thoracique reçue (profondeur en m, fréquence instantanée par minute, relâchement complet).
func compression(depth: float, rate: float, recoil: bool) -> void:
	_last_comp = time
	var q_depth := clampf(1.0 - absf(depth - 0.055) / 0.03, 0.0, 1.0)
	var q_rate := clampf(1.0 - maxf(absf(rate - 110.0) - 10.0, 0.0) / 40.0, 0.0, 1.0)
	var q := q_depth * (0.4 + 0.6 * q_rate) * (1.0 if recoil else 0.6)
	cpr_quality = lerpf(cpr_quality, q, 0.3)


## Une insufflation au ballon (efficace si le masque est bien appliqué et la tête basculée).
func insufflation(effective: bool) -> void:
	if effective:
		bavu_times.append(time)


func bavu_rate() -> float:
	var n := 0
	for t in bavu_times:
		if time - t < 60.0:
			n += 1
	return n


func cpr_running() -> bool:
	return time - _last_comp < 2.0


## Débit d'O2 réellement reçu (selon le dispositif posé et le débit).
func o2_support() -> float:
	match o2_device:
		"lunettes":
			return clampf(o2_flow, 0.0, 6.0) / 6.0 * 0.35
		"masque", "nebu":
			return clampf(o2_flow / 15.0, 0.0, 1.0) * (1.0 if o2_device == "masque" else 0.6)
	return 0.0


func _process(delta: float) -> void:
	if dead:
		return
	time += delta
	for k in levels:
		levels[k] = float(levels[k]) * pow(0.5, delta / float(HALF_LIFE[k]))
	if _fluid_left > 0.0:
		var d := minf(_fluid_left, _fluid_rate * delta)
		_fluid_left -= d
		fluids_ml += d
	cpr_active = cpr_running()
	if not cpr_active:
		cpr_quality = move_toward(cpr_quality, 0.0, delta * 0.5)
	if in_arrest():
		_tick_arrest(delta)
	else:
		_tick_alive(delta)
	for k in signs:
		signs[k] = move_toward(float(signs[k]), float(sign_base[k]), delta * 0.08)
	if in_arrest() or spo2 < 80.0:
		signs["cyanosis"] = move_toward(float(signs["cyanosis"]), clampf((90.0 - spo2) / 30.0, 0.0, 1.0) if not in_arrest() else 0.85, delta * 0.05)
	if in_arrest():
		signs["pallor"] = move_toward(float(signs["pallor"]), 0.8, delta * 0.05)


func _tick_arrest(delta: float) -> void:
	var cpr := cpr_running()
	if cpr:
		low_flow += delta
		brain += delta * lerpf(0.9, 0.12, cpr_quality)
	else:
		no_flow += delta
		brain += delta
	# Oxygène : consommé, apporté par les insufflations (seulement s'il y a du débit)
	var vent := clampf(bavu_rate() / 10.0, 0.0, 1.0)
	oxy = clampf(oxy - delta * 0.004 + delta * vent * 0.01 * (0.4 + 0.6 * cpr_quality), 0.0, 1.0)
	hr = 0.0 if rhythm == "asystolie" else move_toward(hr, 34.0 if rhythm == "aesp" else 0.0, delta * 20.0)
	sys = move_toward(sys, 55.0 * cpr_quality if cpr else 0.0, delta * 40.0)
	dia = move_toward(dia, 15.0 * cpr_quality if cpr else 0.0, delta * 30.0)
	spo2 = move_toward(spo2, 0.0, delta * 3.0)
	etco2 = move_toward(etco2, 8.0 + 18.0 * cpr_quality if cpr else 4.0, delta * 6.0)
	rr = 0.0
	gcs = 3
	conscious = false
	speaks = false
	pupils["size"] = move_toward(float(pupils["size"]), 6.0, delta * 0.03)
	pupils["reactive"] = false
	if brain > 900.0 and not dead:
		dead = true
		died.emit()


func _tick_alive(delta: float) -> void:
	var b := base
	var adr := float(levels["adrenaline"])
	var atro := float(levels["atropine"])
	var salbu := float(levels["salbutamol"])
	var t_hr := float(b["hr"]) + 45.0 * (1.0 - exp(-adr * 2.0)) + 25.0 * (1.0 - exp(-atro * 2.0)) + 4.0 * salbu
	var t_sys := float(b["sys"]) + 45.0 * (1.0 - exp(-adr * 2.0))
	var t_dia := float(b["dia"]) + 20.0 * (1.0 - exp(-adr * 2.0))
	# Remplissage : remonte la tension d'un patient qui en manque (le cas fixe l'effet maximal)
	var t_rr := float(b["rr"])
	var t_spo2 := float(b["spo2"])
	# Oxygène : comble une partie du manque (pas tout si le poumon est atteint)
	var gap := 100.0 - t_spo2
	t_spo2 += gap * o2_support() * float(b.get("o2_response", 0.8))
	# Hypoventilation : la saturation s'effondre quand on respire trop peu (sauf si on ventile au ballon)
	var vent := clampf(bavu_rate() / 12.0, 0.0, 1.0)
	if t_rr < 8.0:
		var hypo := clampf((8.0 - t_rr) / 8.0, 0.0, 1.0) * (1.0 - vent)
		t_spo2 -= hypo * 45.0 * (1.0 - 0.5 * o2_support())
	t_spo2 = clampf(t_spo2, 0.0, 100.0)
	hr = move_toward(hr, t_hr, delta * 6.0)
	sys = move_toward(sys, t_sys, delta * 4.0)
	dia = move_toward(dia, t_dia, delta * 3.0)
	rr = move_toward(rr, t_rr, delta * 2.0)
	spo2 = move_toward(spo2, t_spo2, delta * (1.5 if t_spo2 < spo2 else 1.0))
	temp = move_toward(temp, float(b["temp"]), delta * 0.01)
	pain = move_toward(pain, maxf(0.0, float(b["pain"]) - 3.0 * float(levels["morphine"]) / 3.0), delta * 0.5)
	gcs = int(b["gcs"])
	conscious = gcs >= 13
	speaks = gcs >= 11
	etco2 = move_toward(etco2, 36.0 if t_rr >= 8.0 else 55.0, delta * 2.0)
	oxy = clampf(spo2 / 100.0, 0.0, 1.0)
	if spo2 < 70.0:
		brain += delta * 0.3
	if brain > 900.0 and not dead:
		dead = true
		died.emit()


## Pression artérielle moyenne.
func pam() -> float:
	return (sys + 2.0 * dia) / 3.0
