class_name OpPericardiocentese
extends Operation
## Péricardiocentèse échoguidée d'une tamponnade (plaie au couteau du thorax). Le sang accumulé dans
## le péricarde comprime le cœur : tension effondrée et pincée, veines du cou gonflées, bruits du
## cœur assourdis, microvoltage et alternance électrique au scope.
##   1. Échographie : sonde sous la pointe du sternum, faisceau vers l'épaule gauche ; l'image (calculée
##      sur le vrai volume anatomique) montre le cœur qui bat et « nage » dans le liquide noir.
##   2. Désinfection de la région sous-xiphoïdienne.
##   3. Ponction : aiguille dans l'angle entre l'appendice xiphoïde et le rebord costal gauche, à
##      30-50° de la peau, vers l'épaule gauche, en aspirant : le sang revient quand la pointe entre dans le
##      péricarde (l'aiguille est visible à l'échographie). Plus loin, c'est le cœur : extrasystoles.
##   4. Aspiration de 20 mL : l'épanchement diminue à l'image, la tension remonte.
##   5. On laisse le cathéter souple, raccordé à un robinet (drainage, nouvelle aspiration si besoin).

var echo: EchoView
var cart: Node3D
var probe_spot := Vector3.ZERO  ## fenêtre sous-xiphoïdienne (sur la peau)
var probe_axis := Vector3.DOWN  ## faisceau idéal (vers le cœur)
var entry := Vector3.ZERO  ## point de ponction
var axis := Vector3.DOWN  ## trajet de l'aiguille
var fluid_depth := 0.06  ## distance jusqu'au liquide le long du trajet
var heart_depth := 0.075  ## distance jusqu'au myocarde
var effusion := 1.0
var catheter: Node3D
var _echo_shown := false
var skin_angle := 35.0  ## angle entre l'aiguille et la peau (degrés)
var _touch_ms := 0


func _init() -> void:
	id = "pericardiocentese"
	name = "Péricardiocentèse"
	tagline = "Tamponnade : vider le sang autour du cœur, sous échographie."
	pose = "dos"
	player_spawn = Vector3(-0.2, 0.0, 0.68)
	player_look = Vector3(-0.07, 1.02, 0.02)
	tray_pos = Vector3(-0.62, 0.0, 0.64)
	patient_line = "Sofiane K., 28 ans — coup de couteau au thorax"
	urgency = "URGENCE VITALE"
	intro_title = "Salle de déchocage"
	intro_text = "Un coup de couteau à gauche du sternum il y a vingt minutes. La plaie saigne peu, mais il est gris, couvert de sueur, les veines du cou gonflées ; on entend mal le cœur. La tension s'effondre et se pince malgré le remplissage.\n\nLe sang s'accumule dans le péricarde et comprime le cœur : c'est une tamponnade. Confirme-la à l'échographie, puis retire du sang à l'aiguille sous la pointe du sternum. Vingt millilitres suffisent pour qu'il reprenne des couleurs ; le chirurgien opérera ensuite."
	imaging_tex = ""
	imaging_text = "Échographie au lit (FAST) : épanchement autour du cœur. À confirmer toi-même à la sonde.\n\n•  triade de Beck : tension basse, veines du cou gonflées, bruits du cœur assourdis\n•  tension pincée : 76 / 60\n•  scope : microvoltage, alternance électrique\n•  pas de pneumothorax"
	scan_text = "ÉCHOGRAPHIE FAST\nÉpanchement péricardique\nabondant, cœur comprimé"
	header = "DÉCHOCAGE  ·  PÉRICARDIOCENTÈSE  ·  SOUS-XIPHOÏDIENNE"
	summary = "Le sang retiré libère le cœur : la tension et le pouls se normalisent. Le cathéter reste en place jusqu'au bloc, où la plaie du cœur sera réparée."
	breath_rate = 30.0
	vitals = {"hr": 128.0, "spo2": 93.0, "sys": 76, "dia": 60, "temp": 36.1}
	catalog = [
		["sonde", "Sonde d'échographie (gel)", "proc:sonde", 0.0, 0.0],
		["mikulicz", "Pince à badigeon (chlorhexidine)", "pince_mikulicz", 0.0, 0.0],
		["cathlon", "Cathéter 16G long sur seringue de 20 mL", "proc:cathlon", 0.0, 0.0],
	]


