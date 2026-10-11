class_name EcranMoniteur
extends Control
## Écran de moniteur multiparamétrique (style scope de réanimation) dessiné en 2D dans un
## SubViewport puis plaqué sur l'écran 3D. Tracés à balayage (ECG, pléthysmographie,
## respiration) et valeurs numériques. Mise à jour à 30 Hz seulement, et en pause quand
## l'écran n'est pas visible.

const VERT := Color(0.25, 1.0, 0.35)
const CYAN := Color(0.2, 0.9, 1.0)
const JAUNE := Color(1.0, 0.92, 0.25)
const BLANC := Color(0.95, 0.95, 0.95)
const ROUGE := Color(1.0, 0.25, 0.2)
const VITESSE_BALAYAGE := 0.25   # fraction de largeur par seconde (25 mm/s sur ~10 cm)

var constantes: Constantes
var branche := false          # électrodes et capteurs posés
var brassard := false         # dernière PNI affichée
var police: Font

var _n := 360                 # échantillons par tracé
var _ecg := PackedFloat32Array()
var _pleth := PackedFloat32Array()
var _resp := PackedFloat32Array()
var _curseur := 0.0
var _phase_coeur := 0.0
var _phase_resp := 0.0
var _rr := 0.8
var _accu := 0.0
var _fib := 0.0
var _bip := 0.0


func _ready() -> void:
	_ecg.resize(_n)
	_pleth.resize(_n)
	_resp.resize(_n)
	police = load("res://assets/fonts/Inter.ttf")


## Avance la simulation des tracés (appelé par le moniteur 3D à 30 Hz).
func avancer(delta: float) -> void:
	if constantes == null:
		return
	var c := constantes
	var pas := VITESSE_BALAYAGE * delta * _n
	var debut := int(_curseur)
	_curseur += pas
	var fin := int(_curseur)
	for i in range(debut, fin):
		var dt := delta / maxf(fin - debut, 1)
		_avancer_phases(dt)
		var k := i % _n
		if branche:
			_ecg[k] = _echantillon_ecg()
			_pleth[k] = _echantillon_pleth()
			_resp[k] = sin(_phase_resp * TAU) * 0.5
		else:
			_ecg[k] = 0.0
			_pleth[k] = 0.0
			_resp[k] = 0.0
	_curseur = fmod(_curseur, float(_n))
	_bip = maxf(_bip - delta, 0.0)
	queue_redraw()


func _avancer_phases(dt: float) -> void:
	var c := constantes
	var fc := maxf(c.fc, 1.0)
	if c.rythme == "fa":
		# Fibrillation auriculaire : intervalles RR irréguliers.
		_phase_coeur += dt / _rr
		if _phase_coeur >= 1.0:
			_phase_coeur -= 1.0
			_rr = 60.0 / fc * randf_range(0.65, 1.35)
	else:
		_rr = 60.0 / fc
		var avant := _phase_coeur
		_phase_coeur = fmod(_phase_coeur + dt / _rr, 1.0)
		if _phase_coeur < avant:
			_bip = 0.08
	_phase_resp = fmod(_phase_resp + dt * c.fr / 60.0, 1.0)
	_fib += dt


func _echantillon_ecg() -> float:
	var c := constantes
	var p := _phase_coeur
	match c.rythme:
		"fv":
			return sin(_fib * 31.0) * 0.35 + sin(_fib * 19.0 + 1.3) * 0.25 + randf_range(-0.05, 0.05)
		"asystolie":
			return randf_range(-0.01, 0.01)
		"tv":
			return sin(p * TAU) * 0.9 * (1.0 if fmod(p, 1.0) < 0.6 else 0.7)
	var v := 0.0
	# Onde P (absente en FA, remplacée par une trémulation).
	if c.rythme == "fa":
		v += sin(_fib * 45.0) * 0.03 + sin(_fib * 37.0) * 0.02
	else:
		v += _bosse(p, 0.10, 0.025, 0.12)
	# Complexe QRS.
	v += _bosse(p, 0.215, 0.006, -0.12)
	v += _bosse(p, 0.235, 0.008, 1.0)
	v += _bosse(p, 0.255, 0.007, -0.25)
	# Segment ST (sus-décalage éventuel) et onde T.
	if p > 0.26 and p < 0.42:
		v += c.sus_st * smoothstep(0.26, 0.29, p) * (1.0 - smoothstep(0.38, 0.42, p))
	v += _bosse(p, 0.42, 0.045, 0.28 + c.sus_st * 0.6)
	return v + randf_range(-0.012, 0.012)


