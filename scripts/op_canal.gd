class_name OpCanal
extends Operation
## Libération endoscopique du canal carpien (technique d'Agee, une seule incision). Le bras droit est
## posé le long du corps, paume vers le haut. On regarde l'écran de la colonne d'endoscopie, comme au
## vrai bloc : la caméra au bout de l'endoscope filme l'intérieur du canal, le ligament blanc au
## plafond, que la lame fend en reculant. Le nerf médian, écrasé dessous, est libéré.

const ARM_Z := Patient.ARM_Z
const WRIST_X := Patient.WRIST_X
const TUNNEL_END_X := 0.2

var entry := Vector3.ZERO  ## point d'entrée dans le canal (centre de l'incision, sur la peau)
var tunnel_axis := Vector3.RIGHT
var lig_mat: ShaderMaterial
var nerve: MeshInstance3D
var scope_vp: SubViewport
var scope_cam: Camera3D
var scope_light: OmniLight3D
var screen_mat: ShaderMaterial
var screen_status: Label3D
var screen_info: Label3D
var _cut_lo := -1.0
var _cut_hi := -1.0
var _blade: Node3D


func _init() -> void:
	id = "canal"
	name = "Canal carpien (endoscopie)"
	tagline = "Les doigts s'endorment la nuit : le nerf de la main est écrasé au poignet. On coupe le ligament qui l'écrase avec une caméra, en regardant l'écran."
	intro_text = "Claire, 52 ans : fourmillements et douleurs dans la main droite, surtout la nuit. Son nerf médian est comprimé dans le canal carpien. Elle est réveillée, garrot gonflé au bras. Tu vas couper le ligament par une petite incision au poignet, en regardant l'écran de l'endoscope comme un vrai chirurgien."
	summary = "Ligament coupé sur toute sa longueur : le nerf médian est libéré. Les fourmillements vont disparaître."
	header = "BLOC 4  ·  CANAL CARPIEN  ·  ENDOSCOPIE (AGEE)"
	scan_text = "ÉLECTROMYOGRAMME\\nNerf médian droit :\\nconduction très ralentie au poignet"
	breath_rate = 15.0
	surgeon_spot = Vector3(0.17, 0.0, 0.86)
	tray_pos = Vector3(0.66, 0.0, 0.62)
	vitals = {"hr": 82.0, "spo2": 99.0, "sys": 132, "dia": 82}
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue de lidocaïne", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 90.0, 0.0],
		["endoscope", "Endoscope à lame (Agee)", "proc:endoscope", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille + fil", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	p.op = "canal"
	# Incision transverse de 1,5 cm dans le pli du poignet, côté cubital (vers le corps)
	p.INC_A = Vector2(WRIST_X, ARM_Z - 0.011)
	p.INC_B = Vector2(WRIST_X, ARM_Z + 0.004)
	p.PATCH_MIN = Vector2(0.04, 0.3)
	p.PATCH_SIZE = Vector2(0.3, 0.2)
	p.WINDOW_MIN = Vector2(0.07, 0.325)
	p.WINDOW_MAX = Vector2(0.315, 0.465)
	p.paint_r = Vector2(0.06, 0.035)
	p.wound_w = 0.004
	p.WOUND_DEPTH = 0.011
	p.bowl_radii = Vector3(0.01, 0.008, 0.008)
	p.bowl_color = Color(0.85, 0.7, 0.45)
	p.hole_limit = 0.004
	p.breathe_amp = 0.0


func _surface(x: float, z: float) -> float:
	return Patient.body_height(x, z)


func build_extras() -> void:
	var c := patient.center
	entry = c
	var zc := c.z
	var end := Vector3(TUNNEL_END_X, _surface(TUNNEL_END_X, zc) - 0.0085, zc)
	tunnel_axis = (end - entry).normalized()
	_build_tunnel(zc)
	_build_tower()


## Le canal carpien vu de l'intérieur : plafond (ligament), plancher (tendons, nerf médian), graisse.
func _build_tunnel(zc: float) -> void:
	var n := 14
	var line := PackedVector3Array()
	for i in n:
		var x := lerpf(WRIST_X + 0.002, TUNNEL_END_X + 0.004, float(i) / (n - 1))
		line.append(Vector3(x, _surface(x, zc) - 0.0085, zc))
	lig_mat = ShaderMaterial.new()
	lig_mat.shader = preload("res://shaders/ligament.gdshader")
	lig_mat.set_shader_parameter("center_z", zc)
	_half_tube(line, 0.0065, 0.0045, true, lig_mat, "Ligament")
	_half_tube(line, 0.0078, 0.0058, true, tissue(Color(0.92, 0.78, 0.42), 0.0, 0.25, 0.0, 60.0), "Graisse")
	var floor_mat := tissue(Color(0.9, 0.8, 0.76), 0.0, 0.3, 0.0, 70.0)
	floor_mat.set_shader_parameter("wetness", 1.0)
	_half_tube(line, 0.0065, 0.0045, false, floor_mat, "Tendons")
	# Tendons fléchisseurs (cordons nacrés) et nerf médian (jaunâtre, aplati, avec ses vaisseaux)
	for k in 3:
		var pts := PackedVector3Array()
		for p in line:
			pts.append(p + Vector3(0, -0.0032, -0.0035 + k * 0.0032))
		var rr := PackedFloat32Array()
		rr.resize(pts.size())
		rr.fill(0.0013)
		var t := MeshInstance3D.new()
		t.mesh = MeshUtil.tube(pts, rr, 8)
		t.material_override = tissue(Color(0.95, 0.92, 0.86), 0.0, 0.1, 0.0, 90.0)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patient.add_child(t)
	var np := PackedVector3Array()
	for p in line:
		np.append(p + Vector3(0, -0.0016, 0.0022))
	var nr := PackedFloat32Array()
	nr.resize(np.size())
	nr.fill(0.0019)
	nerve = MeshInstance3D.new()
	nerve.name = "NerfMedian"
	nerve.mesh = MeshUtil.tube(np, nr, 10)
	nerve.material_override = tissue(Color(0.93, 0.82, 0.55), 0.0, 0.7, 0.0, 80.0)
	nerve.scale = Vector3(1, 1, 1)
	nerve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patient.add_child(nerve)
	# Fond du canal (graisse de la paume, arcade artérielle)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.012
	cap.mesh = sm
	cap.material_override = tissue(Color(0.9, 0.7, 0.4), 0.1, 0.8, 0.0, 60.0)
	cap.position = line[n - 1] + Vector3(0.004, 0, 0)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patient.add_child(cap)


## Demi-tube (plafond ou plancher) le long d'une ligne, faces tournées vers l'intérieur.
func _half_tube(line: PackedVector3Array, rz: float, ry: float, top: bool, mat: Material, nm: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	for i in line.size():
		for k in seg + 1:
			var a := PI * float(k) / seg
			var dz := cos(a) * rz
			var dy := sin(a) * ry * (1.0 if top else -1.0)
			var nrm := -Vector3(0, dy / (ry * ry), dz / (rz * rz)).normalized()
			st.set_normal(nrm)
			st.set_uv(Vector2(float(k) / seg, float(i) / (line.size() - 1)))
			st.add_vertex(line[i] + Vector3(0, dy, dz))
	for i in line.size() - 1:
		for k in seg:
			var a := i * (seg + 1) + k
			var b := a + seg + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patient.add_child(mi)


## Colonne d'endoscopie de l'autre côté de la table : chariot, boîtiers, grand écran face au chirurgien.
func _build_tower() -> void:
	var tower := Node3D.new()
	tower.name = "ColonneEndoscopie"
	root.add_child(tower)
	tower.position = Vector3(-0.45, 0, -0.95)
	var look := surgeon_spot - tower.position
	tower.rotation.y = atan2(look.x, look.z)
	var body := MeshUtil.mat(Color(0.86, 0.87, 0.88), 0.45, 0.1)
	var dark := MeshUtil.mat(Color(0.07, 0.08, 0.09), 0.4)
	var steel := MeshUtil.mat(Color(0.7, 0.72, 0.75), 0.35, 0.8)
	for sx in [-0.22, 0.22]:
		for sz in [-0.2, 0.2]:
			MeshUtil.cylinder_instance(tower, 0.012, 1.05, Vector3(sx, 0.55, sz), steel, "Montant")
			MeshUtil.cylinder_instance(tower, 0.03, 0.03, Vector3(sx, 0.03, sz), dark, "Roue")
	for y in [0.12, 0.5, 0.85]:
		MeshUtil.box_instance(tower, Vector3(0.5, 0.025, 0.46), Vector3(0, y, 0), body, "Plateau")
	# Boîtiers : processeur caméra, source de lumière froide (avec son câble), garrot
	MeshUtil.box_instance(tower, Vector3(0.42, 0.11, 0.36), Vector3(0, 0.58, 0), dark, "Processeur")
	MeshUtil.box_instance(tower, Vector3(0.42, 0.11, 0.36), Vector3(0, 0.71, 0), body, "Lumiere")
	MeshUtil.box_instance(tower, Vector3(0.05, 0.02, 0.005), Vector3(0.1, 0.71, 0.181), MeshUtil.emissive(Color(0.3, 1.0, 0.5), 2.0), "Voyant")
	var lbl := Label3D.new()
	lbl.text = "GARROT   250 mmHg   ⏱ 12 min"
	lbl.font_size = 28
	lbl.pixel_size = 0.0008
	lbl.modulate = Color(1.0, 0.75, 0.3)
	lbl.position = Vector3(0, 0.58, 0.182)
	tower.add_child(lbl)
	# Bras et grand écran (34 pouces) à hauteur des yeux
	MeshUtil.cylinder_instance(tower, 0.02, 0.6, Vector3(0, 1.15, -0.05), steel, "Mat")
	var screen_root := Node3D.new()
	screen_root.position = Vector3(0, 1.55, 0.0)
	screen_root.rotation_degrees.x = -6.0
	tower.add_child(screen_root)
	MeshUtil.box_instance(screen_root, Vector3(0.8, 0.5, 0.05), Vector3(0, 0, -0.03), dark, "Moniteur")
	scope_vp = SubViewport.new()
	scope_vp.size = Vector2i(480, 480)
	scope_vp.msaa_3d = Viewport.MSAA_DISABLED
	scope_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(scope_vp)
	scope_cam = Camera3D.new()
	scope_cam.fov = 85.0
	scope_cam.near = 0.0012
	scope_cam.far = 0.6
	scope_vp.add_child(scope_cam)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.75, 0.45)
	quad.mesh = qm
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = preload("res://shaders/scope_screen.gdshader")
	screen_mat.set_shader_parameter("view", scope_vp.get_texture())
	screen_mat.set_shader_parameter("aspect", 0.75 / 0.45)
	quad.material_override = screen_mat
	quad.position = Vector3(0, 0, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen_root.add_child(quad)
	var head := Label3D.new()
	head.text = "ENDOSCOPIE  ·  CANAL CARPIEN DROIT"
	head.font_size = 30
	head.pixel_size = 0.0007
	head.modulate = Color(0.7, 0.9, 1.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.position = Vector3(-0.36, 0.2, 0.002)
	head.offset = Vector2(250, 0)
	screen_root.add_child(head)
	screen_status = Label3D.new()
	screen_status.font_size = 34
	screen_status.pixel_size = 0.0007
	screen_status.position = Vector3(0.26, -0.19, 0.002)
	screen_root.add_child(screen_status)
	screen_info = Label3D.new()
	screen_info.font_size = 26
	screen_info.pixel_size = 0.0007
	screen_info.modulate = Color(0.75, 0.85, 0.9)
	screen_info.position = Vector3(-0.26, -0.19, 0.002)
	screen_root.add_child(screen_info)
	# Lumière froide au bout de l'endoscope
	scope_light = OmniLight3D.new()
	scope_light.light_color = Color(1.0, 0.98, 0.95)
	scope_light.light_energy = 0.0
	scope_light.omni_range = 0.05
	scope_light.omni_attenuation = 1.3
	scope_light.shadow_enabled = false
	root.add_child(scope_light)


func on_start() -> void:
	monitor.target_rate = 82.0


func define_steps() -> void:
	var c := patient.center
	steps = [
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte la main et le poignet",
			"text": "Frotte la compresse de la pince à badigeon sur la paume et le poignet, jusqu'à ce que toute la zone soit brune.",
			"label": "Zone à désinfecter", "ring": 2.6,
			"area": func() -> Vector3: return patient.on_skin(Vector3(0.155, 0, ARM_Z)),
			"done_msg": "Main désinfectée"},
		{"id": "anesthesie", "kind": "inject", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Endors le poignet",
			"text": "Pique dans le pli du poignet sur le repère. Relâche le pouce, puis serre-le pour pousser le piston : un bouton gonfle. Injecte tout, retire l'aiguille, puis attends que ça agisse.",
			"label": "Pique ici", "wait": 8.0,
			"target": func() -> Vector3: return patient.on_skin(c),
			"done_msg": "Produit injecté : attends qu'il agisse"},
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Petite incision au poignet",
			"text": "Quand le bouton a blanchi, incise de 1,5 cm dans le pli du poignet, sur le pointillé : appuie et glisse la lame.",
			"done": _incision_done, "done_msg": "Porte d'entrée faite"},
		{"id": "endoscope", "kind": "insert", "list": "Endoscope", "inst": "endoscope",
			"title": "Glisse l'endoscope dans le canal",
			"text": "Regarde l'écran de la colonne, en face. Glisse l'endoscope dans l'incision et pousse-le doucement vers la paume, sous le ligament : à l'écran, le plafond blanc et nacré, c'est lui.",
			"label": "Entre ici", "depth": 0.045, "axis": tunnel_axis, "zone_depth": 0.014, "zone_r": 0.01,
			"target": func() -> Vector3: return entry,
			"done": _scope_in, "done_msg": "Tu vois le ligament à l'écran"},
		{"id": "section", "kind": "endocut", "list": "Couper le ligament", "inst": "endoscope",
			"title": "Coupe le ligament en reculant",
			"text": "En regardant l'écran : serre la gâchette (pouce contre index) pour sortir la lame, puis recule doucement l'endoscope vers le poignet. Le ligament s'ouvre en deux. Coupe-le sur toute sa longueur.",
			"label": "", "depth": 0.045, "axis": tunnel_axis, "zone_depth": 0.014, "zone_r": 0.01,
			"target": func() -> Vector3: return entry,
			"cut": _cut_range, "done": _released, "done_msg": "Ligament coupé : le nerf est libéré !"},
		{"id": "suture", "kind": "suture", "list": "Suture", "inst": "porte_aiguille",
			"title": "Referme l'incision",
			"text": "Retire l'endoscope. Deux points sur la petite incision : pique à l'entrée, ressors sur l'autre bord.",
			"label": "Point", "radius": 0.006,
			"pairs": _stitch_pairs, "point": _stitch, "done": _closed,
			"done_msg": "Terminé : pansement compressif et on dégonfle le garrot"},
	]


func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
	patient.hole_limit = 0.012
	if instant:
		patient.opening = 0.6
	else:
		tween_opening(0.6)


func _scope_in(_hand: SurgeonHand, _instant: bool) -> void:
	pass


## La lame a coupé le ligament entre deux profondeurs (le long du canal).
func _cut_range(lo: float, hi: float) -> void:
	_cut_lo = lo
	_cut_hi = hi
	var x0 := entry.x + tunnel_axis.x * lo
	var x1 := entry.x + tunnel_axis.x * hi
	lig_mat.set_shader_parameter("cut_x0", minf(x0, x1) - 0.002)
	lig_mat.set_shader_parameter("cut_x1", maxf(x0, x1) + 0.002)


func _released(_hand: SurgeonHand, instant: bool) -> void:
	_cut_range(-0.01, 0.06)
	# Le nerf, enfin libre, reprend sa forme et sa couleur
	var tw := proc.create_tween()
	tw.tween_property(nerve, "scale", Vector3(1.0, 1.12, 1.0), 0.1 if instant else 3.0)
	(nerve.material_override as ShaderMaterial).set_shader_parameter("base_color", Color(0.95, 0.8, 0.62))
	monitor.target_rate = 78.0


func _stitch_pairs() -> Array:
	return [patient.stitch_pair(0.3, 0.003), patient.stitch_pair(0.72, 0.003)]


func _stitch(i: int, instant: bool) -> void:
	patient.add_stitch_at((_stitch_pairs()[i][0] + _stitch_pairs()[i][1]) * 0.5, patient.perp3, 0.009)
	if instant:
		patient.opening = 0.6 - 0.3 * (i + 1)
	else:
		tween_opening(0.6 - 0.3 * (i + 1))


func _closed(_instant: bool) -> void:
	patient.set_stitched(1.0)


## L'écran montre ce que filme l'endoscope tant qu'on le tient ; la lame sort quand on serre.
func process(_delta: float) -> void:
	if scope_cam == null:
		return
	var inst := instrument("endoscope")
	if _blade == null:
		_blade = inst.find_child("Lame", true, false) as Node3D
	var active := inst.held or inst.parked
	var squeeze := 0.0
	for h in proc.hands:
		if h.held == inst:
			squeeze = h.squeeze_value()
	var blade_out := squeeze > 0.6
	if _blade:
		_blade.position.y = 0.0004 + (0.0026 if blade_out else 0.0)
	screen_mat.set_shader_parameter("on", 1.0 if active else 0.0)
	scope_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	scope_light.light_energy = 0.9 if active else 0.0
	if active:
		var tip := inst.tip_global()
		var ax := inst.axis_global()
		var up := inst.global_basis.y.normalized()
		scope_cam.global_transform = Transform3D(Basis.looking_at(ax, up), tip - ax * 0.002)
		scope_light.global_position = tip + ax * 0.001
		var along := (tip - entry).dot(tunnel_axis)
		screen_status.text = "LAME SORTIE" if blade_out else "lame rentrée"
		screen_status.modulate = Color(1.0, 0.3, 0.25) if blade_out else Color(0.6, 0.75, 0.8)
		screen_info.text = "Profondeur %d mm" % int(maxf(along, 0.0) * 1000.0) if along > 0.0 else "Hors du canal"
	else:
		screen_status.text = ""
		screen_info.text = "Caméra en attente"
