class_name DesktopHand
extends SurgeonHand
## Main pilotée à la souris : la pointe de l'instrument suit le point visé sur le patient.
## Clic maintenu = appuyer (l'instrument s'enfonce là où c'est possible) et serrer (mâchoires, piston).

var camera: Camera3D
var patient: Patient
var mouse_left := false
var swallow_click := false  ## le clic qui a pris l'instrument ne déclenche pas d'action
var lift := 0.0
var auto_lift := 0.0  ## levée automatique demandée par la procédure (appendice tenu)
## Effet du clic sur la profondeur : "press" (enfonce tant qu'on appuie), "hold" (la profondeur
## atteinte reste quand on relâche), "none" (le clic ne fait que serrer)
var press_mode := "press"
var press_max := 0.006
var depth := 0.0
## Sans clic, l'instrument survole la peau de 2,5 mm (il ne coupe pas, ne peint pas par accident)
const HOVER := 0.0025
var _tip := Vector3.ZERO
var sim_mouse := Vector2(-1, -1)  ## test robot : position de souris imposée


func squeeze_value() -> float:
	return 1.0 if mouse_left and not swallow_click and held != null else 0.0


func tip() -> Vector3:
	return held.tip_global() if held else global_position


func raw_tip() -> Vector3:
	return _tip if held else global_position


## Point visé : relief du patient (champs) sinon plan du plateau.
func _aim_point(mouse: Vector2) -> Vector3:
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var p := from
	var step := 0.004
	for i in 225:  # 90 cm : portée de bras
		p += dir * step
		if p.x > -0.64 and p.x < 1.1 and absf(p.z) < 0.3:
			if p.y <= Patient.body_height(p.x, p.z):
				# Affinage par dichotomie : précision ~0,1 mm sur la peau
				var lo := p - dir * step
				var hi := p
				for k in 6:
					var mid := (lo + hi) * 0.5
					if mid.y <= Patient.body_height(mid.x, mid.z):
						hi = mid
					else:
						lo = mid
				return hi
		elif p.y <= InstrumentTray.TRAY_Y + 0.01:
			return p
	# Aucun contact : plan horizontal à hauteur du champ, à portée de bras au maximum
	var t := (Patient.TABLE_TOP + 0.2 - from.y) / dir.y if absf(dir.y) > 0.001 else 1.0
	return from + dir * clampf(t, 0.25, 0.9)


func _process(delta: float) -> void:
	if camera == null:
		return
	global_position = camera.global_position
	_update_edges()
	var mouse := sim_mouse if sim_mouse.x >= 0.0 else get_viewport().get_mouse_position()

	# Survol d'un instrument (projection écran) quand la main est vide
	var best: Instrument = null
	if held == null:
		var best_d := 46.0
		for inst in instruments:
			if inst.parked or camera.is_position_behind(inst.global_position):
				continue
			var sp := camera.unproject_position(inst.global_position)
			var spt := camera.unproject_position(inst.tip_global())
			var d := minf(sp.distance_to(mouse), spt.distance_to(mouse))
			var seg := spt - sp
			if seg.length() > 1.0:
				var k := clampf((mouse - sp).dot(seg) / seg.length_squared(), -1.0, 1.0)
				d = minf(d, (sp + seg * k).distance_to(mouse))
			if d < best_d:
				best_d = d
				best = inst
	set_hover(best)

	if held:
		var pressing := mouse_left and not swallow_click
		if pressing and press_mode != "none":
			depth = move_toward(depth, press_max, 0.045 * delta)
		elif press_mode != "hold":
			depth = move_toward(depth, 0.0, 0.1 * delta)
		var aim := _aim_point(mouse)
		if patient:
			aim.y += patient.breath_offset(aim.x, aim.z)
		var target := aim + Vector3.UP * (lift + auto_lift - depth + HOVER)
		# Aide : attire la pointe vers la cible de l'étape quand on en est proche
		if assist_target != Vector3.INF:
			var flat := Vector2(target.x - assist_target.x, target.z - assist_target.z).length()
			if flat < 0.035:
				var w := 1.0 - smoothstep(0.012, 0.035, flat)
				var snapped := assist_target + Vector3.UP * (lift + auto_lift - depth + HOVER)
				target = target.lerp(snapped, w)
		_tip = target if _tip == Vector3.ZERO else _tip.lerp(target, 1.0 - exp(-delta * 22.0))
		var fwd := -camera.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var axis := (fwd * 0.5 + Vector3.DOWN * 0.86).normalized()
		var up := Vector3.DOWN if held.up_mode == "down" else -fwd
		held.pose_tip(_tip, axis, up)
		held.set_squeeze(squeeze_value() if held.has_jaws or held.is_syringe else 0.0)
		_after_place(patient)
	else:
		_tip = Vector3.ZERO
		lift = 0.0
		depth = 0.0
