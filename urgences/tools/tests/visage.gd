extends Node3D
## Scène de test : gros plan d'un personnage (éclairage studio) pour juger peau, yeux, cheveux.
var p: Personnage

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.65)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-30, 35, 0); l.light_energy = 1.6; l.shadow_enabled = true; add_child(l)
	var l2 := OmniLight3D.new(); l2.position = Vector3(-1.0, 1.7, 1.2); l2.light_energy = 0.8; l2.omni_range = 4; add_child(l2)
	p = Personnage.new()
	p.modele = OS.get_environment("MODELE") if OS.get_environment("MODELE") != "" else "patient_gerard"
	p.animation_initiale = "debout"
	add_child(p)

func poses_capture() -> Array:
	var h := 1.62 if p.modele != "infirmiere_claire" else 1.52
	return [
		{"nom": "visage_" + p.modele, "position": Vector3(0.12, h, 0.55), "cible": Vector3(0, h - 0.02, 0), "fov": 30.0},
		{"nom": "pied_" + p.modele, "position": Vector3(0.6, 1.2, 2.6), "cible": Vector3(0, 0.9, 0), "fov": 45.0},
	]
