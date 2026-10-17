class_name IVProcedure
extends Node3D
## Pose d'une voie veineuse périphérique, étape par étape, en vue rapprochée sur le pli du coude.
## Chaque étape a son geste à la souris et un rendu visible :
##  1. garrot au-dessus du coude : clic sur le bras puis tirer la souris pour serrer (les veines
##     se gonflent) ;
##  2. désinfection : clic maintenu en frottant (l'antiseptique colore la peau) ;
##  3. choix de la veine : palper une veine visible (clic maintenu) ; une veine fine ou qui roule
##     risque l'échec ;
##  4. ponction : l'aiguille entre sous un angle faible (glisser dans le sens de l'aiguille), reflux
##     de sang dans la chambre, on abaisse et on avance le cathéter, puis on retire l'aiguille
##     (glisser en sens inverse) ;
##  5. desserrer le garrot (mains) ;
##  6. pansement transparent : glisser sur le cathéter pour le coller ;
##  7. brancher la perfusion (tubulure jusqu'à la poche sur la potence) ou injecter.
## Les fonctions _pull, _rub, _palpate, _advance, _dress… sont celles des gestes : le robot de test
## les appelle directement.

const STEPS := ["garrot", "desinfection", "veine", "ponction", "garrot_off", "pansement", "branchement"]
const TITLES := ["pose le garrot au-dessus du coude", "désinfecte la peau", "choisis une veine", "pique dans la veine",
	"desserre le garrot", "colle le pansement transparent", "branche la perfusion (ou injecte)"]
## Objets du chariot qui lancent la pose quand on clique sur un bras
const KIT := ["garrot", "antiseptique", "catheter18", "catheter20"]
const ELBOW_T := 0.46  ## pli du coude (fraction du bras, 0 : épaule, 1 : bout des doigts)
const ANGLE_IN := 18.0  ## angle de ponction (degrés)
const ANGLE_FLAT := 6.0  ## angle du cathéter une fois posé
const DEPTH_VEIN := 0.0045  ## profondeur de la pointe dans la veine (m)
const PULL_PX := 260.0  ## garrot : distance de souris pour serrer
const RUB_PX := 900.0  ## désinfection : distance de frottement
const PALPATE_S := 1.0
const PUSH_PX := 150.0  ## ponction : course de la souris pour chaque phase
const DRESS_PX := 260.0
const LAYER_GEAR := 2  ## couche visuelle du matériel (les décalcomanies de la peau ne s'y appliquent pas)

var g: Node  ## Gestures
var game: Node
var gear: PatientGear
var zv: ZoneView
var inv: Inventory
var physio: Physio
var patient: Patient

var active := false
var side := "R"
var step := 0
var veins: Array[Dictionary] = []  ## {"side", "id", "pts", "w", "quality", "text"}
var chosen := {}  ## veine choisie : {"vein", "p", "dir"}
var misses := 0

var _act := {}  ## geste en cours : {"kind", ...}
var _vis := {"L": 0.2, "R": 0.2}  ## visibilité des veines affichée (animée vers _vis_to)
var _vis_to := {"L": 0.2, "R": 0.2}
var _vein_decals := {"L": [], "R": []}
var _band: Node3D  ## garrot en cours de pose (aperçu, puis serrage)
var _band_t := 0.36
var _pull := 0.0
var _loosen := -1.0  ## desserrage animé du garrot (0..1), -1 : rien
var _stain: Decal  ## antiseptique
var _stain_c := Vector3.ZERO
var _rub := 0.0
var _ring: MeshInstance3D  ## repère : veine sous le doigt
var _cath: Node3D  ## cathéter tenu pendant la ponction
var _gauge := "18"
var _phase := 0  ## ponction : 0 attente, 1 l'aiguille entre, 2 avancer le cathéter, 3 retirer l'aiguille
var _depth := -0.006
var _adv := 0.0
var _wd := 0.0
var _flash := 0.0
var _flash_on := false
var _dress := 0.0
var _dress_node: Node3D
var _syringe: Node3D  ## seringue en train d'injecter
var _syr_full := Transform3D.IDENTITY
var _auto_selected := -1
var _hematomas: Array = []
static var _tex := {}


func setup(p_gestures: Node) -> void:
	g = p_gestures
	game = g.game
	gear = g.gear
	zv = g.zv
	inv = g.inv
	physio = g.physio
	patient = g.patient
	for s in ["L", "R"]:
		var mid := Patient.arm_top(s, 0.55)
		var yaw := 0.0 if s == "L" else PI
		zv.define("perf_" + s, "Voie veineuse — bras %s" % ("gauche" if s == "L" else "droit"), mid + Vector3(0, 0.01, 0), yaw, 64.0, 0.36, 0.1, 0.8)
	zv.entered.connect(_on_zone_entered)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0042
	tm.outer_radius = 0.0056
	tm.rings = 24
	tm.ring_segments = 6
	_ring.mesh = tm
	var rm := MeshUtil.emissive(Color(0.35, 0.95, 0.8), 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color.a = 0.65
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_ring.layers = 1 << (LAYER_GEAR - 1)
	add_child(_ring)


func toast(t: String, ok := true) -> void:
	game.call("toast", t, ok)


func ev(kind: String, text := "") -> void:
	game.call("event", kind, text)


static func gear_layer(n: Node) -> void:
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).layers = 1 << (LAYER_GEAR - 1)
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 1 << (LAYER_GEAR - 1)


