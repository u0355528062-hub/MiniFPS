class_name Cable
extends RefCounted
## Câbles et tuyaux souples posés une fois pour toutes à la construction de la scène : une corde
## (Verlet) part du trajet prévu, pend sous son poids et se pose sur ce qu'elle rencontre (peau,
## drap, matelas, sol, sphères d'obstacle). Le frottement la garde là où on l'a couchée, seules les
## parties dans le vide tombent : boucles qui pendent au bord de la table, mou qui traîne au sol.

const GRAVITY := Vector3(0.0, -9.8, 0.0)
const STEPS := 110
const ITERATIONS := 8
## Câbles déjà calculés (fichier livré avec le jeu, régénéré en lançant le projet hors export
## quand un trajet change) : clé = empreinte du trajet et des réglages.
const CACHE_PATH := "res://assets/data/cables.json"

static var _cache := {}
static var _cache_loaded := false
static var _dirty := false


## path : trajet de départ (les points d'origine sont gardés, les segments recoupés tous les
## `seg` mètres) ; slack : longueur en plus (0.15 = 15 % de mou) ; r : rayon du câble ;
## pin_a / pin_b : nombre de points tenus au début / à la fin (2 = le câble sort dans l'axe du
## premier segment, comme d'un connecteur) ; obstacles : [[centre, rayon], ...].
static func lay(path: PackedVector3Array, slack: float, r: float, seg := 0.02, pin_a := 1, pin_b := 1, obstacles: Array = []) -> PackedVector3Array:
	var key := _key(path, slack, r, seg, pin_a, pin_b, obstacles)
	_load_cache()
	if _cache.has(key):
		var flat: PackedFloat32Array = _cache[key]
		var out := PackedVector3Array()
		out.resize(flat.size() / 3)
		for i in out.size():
			out[i] = Vector3(flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2])
		return out
	var res := _simulate(path, slack, r, seg, pin_a, pin_b, obstacles)
	var flat2 := PackedFloat32Array()
	for q in res:
		flat2.append_array([q.x, q.y, q.z])
	_cache[key] = flat2
	_dirty = true
	return res


## Empreinte stable d'un câble (valeurs arrondies au dixième de millimètre : mêmes clés sur
## toutes les machines malgré les écarts d'arrondi des fonctions trigonométriques).
static func _key(path: PackedVector3Array, slack: float, r: float, seg: float, pin_a: int, pin_b: int, obstacles: Array) -> String:
	var a := []
	for q in path:
		a.append_array([roundi(q.x * 10000.0), roundi(q.y * 10000.0), roundi(q.z * 10000.0)])
	a.append_array([roundi(slack * 10000.0), roundi(r * 100000.0), roundi(seg * 10000.0), pin_a, pin_b])
	for o in obstacles:
		var c: Vector3 = o[0]
		a.append_array([roundi(c.x * 1000.0), roundi(c.y * 1000.0), roundi(c.z * 1000.0), roundi(float(o[1]) * 1000.0)])
	return str(a).md5_text()


static func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if d is Dictionary:
		for k in d:
			_cache[k] = PackedFloat32Array(d[k])


## Enregistre les câbles calculés pendant cette partie (projet lancé hors export seulement).
static func save_cache() -> void:
	if not _dirty or not OS.has_feature("editor"):
		return
	var d := {}
	for k in _cache:
		var flat: PackedFloat32Array = _cache[k]
		var a := []
		for v in flat:
			a.append(snappedf(v, 0.00001))
		d[k] = a
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		_dirty = false


