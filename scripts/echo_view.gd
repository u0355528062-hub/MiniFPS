class_name EchoView
extends Node
## Échographe : le plan de la sonde coupe le volume anatomique du patient (tissus, cœur, foie,
## poumons, os ; assets/data/echo_dos.bin) ; l'image est calculée en direct (shaders/echo.gdshader)
## dans une SubViewport affichée sur l'écran de l'appareil et dans le HUD.
##
## Le plan de coupe contient le faisceau et la direction gauche-droite du patient : vue
## sous-costale classique (foie en haut, puis le cœur ; la gauche du patient à droite de l'écran).

const VOLUME := "res://assets/data/echo_dos.bin"
const SIZE := Vector2i(560, 420)

static var _tex3d: ImageTexture3D
static var _labels := PackedByteArray()
static var vol_n := 128
static var vol_min := Vector3.ZERO
static var vol_step := 0.0025

var viewport: SubViewport
var material: ShaderMaterial
var texture: Texture2D
var effusion := 1.0  ## 1 = tamponnade, 0 = vidé
var heart_rate := 130.0
var contact := 0.0  ## sonde posée sur la peau
var on := false  ## image affichée (sonde tenue ou posée)
var _beat := 0.0
var _frame := 0.0
var _face := Vector3.ZERO
var _beam := Vector3.DOWN
var _was_on := true


static func load_volume() -> bool:
	if _tex3d:
		return true
	if not FileAccess.file_exists(VOLUME):
		return false
	var b := FileAccess.get_file_as_bytes(VOLUME)
	vol_n = b.decode_s32(0)
	vol_min = Vector3(b.decode_float(4), b.decode_float(8), b.decode_float(12))
	vol_step = b.decode_float(16)
	_labels = b.slice(20)
	var slices: Array[Image] = []
	var plane := vol_n * vol_n * 2
	for k in vol_n:
		slices.append(Image.create_from_data(vol_n, vol_n, false, Image.FORMAT_RG8, _labels.slice(k * plane, (k + 1) * plane)))
	_tex3d = ImageTexture3D.new()
	_tex3d.create(Image.FORMAT_RG8, vol_n, vol_n, vol_n, false, slices)
	return true


## Tissu au point p (côté CPU) : [nature, distance signée au cœur en mm].
static func sample(p: Vector3) -> Array:
	var i := int(floor((p.x - vol_min.x) / vol_step))
	var j := int(floor((p.y - vol_min.y) / vol_step))
	var k := int(floor((p.z - vol_min.z) / vol_step))
	if i < 0 or j < 0 or k < 0 or i >= vol_n or j >= vol_n or k >= vol_n or _labels.is_empty():
		return [0, 99.0]
	var o := ((k * vol_n + j) * vol_n + i) * 2
	return [_labels[o], (_labels[o + 1] - 128) * 0.25]


## Épaisseur du liquide (mm) pour un épanchement donné (même règle que le shader).
static func fluid_thickness(eff: float) -> float:
	return 2.5 + 15.0 * eff


## Distance (m) le long de l'axe jusqu'au liquide péricardique, et jusqu'au myocarde ; -1 si
## l'aiguille n'y arrive pas dans les 12 cm.
static func depths_along(entry: Vector3, axis: Vector3, eff: float) -> Vector2:
	var fluid := -1.0
	var heart := -1.0
	var thick := fluid_thickness(eff)
	for n in 240:
		var d := n * 0.0005
		var s := sample(entry + axis * d)
		var lab: int = s[0]
		var sd: float = s[1]
		if fluid < 0.0 and lab != 0 and lab != 5 and sd > 0.0 and sd < thick:
			fluid = d
		if heart < 0.0 and sd <= 0.0:
			heart = d
			break
	return Vector2(fluid, heart)


func _ready() -> void:
	load_volume()
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/echo.gdshader")
	material.set_shader_parameter("vol", _tex3d)
	material.set_shader_parameter("vol_sdf", _tex3d)
	material.set_shader_parameter("vol_min", vol_min)
	material.set_shader_parameter("vol_size", vol_step * vol_n)
	material.set_shader_parameter("aspect", float(SIZE.x) / SIZE.y)
	material.set_shader_parameter("heart_c", Patient.HEART_C)
	rect.material = material
	viewport.add_child(rect)
	texture = viewport.get_texture()


## Pose de la sonde : centre de sa face et direction du faisceau (vers l'intérieur). `side_hint` :
## direction à garder dans le plan de coupe (trajet d'une aiguille), sinon gauche-droite du patient.
## `needle` : [a, b] d'une aiguille à garder dans la coupe ; la sonde est alors inclinée (par l'aide)
## pour que le plan passe par toute l'aiguille (technique « dans le plan »).
func set_probe(face: Vector3, beam: Vector3, side_hint := Vector3.ZERO, needle: Array = []) -> void:
	_face = face
	_beam = beam.normalized()
	var side := Vector3(0, 0, 1) - _beam * _beam.z
	if needle.size() == 2:
		var a: Vector3 = needle[0]
		var b: Vector3 = needle[1]
		var n := (a - face).cross(b - face)
		if n.length() > 1e-6:
			n = n.normalized()
			var bp := _beam - n * _beam.dot(n)
			if bp.length() > 0.3:
				_beam = bp.normalized()
				side = n.cross(_beam)
	elif side_hint != Vector3.ZERO:
		var h := side_hint - _beam * _beam.dot(side_hint)
		if h.length() > 0.3:
			side = h
	if side.z < 0.0:
		side = -side
	if side.length() < 0.2:
		side = Vector3(1, 0, 0) - _beam * _beam.x
	side = side.normalized()
	material.set_shader_parameter("probe_pos", face)
	material.set_shader_parameter("beam_dir", _beam)
	material.set_shader_parameter("lat_dir", side)


func set_needle(a: Vector3, b: Vector3, visible_now: bool) -> void:
	material.set_shader_parameter("needle_a", a)
	material.set_shader_parameter("needle_b", b)
	material.set_shader_parameter("needle_on", 1.0 if visible_now else 0.0)


func _process(delta: float) -> void:
	_beat = fmod(_beat + delta * heart_rate / 60.0, 1.0)
	_frame += 1.0
	if on:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_was_on = true
	elif _was_on:
		# Sonde rangée : l'écran repasse au noir (pas d'image figée)
		_was_on = false
		contact = 0.0
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	material.set_shader_parameter("beat", _beat)
	material.set_shader_parameter("frame", fmod(_frame, 97.0))
	material.set_shader_parameter("effusion", effusion)
	material.set_shader_parameter("contact", contact)