# ---------------------------------------------------------------- Veines

## Veines superficielles de chaque bras : veine du pli du coude, veine de l'avant-bras, veine du
## poignet (qui roule), veine du dos de la main (fine). Les trois dernières sont aussi dessinées par
## le shader de la peau ; toutes ont une décalcomanie (bleutée, en relief) qui se gonfle sous garrot.
func build_veins() -> void:
	veins.clear()
	var arr := PackedVector4Array()
	for s in ["L", "R"]:
		_add_vein(s, "pli", [[0.53, 0.011], [0.48, 0.002], [0.43, -0.008]], 0.0034, "bonne",
			"Veine du pli du coude : grosse, bien gonflée, elle ne bouge pas. Bon choix.")
		_add_vein(s, "avant_bras", [[0.54, -0.004], [0.59, 0.002], [0.64, 0.006], [0.69, 0.003], [0.74, -0.002]], 0.0029, "bonne",
			"Veine de l'avant-bras : droite et bien gonflée. Bon choix.")
		_add_vein(s, "poignet", [[0.76, 0.012], [0.82, 0.016]], 0.0022, "roule",
			"Veine du poignet : elle roule sous le doigt, près de l'articulation. Risqué.")
		_add_vein(s, "main", [[0.86, 0.004], [0.93, 0.011]], 0.0017, "fine",
			"Veine du dos de la main : fine et fragile. Risqué.")
	for v in veins:
		if v["id"] == "pli":
			continue
		for q in (v["pts"] as PackedVector3Array):
			arr.append(Vector4(q.x, q.y, q.z, float(v["w"]) * 1.6))
		arr.append(Vector4(0, 0, 0, -1.0))
	patient.skin_mat.set_shader_parameter("veins", arr)
	patient.skin_mat.set_shader_parameter("vein_n", arr.size())
	for v in veins:
		_vein_decal(v)
	# Compatibilité : points de la veine de l'avant-bras par bras
	for s in ["L", "R"]:
		g.veins[s] = vein_by("avant_bras", s)["pts"]
	update_vis()


func _add_vein(s: String, id: String, spec: Array, w: float, quality: String, text: String) -> void:
	var pts := PackedVector3Array()
	var mirror := 1.0 if s == "R" else -1.0
	for e in spec:
		var t: float = e[0]
		var c := Patient.arm_point(s, t)
		var lat := Patient.arm_dir(s, t).cross(Vector3.UP).normalized()
		var q := c + lat * float(e[1]) * mirror
		q.y = Patient.body_height(q.x, q.z)
		pts.append(q)
	veins.append({"side": s, "id": id, "pts": pts, "w": w, "quality": quality, "text": text})


func vein_by(id: String, s: String) -> Dictionary:
	for v in veins:
		if v["id"] == id and v["side"] == s:
			return v
	return {}


## Veine la plus proche d'un point : [distance, veine, point sur la veine, direction].
func vein_near(p: Vector3, only_side := "") -> Array:
	var best := INF
	var bv := {}
	var bq := Vector3.ZERO
	var bd := Vector3.ZERO
	for v in veins:
		if only_side != "" and v["side"] != only_side:
			continue
		var pts: PackedVector3Array = v["pts"]
		for i in pts.size() - 1:
			var a := pts[i]
			var ab := pts[i + 1] - a
			var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a + ab * k
			var d := p.distance_to(q)
			if d < best:
				best = d
				bv = v
				bq = q
				bd = ab.normalized()
	return [best, bv, bq, bd]


func _vein_decal(v: Dictionary) -> void:
	var pts: PackedVector3Array = v["pts"]
	var w: float = v["w"]
	var tx := _textures()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var n := Patient.skin_normal(mid.x, mid.z)
		var along := (b - a)
		along = (along - n * along.dot(n)).normalized()
		var d := Decal.new()
		d.name = "Veine"
		d.size = Vector3(w * 7.0, 0.03, a.distance_to(b) + w * 2.5)
		d.texture_albedo = tx["vein"]
		d.texture_normal = tx["vein_n"]
		d.normal_fade = 0.2
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.cull_mask = 1
		d.modulate = Color(1, 1, 1, 0.0)
		add_child(d)
		d.global_transform = Transform3D(Basis(n.cross(along).normalized() * -1.0, n, along).orthonormalized(), mid)
		(_vein_decals[v["side"]] as Array).append([d, w])


