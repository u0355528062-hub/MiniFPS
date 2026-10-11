class_name Convoi
extends Node3D
## Arrivée d'un véhicule de secours : le fourgon (SAMU ou pompiers) arrive par la route,
## gyrophares allumés, s'arrête devant le sas ; deux secouristes poussent le brancard (avec le
## patient couché) jusqu'au point d'arrivée du sas, puis repartent et le véhicule s'en va.

signal patient_depose(p: PatientJeu)

const ROUTE := [Vector3(70, 0, 42), Vector3(48, 0, 41), Vector3(38, 0, 39), Vector3(32.5, 0, 35), Vector3(32.0, 0, 31.5)]

var service: Service
var patient: PatientJeu
var samu := true
var vehicule: Node3D
var brancard: Node3D
var secouristes: Array[Personnage] = []
var _gyros: Array[OmniLight3D] = []
var _mat_gyro: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	vehicule = Bibliotheque.meuble("ambulance_samu" if samu else "vsav_pompiers")
	add_child(vehicule)
	# Gyrophares : matériau propre à ce véhicule (clignote) + deux lumières bleues alternées.
	_mat_gyro = (Bibliotheque.materiau("gyrophare") as StandardMaterial3D).duplicate()
	for mi in vehicule.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m and m.resource_name == "gyrophare":
				mi.set_surface_override_material(s, _mat_gyro)
	for k in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(0.2, 0.4, 1.0)
		l.omni_range = 9.0
		l.position = Vector3(2.2, 2.3, -0.45 + k * 0.9)
		vehicule.add_child(l)
		_gyros.append(l)
	vehicule.global_position = ROUTE[0]
	_rouler()


func _process(delta: float) -> void:
	_t += delta
	var a := fmod(_t * 3.0, 1.0) < 0.5
	_gyros[0].light_energy = 3.0 if a else 0.0
	_gyros[1].light_energy = 0.0 if a else 3.0
	_mat_gyro.emission_energy_multiplier = 6.0 if a else 1.0


func _rouler() -> void:
	# Trajet le long de la route (interpolation douce, orientation selon la tangente).
	var tw := create_tween()
	for i in range(1, ROUTE.size()):
		var de: Vector3 = ROUTE[i - 1]
		var a: Vector3 = ROUTE[i]
		var duree := de.distance_to(a) / (9.0 if i < ROUTE.size() - 1 else 4.0)
		tw.tween_callback(func(): _orienter(a - de))
		tw.tween_property(vehicule, "global_position", a, duree).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_OUT if i == ROUTE.size() - 1 else Tween.EASE_IN_OUT)
	await tw.finished
	_debarquer()


func _orienter(dir: Vector3) -> void:
	# Le modèle de fourgon a son avant vers +X : on l'aligne sur la direction de marche.
	var cible := atan2(-dir.z, dir.x)
	var tw := create_tween()
	tw.tween_property(vehicule, "rotation:y", cible, 0.6)


func _debarquer() -> void:
	brancard = Bibliotheque.meuble("brancard")
	add_child(brancard)
	brancard.global_position = vehicule.global_position + Vector3(0, 0, -3.6)
	brancard.rotation_degrees.y = 90.0
	patient.reparent(brancard)
	patient.position = Vector3(0.13, 0.80 - patient.personnage.hauteur_bassin(), 0)
	patient.rotation = Vector3(0, -PI * 0.5, 0)
	for k in 2:
		var s := Personnage.new()
		s.modele = (["ambulancier_samu", "pompier_1"] if samu else ["pompier_1", "pompier_2"])[k]
		s.animation_initiale = "marche"
		add_child(s)
		secouristes.append(s)
	var arrivee: Vector3 = service.points["sas"]["arrivee"]
	var chemin := service.chemin(brancard.global_position, arrivee)
	var tw := create_tween()
	var prec := brancard.global_position
	for i in range(1, chemin.size()):
		var p := Vector3(chemin[i].x, 0, chemin[i].z)
		var d := p - prec
		if d.length() < 0.05:
			continue
		tw.tween_callback(func(): brancard.rotation.y = atan2(-d.z, d.x) + PI)
		tw.tween_property(brancard, "global_position", p, d.length() / 1.1)
		prec = p
	var t_suivi := create_tween().set_loops(int(60 * 30))
	t_suivi.tween_callback(_placer_secouristes).set_delay(1.0 / 30.0)
	await tw.finished
	t_suivi.kill()
	for s in secouristes:
		s.jouer("attente", 0.3)
	# Le patient est remis au service, sur le brancard du sas.
	patient.reparent(service)
	brancard.reparent(service)
	patient.set_meta("brancard", brancard)
	patient_depose.emit(patient)
	await get_tree().create_timer(4.0).timeout
	_repartir()


func _placer_secouristes() -> void:
	if brancard == null:
		return
	var b := brancard.global_transform.basis
	var avant := b.x.normalized()
	for k in secouristes.size():
		var s := secouristes[k]
		var cote := b.z.normalized() * (0.55 if k == 0 else -0.55)
		var cible := brancard.global_position + avant * (1.15 if k == 0 else -1.15) + cote * 0.3
		s.global_position = Vector3(cible.x, 0.0, cible.z)
		s.rotation.y = atan2(-avant.x, -avant.z) if k == 0 else atan2(avant.x, avant.z)


func _repartir() -> void:
	for s in secouristes:
		var tw := create_tween()
		tw.tween_property(s, "global_position", vehicule.global_position + Vector3(0, 0, -2.0), 3.0)
	await get_tree().create_timer(3.2).timeout
	for s in secouristes:
		s.queue_free()
	secouristes.clear()
	var tw := create_tween()
	_orienter(Vector3(1, 0, 0.6))
	tw.tween_property(vehicule, "global_position", ROUTE[0], 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