func configure_patient(p: Patient) -> void:
	p.init_lung(0.0)  # pas de pneumothorax : poumons bien gonflés
	# Pas de champ (urgence) : le thorax et le haut de l'abdomen sont découverts
	p.WINDOW_MIN = Vector2(-0.3, -0.2)
	p.WINDOW_MAX = Vector2(0.16, 0.2)
	var xi := Patient.lm("xiphoid_tip") if not Patient.landmarks.is_empty() else Vector3(-0.078, 1.058, 0.0)
	var site := Vector2(xi.x - 0.016, 0.012)
	# Peau détaillée (badigeon) autour de la région sous-xiphoïdienne
	p.PATCH_MIN = site - Vector2(0.11, 0.11)
	p.PATCH_SIZE = Vector2(0.22, 0.22)
	p.INC_A = site - Vector2(0.0, 0.003)
	p.INC_B = site + Vector2(0.0, 0.003)
	p.paint_r = Vector2(0.045, 0.04)
	p.wound_w = 0.004
	p.WOUND_DEPTH = 0.01
	p.breathe_amp = 0.005
	p.hole_limit = 0.003
	p.antiseptic = "chlorhexidine"
	# Plaie au couteau : 4e espace, à 3 cm à gauche du sternum, légèrement oblique
	p.stab = Vector4(-0.022, 0.05, 0.5, 0.019)
	p.props_options = {"collar": false}


func build_extras() -> void:
	patient.heart_rate = vitals["hr"]
	var xi := Patient.lm("xiphoid_tip")
	entry = patient.on_skin(Vector3(xi.x - 0.022, 0, 0.012))
	echo = EchoView.new()
	echo.name = "Echographe"
	root.add_child(echo)
	echo.effusion = effusion
	_choose_path()
	# La sonde, juste à droite de l'aiguille, regarde le cœur
	probe_spot = patient.on_skin(Vector3(xi.x - 0.03, 0, -0.022))
	probe_axis = (Patient.HEART_C - probe_spot).normalized()
	# Angle réel entre l'aiguille et la peau (arrondi à 5°) pour la consigne
	var n := Patient.skin_normal(entry.x, entry.z)
	skin_angle = snappedf(90.0 - rad_to_deg(axis.angle_to(-n)), 5.0)
	if OS.get_cmdline_user_args().has("--debug"):
		print("PERICARDE entrée=%s axe=%s liquide=%.4f cœur=%.4f sonde=%s angle peau=%.0f°" % [entry, axis, fluid_depth, heart_depth, probe_spot, skin_angle])
	var needle := instrument("cathlon")
	if needle and needle.model is CathlonModel:
		(needle.model as CathlonModel).draws_blood = true
	cart = _build_cart()
	root.add_child(cart)


func on_start() -> void:
	monitor.target_rate = vitals["hr"]
	monitor.target_spo2 = vitals["spo2"]
	monitor.ecg_voltage = 0.5
	monitor.alternans = 0.35


