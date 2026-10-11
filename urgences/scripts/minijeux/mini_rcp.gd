class_name MiniRCP
extends Control
## Réanimation cardio-pulmonaire : massage cardiaque en rythme (100 à 120/min, Espace ou clic),
## analyse du rythme toutes les 2 minutes (accélérées), charge et choc du défibrillateur en cas
## de rythme choquable, adrénaline toutes les 4 minutes, amiodarone après le 3e choc.
## Le retour d'une circulation spontanée (RACS) dépend de la qualité du massage et des chocs.

signal termine(succes: bool, qualite: float)

const DUREE_CYCLE := 20.0          # secondes réelles par cycle de 2 minutes (accéléré)
const CYCLES_MAX := 6

var constantes: Constantes
var ecran: EcranMoniteur
var _t_cycle := 0.0
var _cycle := 0
var _compressions: Array[float] = []
var _bonnes := 0
var _total := 0
var _phase := "massage"            # massage, analyse, charge, choc, fini
var _charge := 0.0
var _chocs := 0
var _adrenaline := 0
var _amiodarone := false
var _dernier_adre := -999.0
var _message := ""
var _t_msg := 0.0
var _rng := RandomNumberGenerator.new()
var _flash := 0.0
var police: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Plein écran quel que soit le parent (CanvasLayer, fenêtre…).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	police = ThemeHopital.theme().default_font
	_rng.randomize()
	var vue := SubViewportContainer.new()
	vue.stretch = true
	vue.position = Vector2(60, 140)
	vue.size = Vector2(760, 520)
	var sv := SubViewport.new()
	sv.size = Vector2i(760, 520)
	sv.disable_3d = true
	vue.add_child(sv)
	ecran = EcranMoniteur.new()
	ecran.size = Vector2(760, 520)
	ecran.constantes = constantes
	ecran.branche = true
	sv.add_child(ecran)
	add_child(vue)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dire("Arrêt cardiaque ! Commencez le massage : Espace (ou clic) à 100-120/min.")


func _dire(t: String) -> void:
	_message = t
	_t_msg = 4.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_compression()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_SPACE:
			_compression()
		KEY_C:
			if _phase == "charge":
				_charge = 0.001
				_dire("Charge en cours… 200 J")
		KEY_S:
			if _phase == "choc":
				_choquer()
		KEY_A:
			_adrenaline_injecter()
		KEY_M:
			if _chocs >= 3 and not _amiodarone:
				_amiodarone = true
				_dire("Amiodarone 300 mg IV.")
	get_viewport().set_input_as_handled()


func _compression() -> void:
	if _phase != "massage":
		return
	var t := Time.get_ticks_msec() / 1000.0
	_compressions.append(t)
	if _compressions.size() > 6:
		_compressions.pop_front()
	_total += 1
	var f := frequence()
	if f >= 100.0 and f <= 120.0:
		_bonnes += 1
	_flash = 0.12


func frequence() -> float:
	if _compressions.size() < 3:
		return 0.0
	var dt := (_compressions[-1] - _compressions[0]) / (_compressions.size() - 1)
	return 60.0 / maxf(dt, 0.05)


func qualite() -> float:
	return float(_bonnes) / maxf(_total, 1.0)


func _adrenaline_injecter() -> void:
	var t := _cycle * 120.0 + _t_cycle / DUREE_CYCLE * 120.0
	if t - _dernier_adre < 180.0:
		_dire("Trop tôt : adrénaline toutes les 3 à 5 minutes.")
		return
	_dernier_adre = t
	_adrenaline += 1
	_dire("Adrénaline 1 mg IV.")


func _choquer() -> void:
	_chocs += 1
	_flash = 0.5
	_dire("Choc délivré ! Reprenez immédiatement le massage.")
	# Probabilité de RACS : qualité du massage, nombre de chocs, médicaments.
	var p := 0.12 + 0.35 * qualite() + 0.05 * _chocs + (0.1 if _adrenaline > 0 else 0.0) + (0.12 if _amiodarone else 0.0)
	if _rng.randf() < p:
		_racs()
		return
	_phase = "massage"
	_t_cycle = 0.0


