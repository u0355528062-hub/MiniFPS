class_name CathlonModel
extends Node3D
## Aiguille-cathéter 14G de 8 cm montée sur une seringue de 10 mL à moitié remplie de sérum
## physiologique (exsufflation, ponctions). Pointe vers +Z.
##  - set_aspiration(v) : on tire le piston (0 = repos, 1 = tiré au maximum) ;
##  - set_flash("air" | "blood" | "fluid") : ce qui remonte dans la seringue quand la pointe arrive
##    dans la plèvre (bulles d'air), un vaisseau ou le péricarde (sang), un épanchement ;
##  - detach_catheter() : le cathéter souple reste en place, l'aiguille repart avec la seringue.

const BARREL_R := 0.0072
const BARREL_Z0 := -0.072  ## fond du corps (côté piston)
const BARREL_Z1 := -0.014  ## embout de la seringue
const SHEATH_Z1 := 0.086  ## bout du cathéter souple
const TIP_Z := 0.093  ## pointe biseautée de l'aiguille

var aspiration := 0.0
var flash := ""
## Seringue vide au départ qui se remplit de sang quand on tire (ponction d'un épanchement) ; sinon
## seringue à moitié pleine de sérum (bulles d'air quand on aspire de l'air)
var draws_blood := false:
	set(v):
		draws_blood = v
		if v:
			_liquid_mat.albedo_color = Color(0.42, 0.02, 0.03, 0.92)
			_liquid_mat.rim = 0.15
		set_aspiration(aspiration)
var catheter: Node3D
var _seal: MeshInstance3D
var _rod: MeshInstance3D
var _thumb: MeshInstance3D
var _liquid: MeshInstance3D
var _liquid_mat: StandardMaterial3D
var _bubbles: Array[MeshInstance3D] = []
var _flash_k := 0.0
var _t := 0.0


func _init() -> void:
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.92, 0.95, 0.97, 0.2)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.06
	clear.metallic_specular = 0.8
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	var white := MeshUtil.mat(Color(0.94, 0.94, 0.92), 0.45)
	var steel := MeshUtil.mat(Color(0.82, 0.84, 0.86), 0.18, 1.0)
	# Corps de la seringue, ailettes, embout Luer
	var barrel := _cyl(BARREL_R, BARREL_Z1 - BARREL_Z0, (BARREL_Z0 + BARREL_Z1) * 0.5, clear, "Corps")
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flange := MeshUtil.box_instance(self, Vector3(0.034, 0.002, 0.0035), Vector3(0, 0, BARREL_Z0 - 0.001), white, "Ailettes")
	flange.rotation_degrees = Vector3(0, 0, 0)
	_cyl(0.0022, 0.008, BARREL_Z1 + 0.004, white, "EmboutLuer")
	# Graduations
	var grad := MeshUtil.mat(Color(0.1, 0.12, 0.15), 0.6)
	for k in 9:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BARREL_R + 0.00005
		tm.outer_radius = BARREL_R + (0.0004 if k % 2 == 0 else 0.00025)
		tm.rings = 24
		tm.ring_segments = 3
		ring.mesh = tm
		ring.material_override = grad
		ring.rotation_degrees.x = 90
		ring.position = Vector3(0, 0, BARREL_Z1 - 0.004 - k * 0.0055)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	# Sérum (moitié de la seringue), bulles d'air
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.albedo_color = Color(0.78, 0.9, 1.0, 0.38)
	_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_mat.roughness = 0.05
	_liquid_mat.metallic_specular = 0.9
	_liquid_mat.rim_enabled = true
	_liquid_mat.rim = 0.4
	_liquid = _cyl(BARREL_R - 0.0006, 1.0, 0.0, _liquid_mat, "Serum")
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bub_mat := StandardMaterial3D.new()
	bub_mat.albedo_color = Color(1, 1, 1, 0.55)
	bub_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bub_mat.roughness = 0.02
	bub_mat.metallic_specular = 1.0
	for i in 7:
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.0011 + 0.0007 * (i % 3)
		s.height = s.radius * 2.0
		s.radial_segments = 10
		s.rings = 6
		b.mesh = s
		b.material_override = bub_mat
		b.visible = false
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
		_bubbles.append(b)
	# Piston : joint noir, tige et appui-pouce blancs
	_seal = _cyl(BARREL_R - 0.0004, 0.004, 0.0, MeshUtil.mat(Color(0.08, 0.08, 0.09), 0.5), "Joint")
	_rod = MeshUtil.box_instance(self, Vector3(0.0055, 0.0055, 0.06), Vector3.ZERO, white, "Tige")
	_thumb = _cyl(0.0085, 0.0018, 0.0, white, "AppuiPouce")
	# Cathéter : embase orange (14G), gaine translucide ; aiguille d'acier dedans
	catheter = Node3D.new()
	catheter.name = "Catheter"
	add_child(catheter)
	var orange := MeshUtil.mat(Color(0.95, 0.45, 0.08), 0.35)
	_cyl_to(catheter, 0.0042, 0.016, BARREL_Z1 + 0.016, orange, "Embase")
	_cyl_to(catheter, 0.0026, 0.004, BARREL_Z1 + 0.026, orange, "Collet")
	var sheath_mat := StandardMaterial3D.new()
	sheath_mat.albedo_color = Color(0.95, 0.9, 0.85, 0.55)
	sheath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheath_mat.roughness = 0.2
	var z0 := BARREL_Z1 + 0.028
	_cyl_to(catheter, 0.00105, SHEATH_Z1 - z0, (z0 + SHEATH_Z1) * 0.5, sheath_mat, "Gaine")
	var needle := _cyl(0.0008, TIP_Z - 0.004 - BARREL_Z1, (BARREL_Z1 + TIP_Z - 0.004) * 0.5, steel, "Aiguille")
	needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bevel := MeshInstance3D.new()
	bevel.name = "Biseau"
	bevel.mesh = MeshUtil.tube(PackedVector3Array([Vector3(0, 0, TIP_Z - 0.004), Vector3(0, 0, TIP_Z)]), PackedFloat32Array([0.0008, 0.0001]), 8, false, false)
	bevel.material_override = steel
	add_child(bevel)
	set_aspiration(0.0)