## Visibilité voulue des veines : gonflées sous garrot, plates en cas de choc.
func update_vis() -> void:
	var t_side := String(gear.tourniquet.get("side", ""))
	for s in ["L", "R"]:
		var v := 0.22
		if t_side == s:
			v = 0.95 if _loosen < 0.0 else 0.95 * (1.0 - _loosen)
		if physio.sys < 85.0:
			v *= 0.6
		_vis_to[s] = maxf(v, 0.22 * (0.6 if physio.sys < 85.0 else 1.0))


func _tick_vis(delta: float) -> void:
	var changed := false
	for s in ["L", "R"]:
		var cur: float = _vis[s]
		var to: float = _vis_to[s]
		if absf(cur - to) > 0.002:
			# Les veines mettent quelques secondes à se gonfler, se vident plus vite
			_vis[s] = move_toward(cur, to, delta * (0.35 if to > cur else 0.9))
			changed = true
			for e in _vein_decals[s]:
				var d: Decal = e[0]
				d.modulate.a = clampf((_vis[s] - 0.15) * 0.75, 0.0, 1.0)
				d.normal_fade = 0.2
	if changed:
		patient.skin_mat.set_shader_parameter("vein_vis", Vector2(_vis["L"], _vis["R"]) * 0.4)


# ---------------------------------------------------------------- Textures (décalcomanies)

static func _textures() -> Dictionary:
	if not _tex.is_empty():
		return _tex
	# Veine : trait bleuté, bords doux, relief en demi-cylindre (carte de normales)
	var w := 32
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var nimg := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var fy := (y + 0.5) / h
		var fade := smoothstep(0.0, 0.2, fy) * smoothstep(1.0, 0.8, fy)
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var prof := exp(-u * u / 0.2)
			var a := prof * fade
			img.set_pixel(x, y, Color(0.5, 0.55, 0.7, a * 0.55))
			var slope := -2.0 * u / 0.2 * prof
			var n := Vector3(-slope * 0.5 * fade, 0.0, 1.0).normalized()
			nimg.set_pixel(x, y, Color(n.x * 0.5 + 0.5, 0.5, n.z * 0.5 + 0.5, a))
	img.generate_mipmaps()
	nimg.generate_mipmaps()
	_tex["vein"] = ImageTexture.create_from_image(img)
	_tex["vein_n"] = ImageTexture.create_from_image(nimg)
	# Antiseptique (povidone iodée) : tache orangée, bord irrégulier un peu plus foncé (séchage)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var s := 96
	var st := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var hm := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5) / s * 2.0 - Vector2.ONE
			var nn := noise.get_noise_2d(x, y)
			var r := p.length() + nn * 0.22
			var a := 1.0 - smoothstep(0.62, 0.8, r)
			var rim := smoothstep(0.5, 0.72, r) * a
			var streak := 0.85 + 0.15 * noise.get_noise_2d(x * 3.0, y * 0.4)
			st.set_pixel(x, y, Color(0.6 - 0.12 * rim, 0.27 - 0.06 * rim, 0.07, clampf(a * 0.62 * streak + rim * 0.25, 0.0, 1.0)))
			# Hématome : bleu-violet au centre, jaunâtre au bord
			var hr := p.length() + nn * 0.3
			var ha := 1.0 - smoothstep(0.35, 0.85, hr)
			hm.set_pixel(x, y, Color(0.32 + 0.2 * smoothstep(0.3, 0.8, hr), 0.12 + 0.12 * smoothstep(0.4, 0.85, hr), 0.32 - 0.1 * smoothstep(0.3, 0.8, hr), ha * 0.7))
	st.generate_mipmaps()
	hm.generate_mipmaps()
	_tex["stain"] = ImageTexture.create_from_image(st)
	_tex["hematoma"] = ImageTexture.create_from_image(hm)
	return _tex


func _decal(tex: Texture2D, p: Vector3, along: Vector3, size: Vector2, alpha: float) -> Decal:
	var n := Patient.skin_normal(p.x, p.z)
	along = (along - n * along.dot(n)).normalized()
	var d := Decal.new()
	d.size = Vector3(size.x, 0.05, size.y)
	d.texture_albedo = tex
	d.cull_mask = 1
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.modulate = Color(1, 1, 1, alpha)
	add_child(d)
	d.global_transform = Transform3D(Basis(n.cross(along).normalized() * -1.0, n, along).orthonormalized(), p)
	return d


# ---------------------------------------------------------------- Déroulé

func _on_zone_entered(z: String) -> void:
	if z.begins_with("perf_"):
		return
	var s := z.substr(z.length() - 1)
	if not (z.begins_with("bras_") or z.begins_with("main_")):
		return
	if active and s == side:
		zv.focus("perf_" + side)
	elif not active and inv.current_id() in KIT and not gear.has_iv():
		start(s)


