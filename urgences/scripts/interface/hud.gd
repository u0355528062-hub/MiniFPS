class_name Hud
extends CanvasLayer
## Interface de jeu : réticule, invite d'interaction, notifications, sous-titres, barre
## d'action, menu contextuel (actions sur le patient), dossier patient (Tab), compteur FPS.

signal action_choisie(id: String)
signal menu_ferme

var racine: Control
var invite: PanelContainer
var invite_texte: Label
var notifs: VBoxContainer
var sous_titre: PanelContainer
var sous_titre_texte: Label
var barre: PanelContainer
var barre_progres: ProgressBar
var barre_texte: Label
var menu: PanelContainer
var menu_liste: VBoxContainer
var menu_titre: Label
var dossier: PanelContainer
var dossier_contenu: VBoxContainer
var horloge: Label
var fps: Label
var _sous_titre_t := 0.0


func _ready() -> void:
	layer = 10
	racine = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.theme = ThemeHopital.theme()
	add_child(racine)
	# Réticule.
	var ret := Control.new()
	ret.set_anchors_preset(Control.PRESET_CENTER)
	ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ret.draw.connect(func():
		ret.draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.35))
		ret.draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.9)))
	racine.add_child(ret)
	# Invite d'interaction (sous le réticule).
	invite = PanelContainer.new()
	invite_texte = Label.new()
	invite_texte.add_theme_font_size_override("font_size", 18)
	invite.add_child(invite_texte)
	invite.set_anchors_preset(Control.PRESET_CENTER)
	invite.position = Vector2(-160, 40)
	invite.visible = false
	racine.add_child(invite)
	# Horloge et lieu.
	horloge = Label.new()
	horloge.position = Vector2(24, 18)
	horloge.add_theme_font_size_override("font_size", 18)
	horloge.add_theme_color_override("font_color", Color.WHITE)
	horloge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	horloge.add_theme_constant_override("shadow_offset_y", 2)
	racine.add_child(horloge)
	# Notifications (en haut à droite).
	notifs = VBoxContainer.new()
	notifs.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notifs.position = Vector2(-430, 20)
	notifs.custom_minimum_size = Vector2(410, 0)
	notifs.add_theme_constant_override("separation", 8)
	racine.add_child(notifs)
	# Sous-titres (paroles du patient).
	sous_titre = PanelContainer.new()
	sous_titre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sous_titre.position = Vector2(-420, -150)
	sous_titre.custom_minimum_size = Vector2(840, 0)
	sous_titre_texte = Label.new()
	sous_titre_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sous_titre_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sous_titre_texte.add_theme_font_size_override("font_size", 21)
	sous_titre.add_child(sous_titre_texte)
	sous_titre.visible = false
	racine.add_child(sous_titre)
	# Barre de progression d'une action.
	barre = PanelContainer.new()
	barre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barre.position = Vector2(-220, -260)
	barre.custom_minimum_size = Vector2(440, 0)
	var vb := VBoxContainer.new()
	barre_texte = Label.new()
	barre_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barre_progres = ProgressBar.new()
	barre_progres.custom_minimum_size = Vector2(0, 14)
	barre_progres.show_percentage = false
	vb.add_child(barre_texte)
	vb.add_child(barre_progres)
	barre.add_child(vb)
	barre.visible = false
	racine.add_child(barre)
	# Menu contextuel.
	menu = PanelContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-230, -260)
	menu.custom_minimum_size = Vector2(460, 0)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	menu_titre = ThemeHopital.titre("", 22)
	mv.add_child(menu_titre)
	mv.add_child(HSeparator.new())
	menu_liste = VBoxContainer.new()
	menu_liste.add_theme_constant_override("separation", 6)
	mv.add_child(menu_liste)
	menu.add_child(mv)
	menu.visible = false
	racine.add_child(menu)
	# Dossier patient (à droite).
	dossier = PanelContainer.new()
	dossier.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	dossier.offset_left = -470
	dossier.offset_right = -20
	dossier.offset_top = 90
	dossier.offset_bottom = -90
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_contenu = VBoxContainer.new()
	dossier_contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_contenu.add_theme_constant_override("separation", 6)
	sc.add_child(dossier_contenu)
	dossier.add_child(sc)
	dossier.visible = false
	racine.add_child(dossier)
	# Compteur de performances.
	fps = Label.new()
	fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fps.position = Vector2(16, -120)
	fps.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	fps.add_theme_color_override("font_shadow_color", Color.BLACK)
	fps.add_theme_font_size_override("font_size", 15)
	fps.visible = Reglages.jeu["afficher_fps"]
	racine.add_child(fps)


