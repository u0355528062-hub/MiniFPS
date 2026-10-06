class_name PlayerHand
extends SurgeonHand
## Main du joueur. L'instrument tenu suit le centre de l'écran (le viseur) :
##  - sur le patient, à portée de bras : sa pointe se pose là où l'on vise ;
##  - ailleurs : il est tenu devant soi, prêt à servir.
## Clic gauche maintenu : appuyer (la pointe s'enfonce là où le geste le permet) et serrer
## (mâchoires, piston). Molette : lever / baisser. Clic sur un instrument (ou E) : le prendre.
## R : le reposer. 1-9 et 0 : prendre directement l'instrument n (à portée de la table).

signal hint_changed(text: String)

const REACH := 0.95  ## portée de la main depuis les yeux
const TAKE_REACH := 2.0
## Sans clic, l'instrument survole la peau de 2,5 mm (il ne coupe pas, ne peint pas par accident)
const HOVER := 0.0025

var camera: Camera3D
var player: Node3D
var patient: Patient
var tray: InstrumentTray
var mouse_left := false
var swallow_click := false
var lift := 0.0
var auto_lift := 0.0
var bot_lift := 0.0  ## réglage de hauteur du robot de test (le joueur, lui, a la molette)
var press_mode := "press"
var press_max := 0.006
var press_speed := 0.045
var press_rel := false  ## press_max compté depuis la peau (le fond de la brèche est déjà plus bas)
var depth := 0.0
var on_patient := false  ## la pointe est posée sur le patient (sinon, instrument tenu devant soi)
var aim_point := Vector3.ZERO
var sim_aim := Vector2(-1, -1)  ## tests : point d'écran visé imposé
var sim_click := -1  ## tests : clic imposé (0/1), -1 = vraie souris
var test_mode := false  ## tests : touches acceptées sans capture de la souris
var _tip := Vector3.ZERO
var _xf := Transform3D.IDENTITY
var _blend := 0.0
var _hint := ""


func set_press_mode(mode: String, pmax: float, speed := 0.045, relative := false) -> void:
	press_mode = mode
	press_max = pmax
	press_speed = speed
	press_rel = relative


func squeeze_value() -> float:
	return 1.0 if _clicking() and not swallow_click and held != null else 0.0


func pressing() -> bool:
	return _clicking() and held == null and not swallow_click


func _clicking() -> bool:
	if sim_click >= 0:
		return sim_click == 1
	return mouse_left


func tip() -> Vector3:
	return held.tip_global() if held else global_position


func raw_tip() -> Vector3:
	return _tip if held else global_position


func aim_distance() -> float:
	return camera.global_position.distance_to(aim_point) if aim_point != Vector3.ZERO else 10.0


func screen_aim() -> Vector2:
	if sim_aim.x >= 0.0:
		return sim_aim
	return get_viewport().get_visible_rect().size * 0.5


## Surface visée (peau dans la fenêtre du champ, sinon champ ou peau) : relief du patient.
func _surface_y(x: float, z: float) -> float:
	if patient and patient.in_window(x, z):
		var floor_y := patient.breach_floor(x, z)
		if floor_y > -INF:
			return floor_y
		return Patient.body_height(x, z)
	return Patient.top_height(x, z)


