class_name Moniteur
extends Node3D
## Moniteur multiparamétrique 3D : le modèle + un SubViewport qui dessine l'écran.
## L'écran n'est redessiné qu'à 30 Hz et seulement s'il est à l'écran (notifieur de visibilité).

const FREQUENCE := 30.0

var ecran: EcranMoniteur
var vue: SubViewport
var _visible_ecran := true
var _accu := 0.0
var _lumiere: OmniLight3D
var _son_bip: AudioStreamPlayer3D
var _son_alarme: AudioStreamPlayer3D
var _alarme := ""
var _t_alarme := 0.0


func _ready() -> void:
	var modele := Bibliotheque.meuble("moniteur")
	add_child(modele)
	vue = SubViewport.new()
	vue.size = Vector2i(640, 440)
	vue.disable_3d = true
	vue.transparent_bg = false
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vue)
	ecran = EcranMoniteur.new()
	ecran.size = Vector2(vue.size)
	vue.add_child(ecran)
	# Matériau d'écran : émissif, texture = rendu du SubViewport.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.0, 0.0, 0.0)
	m.emission_enabled = true
	m.emission_texture = vue.get_texture()
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.12
	m.metallic_specular = 0.6
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat and mat.resource_name == "ecran_moniteur":
				mi.set_surface_override_material(s, m)
	# Lueur de l'écran sur l'entourage.
	_lumiere = OmniLight3D.new()
	_lumiere.position = Vector3(0, 0.02, 0.25)
	_lumiere.light_color = Color(0.4, 0.9, 0.6)
	_lumiere.light_energy = 0.0
	_lumiere.omni_range = 1.2
	add_child(_lumiere)
	var notif := VisibleOnScreenNotifier3D.new()
	notif.aabb = AABB(Vector3(-0.2, -0.15, -0.1), Vector3(0.4, 0.3, 0.2))
	notif.screen_entered.connect(func(): _visible_ecran = true)
	notif.screen_exited.connect(func(): _visible_ecran = false)
	add_child(notif)
	# Sons : bip à chaque QRS (plus grave quand la SpO2 baisse, comme les vrais scopes) et alarmes.
	_son_bip = Sons.lecteur_3d(self, "bip_scope", -14.0, 10.0)
	_son_alarme = Sons.lecteur_3d(self, "alarme_moyenne", -8.0, 18.0)
	ecran.battement.connect(_bip)


func connecter(c: Constantes) -> void:
	ecran.constantes = c


func brancher(oui: bool) -> void:
	ecran.branche = oui
	_lumiere.light_energy = 0.06 if oui else 0.0
	if not oui:
		_regler_alarme("")


func _bip() -> void:
	var c := ecran.constantes
	_son_bip.pitch_scale = clampf(1.0 - (100.0 - c.spo2) * 0.012, 0.7, 1.0)
	_son_bip.play()


## Niveau d'alarme selon les constantes : « haute » (arrêt, TV), « moyenne » (constante hors limites).
func niveau_alarme() -> String:
	var c := ecran.constantes
	if c == null or not ecran.branche:
		return ""
	if c.rythme in ["fv", "tv", "asystolie"]:
		return "haute"
	if c.spo2 < 90.0 or c.fc > 130.0 or c.fc < 45.0 or c.tas < 85.0 or c.tas > 200.0:
		return "moyenne"
	return ""


func _regler_alarme(niveau: String) -> void:
	if niveau == _alarme:
		return
	_alarme = niveau
	_son_alarme.stop()
	if niveau != "":
		_son_alarme.stream = Sons.flux("alarme_" + niveau)
		_son_alarme.volume_db = -4.0 if niveau == "haute" else -9.0
		_son_alarme.play()


func _process(delta: float) -> void:
	var _t_prof := Profileur.debut()
	_accu += delta
	_t_alarme -= delta
	if _t_alarme <= 0.0:
		_t_alarme = 0.5
		_regler_alarme(niveau_alarme())
	if _accu < 1.0 / FREQUENCE:
		Profileur.fin("moniteurs", _t_prof)
		return
	ecran.avancer(_accu)
	_accu = 0.0
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _visible_ecran else SubViewport.UPDATE_DISABLED
	Profileur.fin("moniteurs", _t_prof)
