class_name DesktopHand
extends SurgeonHand
## Main pilotée à la souris : la pointe de l'instrument suit le point visé sur le patient.

var camera: Camera3D
var mouse_left := false
var swallow_click := false  ## le clic qui a pris l'instrument ne déclenche pas d'action
var lift := 0.0
var auto_lift := 0.0  ## levée automatique demandée par la procédure (appendice tenu)
var _tip := Vector3.ZERO
var sim_mouse := Vector2(-1, -1)  ## test robot : position de souris imposée


func trigger_value() -> float:
	return 1.0 if mouse_left and not swallow_click and held != null else 0.0


func tip() -> Vector3:
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
				return p
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
			# Distance au segment centre-pointe à l'écran
			var seg := spt - sp
			if seg.length() > 1.0:
				var k := clampf((mouse - sp).dot(seg) / seg.length_squared(), -1.0, 1.0)
				d = minf(d, (sp + seg * k).distance_to(mouse))
			if d < best_d:
				best_d = d
				best = inst
	set_hover(best)

	if held:
		var target := _aim_point(mouse) + Vector3.UP * (lift + auto_lift)
		# Aide : attire la pointe vers la cible de l'étape quand on en est proche
		if assist_target != Vector3.INF:
			var flat := Vector2(target.x - assist_target.x, target.z - assist_target.z).length()
			if flat < 0.035:
				var w := 1.0 - smoothstep(0.012, 0.035, flat)
				var snapped := assist_target + Vector3.UP * (lift + auto_lift)
				target = target.lerp(snapped, w)
		_tip = target if _tip == Vector3.ZERO else _tip.lerp(target, 1.0 - exp(-delta * 22.0))
		var fwd := -camera.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var axis := (fwd * 0.5 + Vector3.DOWN * 0.86).normalized()
		held.pose_tip(_tip, axis, -fwd)
	else:
		_tip = Vector3.ZERO
		lift = 0.0