## Point du patient visé par le viseur (INF si on ne vise pas le patient à portée).
func _aim_patient(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var p := from
	var step := 0.004
	for i in int(REACH / step) + 40:
		p += dir * step
		var top := _surface_y(p.x, p.z)
		if top > 0.0 and p.y <= top:
			var lo := p - dir * step
			var hi := p
			for k in 7:
				var mid := (lo + hi) * 0.5
				if mid.y <= _surface_y(mid.x, mid.z):
					hi = mid
				else:
					lo = mid
			return hi if hi.distance_to(from) <= REACH + 0.12 else Vector3.INF
	return Vector3.INF


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not test_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_left = mb.pressed
			if mb.pressed:
				if held == null and hovered:
					swallow_click = true
					take_requested.emit(self, hovered)
			else:
				swallow_click = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			lift = minf(lift + 0.004, 0.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			lift = maxf(lift - 0.004, 0.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE and held:
			put_back_requested.emit(self)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_E and held == null and hovered:
			take_requested.emit(self, hovered)
		elif k.physical_keycode == KEY_R and held:
			put_back_requested.emit(self)
		elif k.physical_keycode >= KEY_0 and k.physical_keycode <= KEY_9:
			# 1-9 : instruments 1 à 9 ; 0 : le dixième
			var i := 9 if k.physical_keycode == KEY_0 else k.physical_keycode - KEY_1
			if i < instruments.size():
				request_index(i)


## Prendre l'instrument n (touches 1-9) : il faut être près de la table d'instruments.
func request_index(i: int) -> void:
	var inst := instruments[i]
	if held == inst:
		return
	if tray and camera.global_position.distance_to(InstrumentTray.MAYO_POS + Vector3.UP) > TAKE_REACH + 0.6:
		_set_hint("Approche-toi de la table d'instruments")
		Sfx.play("erreur", Vector3.INF, -18.0, 1.4)
		return
	take_requested.emit(self, inst)


func _set_hint(t: String) -> void:
	if t != _hint:
		_hint = t
		hint_changed.emit(t)


func _process(delta: float) -> void:
	if camera == null:
		return
	global_position = camera.global_position
	_update_edges()
	var screen := screen_aim()
	var target_pt := _aim_patient(screen)
	aim_point = target_pt if target_pt != Vector3.INF else camera.global_position - camera.global_basis.z * 3.0

	# Survol d'un instrument (main vide) : le plus proche du viseur, à portée
	var best: Instrument = null
	if held == null:
		var best_d := 34.0 * (camera.fov / 70.0 + 0.4)
		for inst in instruments:
			if inst.parked or not inst.visible or camera.is_position_behind(inst.global_position):
				continue
			if camera.global_position.distance_to(inst.global_position) > TAKE_REACH:
				continue
			var sp := camera.unproject_position(inst.global_position)
			var spt := camera.unproject_position(inst.tip_global())
			var d := minf(sp.distance_to(screen), spt.distance_to(screen))
			var seg := spt - sp
			if seg.length() > 1.0:
				var k := clampf((screen - sp).dot(seg) / seg.length_squared(), -1.0, 1.0)
				d = minf(d, (sp + seg * k).distance_to(screen))
			if d < best_d:
				best_d = d
				best = inst
	set_hover(best)

	if held:
		var pressing := _clicking() and not swallow_click
		on_patient = target_pt != Vector3.INF
		if pressing and press_mode != "none" and on_patient:
			# On appuie pour travailler : l'instrument levé à la molette redescend sur le patient
			lift = move_toward(lift, 0.0, 0.3 * delta)
			var pm := press_max
			if press_rel:
				pm = maxf(0.002, press_max - (Patient.body_height(target_pt.x, target_pt.z) - target_pt.y))
			depth = move_toward(depth, pm, press_speed * delta)
		elif press_mode != "hold" or not on_patient:
			depth = move_toward(depth, 0.0, 0.1 * delta)
		var want: Transform3D
		var fwd := -camera.global_basis.z
		var flat := Vector3(fwd.x, 0, fwd.z).normalized()
		if on_patient:
			var aim := target_pt
			if patient:
				aim.y += patient.breath_offset(aim.x, aim.z)
			var target := aim + Vector3.UP * (lift + bot_lift + auto_lift - depth + HOVER)
			if assist_target != Vector3.INF:
				var dflat := Vector2(target.x - assist_target.x, target.z - assist_target.z).length()
				if dflat < 0.03:
					var w := 1.0 - smoothstep(0.01, 0.03, dflat)
					var snapped := assist_target + Vector3.UP * (lift + bot_lift + auto_lift - depth + HOVER)
					target = target.lerp(snapped, w * 0.85)
			# Visée sur l'orifice d'un trajet (pince, drain) : la pointe s'enfonce le long du trajet
			if assist_axis != Vector3.ZERO and assist_target != Vector3.INF:
				var off := Vector3(aim.x - assist_target.x, 0.0, aim.z - assist_target.z)
				# Un orifice au-dessus de la peau (embase d'une aiguille plantée) s'attrape en le
				# regardant : on compte aussi la distance entre le repère et la ligne de visée
				var from := camera.project_ray_origin(screen)
				var dir := camera.project_ray_normal(screen)
				var near := from + dir * maxf(0.0, (assist_target - from).dot(dir))
				var ray_off := Vector3(near.x - assist_target.x, 0.0, near.z - assist_target.z)
				if near.distance_to(assist_target) < off.length():
					off = ray_off
				var fl := off.length()
				var we := 1.0 - smoothstep(0.014, 0.028, fl)
				if we > 0.0:
					var along := depth - lift - bot_lift - auto_lift - HOVER
					var lateral := off * 0.35
					var deep := assist_target + lateral + assist_axis * along
					target = target.lerp(deep, we)
			_tip = target if _tip == Vector3.ZERO else _tip.lerp(target, 1.0 - exp(-delta * 24.0))
			var axis := (flat * 0.5 + Vector3.DOWN * 0.86).normalized()
			# Près de l'orifice, l'instrument s'aligne sur le trajet à suivre (pince, drain)
			var wa := tract_weight(_tip)
			if wa > 0.0:
				axis = axis.slerp(assist_axis, wa).normalized()
			var up := Vector3.DOWN if held.up_mode == "down" else -flat
			want = held.tip_transform(_tip, axis, up)
		else:
			# Tenu devant soi, pointe en avant et vers le bas, à droite du regard
			var right := camera.global_basis.x
			var tip_pos := camera.global_position + fwd * 0.42 + right * 0.13 - camera.global_basis.y * 0.15
			_tip = tip_pos
			var axis := (fwd * 0.8 - camera.global_basis.y * 0.35 - right * 0.15).normalized()
			want = held.tip_transform(tip_pos, axis, camera.global_basis.y)
		# Transition douce entre « devant soi » et « sur le patient »
		_blend = move_toward(_blend, 1.0 if on_patient else 0.0, delta * 5.0)
		if _xf == Transform3D.IDENTITY:
			_xf = want
		var k := 1.0 - exp(-delta * (30.0 if on_patient and _blend > 0.99 else 14.0))
		_xf = Transform3D(_xf.basis.slerp(want.basis, k).orthonormalized(), _xf.origin.lerp(want.origin, k))
		if on_patient and _blend > 0.98:
			_xf = want
			held.place(want)
		else:
			held.global_transform = _xf
			held.tip_depth = -1.0
		held.set_squeeze(squeeze_value() if held.has_jaws or held.is_syringe or held.model_squeeze else 0.0)
		if on_patient:
			_after_place(patient)
		_set_hint("")
	else:
		_tip = Vector3.ZERO
		_xf = Transform3D.IDENTITY
		_blend = 0.0
		lift = 0.0
		bot_lift = 0.0
		depth = 0.0
		on_patient = false
		_set_hint(("Clic : prendre  « %s »" % hovered.label) if hovered else "")
