class_name Joueur
extends CharacterBody3D
## Soignant joué : déplacement à la première personne (ZQSD / WASD), course, accroupi,
## vue à la troisième personne (V), visée d'objets interactifs (rayon depuis la caméra).

signal cible_changee(cible: Node)
signal interaction(cible: Node)

const VITESSE := 1.9
const VITESSE_COURSE := 3.6
const ACCEL := 10.0
const HAUTEUR_YEUX := 1.66
const HAUTEUR_ACCROUPI := 1.05
const PORTEE := 2.4

@export var modele_corps := "medecin_karim"

var tete: Node3D
var camera: Camera3D
var bras_camera: SpringArm3D
var rayon: RayCast3D
var corps_visuel: Personnage
var cible: Node = null
var troisieme_personne := false
var controle := true          # faux quand un menu est ouvert
var _tangage := 0.0
var _hauteur := HAUTEUR_YEUX
var _balancement := 0.0
var _attributs: CameraAttributesPractical
var _mise_au_point := 3.0
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	cs.shape = capsule
	cs.position.y = 0.875
	add_child(cs)
	tete = Node3D.new()
	tete.name = "Tete"
	tete.position.y = HAUTEUR_YEUX
	# La tête (et la caméra) bougent dans _process (souris, balancement) : pas d'interpolation
	# physique pour elles, le corps (CharacterBody3D) reste interpolé.
	tete.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(tete)
	bras_camera = SpringArm3D.new()
	bras_camera.spring_length = 0.0
	bras_camera.margin = 0.15
	bras_camera.add_excluded_object(get_rid())
	tete.add_child(bras_camera)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.03
	camera.far = 200.0
	camera.fov = Reglages.jeu["fov"]
	_attributs = CameraAttributesPractical.new()
	camera.attributes = _attributs
	bras_camera.add_child(camera)
	camera.make_current()
	rayon = RayCast3D.new()
	rayon.target_position = Vector3(0, 0, -PORTEE)
	rayon.collide_with_areas = true
	rayon.add_exception(self)
	tete.add_child(rayon)
	# Corps visible seulement en vue à la troisième personne.
	corps_visuel = Personnage.new()
	corps_visuel.modele = modele_corps
	corps_visuel.animation_initiale = "debout"
	corps_visuel.rotation_degrees.y = 180.0  # le modèle regarde +Z, le joueur -Z
	add_child(corps_visuel)
	corps_visuel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Reglages.change.connect(func(): camera.fov = Reglages.jeu["fov"])


func _unhandled_input(event: InputEvent) -> void:
	if not controle:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Reglages.jeu["sensibilite"]
		rotate_y(-event.relative.x * s)
		_tangage = clampf(_tangage - event.relative.y * s, deg_to_rad(-85), deg_to_rad(85))
		tete.rotation.x = _tangage
	elif event.is_action_pressed("camera"):
		basculer_vue()
	elif event.is_action_pressed("interagir") and cible:
		interaction.emit(cible)


func basculer_vue() -> void:
	troisieme_personne = not troisieme_personne
	corps_visuel.visible = troisieme_personne
	bras_camera.spring_length = 2.2 if troisieme_personne else 0.0
	bras_camera.position = Vector3(0.45, 0.15, 0) if troisieme_personne else Vector3.ZERO


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if controle:
		var e := Input.get_vector("gauche", "droite", "avancer", "reculer")
		dir = (transform.basis * Vector3(e.x, 0, e.y))
		dir.y = 0
		dir = dir.normalized() * minf(e.length(), 1.0)
	var accroupi := controle and Input.is_action_pressed("accroupir")
	var v_max := VITESSE_COURSE if (controle and Input.is_action_pressed("courir") and not accroupi) else VITESSE
	if accroupi:
		v_max *= 0.5
	var horiz := Vector3(velocity.x, 0, velocity.z).lerp(dir * v_max, clampf(ACCEL * delta, 0, 1))
	velocity.x = horiz.x
	velocity.z = horiz.z
	if not is_on_floor():
		velocity.y -= _gravite * delta
	else:
		velocity.y = -0.1
	move_and_slide()


func _process(delta: float) -> void:
	var _t_prof := Profileur.debut()
	# Hauteur des yeux (accroupi) et léger balancement de marche.
	var cible_h := HAUTEUR_ACCROUPI if (controle and Input.is_action_pressed("accroupir")) else HAUTEUR_YEUX
	_hauteur = lerpf(_hauteur, cible_h, clampf(8.0 * delta, 0, 1))
	var v := Vector2(velocity.x, velocity.z).length()
	var pas_avant := int(_balancement / PI)
	_balancement += delta * v * 4.2
	# Un bruit de pas à chaque creux du balancement (deux par cycle).
	if int(_balancement / PI) != pas_avant and v > 0.4 and is_on_floor():
		Sons.jouer("pas_%d" % randi_range(0, 3), -16.0 + clampf(v - VITESSE, 0.0, 3.0) * 2.0, "Effets", randf_range(0.92, 1.06))
	var amp := 0.018 * clampf(v / VITESSE, 0.0, 1.5) * (0.0 if troisieme_personne else 1.0)
	tete.position.y = _hauteur + sin(_balancement) * amp
	tete.position.x = cos(_balancement * 0.5) * amp * 0.6
	# Animation du corps visible (troisième personne).
	if troisieme_personne and corps_visuel.lecteur:
		var anim := "marche" if v > 0.3 else "debout"
		if corps_visuel.lecteur.current_animation != anim:
			corps_visuel.jouer(anim, 0.3, clampf(v / 1.4, 0.7, 2.2) if anim == "marche" else 1.0)
	_viser()
	_profondeur_champ(delta)
	Profileur.fin("joueur", _t_prof)

## Profondeur de champ : quand on examine de près (moins de 1,6 m), l'arrière-plan se floute.
func _profondeur_champ(delta: float) -> void:
	var actif: bool = Reglages.graphismes.get("profondeur_champ", true) and not troisieme_personne
	var d := 99.0
	if actif and rayon.is_colliding():
		d = tete.global_position.distance_to(rayon.get_collision_point())
	_mise_au_point = lerpf(_mise_au_point, d, clampf(delta * 4.0, 0.0, 1.0))
	var proche := actif and _mise_au_point < 1.6
	_attributs.dof_blur_far_enabled = proche
	if proche:
		_attributs.dof_blur_far_distance = _mise_au_point + 0.5
		_attributs.dof_blur_far_transition = 1.2
		_attributs.dof_blur_amount = 0.06


func _viser() -> void:
	var nouvelle: Node = null
	if controle and rayon.is_colliding():
		var c := rayon.get_collider()
		var n: Node = c
		while n and not n.is_in_group("interactif"):
			n = n.get_parent()
		nouvelle = n
	if nouvelle != cible:
		cible = nouvelle
		cible_changee.emit(cible)
