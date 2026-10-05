class_name ProbeModel
extends Node3D
## Sonde d'échographie cardiaque (barrette phasée) : tête plate et large, face acoustique en
## caoutchouc couverte de gel, corps qui s'affine vers la main, repère lumineux sur le côté
## (il indique le côté gauche de l'image), manchon et départ du câble. Face vers +Z.

const FACE_Z := 0.05


func _init() -> void:
	var shell := MeshUtil.mat(Color(0.82, 0.83, 0.85), 0.35)
	shell.clearcoat_enabled = true
	shell.clearcoat = 0.4
	var rubber := MeshUtil.mat(Color(0.22, 0.24, 0.27), 0.75)
	# Tête : bloc arrondi 2,6 × 1,8 cm
	var head := MeshInstance3D.new()
	head.name = "Tete"
	var cap := CapsuleMesh.new()
	cap.radius = 0.0115
	cap.height = 0.03
	cap.radial_segments = 24
	cap.rings = 6
	head.mesh = cap
	head.material_override = shell
	head.rotation_degrees = Vector3(0, 0, 90)
	head.scale = Vector3(1.0, 1.0, 1.0)
	head.position = Vector3(0, 0, FACE_Z - 0.016)
	add_child(head)
	var head2 := MeshUtil.box_instance(self, Vector3(0.03, 0.023, 0.026), Vector3(0, 0, FACE_Z - 0.015), shell, "Bloc")
	head2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Face acoustique (lentille) et gel
	MeshUtil.box_instance(self, Vector3(0.027, 0.02, 0.004), Vector3(0, 0, FACE_Z - 0.0019), rubber, "Lentille")
	var gel := MeshInstance3D.new()
	gel.name = "Gel"
	var gm := SphereMesh.new()
	gm.radius = 1.0
	gm.height = 2.0
	gm.radial_segments = 16
	gm.rings = 8
	gel.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.roughness = 0.03
	gmat.metallic_specular = 1.0
	gel.material_override = gmat
	gel.scale = Vector3(0.012, 0.008, 0.0018)
	gel.position = Vector3(0.001, 0, FACE_Z - 0.0002)
	gel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gel)
	# Corps : s'affine vers l'arrière, section ovale
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 12:
		var t := float(i) / 11.0
		pts.append(Vector3(0, 0, lerpf(FACE_Z - 0.026, FACE_Z - 0.125, t)))
		rr.append(lerpf(0.0135, 0.0095, smoothstep(0.0, 1.0, t)) * (1.0 + 0.06 * sin(t * PI * 2.0)))
	var body := MeshInstance3D.new()
	body.name = "Corps"
	body.mesh = MeshUtil.tube(pts, rr, 20, false, true)
	body.material_override = shell
	body.scale = Vector3(1.15, 0.82, 1.0)
	add_child(body)
	# Repère d'orientation : petite diode verte sur le côté de la tête
	var led := MeshUtil.emissive(Color(0.25, 1.0, 0.45), 2.5)
	MeshUtil.box_instance(self, Vector3(0.0016, 0.005, 0.005), Vector3(0.0153, 0.0, FACE_Z - 0.013), led, "Repere")
	# Manchon et départ du câble
	var black := MeshUtil.mat(Color(0.06, 0.06, 0.07), 0.6)
	var sp := PackedVector3Array([Vector3(0, 0, FACE_Z - 0.124), Vector3(0, 0, FACE_Z - 0.15)])
	var sl := MeshInstance3D.new()
	sl.mesh = MeshUtil.tube(sp, PackedFloat32Array([0.0062, 0.0042]), 14, false, false)
	sl.material_override = black
	add_child(sl)
	# (droit, dans l'axe : le centre de la boîte englobante reste sur l'axe de la sonde)
	var cp := PackedVector3Array([Vector3(0, 0, FACE_Z - 0.15), Vector3(0, 0, FACE_Z - 0.19)])
	var cable := MeshInstance3D.new()
	var cr := PackedFloat32Array()
	cr.resize(cp.size())
	cr.fill(0.0034)
	cable.mesh = MeshUtil.tube(cp, cr, 10, false, false)
	cable.material_override = black
	add_child(cable)
