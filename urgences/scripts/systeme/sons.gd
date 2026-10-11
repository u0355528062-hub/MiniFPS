extends Node
## Gestionnaire audio (autoload « Sons ») : crée les bus (Ambiance, Effets, Voix → Master),
## charge les sons de assets/audio/ à la demande et les joue en 2D (interface) ou en 3D
## (positionnés dans le service). Un petit réservoir de lecteurs 2D évite d'en créer à chaque son.

const DOSSIER := "res://assets/audio/"
const BUS := ["Ambiance", "Effets", "Voix"]

var _flux := {}
var _reservoir: Array[AudioStreamPlayer] = []
var _ambiance: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nom in BUS:
		if AudioServer.get_bus_index(nom) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, nom)
			AudioServer.set_bus_send(i, "Master")
	# Légère réverbération de pièce carrelée sur les effets et les voix.
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.35
	rev.damping = 0.6
	rev.wet = 0.12
	rev.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Effets"), rev)
	Reglages.appliquer_volumes()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Effets"
		add_child(p)
		_reservoir.append(p)


func flux(nom: String) -> AudioStream:
	if not _flux.has(nom):
		var chemin := DOSSIER + nom + ".wav"
		# Le bouclage des ambiances, sirènes et alarmes est réglé dans leurs fichiers .import.
		_flux[nom] = load(chemin) if ResourceLoader.exists(chemin) else null
	return _flux[nom]


## Son d'interface ou non spatialisé.
func jouer(nom: String, volume_db := 0.0, bus := "Effets", hauteur := 1.0) -> void:
	var f := flux(nom)
	if f == null:
		return
	var p: AudioStreamPlayer = null
	for r in _reservoir:
		if not r.playing:
			p = r
			break
	if p == null:
		p = _reservoir[0]
	p.stream = f
	p.volume_db = volume_db
	p.bus = bus
	p.pitch_scale = hauteur
	p.play()


## Lecteur 3D attaché à `parent` (réutilisable : le renvoie, à libérer par le parent).
func lecteur_3d(parent: Node3D, nom: String, volume_db := 0.0, distance := 14.0, bus := "Effets") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if nom != "":
		p.stream = flux(nom)
	p.volume_db = volume_db
	p.max_distance = distance
	p.unit_size = 3.0
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -12.0
	parent.add_child(p)
	return p


## Son 3D ponctuel à une position du monde (lecteur libéré à la fin).
func jouer_3d(nom: String, position: Vector3, volume_db := 0.0, distance := 14.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D or scene is Node):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = flux(nom)
	if p.stream == null:
		p.free()
		return
	p.volume_db = volume_db
	p.max_distance = distance
	p.unit_size = 3.0
	p.bus = "Effets"
	scene.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


## Fichier de voix d'une réplique : empreinte MD5 du texte (même calcul dans gen_voix.py).
func chemin_voix(texte: String, homme: bool) -> String:
	return "%svoix/%s_%s.ogg" % [DOSSIER, "h" if homme else "f", texte.md5_text().substr(0, 12)]


## Fait dire `texte` à `parent` (voix 3D à hauteur de bouche). Renvoie la durée (0 si absente).
func voix(parent: Node3D, texte: String, homme: bool, hauteur := 1.0) -> float:
	var chemin := chemin_voix(texte, homme)
	if not ResourceLoader.exists(chemin):
		return 0.0
	var f: AudioStream = load(chemin)
	var p: AudioStreamPlayer3D = parent.get_meta("voix") if parent.has_meta("voix") else null
	if p == null or not is_instance_valid(p):
		p = lecteur_3d(parent, "", 0.0, 16.0, "Voix")
		p.position.y = 1.5
		parent.set_meta("voix", p)
	p.stream = f
	p.pitch_scale = hauteur
	p.play()
	return f.get_length() / hauteur


func demarrer_ambiance() -> void:
	if _ambiance == null:
		_ambiance = AudioStreamPlayer.new()
		_ambiance.bus = "Ambiance"
		_ambiance.volume_db = -8.0
		add_child(_ambiance)
	_ambiance.stream = flux("ambiance_hopital")
	if not _ambiance.playing:
		_ambiance.play()


func arreter_ambiance() -> void:
	if _ambiance:
		_ambiance.stop()
