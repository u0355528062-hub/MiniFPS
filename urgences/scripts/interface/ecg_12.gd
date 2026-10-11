class_name Ecg12
extends Control
## Tracé d'ECG 12 dérivations sur papier millimétré (25 mm/s, 10 mm/mV), disposition
## standard 4 × 3 + bande de rythme D2. Le tracé dépend du rythme (sinusal, FA, TV, FV),
## de la fréquence et d'un éventuel sus-décalage du segment ST dans certaines dérivations.

const DERIVATIONS := [["I", "aVR", "V1", "V4"], ["II", "aVL", "V2", "V5"], ["III", "aVF", "V3", "V6"]]
## Amplitude relative du QRS et de l'onde T par dérivation (approximation d'un axe normal).
const GAIN := {"I": 0.7, "II": 1.0, "III": 0.45, "aVR": -0.8, "aVL": 0.35, "aVF": 0.7,
	"V1": -0.6, "V2": -0.2, "V3": 0.5, "V4": 1.1, "V5": 1.0, "V6": 0.8}

var fc := 75.0
var rythme := "sinusal"
var st := {}                # dérivation -> mV (positif = sus-décalage, négatif = sous-décalage)
var px_mm := 4.0
var _graine := 1


func configurer(c: Constantes, sus_st: Dictionary) -> void:
	fc = c.fc
	rythme = c.rythme
	st = sus_st
	_graine = int(c.fc * 13.0)
	queue_redraw()


func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(1.0, 0.97, 0.96))
	# Quadrillage : petits carreaux 1 mm, gros carreaux 5 mm.
	var x := 0.0
	var i := 0
	while x < t.x:
		draw_line(Vector2(x, 0), Vector2(x, t.y), Color(0.96, 0.72, 0.72) if i % 5 == 0 else Color(0.99, 0.88, 0.88), 1.0)
		x += px_mm
		i += 1
	var y := 0.0
	i = 0
	while y < t.y:
		draw_line(Vector2(0, y), Vector2(t.x, y), Color(0.96, 0.72, 0.72) if i % 5 == 0 else Color(0.99, 0.88, 0.88), 1.0)
		y += px_mm
		i += 1
	var police := ThemeHopital.theme().default_font
	var rng := RandomNumberGenerator.new()
	rng.seed = _graine
	var battements := _battements(rng, 10.0)
	var h_ligne := t.y / 4.0
	var l_col := t.x / 4.0
	for r in 3:
		for c in 4:
			var nom: String = DERIVATIONS[r][c]
			var y0 := h_ligne * (r + 0.55)
			var t0 := c * 2.5
			_tracer(nom, Vector2(c * l_col, y0), l_col, t0, 2.5, battements, rng)
			draw_string(police, Vector2(c * l_col + 6, y0 - h_ligne * 0.32), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.15, 0.2))
	# Bande de rythme D2 sur 10 s.
	_tracer("II", Vector2(0, h_ligne * 3.55), t.x, 0.0, 10.0, battements, rng)
	draw_string(police, Vector2(6, h_ligne * 3.2), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.15, 0.2))
	draw_string(police, Vector2(t.x - 330, t.y - 8), "25 mm/s   10 mm/mV   FC %d/min" % int(fc), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 0.2, 0.2))


## Instants des complexes QRS sur la durée totale.
func _battements(rng: RandomNumberGenerator, duree: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	var tt := rng.randf() * 0.4
	var rr := 60.0 / maxf(fc, 20.0)
	while tt < duree + 1.0:
		b.append(tt)
		tt += rr * (rng.randf_range(0.65, 1.35) if rythme == "fa" else rng.randf_range(0.98, 1.02))
	return b


func _tracer(nom: String, origine: Vector2, largeur: float, t0: float, duree: float, battements: PackedFloat32Array,
		rng: RandomNumberGenerator) -> void:
	var g: float = GAIN.get(nom, 1.0)
	var n := int(largeur / 1.5)
	var pts := PackedVector2Array()
	pts.resize(n)
	var mm_mv := 10.0 * px_mm
	for k in n:
		var tps := t0 + duree * k / (n - 1)
		var v := 0.0
		match rythme:
			"fv":
				v = sin(tps * 31.0) * 0.4 + sin(tps * 19.0 + 1.3) * 0.3
			"asystolie":
				v = 0.0
			"tv":
				v = sin(fmod(tps, 60.0 / maxf(fc, 20.0)) / (60.0 / maxf(fc, 20.0)) * TAU) * 1.2 * signf(g)
			_:
				v = _complexe(tps, battements, g, nom)
		pts[k] = origine + Vector2(largeur * k / (n - 1), -(v + rng.randf_range(-0.01, 0.01)) * mm_mv)
	draw_polyline(pts, Color(0.08, 0.08, 0.1), 1.6, true)


func _complexe(tps: float, battements: PackedFloat32Array, g: float, nom: String) -> float:
	# Battement le plus proche (le QRS est à l'instant du battement).
	var dt := 1e9
	for b in battements:
		if absf(tps - b) < absf(dt):
			dt = tps - b
	var v := 0.0
	if rythme == "fa":
		v += sin(tps * 47.0) * 0.04 + sin(tps * 33.0) * 0.03
	else:
		v += _bosse(dt, -0.16, 0.035, 0.12 * absf(g) + 0.03)
	v += _bosse(dt, -0.02, 0.008, -0.1 * g)
	v += _bosse(dt, 0.0, 0.012, 1.0 * g)
	v += _bosse(dt, 0.025, 0.010, -0.25 * absf(g))
	var s: float = st.get(nom, 0.0)
	if dt > 0.04 and dt < 0.22:
		v += s * smoothstep(0.04, 0.07, dt) * (1.0 - smoothstep(0.18, 0.22, dt))
	v += _bosse(dt, 0.26, 0.06, 0.28 * g + s * 0.5)
	return v


static func _bosse(x: float, c: float, l: float, h: float) -> float:
	var d := (x - c) / l
	return h * exp(-d * d)
