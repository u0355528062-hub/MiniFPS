class_name MenuPause
extends CanvasLayer
## Menu pause (Échap) avec les réglages graphiques complets : préréglages Bas / Moyen /
## Élevé / Ultra, mise à l'échelle FSR 2, anticrénelage, ombres, effets d'écran, GI…

signal quitter_demande

var fond: ColorRect
var panneau: PanelContainer
var pages: TabContainer
var _construit := false
var _maj := false
var _controles := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func basculer() -> void:
	if not _construit:
		_construire()
	visible = not visible
	get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_rafraichir()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		basculer()
		get_viewport().set_input_as_handled()


func _construire() -> void:
	_construit = true
	fond = ColorRect.new()
	fond.color = Color(0.02, 0.05, 0.07, 0.55)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	panneau = PanelContainer.new()
	panneau.theme = ThemeHopital.theme()
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.custom_minimum_size = Vector2(760, 640)
	panneau.position = Vector2(-380, -320)
	add_child(panneau)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panneau.add_child(vb)
	var tete := HBoxContainer.new()
	tete.add_child(ThemeHopital.titre("Pause", 30))
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(esp)
	var rep := Button.new()
	rep.text = "Reprendre"
	rep.pressed.connect(basculer)
	tete.add_child(rep)
	var q := Button.new()
	q.text = "Quitter"
	q.pressed.connect(func(): quitter_demande.emit())
	tete.add_child(q)
	vb.add_child(tete)
	pages = TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(pages)
	pages.add_child(_page_graphismes())
	pages.add_child(_page_jeu())


func _page_graphismes() -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Graphismes"
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("separation", 8)
	sc.add_child(g)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	presets.add_child(ThemeHopital.texte_doux("Préréglage :", 17))
	for p in ["bas", "moyen", "eleve", "ultra"]:
		var b := Button.new()
		b.text = Reglages.NOMS_PRESETS[p]
		b.toggle_mode = true
		b.pressed.connect(func():
			Reglages.choisir_preset(p)
			_rafraichir())
		presets.add_child(b)
		_controles["preset_" + p] = b
	g.add_child(presets)
	g.add_child(HSeparator.new())
	_curseur(g, "echelle", "Résolution de rendu", 0.5, 1.0, 0.01, func(v): return "%d %%" % int(v * 100))
	_choix(g, "mise_echelle", "Mise à l'échelle", [["fsr2", "AMD FSR 2.2 (qualité)"], ["fsr1", "AMD FSR 1.0"], ["bilineaire", "Bilinéaire"]])
	_choix(g, "anticrenelage", "Anticrénelage", [["taa", "TAA (temporel)"], ["fxaa", "FXAA"], ["msaa2", "MSAA 2x"], ["msaa4", "MSAA 4x"], ["aucun", "Aucun"]])
	_choix(g, "ombres", "Qualité des ombres", [[0, "Basse"], [1, "Moyenne"], [2, "Haute"], [3, "Ultra"]])
	_choix(g, "gi", "Illumination globale", [["voxelgi", "VoxelGI (intérieurs)"], ["sdfgi", "SDFGI"], ["aucune", "Aucune"]])
	_choix(g, "reflets", "Sondes de reflets", [[0, "Statiques"], [1, "Basses"], [2, "Hautes"], [3, "Ultra"]])
	for k in [["ssao", "Occlusion ambiante (SSAO)"], ["ssil", "Lumière indirecte d'écran (SSIL)"],
			["ssr", "Réflexions d'écran (SSR)"], ["brouillard", "Brume volumétrique"], ["bloom", "Halo lumineux (bloom)"],
			["profondeur_champ", "Profondeur de champ"], ["sss", "Diffusion sous-cutanée (peau)"]]:
		_case(g, k[0], k[1])
	_curseur(g, "detail_lod", "Seuil de niveau de détail", 0.5, 6.0, 0.25, func(v): return "%.2f px" % v)
	return sc


func _page_jeu() -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Jeu"
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("separation", 8)
	sc.add_child(g)
	_curseur(g, "fov", "Champ de vision", 60.0, 100.0, 1.0, func(v): return "%d°" % int(v))
	_curseur(g, "sensibilite", "Sensibilité de la souris", 0.0005, 0.006, 0.0001, func(v): return "%.1f" % (v * 1000.0))
	_curseur(g, "volume_general", "Volume général", 0.0, 1.0, 0.01, func(v): return "%d %%" % int(v * 100))
	_case(g, "vsync", "Synchronisation verticale")
	_choix(g, "fps_max", "Images par seconde max.", [[0, "Illimité"], [60, "60"], [120, "120"], [144, "144"]])
	_case(g, "afficher_fps", "Afficher le compteur de performances (F3)")
	return sc


func _ligne(g: Container, libelle: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = libelle
	l.custom_minimum_size = Vector2(300, 0)
	hb.add_child(l)
	g.add_child(hb)
	return hb


func _curseur(g: Container, cle: String, libelle: String, mini: float, maxi: float, pas: float, fmt: Callable) -> void:
	var hb := _ligne(g, libelle)
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Label.new()
	v.custom_minimum_size = Vector2(80, 0)
	s.value_changed.connect(func(x):
		v.text = fmt.call(x)
		if not _maj:
			Reglages.regler(cle, x))
	hb.add_child(s)
	hb.add_child(v)
	_controles[cle] = [s, v, fmt]


func _choix(g: Container, cle: String, libelle: String, options: Array) -> void:
	var hb := _ligne(g, libelle)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in options.size():
		o.add_item(options[i][1], i)
		o.set_item_metadata(i, options[i][0])
	o.item_selected.connect(func(i):
		if not _maj:
			Reglages.regler(cle, o.get_item_metadata(i))
			_rafraichir())
	hb.add_child(o)
	_controles[cle] = o


func _case(g: Container, cle: String, libelle: String) -> void:
	var c := CheckBox.new()
	c.text = libelle
	c.toggled.connect(func(b):
		if not _maj:
			Reglages.regler(cle, b)
			_rafraichir())
	g.add_child(c)
	_controles[cle] = c


func _rafraichir() -> void:
	_maj = true
	var tout := Reglages.graphismes.duplicate()
	tout.merge(Reglages.jeu)
	for cle in _controles:
		if cle.begins_with("preset_"):
			_controles[cle].button_pressed = Reglages.preset == cle.substr(7)
			continue
		var c = _controles[cle]
		var v = tout.get(cle)
		if c is Array:
			c[0].value = v
			c[1].text = c[2].call(v)
		elif c is OptionButton:
			for i in c.item_count:
				if c.get_item_metadata(i) == v:
					c.select(i)
		elif c is CheckBox:
			c.button_pressed = v
	_maj = false