func _racs() -> void:
	_phase = "fini"
	constantes.rythme = "sinusal"
	constantes.fc = 104.0
	constantes.cibles["fc"] = 98.0
	constantes.tas = 92.0
	constantes.cibles["tas"] = 105.0
	constantes.spo2 = 90.0
	constantes.cibles["spo2"] = 95.0
	_dire("RACS ! Pouls retrouvé. Orientez le patient en réanimation.")
	get_tree().create_timer(3.0).timeout.connect(func(): _fin(true))


func _fin(ok: bool) -> void:
	termine.emit(ok, qualite())
	queue_free()


func _process(delta: float) -> void:
	_t_msg -= delta
	_flash = maxf(_flash - delta, 0.0)
	if _charge > 0.0:
		_charge += delta / 2.5
		if _charge >= 1.0:
			_charge = 0.0
			_phase = "choc"
			_dire("Chargé ! Écartez-vous… Appuyez sur S pour CHOQUER.")
	if _phase == "massage":
		_t_cycle += delta
		if _t_cycle >= DUREE_CYCLE:
			_cycle += 1
			if _cycle >= CYCLES_MAX:
				_phase = "fini"
				_dire("Échec de la réanimation après %d cycles." % CYCLES_MAX)
				get_tree().create_timer(3.0).timeout.connect(func(): _fin(false))
			else:
				_phase = "charge"
				_dire("Analyse : fibrillation ventriculaire, rythme CHOQUABLE. Appuyez sur C pour charger.")
	ecran.avancer(delta)
	queue_redraw()


func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.03, 0.04, 0.05, 0.92))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, t), Color(1, 1, 1, _flash * 0.6))
	draw_string(police, Vector2(60, 70), "Réanimation cardio-pulmonaire", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
	draw_string(police, Vector2(60, 112), "Cycle %d / %d · chocs %d · adrénaline %d mg%s" % [_cycle + 1, CYCLES_MAX, _chocs,
		_adrenaline, " · amiodarone" if _amiodarone else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.8, 0.85))
	# Jauge de fréquence de massage.
	var x0 := 880.0
	var f := frequence()
	draw_string(police, Vector2(x0, 180), "Fréquence de massage", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var barre := Rect2(x0, 200, 520, 40)
	draw_rect(barre, Color(0.2, 0.22, 0.25))
	var a := barre.position.x + barre.size.x * (100.0 - 60.0) / 100.0
	var b := barre.position.x + barre.size.x * (120.0 - 60.0) / 100.0
	draw_rect(Rect2(a, barre.position.y, b - a, barre.size.y), Color(0.15, 0.6, 0.3))
	var xf := barre.position.x + barre.size.x * clampf((f - 60.0) / 100.0, 0.0, 1.0)
	draw_rect(Rect2(xf - 3, barre.position.y - 8, 6, barre.size.y + 16), Color.WHITE)
	draw_string(police, Vector2(x0, 290), "%d /min" % int(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 54,
		Color(0.4, 1.0, 0.5) if f >= 100.0 and f <= 120.0 else Color(1.0, 0.5, 0.4))
	draw_string(police, Vector2(x0, 340), "Qualité du massage : %d %%" % int(qualite() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	# Métronome (repère visuel à 110/min).
	var ph := fmod(Time.get_ticks_msec() / 1000.0 * 110.0 / 60.0, 1.0)
	draw_circle(Vector2(x0 + 470, 300), 18.0 + 10.0 * (1.0 - ph), Color(0.2, 0.8, 1.0, 1.0 - ph))
	# Cycle de 2 minutes.
	draw_string(police, Vector2(x0, 400), "Cycle de 2 min", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.8, 0.85))
	draw_rect(Rect2(x0, 412, 520, 14), Color(0.2, 0.22, 0.25))
	draw_rect(Rect2(x0, 412, 520 * clampf(_t_cycle / DUREE_CYCLE, 0, 1), 14), Color(0.9, 0.7, 0.2))
	if _charge > 0.0:
		draw_string(police, Vector2(x0, 470), "Charge : %d J" % int(200 * _charge), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.8, 0.2))
	# Commandes.
	var aide := ["Espace / clic : compression", "C : charger le défibrillateur", "S : choquer",
		"A : adrénaline 1 mg (toutes les 4 min)", "M : amiodarone (après le 3e choc)"]
	for i in aide.size():
		draw_string(police, Vector2(x0, 520 + i * 30), aide[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.75, 0.8, 0.85))
	if _t_msg > 0.0:
		draw_string(police, Vector2(60, t.y - 60), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.9, 0.5))