## Commence la pose sur un bras : la caméra se rapproche du pli du coude.
func start(s: String, focus := true) -> void:
	if gear.has_iv():
		toast("Il a déjà une voie veineuse", false)
		return
	active = true
	side = s
	step = 0
	chosen = {}
	_act = {}
	_pull = 0.0
	_rub = 0.0
	_phase = 0
	_auto_selected = -1
	# Garrot déjà posé (avant la séquence) : on passe à la suite
	if String(gear.tourniquet.get("side", "")) == side:
		step = 1
	elif not gear.tourniquet.is_empty():
		toast("Le garrot est sur l'autre bras", false)
	if bool(g._disinfected.get(side, false)) and step == 1:
		step = 2
	if focus and zv.active:
		zv.focus("perf_" + side)
	elif focus:
		zv.enter("perf_" + side)
	_announce()


func _announce() -> void:
	toast("Perfusion — étape %d/7 : %s" % [step + 1, TITLES[step]])
	_select_needed()


func _next() -> void:
	_act = {}
	game.call("set_progress", 0.0, "")
	step += 1
	if step >= STEPS.size():
		_finish()
		return
	if STEPS[step] == "ponction":
		_new_catheter()
		if not chosen.is_empty():
			zv.glide(chosen["p"] + Vector3(0, 0.005, 0), 0.24)
	elif STEPS[step] == "garrot_off" or STEPS[step] == "pansement":
		if gear.has_iv():
			zv.glide(gear.iv["hub"], 0.28)
	_announce()


func _finish() -> void:
	active = false
	step = 0
	_act = {}
	toast("Voie veineuse posée, pansée et branchée")
	if zv.active and zv.zone.begins_with("perf_"):
		zv.glide(Patient.arm_top(side, 0.55) + Vector3(0, 0.01, 0), 0.4)


## Ce qu'il faut avoir en main pour l'étape en cours.
func needed() -> Array:
	match STEPS[step]:
		"garrot":
			return ["garrot"]
		"desinfection":
			return ["antiseptique"]
		"ponction":
			return ["catheter18", "catheter20"]
		"branchement":
			return ["perfuseur", "seringue"]
	return ["main"]


func _select_needed() -> bool:
	var want := needed()
	if inv.current_id() in want:
		return true
	for id in want:
		if inv.has(id):
			inv.select_id(id)
			return true
	return false


func _missing_text() -> String:
	match STEPS[step]:
		"garrot":
			return "Il te manque le garrot : prends-le au chariot d'urgence (Voie veineuse)"
		"desinfection":
			return "Il te manque les compresses et l'antiseptique (chariot d'urgence)"
		"ponction":
			return "Il te manque un cathéter (18G vert ou 20G rose) : chariot d'urgence"
		"branchement":
			return "Prends la perfusion (NaCl + tubulure) ou une seringue préparée au chariot"
	return ""


## Ligne d'aide : étape en cours et geste à faire.
func hint(h: Dictionary) -> String:
	var head := "Perfusion — étape %d/7 : %s" % [step + 1, TITLES[step]]
	if not _select_needed():
		return head + " · " + _missing_text()
	var tip := ""
	match STEPS[step]:
		"garrot":
			tip = "clic sur le bras au-dessus du coude, puis tire la souris pour serrer"
		"desinfection":
			tip = "clic maintenu et frotte le pli du coude et l'avant-bras"
		"veine":
			tip = "clic maintenu sur une veine bleutée pour la palper"
			if not h.is_empty() and float(vein_near(h["pos"], side)[0]) < 0.007:
				tip = "clic maintenu : palper cette veine"
		"ponction":
			match _phase:
				0, 1:
					tip = "clic puis glisse la souris dans le sens de l'aiguille (vers le coude) pour piquer"
				2:
					tip = "reflux de sang ! continue de glisser : abaisse et avance le cathéter dans la veine"
				3:
					tip = "glisse la souris en sens inverse (vers la main) pour retirer l'aiguille"
		"garrot_off":
			tip = "clic sur le garrot pour le desserrer"
		"pansement":
			tip = "clic sur le cathéter et glisse pour coller le pansement transparent"
		"branchement":
			if inv.current_id() == "perfuseur":
				tip = "clic sur le cathéter : brancher la tubulure de la perfusion"
			else:
				tip = "clic maintenu sur le bouchon du cathéter : injecter"
	return head + " · " + tip


## Le clic doit-il aller à la pose de voie veineuse ?
func wants(id: String, h: Dictionary) -> bool:
	if active:
		if id == "tubes":
			return false
		return zv.zone.begins_with("perf_") or zv.zone.ends_with("_" + side)
	if id in KIT and not h.is_empty() and not gear.has_iv():
		var reg: String = g._region(h["pos"])
		return reg.begins_with("bras") or reg.begins_with("main")
	return false


