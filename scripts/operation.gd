class_name Operation
extends RefCounted
## Une opération = un réglage du patient + une liste d'instruments + une liste d'étapes.
## Chaque étape est d'un type de geste générique et physique (voir Procedure) : paint, incise,
## inject, retract, spread, lift, ligate, cut, carry, suture, insert, hold, place.

## Opérations proposées dans le menu
const ALL := ["appendicectomie", "drain", "laparotomie", "abces"]

var id := ""
var name := ""
var tagline := ""
var intro_title := "Bienvenue au bloc"
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

var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var root: Node3D


static func create(op_id: String) -> Operation:
	match op_id:
		"drain":
			return OpDrain.new()
		"laparotomie":
			return OpLaparo.new()
		"abces":
			return OpAbces.new()
		_:
			return OpAppendix.new()


static func menu_entries() -> Array:
	var out := []
	for k in ALL:
		var o := create(k)
		out.append([o.name, o.tagline])
	return out


## Réglages du patient avant sa construction (incision, fenêtre, plaie...).
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
