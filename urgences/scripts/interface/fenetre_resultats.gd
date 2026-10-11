class_name FenetreResultats
extends PanelContainer
## Fenêtre d'affichage d'un résultat d'examen : tracé ECG 12 dérivations, cliché de radiologie
## avec compte rendu, tableau de biologie (valeurs anormales en rouge), ou texte (écho, scanner…).

signal fermee

var _contenu: VBoxContainer


func _ready() -> void:
	theme = ThemeHopital.theme()
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1200, 760)
	position = Vector2(-600, -380)
	_contenu = VBoxContainer.new()
	_contenu.add_theme_constant_override("separation", 10)
	add_child(_contenu)
	visible = false


func montrer(p: PatientJeu, ex: String) -> void:
	for c in _contenu.get_children():
		_contenu.remove_child(c)
		c.queue_free()
	var tete := HBoxContainer.new()
	tete.add_child(ThemeHopital.titre("%s — %s" % [Pathologies.EXAMENS[ex][0], p.titre()], 22))
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(esp)
	var f := Button.new()
	f.text = "Fermer"
	f.pressed.connect(fermer)
	tete.add_child(f)
	_contenu.add_child(tete)
	var e: Dictionary = p.examens[ex]
	var pid: String = p.patho.get("id", "")
	match ex:
		"ecg":
			var ecg := Ecg12.new()
			ecg.custom_minimum_size = Vector2(1160, 560)
			_contenu.add_child(ecg)
			ecg.configurer(p.constantes, Pathologies.ECG_ST.get(pid, {}))
		"radio":
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 16)
			var tr := TextureRect.new()
			tr.texture = load("res://assets/textures/radios/%s.png" % Pathologies.RADIO.get(pid, "thorax_normal"))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(560, 640)
			hb.add_child(tr)
			hb.add_child(_compte_rendu(e["resultat"]))
			_contenu.add_child(hb)
		"bio":
			var g := GridContainer.new()
			g.columns = 4
			g.add_theme_constant_override("h_separation", 40)
			g.add_theme_constant_override("v_separation", 6)
			for t in ["Analyse", "Résultat", "Unité", "Normes"]:
				var l := ThemeHopital.titre(t, 17)
				g.add_child(l)
			for ligne in Pathologies.bio(pid):
				var v: float = ligne[1]
				var anormal: bool = v < ligne[3] or v > ligne[4]
				g.add_child(ThemeHopital.texte_doux(ligne[0], 17))
				var lv := Label.new()
				lv.text = ("%.2f" % v if v < 10.0 else "%.1f" % v).replace(".", ",") + (" ▲" if v > ligne[4] else (" ▼" if v < ligne[3] else ""))
				lv.add_theme_color_override("font_color", ThemeHopital.ROUGE if anormal else ThemeHopital.TEXTE)
				lv.add_theme_font_size_override("font_size", 17)
				g.add_child(lv)
				g.add_child(ThemeHopital.texte_doux(ligne[2], 16))
				g.add_child(ThemeHopital.texte_doux(("%s – %s" % [str(ligne[3]), str(ligne[4])]).replace(".", ","), 16))
			_contenu.add_child(g)
			_contenu.add_child(HSeparator.new())
			_contenu.add_child(_compte_rendu(e["resultat"]))
		_:
			_contenu.add_child(_compte_rendu(e["resultat"]))
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Le contenu change de taille : recentrage après la mise en page.
	(func(): ThemeHopital.centrer(self)).call_deferred()


func _compte_rendu(texte: String) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ThemeHopital.titre("Compte rendu", 19))
	var l := ThemeHopital.texte_doux(texte, 18)
	l.custom_minimum_size = Vector2(500, 0)
	v.add_child(l)
	return v


func fermer() -> void:
	visible = false
	fermee.emit()
