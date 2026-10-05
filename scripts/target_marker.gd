class_name TargetMarker
extends Node3D
## Repère lumineux de l'endroit où agir : anneau pulsé visible à travers les tissus + étiquette.

var ring: MeshInstance3D
var label: Label3D
var _mat := StandardMaterial3D.new()
var _t := 0.0
var color := UIKit.ACCENT: set = set_color
var label_below := false  ## étiquette sous l'anneau (second repère : ne chevauche pas le premier)


func _init() -> void:
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.009
	tm.outer_radius = 0.0115
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.render_priority = 10
	_mat.albedo_color = Color(color, 0.85)
	ring.material_override = _mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 11
	label.font = load("res://assets/fonts/Inter.ttf")
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.0004
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = Vector3(0, 0.03, 0)
	add_child(label)
	visible = false


func set_color(c: Color) -> void:
	color = c
	_mat.albedo_color = Color(c, 0.85)
	if label:
		label.modulate = c


func show_at(p: Vector3, text := "", size := 1.0) -> void:
	global_position = p
	ring.scale = Vector3.ONE * size
	label.text = text
	visible = true


func _process(delta: float) -> void:
	_t += delta
	# L'étiquette garde une taille lisible à l'écran quand on regarde de loin (jusqu'à 3 fois plus grande)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		var k := clampf(cam.global_position.distance_to(global_position) / 0.38, 1.0, 3.0)
		label.pixel_size = 0.0004 * k
		label.position.y = (-0.024 if label_below else 0.03) * k
	var s := 1.0 + 0.18 * sin(_t * 5.0)
	ring.scale = Vector3(s, 1, s) * ring.scale.y
	_mat.albedo_color.a = 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 5.0))