func _echantillon_pleth() -> float:
	var p := fmod(_phase_coeur + 0.75, 1.0)  # retard pouls / ECG
	var v := _bosse(p, 0.18, 0.07, 1.0) + _bosse(p, 0.42, 0.06, 0.28)
	return v * clampf((constantes.spo2 - 60.0) / 35.0, 0.2, 1.0) - 0.5


static func _bosse(x: float, centre: float, largeur: float, hauteur: float) -> float:
	var d := (x - centre) / largeur
	return hauteur * exp(-d * d)


# ---------------------------------------------------------------------------------------------
func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.015, 0.02, 0.025))
	var zone_courbes := t.x * 0.70
	# Bandeau supérieur.
	draw_rect(Rect2(0, 0, t.x, 26), Color(0.08, 0.12, 0.18))
	_texte(Vector2(10, 19), "Box 3  —  Adulte", 15, BLANC)
	_texte(Vector2(t.x - 110, 19), Time.get_time_string_from_system().substr(0, 5), 15, BLANC)
	if constantes == null:
		return
	var c := constantes
	if not branche:
		_texte(Vector2(20, t.y * 0.5), "Pas de patient connecté", 22, Color(0.6, 0.6, 0.6))
		return
	# Tracés.
	var lignes := [
		[_ecg, VERT, "II", 0.30, 0.75],
		[_pleth, CYAN, "Pleth", 0.55, 0.55],
		[_resp, JAUNE, "Resp", 0.78, 0.35],
	]
	for l in lignes:
		var y0: float = t.y * l[3]
		var amp: float = t.y * 0.11 * l[4] / 0.75
		_texte(Vector2(8, y0 - amp - 6), l[2], 13, l[1])
		_trace(l[0], l[1], y0, amp, zone_courbes)
	# Barre d'effacement du balayage.
	var xc := _curseur / _n * zone_courbes
	draw_rect(Rect2(xc, 28, 10, t.y - 28), Color(0.015, 0.02, 0.025))
	# Valeurs numériques.
	var x := zone_courbes + 10
	draw_line(Vector2(zone_courbes, 28), Vector2(zone_courbes, t.y), Color(0.2, 0.25, 0.3), 1.0)
	_valeur(Vector2(x, 32), "FC", str(c.valeur("fc")), "bpm", VERT, c.fc > 120 or c.fc < 45)
	_valeur(Vector2(x, 32 + t.y * 0.24), "SpO₂", str(c.valeur("spo2")), "%", CYAN, c.spo2 < 92)
	_valeur(Vector2(x, 32 + t.y * 0.48), "FR", str(c.valeur("fr")), "/min", JAUNE, c.fr > 25 or c.fr < 8)
	var pni := "-?-/-?-"
	if c.mesures.has("ta"):
		pni = c.mesures["ta"]["valeur"]
	_texte(Vector2(x, 32 + t.y * 0.72 + 14), "PNI  mmHg", 13, BLANC)
	_texte(Vector2(x, 32 + t.y * 0.72 + 44), pni, 28, BLANC)
	if _bip > 0.0:
		draw_circle(Vector2(t.x - 18, 46), 6, VERT)


func _trace(buf: PackedFloat32Array, coul: Color, y0: float, amp: float, largeur: float) -> void:
	var pts := PackedVector2Array()
	pts.resize(_n)
	for i in _n:
		pts[i] = Vector2(i * largeur / (_n - 1), y0 - buf[i] * amp)
	draw_polyline(pts, coul, 2.0, true)


func _valeur(p: Vector2, nom: String, v: String, unite: String, coul: Color, alarme: bool) -> void:
	var cc := ROUGE if (alarme and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0) else coul
	_texte(p + Vector2(0, 14), nom, 13, cc)
	_texte(p + Vector2(size.x * 0.17, 14), unite, 11, cc)
	_texte(p + Vector2(0, 58), v, 44, cc)


func _texte(p: Vector2, s: String, taille: int, coul: Color) -> void:
	draw_string(police, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, coul)