func busy() -> bool:
	return not _act.is_empty()


func cancel() -> bool:
	if not _act.is_empty():
		_act = {}
		game.call("set_progress", 0.0, "")
		return true
	return false


func _on_arm(h: Dictionary) -> bool:
	if h.is_empty():
		return false
	var reg: String = g._region(h["pos"])
	return reg.ends_with("_" + side)


func arm_t(p: Vector3) -> float:
	var best := INF
	var bt := 0.0
	for k in 101:
		var t := k / 100.0
		var q := Patient.arm_point(side, t)
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < best:
			best = d
			bt = t
	return bt


func press(h: Dictionary) -> void:
	if not active:
		var reg: String = g._region(h["pos"])
		start(reg.substr(reg.length() - 1))
		return
	if not _select_needed():
		toast(_missing_text(), false)
		return
	match STEPS[step]:
		"garrot":
			if not _on_arm(h):
				toast("Vise le bras, au-dessus du coude", false)
				return
			var t := arm_t(h["pos"])
			if t > ELBOW_T - 0.03:
				toast("Plus haut : le garrot se serre au-dessus du coude, sur le bras", false)
				return
			_band_t = clampf(t, 0.2, ELBOW_T - 0.06)
			_act = {"kind": "garrot"}
			_show_band(1.0 - _pull / PULL_PX)
		"desinfection":
			if not _on_arm(h) or arm_t(h["pos"]) < ELBOW_T - 0.06 or arm_t(h["pos"]) > 0.8:
				toast("Désinfecte le pli du coude et l'avant-bras, là où tu vas piquer", false)
				return
			if _stain == null:
				var t2 := clampf(arm_t(h["pos"]), 0.5, 0.62)
				_stain_c = Patient.arm_top(side, t2)
				_stain = _decal(_textures()["stain"], _stain_c, Patient.arm_dir(side, t2), Vector2(0.08, 0.13), 0.0)
			_act = {"kind": "desinf"}
			g._gloves_check("désinfection")
		"veine":
			var vn := vein_near(h["pos"], side) if not h.is_empty() else [INF]
			if float(vn[0]) > 0.007:
				toast("Pas de veine sous le doigt : vise un trait bleuté gonflé", false)
				return
			_act = {"kind": "palpe", "t": 0.0, "vn": vn}
		"ponction":
			_act = {"kind": "ponction"}
			if _phase == 0:
				_phase = 1
				g._gloves_check("pose de cathéter")
				Sfx.play("pique", chosen["p"], -8.0)
		"garrot_off":
			if h.is_empty() or not (_on_arm(h) or float(h["pos"].distance_to(gear.iv.get("hub", Vector3.ZERO))) < 0.2):
				toast("Clic sur le garrot (au-dessus du coude)", false)
				return
			_release_tourniquet()
		"pansement":
			if h.is_empty() or (h["pos"] as Vector3).distance_to(gear.iv["hub"]) > 0.05:
				toast("Clic sur le cathéter pour poser le pansement", false)
				return
			_act = {"kind": "pansement"}
			if _dress_node == null:
				_dress_node = gear.dressing_node()
				_dress_node.visible = true
		"branchement":
			if h.is_empty() or (h["pos"] as Vector3).distance_to(gear.iv["hub"]) > 0.05:
				toast("Clic sur le cathéter", false)
				return
			if inv.current_id() == "perfuseur":
				connect_perfusion()
			else:
				g._syringe_press(gear.iv["port"], "bras_" + side)


func release(_h: Dictionary) -> void:
	if _act.is_empty():
		return
	var k: String = _act["kind"]
	if k == "palpe":
		toast("Palpe un peu plus longtemps (clic maintenu)", false)
	_act = {}
	game.call("set_progress", 0.0, "")


func drag(h: Dictionary, rel: Vector2) -> void:
	if _act.is_empty():
		return
	match String(_act["kind"]):
		"garrot":
			_pull_band(rel.length())
		"desinf":
			if _on_arm(h):
				_rub_skin(rel.length())
		"ponction":
			_advance(rel.dot(_screen_dir()))
		"pansement":
			_dress_px(rel.length())


## Direction de l'aiguille à l'écran (vers le coude).
func _screen_dir() -> Vector2:
	if chosen.is_empty() or not zv.active:
		return Vector2.UP
	var p: Vector3 = chosen["p"]
	var a := zv.camera.unproject_position(p)
	var b := zv.camera.unproject_position(p + (chosen["dir"] as Vector3) * 0.05)
	var d := b - a
	return d.normalized() if d.length() > 2.0 else Vector2.UP


# ---------------------------------------------------------------- Gestes de chaque étape

