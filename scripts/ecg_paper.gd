class_name EcgPaper
extends Control
## Tracé d'ECG 12 dérivations sur papier millimétré (25 mm/s, 10 mm/mV) : 3 lignes de 4 dérivations
## (I, II, III, aVR, aVL, aVF, V1 à V6) et une bande de rythme en DII. Rythme et sus-décalage du ST
## donnés par le cas ; une électrode mal posée donne un tracé parasité.

var data := {}
var bad: Array = []

const LEADS := [["I", "aVR", "V1", "V4"], ["II", "aVL", "V2", "V5"], ["III", "aVF", "V3", "V6"]]
## Amplitude de base (R) et de l'onde S par dérivation : axe normal, progression de R en précordiales
const SHAPE := {"I": [0.7, 0.1], "II": [1.0, 0.15], "III": [0.45, 0.1], "aVR": [-0.6, 0.0], "aVL": [0.3, 0.1], "aVF": [0.7, 0.1],
	"V1": [0.2, 0.9], "V2": [0.35, 1.0], "V3": [0.7, 0.6], "V4": [1.1, 0.3], "V5": [1.0, 0.15], "V6": [0.8, 0.1]}


func _st(lead: String) -> float:
	match String(data.get("st", "")):
		"anterieur":
			if lead in ["V1", "V2", "V3", "V4"]:
				return 0.28 if lead in ["V2", "V3"] else 0.2
			if lead in ["II", "III", "aVF"]:
				return -0.08
		"inferieur":
			if lead in ["II", "III", "aVF"]:
				return 0.25
			if lead in ["I", "aVL"]:
				return -0.1
	return 0.0


## Tension (mV) de la dérivation au temps t (s).
func _v(lead: String, t: float) -> float:
	var rhythm := String(data.get("rhythm", "sinus"))
	var rate := maxf(float(data.get("rate", 75.0)), 1.0)
	var noise := 0.0
	if lead in bad or (lead == "I" and ("RA" in bad or "LA" in bad)) or (lead == "III" and "LL" in bad):
		noise = 0.18 * sin(t * 47.0) + 0.12 * sin(t * 113.0 + 1.0) + 0.1 * sin(t * 2.3)
	match rhythm:
		"fv":
			return noise + 0.35 * sin(TAU * 5.3 * t + lead.length()) + 0.22 * sin(TAU * 7.9 * t + 1.3) + 0.12 * sin(TAU * 11.0 * t)
		"asystolie":
			return noise + 0.02 * sin(t * 1.7)
		"tv", "tvsp":
			var pr := 60.0 / rate
			return noise + 1.1 * sin(TAU * fmod(t, pr) / pr) * (1.0 if not lead in ["aVR", "V1"] else -1.0)
	var period := 60.0 / rate
	var x := fmod(t, period)
	var s: Array = SHAPE[lead]
	var r: float = s[0]
	var sd: float = s[1]
	var st := _st(lead)
	var v := 0.12 * exp(-pow((x - 0.06) / 0.025, 2.0)) * signf(r + 0.001)
	v += r * exp(-pow((x - 0.17) / 0.011, 2.0))
	v -= sd * exp(-pow((x - 0.195) / 0.012, 2.0))
	v += st * smoothstep(0.2, 0.22, x) * (1.0 - smoothstep(0.34, 0.42, x))
	v += (0.22 * signf(r + 0.001) + st * 0.6) * exp(-pow((x - 0.38) / 0.055, 2.0))
	return v + noise


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.95, 0.94))
	var mm := w / 260.0  # 260 mm de large (10 s + marges)
	var minor := Color(0.98, 0.78, 0.76)
	var major := Color(0.93, 0.55, 0.53)
	var x := 0.0
	var i := 0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), major if i % 5 == 0 else minor, 1.0 if i % 5 else 1.6)
		x += mm
		i += 1
	var y := 0.0
	i = 0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), major if i % 5 == 0 else minor, 1.0 if i % 5 else 1.6)
		y += mm
		i += 1
	var font := UIKit.font()
	var ink := Color(0.08, 0.08, 0.1)
	var row_h := h / 4.0
	var col_w := (w - 10.0 * mm) / 4.0
	for r in 4:
		var base_y := row_h * (r + 0.6)
		# Étalonnage 1 mV
		var cal := PackedVector2Array([Vector2(2 * mm, base_y), Vector2(3 * mm, base_y), Vector2(3 * mm, base_y - 10 * mm),
			Vector2(8 * mm, base_y - 10 * mm), Vector2(8 * mm, base_y), Vector2(9 * mm, base_y)])
		draw_polyline(cal, ink, 1.6)
		if r < 3:
			for c in 4:
				var lead: String = LEADS[r][c]
				var x0 := 10.0 * mm + c * col_w
				var pts := PackedVector2Array()
				var n := 260
				for k in n:
					var tt := c * 2.5 + 2.5 * k / n
					pts.append(Vector2(x0 + col_w * k / n, base_y - _v(lead, tt) * 10.0 * mm))
				draw_polyline(pts, ink, 1.6, true)
				draw_string(font, Vector2(x0 + 4, base_y - 14 * mm), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
		else:
			var pts2 := PackedVector2Array()
			var n2 := 1000
			for k in n2:
				var tt2 := 10.0 * k / n2
				pts2.append(Vector2(10.0 * mm + (w - 10.0 * mm) * k / n2, base_y - _v("II", tt2) * 10.0 * mm))
			draw_polyline(pts2, ink, 1.6, true)
			draw_string(font, Vector2(10.0 * mm + 4, base_y - 14 * mm), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(font, Vector2(12, h - 10), "25 mm/s   10 mm/mV   FC %d/min" % int(data.get("rate", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
