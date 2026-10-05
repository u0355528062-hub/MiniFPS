class_name PlayerBot
extends BotDriver
## Robot de test du jeu à la première personne : vrais événements clavier (touches 1-7, R), clic
## simulé, regard orienté vers la cible (le viseur est au centre de l'écran) et molette (hauteur).

var player: Player
var hand: PlayerHand
var home := Vector3(0.02, 0.0, 0.6)


func setup(p_player: Player, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	player = p_player
	hand = player.hand
	proc = p_proc
	patient = p_patient
	tray = p_tray
	prefix = "DESKTEST"
	hand.test_mode = true
	hand.sim_click = 0
	# Chirurgien à droite du patient (chirurgie cardiaque) : le robot se place du même côté
	if p_proc.op.player_spawn.z < 0.0:
		home = Vector3(p_proc.op.player_spawn.x, 0.0, p_proc.op.player_spawn.z)
	player.position = home


func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Oriente le regard pour que le viseur tombe sur la surface sous `p`.
func aim(p: Vector3) -> void:
	var y := hand._surface_y(p.x, p.z)
	var surf := Vector3(p.x, y, p.z) if y > 0.0 else p
	player.look_towards(surf)
	if OS.get_cmdline_user_args().has("--debugaim"):
		var cam := player.camera.global_position
		var fwd := -player.camera.global_basis.z
		print("DEBUGAIM cam=%s fwd=%s voulu=%s visé=%s" % [cam, fwd, (surf - cam).normalized(), hand._aim_patient(hand.screen_aim())])


func _settle() -> void:
	var last := hand.tip()
	for i in 90:
		await _frames(1)
		var now := hand.tip()
		if now.distance_to(last) < 0.0005 and i > 3:
			break
		last = now


func take(inst_id: String) -> void:
	if hand.held and hand.held.id == inst_id:
		return
	player.position = home
	var idx := tray.ordered.find(tray.instruments[inst_id])
	key(KEY_0 if idx == 9 else KEY_1 + idx)
	await _frames(3)


func put_back_all() -> void:
	hand.sim_click = 0
	await _frames(2)
	if hand.held:
		key(KEY_R)
	hand.lift = 0.0
	player.position = home


func tip_to(p: Vector3, frames_n := 12) -> void:
	# Cible au fond d'une plaie (cœur, vaisseaux) : on se penche au-dessus du patient pour la voir.
	# Le long d'un trajet (aiguille, drain), c'est le point d'entrée qu'il faut voir.
	var seen := p
	if hand.assist_axis != Vector3.ZERO and hand.held and hand.tract_weight(p) > 0.5:
		seen = hand.assist_target
	var lean := 1.0 if seen.y < Patient.body_height(seen.x, seen.z) - 0.025 and patient.in_window(seen.x, seen.z) else 0.0
	if lean != player.sim_lean:
		player.snap_lean(lean)
	# Le long d'un trajet (pince, drain) : on vise l'orifice et on règle la profondeur d'enfoncement
	if hand.assist_axis != Vector3.ZERO and hand.held and hand.tract_weight(p) > 0.5:
		var at0 := hand.assist_target
		var along := (p - at0).dot(hand.assist_axis)
		player.look_towards(at0)
		if OS.get_cmdline_user_args().has("--debug"):
			print("DEBUG trajet cam=", player.camera.global_position, " cible=", at0, " visée=", hand.aim_point, " penché=", player.crouch)
		hand.lift = hand.depth - PlayerHand.HOVER - along
		if frames_n > 4:
			await _settle()
		else:
			await _frames(frames_n)
		return
	aim(p)
	var y := hand._surface_y(p.x, p.z)
	var surf := y if y > 0.0 else p.y
	var at := hand.assist_target
	if at != Vector3.INF and Vector2(p.x - at.x, p.z - at.z).length() < 0.012:
		surf = at.y
	if y > 0.0:
		surf += patient.breath_offset(p.x, p.z)
	# Coupe au fond de la plaie : le clic maintenu enfonce la main ; on compense pour rester sur la ligne
	var held_down := hand.depth if proc.current().get("kind", "") == "cutline" else 0.0
	hand.lift = clampf(p.y - surf - PlayerHand.HOVER + held_down, -0.12, 0.25)
	if frames_n > 4:
		await _settle()
	else:
		await _frames(frames_n)


func squeeze(v: float) -> void:
	hand.sim_click = 1 if v > 0.5 else 0


func aim_hand(p: Vector3) -> void:
	aim(p)
	await _frames(1)


func held_id() -> String:
	return hand.held.id if hand.held else ""


func debug_state() -> String:
	var tip := hand.tip()
	return "tenu=%s tip=%s peau=%.3f prof=%.4f lift=%.3f appui=%.3f surPatient=%s cut=[%.2f %.2f] st=%s" % [held_id(), tip, Patient.body_height(tip.x, tip.z), hand.held.tip_depth if hand.held else 0.0, hand.lift, hand.depth, hand.on_patient, patient.cut0, patient.cut1, proc.st.keys()]


func held_inst() -> Instrument:
	return hand.held


func lift_clear() -> void:
	hand.lift = 0.06
	await _frames(3)
