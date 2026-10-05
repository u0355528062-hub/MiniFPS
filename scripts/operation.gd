class_name Operation
extends RefCounted
## Une opération = un réglage du patient + une liste d'instruments + une liste d'étapes.
## Chaque étape est d'un type de geste générique et physique (voir Procedure) : mark, paint,
## inject, incise, spread, insert, suture.

## Opérations du menu, dans l'ordre. « ready » : jouable (les autres sont annoncées).
const CATALOG := [
	{"id": "drain", "name": "Drain thoracique", "tag": "Pneumothorax compressif : un drain entre deux côtes, en urgence.", "level": 2, "minutes": 6, "ready": true},
	{"id": "exsufflation", "name": "Exsufflation à l'aiguille", "tag": "Pneumothorax suffocant : faire sortir l'air en quelques secondes.", "level": 1, "minutes": 3, "ready": true},
	{"id": "pericardiocentese", "name": "Péricardiocentèse", "tag": "Tamponnade : vider le sang autour du cœur, sous échographie.", "level": 2, "minutes": 5, "ready": true},
	{"id": "voie_centrale", "name": "Voie veineuse centrale", "tag": "Choc : un cathéter dans la veine sous-clavière (technique de Seldinger).", "level": 2, "minutes": 7, "ready": true},
	{"id": "thoracotomie", "name": "Thoracotomie de sauvetage", "tag": "Arrêt cardiaque après une plaie : ouvrir le thorax, masser le cœur.", "level": 3, "minutes": 8, "ready": true},
	{"id": "pontage", "name": "Pontage coronarien", "tag": "Infarctus : cœur arrêté sous machine, nouvelle artère sur l'IVA.", "level": 3, "minutes": 20, "ready": true},
]

var id := ""
var name := ""
var tagline := ""
var intro_title := "Bloc opératoire"
var intro_text := ""
var summary := ""  ## phrase de l'écran de fin
var header := "BLOC 2"  ## bandeau du panneau
var scan_text := ""  ## négatoscope (imagerie du patient)
var breath_rate := 14.0  ## respirations par minute
var surgeon_spot := Vector3(0.12, 0.0, 0.6)
var tray_pos := Vector3(0.62, 0.0, 0.56)
var with_dish := false
## [id, nom, fichier .glb ou "proc:xxx", roulis, longueur visée, rotation du modèle (degrés)]
var catalog: Array = []
var vitals := {"hr": 84.0, "spo2": 99.0, "sys": 124, "dia": 76}
var steps: Array = []
## Temps de référence (s) au-delà duquel la note baisse ; 0 : 90 s + 45 s par étape
var par_time := 0.0
## Position du patient (voir Patient.POSES) et place du joueur au début
var pose := "lateral"
var player_spawn := Vector3(0.2, 0.0, 1.05)
var player_look := Vector3(0.0, 1.3, 0.0)
## Briefing : patient, bandeau d'urgence, imagerie (texture + légende, ou texte si pas d'image)
var patient_line := "Karim B., 31 ans — accident de moto"
var urgency := "URGENCE VITALE"
var imaging_tex := "res://assets/textures/radio_thorax.png"
var imaging_caption := "Thorax de face · pneumothorax droit compressif"
var imaging_side := "D"
var imaging_text := ""

var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var root: Node3D


static func create(op_id: String) -> Operation:
	match op_id:
		"exsufflation":
			return OpExsufflation.new()
		"pericardiocentese":
			return OpPericardiocentese.new()
		"voie_centrale":
			return OpVoieCentrale.new()
		"thoracotomie":
			return OpThoracotomie.new()
		"pontage":
			return OpPontage.new()
		_:
			return OpDrain.new()


static func is_ready(op_id: String) -> bool:
	for e in CATALOG:
		if e["id"] == op_id:
			return e["ready"]
	return false


## Réglages du patient avant sa construction (incision, fenêtre, plaie...).
## Temps de référence de l'intervention : une longue opération a droit à plus de temps.
func reference_time() -> float:
	return par_time if par_time > 0.0 else 90.0 + 45.0 * steps.size()


func configure_patient(_p: Patient) -> void:
	pass


## Éléments propres à l'opération (organes, bocal...) une fois patient et plateau construits.
func build_extras() -> void:
	pass


## Remplit `steps` (appelé après build_extras).
func define_steps() -> void:
	pass


func on_start() -> void:
	pass


## Appelé à chaque image (animations propres à l'opération).
func process(_delta: float) -> void:
	pass


func instrument(inst_id: String) -> Instrument:
	return tray.instruments[inst_id]


## Ouverture de repos de la plaie : les bords y vont d'eux-mêmes (ressort), sans à-coup.
func tween_opening(v: float, _dur := 0.0) -> void:
	patient.rest_open = v


## L'anesthésie locale vient d'être injectée (elle fera effet dans `wait` secondes).
func anesthesia_started(_wait: float) -> void:
	pass


## Pose un instrument hors de la main (écarteur, drain...) à une position fixe.
func park(inst: Instrument, xf: Transform3D, instant: bool) -> void:
	proc.parked.append(inst)
	if instant:
		inst.held = false
		inst.parked = true
		inst.global_transform = xf
	else:
		inst.park(xf)


## Rend tous les instruments posés à la table (les bords tenus par l'aide se détendent).
func unpark_all(instant: bool) -> void:
	patient.held_l = -1.0
	patient.held_r = -1.0
	for inst in proc.parked:
		if instant:
			inst.parked = false
			inst.global_transform = inst.tray_transform
		else:
			inst.return_to_tray()
	proc.parked.clear()


func tissue(base: Color, inflamed := 0.0, vessels := 0.6, fibrin := 0.0, scale := 14.0) -> ShaderMaterial:
	return Tex.tissue(base, inflamed, vessels, fibrin, scale)
