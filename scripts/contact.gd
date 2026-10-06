class_name Contact
extends RefCounted
## Contacts des instruments tenus avec le patient, les champs et les tables : un instrument ne
## traverse ni la peau ni les objets. Il ne pénètre que là où le geste le permet (zones déclarées
## par la procédure : la lame le long du tracé, l'aiguille au point d'injection, la plaie ouverte...).
## La peau cède un peu sous la pression (fossette visible).

const SOFT := 0.0025  ## la peau s'enfonce de 2,5 mm avant de bloquer

static var patient: Patient
## Zones où la pointe peut entrer : {"a": Vector3, "b": Vector3, "r": float, "depth": float, "tags": Array}
static var zones: Array = []


static func clear_zones() -> void:
	zones.clear()


## Zone en forme de capsule (segment a-b, rayon r mesuré à l'horizontale), profondeur autorisée.
static func add_zone(a: Vector3, b: Vector3, r: float, depth: float, tags: Array) -> void:
	zones.append({"a": a, "b": b, "r": r, "depth": depth, "tags": tags})


static func _zone_depth(p: Vector3, tag: String) -> float:
	var best := 0.0
	for z in zones:
		if not (tag in z["tags"] or "any" in z["tags"]):
			continue
		var a: Vector3 = z["a"]
		var b: Vector3 = z["b"]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		var q := Vector2(p.x, p.z)
		var k := 0.0 if ab.length_squared() < 1e-10 else clampf((q - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a2 + ab * k).distance_to(q) < z["r"]:
			best = maxf(best, z["depth"])
	return best


## Hauteur de la surface solide sous p (peau, champ, table, plateau), -INF s'il n'y a rien.
## Un instrument entré par la fenêtre continue sous la peau dans la zone de son geste (tag), même
## là où le champ recouvre la peau (aiguille de la voie centrale vers le creux sus-sternal).
static func surface(p: Vector3, tag := "") -> float:
	if patient:
		if is_skin(p, tag):
			return Patient.body_height(p.x, p.z) + patient.breath_offset(p.x, p.z)
		var top := Patient.top_height(p.x, p.z)
		if top > 0.0:
			return top + patient.breath_offset(p.x, p.z)
	for m in InstrumentTray.TABLES:
		if absf(p.x - m.x) < 0.26 and absf(p.z - m.z) < 0.22:
			return InstrumentTray.TRAY_Y + 0.003
	return -INF


## Est-ce de la peau (on peut la creuser un peu, la piquer, l'inciser) ?
static func is_skin(p: Vector3, tag := "") -> bool:
	return patient != null and (patient.in_window(p.x, p.z) or (tag != "" and _zone_depth(p, tag) > 0.0))


## Profondeur que la pointe peut atteindre sous la surface en p.
static func allowance(p: Vector3, tag: String) -> float:
	if not is_skin(p, tag):
		return 0.0
	var a := SOFT
	# La plaie ouverte est un vrai trou : tout l'instrument peut y entrer
	a = maxf(a, patient.hole_depth(p))
	return maxf(a, _zone_depth(p, tag))


## Pose corrigée : l'instrument est remonté juste assez pour qu'aucun de ses points ne traverse.
## Note aussi la profondeur de la pointe sous la peau (tip_depth).
static func solve(inst: Instrument, xf: Transform3D) -> Transform3D:
	if inst.samples.is_empty():
		inst.build_samples()
	var push := 0.0
	for s in inst.samples:
		var p: Vector3 = xf * (s[0] as Vector3)
		var top := surface(p, s[1])
		if top == -INF:
			continue
		var pen := top - allowance(p, s[1]) - p.y
		if pen > push:
			push = pen
	var out := xf
	out.origin.y += push
	inst.correction = push
	var tip := out * inst.tip_local
	inst.tip_depth = Patient.body_height(tip.x, tip.z) + patient.breath_offset(tip.x, tip.z) - tip.y if is_skin(tip, inst.samples[0][1]) else -1.0
	return out