## Garrot : on tire sur la bande, elle se resserre autour du bras.
func _pull_band(px: float) -> void:
	_pull = minf(PULL_PX, _pull + px)
	var k := _pull / PULL_PX
	_show_band(1.0 - k)
	game.call("set_progress", k, "Serrer le garrot…")
	if k >= 1.0:
		if _band:
			_band.queue_free()
			_band = null
		gear.place_tourniquet(side, _band_t)
		update_vis()
		ev("garrot", "Garrot posé au-dessus du coude")
		toast("Garrot serré : les veines se gonflent")
		Sfx.play("drap", Vector3.INF, -16.0, 1.6)
		_pull = 0.0
		_next()


func _show_band(slack: float) -> void:
	if _band:
		_band.queue_free()
	_band = gear.tourniquet_node(side, _band_t, slack, slack > 0.0)
	add_child(_band)
	gear_layer(_band)


## Désinfection : on frotte, l'antiseptique colore peu à peu la peau.
func _rub_skin(px: float) -> void:
	_rub = minf(RUB_PX, _rub + px)
	var k := _rub / RUB_PX
	if _stain:
		_stain.modulate.a = 0.25 + 0.75 * k
		var sc := 0.6 + 0.4 * k
		_stain.size = Vector3(0.08 * sc, 0.05, 0.13 * sc)
	game.call("set_progress", k, "Désinfection…")
	if k >= 1.0:
		g._disinfected[side] = true
		ev("desinfection", "Désinfection cutanée (antiseptique)")
		toast("Peau désinfectée : ne la touche plus qu'avec le cathéter")
		_rub = 0.0
		_next()


## Palpation d'une veine : bonne, fine ou qui roule.
func _palpate(vn: Array) -> void:
	var v: Dictionary = vn[1]
	var p: Vector3 = vn[2]
	var dir: Vector3 = vn[3]
	# Le cathéter monte vers le cœur (vers le coude)
	var toward := (Patient.arm_point(side, 0.0) - Patient.arm_point(side, 1.0)).normalized()
	if dir.dot(toward) < 0.0:
		dir = -dir
	chosen = {"vein": v, "p": p, "dir": dir}
	var txt: String = v["text"]
	if physio.sys < 85.0:
		txt += " Veines plates (choc) : pique avec soin."
	toast(txt, v["quality"] == "bonne")
	if _stain and p.distance_to(_stain_c) > 0.055:
		toast("Attention : cette veine est hors de la zone désinfectée", false)
		game.call("case_fault", "Ponction hors de la zone désinfectée", 2.0)
	ev("veine", "Veine choisie : %s" % String(v["id"]))
	_next()


func _new_catheter() -> void:
	if _cath:
		_cath.queue_free()
		_cath = null
	_gauge = "18" if inv.current_id() == "catheter18" or (not inv.has("catheter20") and inv.has("catheter18")) else "20"
	if not inv.has("catheter" + _gauge):
		return
	_cath = gear.catheter_node(_gauge)
	add_child(_cath)
	gear_layer(_cath)
	_phase = 0
	_depth = -0.006
	_adv = 0.0
	_wd = 0.0
	_flash = 0.0
	_flash_on = false
	(_cath.find_child("Reflux", true, false) as Node3D).scale = Vector3(1, 1, 0.001)
	(_cath.find_child("Reflux", true, false) as Node3D).visible = false
	(_cath.find_child("Obturateur", true, false) as Node3D).visible = false
	_pose_catheter()


## Ponction : une seule course de souris, dans le sens de l'aiguille (positif) ou à l'inverse.
func _advance(px: float) -> void:
	if _cath == null or chosen.is_empty():
		_new_catheter()
		if _cath == null:
			return
	match _phase:
		0, 1:
			_phase = 1
			_depth = clampf(_depth + px / PUSH_PX * 0.012, -0.006, 0.008)
			game.call("set_progress", clampf((_depth + 0.006) / (DEPTH_VEIN + 0.006), 0.0, 1.0), "L'aiguille entre…")
			if _depth >= DEPTH_VEIN:
				_in_vein()
		2:
			_adv = clampf(_adv + px / PUSH_PX, 0.0, 1.0)
			game.call("set_progress", _adv, "Avancer le cathéter…")
			if _adv >= 1.0:
				_phase = 3
				toast("Cathéter dans la veine : retire l'aiguille")
		3:
			_wd = clampf(_wd - px / PUSH_PX, 0.0, 1.0)
			game.call("set_progress", _wd, "Retirer l'aiguille…")
			if _wd >= 1.0:
				_placed()
	_pose_catheter()


func _in_vein() -> void:
	var q: String = chosen["vein"]["quality"]
	var ok := true
	if q != "bonne":
		ok = randf() > 0.6
	if not ok:
		_miss("la veine a roulé sous l'aiguille" if q == "roule" else "la veine, trop fine, a éclaté")
		return
	_phase = 2
	_flash_on = true
	(_cath.find_child("Reflux", true, false) as Node3D).visible = true
	toast("Reflux de sang dans la chambre : tu es dans la veine. Abaisse et avance le cathéter")
	ev("reflux", "Reflux de sang dans la chambre du cathéter")