func define_steps() -> void:
	steps = [
		{"id": "echo", "kind": "probe", "list": "Échographie", "inst": "sonde",
			"title": "Regarde le cœur à l'échographie",
			"text": "Pose la sonde juste sous la pointe du sternum, à plat, le faisceau vers l'épaule gauche (clic pour appuyer). Sur l'image : le foie en haut, puis le cœur. Le liquide autour est noir : c'est le sang qui le comprime.",
			"label": "Sous la pointe du sternum", "ring": 1.6,
			"target": func() -> Vector3: return probe_spot,
			"axis": probe_axis, "judge": _judge_probe, "hold_s": 1.5,
			"done": _probe_done, "done_msg": "Tamponnade confirmée : l'aide garde la sonde en place"},
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte sous le sternum",
			"text": "Chlorhexidine alcoolique sous la pointe du sternum et sur le rebord costal gauche, là où l'aiguille entrera.",
			"label": "Désinfecte ici", "ring": 1.8,
			"area": func() -> Vector3: return entry,
			"done_msg": "Désinfecté"},
		{"id": "ponction", "kind": "needle", "list": "Ponction", "inst": "cathlon",
			"title": "Pique vers l'épaule gauche",
			"text": "Dans l'angle entre la pointe du sternum et le rebord des côtes à gauche, à %d° de la peau, vers la gauche et vers le haut (direction de l'épaule gauche). Maintiens le clic : l'aiguille avance en aspirant. Suis la pointe brillante à l'échographie ; dès que du sang revient dans la seringue, arrête-toi." % int(skin_angle),
			"label": "Pique ici", "ring": 0.8,
			"target": func() -> Vector3: return patient.live(entry),
			"axis": axis, "flash_depth": fluid_depth + 0.0025, "max_depth": heart_depth - 0.0015, "flash": "blood",
			"aspiration_max": 0.08, "speed": 0.012,
			"deep_msg": "Tu touches le cœur : extrasystoles ! Recule de quelques millimètres.",
			"on_too_deep": _touch_heart, "on_flash": _blood_flash,
			"done_msg": "Du sang qui ne coagule pas : tu es dans le péricarde"},
		{"id": "aspiration", "kind": "aspirate", "list": "Aspiration", "inst": "cathlon",
			"title": "Aspire le sang",
			"text": "Ne bouge plus l'aiguille. Maintiens le clic pour tirer le piston : vingt millilitres suffisent. Regarde l'épanchement diminuer à l'image et la tension remonter.",
			"label": "", "ring": 0.6,
			"target": func() -> Vector3: return patient.live(entry),
			"axis": axis, "max_depth": heart_depth - 0.0015,
			"in_liquid": _in_liquid, "seconds": 6.0, "ml": 20.0, "what": "Sang retiré",
			"hold_depth": fluid_depth + 0.004,
			"on_fill": _on_fill, "done": _aspirated,
			"done_msg": "20 mL retirés : la tension remonte, le cœur bat librement"},
		{"id": "catheter", "kind": "withdraw", "list": "Laisser le cathéter", "inst": "cathlon",
			"title": "Laisse le cathéter en place",
			"text": "Retire l'aiguille (molette vers le haut, ou R) en laissant le cathéter souple dans le péricarde : on pourra ré-aspirer si le sang se reforme, en attendant le bloc.",
			"label": "Cathéter", "ring": 0.6,
			"target": func() -> Vector3: return patient.live(entry),
			"axis": axis, "max_depth": heart_depth - 0.0015,
			"deep_msg": "Tu touches le cœur !",
			"done": _leave_catheter, "done_msg": "Cathéter en place : il reprend des couleurs"},
	]


## Trajet de l'aiguille : vers la gauche (épaule gauche) et vers le haut, en passant sous le rebord
## costal ; parmi les directions classiques, celle qui traverse le plus de liquide avant le
## myocarde sans toucher d'os ni de poumon (mesuré sur le volume anatomique).
func _choose_path() -> void:
	var best := -1.0
	for pitch in [30.0, 35.0, 40.0, 45.0, 50.0, 55.0]:
		for yaw in [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0]:
			var pr := deg_to_rad(pitch)
			var yr := deg_to_rad(yaw)
			var a := Vector3(cos(pr) * cos(yr), -sin(pr), cos(pr) * sin(yr))
			var fluid := -1.0
			var heart := -1.0
			var ok := true
			for n in range(1, 125):
				var d := n * 0.001
				var smp := EchoView.sample(entry + a * d)
				var lab: int = smp[0]
				var sd: float = smp[1]
				if fluid < 0.0 and (lab == 5 or lab == 4):
					ok = false
					break
				if fluid < 0.0 and lab != 0 and sd > 0.0 and sd < EchoView.fluid_thickness(effusion):
					fluid = d
				if sd <= 0.0:
					heart = d
					break
			if not ok or fluid < 0.0 or heart < 0.0:
				continue
			# Plus de liquide traversé, angle proche de 45°, plutôt vers l'épaule gauche
			var score: float = (heart - fluid) - absf(pitch - 45.0) * 0.0002 + yaw * 0.00008
			if score > best:
				best = score
				axis = a
				fluid_depth = fluid
				heart_depth = heart
	if best < 0.0:
		# Repli : droit vers le cœur
		axis = (Patient.HEART_C - entry).normalized()
		var dd := EchoView.depths_along(entry, axis, effusion)
		fluid_depth = dd.x if dd.x > 0.0 else 0.07
		heart_depth = dd.y if dd.y > 0.0 else fluid_depth + 0.012