static func _simulate(path: PackedVector3Array, slack: float, r: float, seg: float, pin_a: int, pin_b: int, obstacles: Array) -> PackedVector3Array:
	var pts := _resample(path, seg)
	var n := pts.size()
	if n < 3:
		return pts
	var rest := PackedFloat32Array()
	rest.resize(n - 1)
	for i in n - 1:
		rest[i] = pts[i].distance_to(pts[i + 1]) * (1.0 + slack)
	var inv := PackedFloat32Array()  # masse inverse : 0 pour les points tenus
	inv.resize(n)
	for i in n:
		inv[i] = 0.0 if (i < pin_a or i >= n - pin_b) else 1.0
	var prev := pts.duplicate()
	var dt := 1.0 / 60.0
	var g := GRAVITY * dt * dt * 3.0
	# Obstacles utiles : ceux proches du trajet
	var lo := path[0]
	var hi := path[0]
	for q in path:
		lo = lo.min(q)
		hi = hi.max(q)
	var near: Array = []
	for o in obstacles:
		var c: Vector3 = o[0]
		var m: float = o[1] + 0.3
		if c.x > lo.x - m and c.x < hi.x + m and c.y > lo.y - m and c.y < hi.y + m and c.z > lo.z - m and c.z < hi.z + m:
			near.append(o)
	for _s in STEPS:
		for i in n:
			if inv[i] == 0.0:
				continue
			var p := pts[i]
			var v := (p - prev[i]) * 0.88
			prev[i] = p
			pts[i] = p + v + g
		for it in ITERATIONS:
			for i in n - 1:
				var wa := inv[i]
				var wb := inv[i + 1]
				var w := wa + wb
				if w == 0.0:
					continue
				var a := pts[i]
				var b := pts[i + 1]
				var d := b - a
				var l := d.length()
				if l < 0.000001:
					continue
				var c := d * ((l - rest[i]) / (l * w))
				pts[i] = a + c * wa
				pts[i + 1] = b - c * wb
			if it % 3 != 2 and it != ITERATIONS - 1:
				continue
			for i in n:
				if inv[i] == 0.0:
					continue
				var p := pts[i]
				var q := _collide(p, r, near)
				if q != p:
					pts[i] = q
					# Frottement : un point posé ne glisse pas (seule la corde tendue le tire)
					prev[i] = q
	return pts


## Sépare un point de ce qu'il traverse ; renvoie le point inchangé s'il est libre.
static func _collide(p: Vector3, r: float, obstacles: Array) -> Vector3:
	var q := p
	for o in obstacles:
		var c: Vector3 = o[0]
		var rr: float = o[1] + r
		var d := q - c
		if d.length_squared() < rr * rr:
			q = c + d.normalized() * rr
	# Sous le plateau de la table : on ressort par le bord le plus proche (côtés et bouts)
	if Patient.on_table(q.x, q.z) and q.y < Patient.TABLE_TOP - 0.025:
		var dz0 := q.z - Patient.TABLE_MIN.y
		var dz1 := Patient.TABLE_MAX.y - q.z
		var dx1 := Patient.TABLE_MAX.x - q.x
		var m := minf(minf(dz0, dz1), dx1)
		if m == dz0:
			q.z = Patient.TABLE_MIN.y - r
		elif m == dz1:
			q.z = Patient.TABLE_MAX.y + r
		else:
			q.x = Patient.TABLE_MAX.x + r
		return q
	var h := Patient.top_height(q.x, q.z)
	if h < 0.0:
		h = 0.0
	if q.y < h + r:
		q.y = h + r
	return q


## Trajet recoupé : chaque segment du trajet est divisé en parts de `seg` mètres au plus.
static func _resample(path: PackedVector3Array, seg: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var k := maxi(1, ceili(a.distance_to(b) / seg))
		for j in k:
			out.append(a.lerp(b, float(j) / k))
	out.append(path[path.size() - 1])
	return out


## Courbe lisse (Catmull-Rom) passant par les points de la corde, pour le maillage.
static func smooth(pts: PackedVector3Array, sub := 3) -> PackedVector3Array:
	var n := pts.size()
	if n < 3:
		return pts
	var out := PackedVector3Array()
	for i in n - 1:
		var p0 := pts[maxi(0, i - 1)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(n - 1, i + 2)]
		for j in sub:
			var t := float(j) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


## Point posé sur la surface la plus haute (peau, drap, matelas ; sol hors de la table).
static func on_surface(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, maxf(0.0, Patient.top_height(x, z)) + lift, z)