func _process(delta: float) -> void:
	if sous_titre.visible:
		_sous_titre_t -= delta
		if _sous_titre_t <= 0.0:
			sous_titre.visible = false
	if fps.visible:
		fps.text = "%d i/s  (%.1f ms)\nappels de dessin : %d\nobjets : %d\nprimitives : %d k" % [
			Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fps"):
		fps.visible = not fps.visible
		Reglages.regler("afficher_fps", fps.visible)


func montrer_invite(texte: String) -> void:
	invite.visible = texte != ""
	invite_texte.text = texte
	invite.reset_size()
	invite.position = Vector2(-invite.size.x * 0.5, 40)


func notifier(texte: String, couleur := ThemeHopital.ACCENT, duree := 5.0) -> void:
	var p := PanelContainer.new()
	var hb := HBoxContainer.new()
	var pastille := ColorRect.new()
	pastille.color = couleur
	pastille.custom_minimum_size = Vector2(6, 0)
	hb.add_child(pastille)
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	l.add_theme_font_size_override("font_size", 17)
	hb.add_child(l)
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	notifs.add_child(p)
	var tw := create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duree)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func dire(qui: String, texte: String) -> void:
	sous_titre_texte.text = "%s : « %s »" % [qui, texte]
	sous_titre.visible = true
	_sous_titre_t = clampf(texte.length() * 0.07, 3.0, 9.0)
	sous_titre.reset_size()
	sous_titre.position.x = -sous_titre.size.x * 0.5


func progression(texte: String, valeur: float) -> void:
	barre.visible = valeur >= 0.0 and valeur < 1.0
	barre_texte.text = texte
	barre_progres.value = valeur * 100.0


## Ouvre un menu de boutons : options = [[id, libellé], …] (un id vide = séparateur/texte).
func ouvrir_menu(titre: String, options: Array) -> void:
	menu_titre.text = titre
	for c in menu_liste.get_children():
		c.queue_free()
	for o in options:
		if o[0] == "":
			menu_liste.add_child(ThemeHopital.texte_doux(o[1], 15))
			continue
		var b := Button.new()
		b.text = o[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if o.size() > 2:
			var st: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
			st.bg_color = o[2]
			b.add_theme_stylebox_override("normal", st)
			var st2: StyleBoxFlat = st.duplicate()
			st2.bg_color = (o[2] as Color).lightened(0.15)
			b.add_theme_stylebox_override("hover", st2)
		var id: String = o[0]
		b.pressed.connect(func(): action_choisie.emit(id))
		menu_liste.add_child(b)
	menu.visible = true
	menu.reset_size()
	menu.position = Vector2(-menu.size.x * 0.5, -menu.size.y * 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fermer_menu() -> void:
	if menu.visible:
		menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		menu_ferme.emit()


## Remplit le dossier patient (fiche d'accueil + constantes mesurées + tri).
func remplir_dossier(p: PatientJeu) -> void:
	for c in dossier_contenu.get_children():
		c.queue_free()
	var d := p.dossier
	dossier_contenu.add_child(ThemeHopital.titre("Dossier de soins — urgences", 22))
	dossier_contenu.add_child(ThemeHopital.texte_doux("IEP %s · admis à %s" % [d.get("iep", "—"), d.get("arrivee", "—")], 14))
	dossier_contenu.add_child(HSeparator.new())
	dossier_contenu.add_child(ThemeHopital.titre(p.titre(), 20))
	dossier_contenu.add_child(ThemeHopital.texte_doux("Motif : " + d.get("motif", ""), 16))
	for cle in ["antecedents", "traitement", "allergies"]:
		if p.dossier.has("connu_" + cle):
			var l := ThemeHopital.texte_doux({"antecedents": "Antécédents", "traitement": "Traitement", "allergies": "Allergies"}[cle] + " : " + d.get(cle, ""), 15)
			dossier_contenu.add_child(l)
	dossier_contenu.add_child(HSeparator.new())
	dossier_contenu.add_child(ThemeHopital.titre("Constantes", 19))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	for k in ["fc", "ta", "spo2", "fr", "temperature", "glycemie", "eva"]:
		var nom := ThemeHopital.texte_doux(Constantes.NOMS[k], 15)
		nom.autowrap_mode = TextServer.AUTOWRAP_OFF
		g.add_child(nom)
		var v := Label.new()
		var h := Label.new()
		h.add_theme_font_size_override("font_size", 13)
		h.add_theme_color_override("font_color", ThemeHopital.TEXTE_DOUX)
		if p.constantes.mesures.has(k):
			v.text = Constantes.texte(k, p.constantes.mesures[k]["valeur"])
			h.text = p.constantes.mesures[k]["heure"]
		else:
			v.text = "—"
		v.add_theme_font_size_override("font_size", 17)
		g.add_child(v)
		g.add_child(h)
	dossier_contenu.add_child(g)
	dossier_contenu.add_child(HSeparator.new())
	var t := ThemeHopital.titre("Tri IOA : " + (str(p.tri) if p.tri > 0 else "non attribué"), 19)
	if p.tri > 0:
		t.add_theme_color_override("font_color", ThemeHopital.TRI[p.tri].darkened(0.2))
	dossier_contenu.add_child(t)
	if d.has("notes"):
		for n in d["notes"]:
			dossier_contenu.add_child(ThemeHopital.texte_doux("• " + n, 15))
