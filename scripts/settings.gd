extends Node
## Réglages du joueur (enregistrés dans user://reglages.cfg) : graphismes, souris, son, aides.
## Chargé automatiquement au démarrage (autoload « Settings »).

signal changed

const PATH := "user://reglages.cfg"
const PRESETS := ["Bas", "Moyen", "Élevé", "Ultra"]

var quality := 2  ## 0 bas … 3 ultra
var render_scale := 1.0
var fov := 72.0
var sensitivity := 1.0
var invert_y := false
var volume := 0.8
var fullscreen := false
var vsync := true
var show_hints := true
var head_bob := true

var _env: Environment
var _viewport: Viewport


func _ready() -> void:
	_load()
	apply_window()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = cfg.get_value("graphismes", "qualite", quality)
	render_scale = cfg.get_value("graphismes", "echelle", render_scale)
	fov = cfg.get_value("jeu", "fov", fov)
	sensitivity = cfg.get_value("jeu", "sensibilite", sensitivity)
	invert_y = cfg.get_value("jeu", "inverser_y", invert_y)
	volume = cfg.get_value("son", "volume", volume)
	fullscreen = cfg.get_value("graphismes", "plein_ecran", fullscreen)
	vsync = cfg.get_value("graphismes", "vsync", vsync)
	show_hints = cfg.get_value("jeu", "aides", show_hints)
	head_bob = cfg.get_value("jeu", "balancement", head_bob)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphismes", "qualite", quality)
	cfg.set_value("graphismes", "echelle", render_scale)
	cfg.set_value("graphismes", "plein_ecran", fullscreen)
	cfg.set_value("graphismes", "vsync", vsync)
	cfg.set_value("jeu", "fov", fov)
	cfg.set_value("jeu", "sensibilite", sensitivity)
	cfg.set_value("jeu", "inverser_y", invert_y)
	cfg.set_value("jeu", "aides", show_hints)
	cfg.set_value("jeu", "balancement", head_bob)
	cfg.set_value("son", "volume", volume)
	cfg.save(PATH)


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


## Applique la qualité graphique à l'environnement et à la fenêtre du jeu.
func apply_graphics(env: Environment, vp: Viewport) -> void:
	_env = env
	_viewport = vp
	if env == null or vp == null:
		return
	var q := quality
	env.ssao_enabled = q >= 1
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.8
	env.ssao_detail = 0.5 if q < 3 else 1.0
	env.ssil_enabled = q >= 2
	env.ssil_radius = 1.5
	env.ssil_intensity = 0.8
	env.ssr_enabled = q >= 2
	env.ssr_max_steps = 48 if q < 3 else 96
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.12
	env.sdfgi_enabled = q >= 3
	env.volumetric_fog_enabled = q >= 2
	env.glow_enabled = true
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM if q < 3 else RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM if q < 3 else RenderingServer.ENV_SSIL_QUALITY_HIGH, true, 0.5, 4, 50, 300)
	RenderingServer.sub_surface_scattering_set_quality(RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_DISABLED if q == 0 else (RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_MEDIUM if q < 3 else RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_HIGH))
	RenderingServer.sub_surface_scattering_set_scale(0.004, 0.25)
	var sq: RenderingServer.ShadowQuality = [RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q]
	RenderingServer.directional_soft_shadow_filter_set_quality(sq)
	RenderingServer.positional_soft_shadow_filter_set_quality(sq)
	vp.positional_shadow_atlas_size = [2048, 4096, 4096, 8192][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 2 else Viewport.SCREEN_SPACE_AA_SMAA
	vp.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][q]
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X if q >= 2 else Viewport.ANISOTROPY_4X
	changed.emit()


func reapply() -> void:
	apply_window()
	apply_graphics(_env, _viewport)
	save()