func _miss(why: String) -> void:
	misses += 1
	g._iv_misses = misses
	toast("Pas de reflux : %s. Un hématome se forme ; choisis une autre veine" % why, false)
	ev("vvp_echec", "Ponction veineuse ratée (%s)" % why)
	_hematomas.append(_decal(_textures()["hematoma"], chosen["p"], chosen["dir"], Vector2(0.03, 0.035), 0.9))
	if misses == 2:
		game.call("case_fault", "Plusieurs ponctions veineuses ratées", 2.0)
	# Le cathéter est jeté
	inv.select_id("catheter" + _gauge)
	inv.use_current()
	if _cath:
		_cath.queue_free()
		_cath = null
	chosen = {}
	_act = {}
	_phase = 0
	game.call("set_progress", 0.0, "")
	step = STEPS.find("veine")
	_announce()


## Position du cathéter tenu : pointe qui entre sous un angle faible, puis cathéter avancé sur
## l'aiguille, puis aiguille retirée.
func _pose_catheter() -> void:
	if _cath == null:
		return
	var p: Vector3
	var d: Vector3
	if chosen.is_empty():
		_cath.visible = false
		return
	_cath.visible = true
	p = chosen["p"]
	d = chosen["dir"]
	var n := Patient.skin_normal(p.x, p.z)
	var L := PatientGear.cath_len(_gauge)
	var s1 := DEPTH_VEIN
	var c := _cath.find_child("Catheter", true, false) as Node3D
	var a := _cath.find_child("Aiguille", true, false) as Node3D
	var r := _cath.find_child("Reflux", true, false) as Node3D
	var rz0 := r.position.z if not r.has_meta("z0") else float(r.get_meta("z0"))
	r.set_meta("z0", rz0)
	if _phase <= 1:
		_cath.global_transform = PatientGear.iv_pose(p, d, n, ANGLE_IN, _depth)
		c.position.z = 0.0
	else:
		var u := _adv
		_cath.global_transform = PatientGear.iv_pose(p, d, n, lerpf(ANGLE_IN, ANGLE_FLAT, u), s1)
		_cath.global_position += n * PatientGear.IV_LIFT * u
		c.position.z = u * (L - 0.002 - s1)
	a.position.z = -_wd * (L + 0.04)
	r.position.z = rz0 - _wd * (L + 0.04)
	a.visible = _wd < 1.0
	r.visible = _flash_on and _wd < 1.0


## Cathéter en place, aiguille retirée (jetée au collecteur), bouchon vissé.
func _placed() -> void:
	(_cath.find_child("Aiguille", true, false) as Node3D).visible = false
	(_cath.find_child("Reflux", true, false) as Node3D).visible = false
	(_cath.find_child("Obturateur", true, false) as Node3D).visible = true
	var label: String = "Cathéter %sG (%s)" % [_gauge, "vert" if _gauge == "18" else "rose"]
	var node := _cath
	_cath = null
	remove_child(node)
	gear.place_iv(side, chosen["p"], chosen["dir"], _gauge, node)
	inv.select_id("catheter" + _gauge)
	inv.use_current()
	Sfx.play("plop", gear.iv["hub"], -10.0)
	ev("vvp", "Voie veineuse périphérique posée (%s)" % label)
	toast("Aiguille retirée et jetée au collecteur. Desserre le garrot !")
	_phase = 0
	_next()


func _release_tourniquet() -> void:
	if gear.tourniquet.is_empty():
		_next()
		return
	_loosen = 0.0
	toast("Garrot desserré")
	ev("garrot_retire", "Garrot desserré")
	Sfx.play("drap", Vector3.INF, -16.0, 1.3)
	var t := float(gear.tourniquet.get("t", 0.36))
	gear.remove_tourniquet()
	_band_t = t
	_show_band(0.15)
	update_vis()
	_next()


## Pansement transparent : on le lisse sur le cathéter.
func _dress_px(px: float) -> void:
	_dress = minf(DRESS_PX, _dress + px)
	var k := _dress / DRESS_PX
	if _dress_node:
		gear.dressing_progress(_dress_node, k)
	game.call("set_progress", k, "Coller le pansement…")
	if k >= 1.0:
		gear.add_dressing(_dress_node)
		_dress_node = null
		_dress = 0.0
		ev("pansement", "Pansement transparent posé sur le cathéter")
		toast("Pansement collé : le cathéter est bien fixé")
		_next()


