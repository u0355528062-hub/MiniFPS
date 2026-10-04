class_name Operation
extends RefCounted
## Une opération = un réglage du patient + une liste d'instruments + une liste d'étapes.
## Chaque étape est d'un type de geste générique (la procédure et les robots savent tous les jouer) :
##   paint  : badigeonner une zone            trace  : suivre le tracé d'incision
##   place  : amener la pointe + gâchette      hold   : maintenir la gâchette sur un point
##   push   : enfoncer la pointe en profondeur lift   : saisir et soulever
##   carry  : saisir un objet et le déposer    points : toucher une série de points (sutures)

const ALL := ["appendicectomie", "drain", "laparotomie"]

var id := ""
var name := ""
var tagline := ""
var intro_title := "Bienvenue au bloc"
var intro_text := ""
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


func instrument(inst_id: String) -> Instrument:
	return tray.instruments[inst_id]


func tween_opening(v: float, dur: float) -> void:
	var tw := proc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(patient, "opening", v, dur)


## Pose un instrument hors de la main (écarteur, drain...) à une position fixe.
func park(inst: Instrument, xf: Transform3D, instant: bool) -> void:
	proc.parked.append(inst)
	if instant:
		inst.held = false
		inst.parked = true
		inst.global_transform = xf
	else:
		inst.park(xf)


## Rend tous les instruments posés à la table.
func unpark_all(instant: bool) -> void:
	for inst in proc.parked:
		if instant:
			inst.parked = false
			inst.global_transform = inst.tray_transform
		else:
			inst.return_to_tray()
	proc.parked.clear()


func tissue(base: Color, inflamed := 0.0, vessels := 0.6, fibrin := 0.0, scale := 14.0) -> ShaderMaterial:
	return Tex.tissue(base, inflamed, vessels, fibrin, scale)