## Pose de la sonde : sur la peau, sous la pointe du sternum, faisceau vers le cœur.
func _judge_probe(face: Vector3, beam: Vector3, on_skin: bool) -> Dictionary:
	if not on_skin:
		return {"q": 0.0, "msg": "Pose la sonde sur la peau, sous la pointe du sternum"}
	var d := Vector2(face.x - probe_spot.x, face.z - probe_spot.z).length()
	if d > 0.045:
		if face.x > probe_spot.x + 0.03:
			return {"q": 0.1, "msg": "Trop haut : sur le sternum et les côtes, les ultrasons ne passent pas. Descends sous la pointe du sternum"}
		return {"q": 0.1, "msg": "Fenêtre sous-xiphoïdienne : juste sous la pointe du sternum"}
	var ang := rad_to_deg(beam.angle_to((Patient.HEART_C - face).normalized()))
	if ang > 24.0:
		return {"q": 0.4, "msg": "Couche la sonde et vise l'épaule gauche : le cœur est derrière le foie"}
	return {"q": 1.0, "msg": "Épanchement péricardique : le cœur nage dans le liquide"}


## L'aide garde la sonde sur la fenêtre (un peu à droite de l'aiguille).
func _probe_done(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("sonde")
	var face := probe_spot + Vector3.UP * 0.001
	var b := Basis.looking_at(-probe_axis, Vector3(1, 0, 0) if absf(probe_axis.x) < 0.9 else Vector3.UP)
	# Repère de l'instrument : pointe (face de la sonde) vers +Z
	var xf := Transform3D(b, face) * Transform3D(Basis.IDENTITY, -inst.tip_local)
	if hand and hand.held == inst:
		hand.release_parked()
	park(inst, xf, instant)


## Le sang revient dans la seringue.
func _blood_flash() -> void:
	var inst := instrument("cathlon")
	if inst and inst.model is CathlonModel:
		(inst.model as CathlonModel).set_aspiration(0.1)
	Sfx.play("succes", entry, -10.0, 0.9)


## La pointe touche le myocarde : extrasystoles.
func _touch_heart() -> void:
	monitor.ectopic(4)


func _in_liquid(tip: Vector3) -> bool:
	var s := EchoView.sample(tip)
	var sd: float = s[1]
	if sd <= 0.0:
		if Time.get_ticks_msec() - _touch_ms > 2500:
			_touch_ms = Time.get_ticks_msec()
			monitor.ectopic(2)
		return false
	return sd < EchoView.fluid_thickness(1.0) + 2.5


## Le sang retiré libère le cœur, peu à peu.
func _on_fill(f: float) -> void:
	effusion = lerpf(1.0, 0.3, f)
	var inst := instrument("cathlon")
	if inst and inst.model is CathlonModel:
		(inst.model as CathlonModel).set_aspiration(0.1 + 0.9 * f)
	monitor.sys = int(lerpf(76.0, 108.0, f))
	monitor.dia = int(lerpf(60.0, 66.0, f))
	monitor.target_rate = lerpf(128.0, 102.0, f)
	monitor.target_spo2 = lerpf(93.0, 97.0, f)
	monitor.ecg_voltage = lerpf(0.5, 0.85, f)
	monitor.alternans = lerpf(0.35, 0.0, f)
	patient.heart_rate = monitor.target_rate


func _aspirated(_hand: SurgeonHand, instant: bool) -> void:
	if instant:
		_on_fill(1.0)


func _leave_catheter(hand: SurgeonHand, _instant: bool) -> void:
	var inst := instrument("cathlon")
	var model := inst.model
	if model.has_method("detach_catheter") and model.get("catheter") != null:
		var c: Node3D = model.call("detach_catheter")
		root.add_child(c)
		var b := Basis.looking_at(-axis, Vector3.UP if absf(axis.y) < 0.95 else Vector3.FORWARD)
		c.global_transform = Transform3D(b, entry - axis * 0.03)
		catheter = c
	_on_fill(1.0)
	if hand and hand.held == inst:
		hand.put_back()


func process(_delta: float) -> void:
	if echo == null:
		return
	var probe := instrument("sonde")
	var held := false
	for h in proc.hands:
		if h.held == probe:
			held = true
	var showing := held or probe.parked
	if showing:
		var face := probe.tip_global()
		var beam := probe.global_transform.basis.z.normalized()
		var on_skin := probe.parked or probe.tip_depth > -0.004
		echo.contact = move_toward(echo.contact, 1.0 if on_skin else 0.0, 0.08)
		# Pendant la ponction, l'aide oriente la coupe sur le trajet de l'aiguille
		var needle := instrument("cathlon")
		var seg := []
		var needle_in := false
		for h in proc.hands:
			if h.held == needle and needle.tip_depth > 0.0:
				needle_in = true
		if needle_in:
			var m := needle.model.global_transform
			var a := m * Vector3(0, 0, CathlonModel.BARREL_Z1 + 0.01)
			var b := m * Vector3(0, 0, CathlonModel.TIP_Z)
			echo.set_needle(a, b, true)
			seg = [a, b]
		else:
			echo.set_needle(Vector3.ZERO, Vector3.ZERO, false)
		echo.set_probe(face, beam, Vector3.ZERO, seg)
	echo.on = showing
	echo.effusion = effusion
	echo.heart_rate = patient.heart_rate
	if showing != _echo_shown:
		_echo_shown = showing
		for ui in proc.uis:
			if ui.has_method("show_echo"):
				ui.call("show_echo", echo.texture if showing else null, "ÉCHOGRAPHIE  ·  SOUS-XIPHOÏDIENNE")


## Échographe sur son chariot, l'écran tourné vers l'opérateur.
func _build_cart() -> Node3D:
	var c := Node3D.new()
	c.name = "ChariotEcho"
	var shell := MeshUtil.mat(Color(0.86, 0.87, 0.88), 0.45)
	var dark := MeshUtil.mat(Color(0.12, 0.13, 0.15), 0.5)
	MeshUtil.box_instance(c, Vector3(0.46, 0.07, 0.42), Vector3(0, 0.11, 0), shell, "Socle")
	for k in 4:
		var w := MeshUtil.cylinder_instance(c, 0.035, 0.03, Vector3((k % 2 - 0.5) * 0.38, 0.035, (k / 2 - 0.5) * 0.34), dark, "Roue")
		w.rotation_degrees.z = 90
	MeshUtil.box_instance(c, Vector3(0.12, 0.72, 0.1), Vector3(0, 0.5, -0.04), shell, "Colonne")
	var console := MeshUtil.box_instance(c, Vector3(0.5, 0.05, 0.34), Vector3(0, 0.9, 0.02), shell, "Console")
	console.rotation_degrees.x = 12
	var keys := MeshUtil.box_instance(c, Vector3(0.36, 0.008, 0.16), Vector3(0, 0.93, 0.06), dark, "Clavier")
	keys.rotation_degrees.x = 12
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.018
	bs.height = 0.036
	ball.mesh = bs
	ball.material_override = MeshUtil.mat(Color(0.2, 0.35, 0.55), 0.2)
	ball.position = Vector3(0.1, 0.94, 0.1)
	c.add_child(ball)
	# Support de sonde et flacon de gel
	MeshUtil.cylinder_instance(c, 0.025, 0.07, Vector3(-0.27, 0.9, 0.06), dark, "SupportSonde")
	MeshUtil.cylinder_instance(c, 0.022, 0.11, Vector3(-0.27, 0.97, -0.06), MeshUtil.mat(Color(0.3, 0.55, 0.85), 0.3), "Gel")
	# Écran
	MeshUtil.box_instance(c, Vector3(0.05, 0.22, 0.05), Vector3(0, 1.03, -0.1), dark, "Bras")
	var frame := MeshUtil.box_instance(c, Vector3(0.46, 0.34, 0.035), Vector3(0, 1.3, -0.1), dark, "Cadre")
	frame.rotation_degrees.x = -8
	var scr := MeshInstance3D.new()
	scr.name = "Ecran"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.42, 0.315)
	scr.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = echo.texture
	scr.material_override = sm
	scr.position = Vector3(0, 1.3, -0.081)
	scr.rotation_degrees.x = -8
	c.add_child(scr)
	# Face à l'opérateur, à sa droite
	c.position = Vector3(0.3, 0.0, 0.66)
	var to_player := Vector3(player_spawn.x - c.position.x, 0.0, player_spawn.z + 0.2 - c.position.z)
	c.rotation.y = atan2(to_player.x, to_player.z)
	return c