## Tubulure de la poche (sur la potence) jusqu'au cathéter.
func connect_perfusion() -> void:
	if not gear.has_iv():
		toast("Il n'a pas de voie veineuse", false)
		return
	if not gear.tourniquet.is_empty():
		game.call("case_fault", "Perfusion branchée avec le garrot encore serré", 4.0)
		toast("Le garrot est encore serré : desserre-le d'abord", false)
		return
	inv.select_id("perfuseur")
	gear.connect_line()
	inv.use_current()
	physio.give("nacl", 500.0, "PERF")
	game.call("drug_given", "nacl", 500.0, "PERF")
	ev("perfusion", "Perfusion de NaCl 0,9 % 500 mL en débit libre")
	Sfx.play("clic", gear.iv["hub"], -10.0)
	line_or_injection()


## La perfusion est branchée ou un produit est injecté : la pose est terminée.
func line_or_injection() -> void:
	if active and STEPS[step] == "branchement":
		_next()


# ---------------------------------------------------------------- Seringue (injection)

## Seringue posée là où l'on injecte : sur le bouchon du cathéter (IV, sans aiguille) ou plantée
## dans le muscle (IM) ; le piston descend pendant l'injection.
func show_syringe(p: Vector3, route: String) -> void:
	hide_syringe()
	_syringe = gear.syringe_node()
	add_child(_syringe)
	gear_layer(_syringe)
	var needle := _syringe.find_child("Aiguille", true, false) as Node3D
	needle.visible = route == "IM"
	var axis: Vector3
	var at: Vector3
	if route == "IV" and gear.has_iv():
		# Dans l'axe du site d'injection (dessus du cathéter), un peu incliné vers le soignant
		var up: Vector3 = gear.iv["port_up"]
		axis = -(up + Vector3(0, 0, 0.35 if side == "L" else -0.35)).normalized()
		at = gear.iv["port"]
	else:
		var n := Patient.skin_normal(p.x, p.z)
		axis = -n
		at = p + n * 0.012
	var ref := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var x := ref.cross(axis).normalized()
	_syringe.global_transform = Transform3D(Basis(x, axis.cross(x), axis), at)
	syringe_progress(0.0)


func syringe_progress(k: float) -> void:
	if _syringe == null:
		return
	var pis := _syringe.find_child("Piston", true, false) as Node3D
	var liq := _syringe.find_child("Liquide", true, false) as Node3D
	if not liq.has_meta("z0"):
		liq.set_meta("z0", liq.position.z)
	# Seringue préparée à moitié (5 mL), vidée pendant l'injection
	var fill := 0.5 * (1.0 - k)
	pis.position.z = (1.0 - fill) * 0.06
	liq.scale = Vector3(1, 1, maxf(fill, 0.001))
	liq.visible = fill > 0.01


func hide_syringe() -> void:
	if _syringe:
		_syringe.queue_free()
		_syringe = null


# ---------------------------------------------------------------- Boucle

func tick(delta: float, h: Dictionary) -> void:
	_tick_vis(delta)
	if _loosen >= 0.0:
		_loosen = minf(1.0, _loosen + delta * 2.5)
		if _band:
			_show_band(0.15 + _loosen * 0.85)
		if _loosen >= 1.0:
			_loosen = -1.0
			if _band:
				_band.queue_free()
				_band = null
	if _flash_on and _cath:
		_flash = minf(1.0, _flash + delta * 0.9)
		var r := _cath.find_child("Reflux", true, false) as Node3D
		r.scale = Vector3(1, 1, maxf(0.001, _flash))
	if not active:
		_ring.visible = false
		return
	var id := inv.current_id()
	if active and step != _auto_selected:
		_auto_selected = step
		_select_needed()
	# Repère sous la souris : veine palpable
	_ring.visible = false
	if STEPS[step] == "veine" and not h.is_empty() and zv.active:
		var vn := vein_near(h["pos"], side)
		if float(vn[0]) < 0.007:
			var q: Vector3 = vn[2]
			var n := Patient.skin_normal(q.x, q.z)
			_ring.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), q + n * 0.0015)
			_ring.visible = true
	# Aperçu du garrot sous la souris (bande lâche) avant de serrer
	if STEPS[step] == "garrot" and _act.is_empty() and id == "garrot" and zv.active:
		if _on_arm(h) and arm_t(h["pos"]) < ELBOW_T - 0.03:
			var t := clampf(arm_t(h["pos"]), 0.2, ELBOW_T - 0.06)
			if absf(t - _band_t) > 0.01 or _band == null:
				_band_t = t
				_show_band(1.0 - _pull / PULL_PX)
		elif _band and _pull <= 0.0:
			_band.queue_free()
			_band = null
	if _act.is_empty():
		return
	match String(_act["kind"]):
		"palpe":
			if not zv.mouse_left:
				_act = {}
				return
			_act["t"] = float(_act["t"]) + delta
			game.call("set_progress", float(_act["t"]) / PALPATE_S, "Palpation de la veine…")
			if float(_act["t"]) >= PALPATE_S:
				var vn2: Array = _act["vn"]
				_act = {}
				game.call("set_progress", 0.0, "")
				_palpate(vn2)