func _cyl(r: float, h: float, z: float, mat: Material, nm: String) -> MeshInstance3D:
	return _cyl_to(self, r, h, z, mat, nm)


func _cyl_to(parent: Node3D, r: float, h: float, z: float, mat: Material, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation_degrees.x = 90
	mi.position = Vector3(0, 0, z)
	parent.add_child(mi)
	return mi


## Piston tiré : 0 = au repos (5 mL de sérum), 1 = tiré de 2 cm (dépression).
func set_aspiration(v: float) -> void:
	aspiration = clampf(v, 0.0, 1.0)
	if draws_blood:
		# Piston enfoncé au départ ; le sang remplit la place libérée
		var sz := lerpf(-0.0175, -0.066, aspiration)
		_seal.position.z = sz
		_rod.position.z = sz - 0.032
		_thumb.position.z = sz - 0.063
		var hb := BARREL_Z1 - sz - 0.002
		_liquid.visible = hb > 0.0008
		_liquid.scale = Vector3(1, maxf(hb, 0.0001), 1)
		_liquid.position.z = BARREL_Z1 - hb * 0.5
		return
	var seal_z := lerpf(-0.044, -0.064, aspiration)
	_seal.position.z = seal_z
	_rod.position.z = seal_z - 0.032
	_thumb.position.z = seal_z - 0.063
	# Le sérum reste du côté de l'embout ; l'air aspiré occupe la place libérée
	var liq_top := -0.044
	var h := BARREL_Z1 - liq_top
	_liquid.scale = Vector3(1, h, 1)
	_liquid.position.z = (BARREL_Z1 + liq_top) * 0.5


## Ce qui remonte dans la seringue : "air" (bulles), "blood" (sang), "fluid" (liquide citrin).
func set_flash(kind: String) -> void:
	flash = kind
	_flash_k = 0.0


func detach_catheter() -> Node3D:
	var xf := catheter.global_transform
	remove_child(catheter)
	var c := catheter
	catheter = null
	c.set_meta("xf", xf)
	return c


func _process(delta: float) -> void:
	_t += delta
	if flash == "":
		for b in _bubbles:
			b.visible = false
		return
	_flash_k = minf(1.0, _flash_k + delta * 0.8)
	match flash:
		"air":
			# Bulles qui montent dans le sérum vers le piston, en continu tant qu'on aspire
			for i in _bubbles.size():
				var b := _bubbles[i]
				var ph := fmod(_t * (0.6 + 0.15 * i) + i * 0.37, 1.0)
				b.visible = aspiration > 0.15 or ph < 0.6 * (1.0 - _flash_k * 0.5)
				var a := i * 2.4
				b.position = Vector3(cos(a) * 0.003, sin(a) * 0.003, lerpf(BARREL_Z1 - 0.002, -0.046, ph))
		"blood", "fluid":
			if draws_blood:
				return
			var c := Color(0.55, 0.03, 0.04, 0.85) if flash == "blood" else Color(0.92, 0.8, 0.4, 0.6)
			_liquid_mat.albedo_color = Color(0.78, 0.9, 1.0, 0.38).lerp(c, _flash_k)
			for b in _bubbles:
				b.visible = false
