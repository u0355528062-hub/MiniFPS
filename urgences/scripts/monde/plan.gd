class_name Plan
extends RefCounted
## Plan du service des urgences (étape 2) et génération automatique des murs.
## Les pièces sont des rectangles (mètres, X vers l'est, Z vers le sud). Une grille de 10 cm
## repère les frontières entre pièces différentes : chaque frontière devient un mur dont
## chaque face prend le revêtement de la pièce qu'elle regarde (façade côté extérieur).
## Les ouvertures (portes, baies, passages libres) sont déclarées sur les lignes de frontière.

const PAS := 0.1
const EP := 0.12

## id, rectangle, sol, murs, hauteur sous plafond.
const PIECES := [
	{"id": "couloir", "r": Rect2(0, 13, 40, 3), "sol": "sol_vinyle_bleu", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_1", "r": Rect2(0.0, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_2", "r": Rect2(3.6, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_3", "r": Rect2(7.2, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_4", "r": Rect2(10.8, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_5", "r": Rect2(14.4, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "box_6", "r": Rect2(18.0, 9, 3.6, 4), "sol": "sol_vinyle_vert", "mur": "mur_blanc", "h": 2.7},
	{"id": "dechocage", "r": Rect2(21.6, 6, 8.4, 7), "sol": "sol_vinyle_gris", "mur": "mur_bleu", "h": 3.0},
	{"id": "platre", "r": Rect2(30, 9, 4, 4), "sol": "sol_vinyle_gris", "mur": "carrelage_blanc", "h": 2.7},
	{"id": "radiologie", "r": Rect2(34, 7, 6, 6), "sol": "sol_vinyle_gris", "mur": "mur_blanc", "h": 3.0},
	{"id": "hall", "r": Rect2(0, 16, 14, 10), "sol": "sol_vinyle_gris", "mur": "mur_blanc", "h": 3.2},
	{"id": "poste", "r": Rect2(14, 16, 6, 4), "sol": "sol_vinyle_bleu", "mur": "mur_jaune", "h": 2.7},
	{"id": "tri", "r": Rect2(14, 20, 3.5, 6), "sol": "sol_vinyle_vert", "mur": "mur_vert_eau", "h": 2.7},
	{"id": "bureau", "r": Rect2(17.5, 20, 2.5, 6), "sol": "sol_vinyle_gris", "mur": "mur_blanc", "h": 2.7},
	{"id": "scanner", "r": Rect2(20, 16, 7, 7.5), "sol": "sol_vinyle_gris", "mur": "mur_blanc", "h": 3.0},
	{"id": "pupitre", "r": Rect2(20, 23.5, 7, 2.5), "sol": "sol_vinyle_gris", "mur": "mur_bleu", "h": 2.7},
	{"id": "sas", "r": Rect2(27, 16, 10, 12), "sol": "beton", "mur": "mur_blanc", "h": 4.0},
	{"id": "reserve", "r": Rect2(37, 16, 3, 10), "sol": "sol_vinyle_gris", "mur": "mur_blanc", "h": 2.7},
]

## Ouvertures sur les lignes de frontière : axe « x » = ligne z constante, « z » = ligne x constante.
## type : porte (pleine hauteur jusqu'à « haut »), baie (allège « bas » → « haut »), libre (aucun mur).
static func ouvertures() -> Array:
	var o := []
	# Box : baie vitrée + porte coulissante sur le couloir (même dessin que le prototype).
	for i in 6:
		var x0 := i * 3.6
		o.append({"axe": "x", "c": 13.0, "a": x0 + 0.35, "b": x0 + 1.65, "bas": 0.95, "haut": 2.15})
		o.append({"axe": "x", "c": 13.0, "a": x0 + 1.95, "b": x0 + 3.35, "bas": 0.0, "haut": 2.15})
	# Déchocage : double porte battante large (brancards) sur le couloir.
	o.append({"axe": "x", "c": 13.0, "a": 24.2, "b": 26.2, "bas": 0.0, "haut": 2.3})
	o.append({"axe": "x", "c": 13.0, "a": 31.0, "b": 32.2, "bas": 0.0, "haut": 2.1})   # plâtre
	o.append({"axe": "x", "c": 13.0, "a": 35.0, "b": 36.6, "bas": 0.0, "haut": 2.2})   # radiologie
	# Hall ↔ couloir : grand passage ; poste de soins ouvert sur le couloir.
	o.append({"axe": "x", "c": 16.0, "a": 4.5, "b": 8.5, "bas": 0.0, "haut": 2.6})
	o.append({"axe": "x", "c": 16.0, "a": 14.0, "b": 20.0, "libre": true})
	o.append({"axe": "z", "c": 14.0, "a": 16.0, "b": 18.5, "bas": 0.0, "haut": 2.6})  # hall ↔ poste
	o.append({"axe": "z", "c": 14.0, "a": 18.8, "b": 19.8, "bas": 1.05, "haut": 2.1})  # guichet accueil/poste
	o.append({"axe": "x", "c": 20.0, "a": 15.0, "b": 16.1, "bas": 0.0, "haut": 2.1})   # tri ↔ poste
	o.append({"axe": "z", "c": 14.0, "a": 21.0, "b": 22.1, "bas": 0.0, "haut": 2.1})   # hall ↔ tri
	o.append({"axe": "x", "c": 20.0, "a": 18.2, "b": 19.3, "bas": 0.0, "haut": 2.1})   # bureau ↔ poste
	# Scanner : porte sur le couloir, vitre plombée vers le pupitre, porte pupitre.
	o.append({"axe": "x", "c": 16.0, "a": 21.0, "b": 22.6, "bas": 0.0, "haut": 2.2})
	o.append({"axe": "x", "c": 23.5, "a": 21.5, "b": 25.5, "bas": 0.95, "haut": 2.0})
	o.append({"axe": "z", "c": 27.0, "a": 24.2, "b": 25.3, "bas": 0.0, "haut": 2.1})   # pupitre ↔ sas
	# Sas ambulances : grand passage vers le couloir, ouverture sur l'extérieur (sud).
	o.append({"axe": "x", "c": 16.0, "a": 29.0, "b": 32.0, "bas": 0.0, "haut": 2.6})
	o.append({"axe": "x", "c": 28.0, "a": 28.5, "b": 35.5, "bas": 0.0, "haut": 3.6})
	o.append({"axe": "z", "c": 37.0, "a": 17.0, "b": 18.1, "bas": 0.0, "haut": 2.1})   # réserve
	# Façade sud du hall : vitrage toute hauteur + entrée automatique.
	o.append({"axe": "x", "c": 26.0, "a": 0.6, "b": 5.6, "bas": 0.35, "haut": 2.9})
	o.append({"axe": "x", "c": 26.0, "a": 5.9, "b": 8.1, "bas": 0.0, "haut": 2.6})
	o.append({"axe": "x", "c": 26.0, "a": 8.4, "b": 13.4, "bas": 0.35, "haut": 2.9})
	# Fenêtres : bout ouest du couloir, déchocage (nord), bureau (sud).
	o.append({"axe": "z", "c": 0.0, "a": 13.5, "b": 15.5, "bas": 0.9, "haut": 2.3})
	o.append({"axe": "x", "c": 6.0, "a": 23.0, "b": 28.6, "bas": 1.0, "haut": 2.5})
	o.append({"axe": "x", "c": 26.0, "a": 18.1, "b": 19.4, "bas": 0.9, "haut": 2.2})
	return o


var grille: PackedInt32Array
var nx := 0
var nz := 0
var origine := Vector2(-1, 5)        # coin nord-ouest de la grille (avec une marge extérieure)
var taille := Vector2(42, 24)


func _init() -> void:
	nx = int(round(taille.x / PAS))
	nz = int(round(taille.y / PAS))
	grille = PackedInt32Array()
	grille.resize(nx * nz)
	grille.fill(-1)
	for i in PIECES.size():
		var r: Rect2 = PIECES[i]["r"]
		var i0 := int(round((r.position.x - origine.x) / PAS))
		var i1 := int(round((r.end.x - origine.x) / PAS))
		var j0 := int(round((r.position.y - origine.y) / PAS))
		var j1 := int(round((r.end.y - origine.y) / PAS))
		for j in range(j0, j1):
			for k in range(i0, i1):
				grille[j * nx + k] = i


func piece(id: String) -> Dictionary:
	for p in PIECES:
		if p["id"] == id:
			return p
	return {}


func piece_en(x: float, z: float) -> int:
	var i := int(floor((x - origine.x) / PAS))
	var j := int(floor((z - origine.y) / PAS))
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return -1
	return grille[j * nx + i]


## Construit tous les murs, sols, plafonds et le toit dans le Batisseur.
func construire(b: Batisseur) -> void:
	var ouv := ouvertures()
	# Sols et plafonds.
	for p in PIECES:
		var r: Rect2 = p["r"]
		b.boite(AABB(Vector3(r.position.x, -0.1, r.position.y), Vector3(r.size.x, 0.1, r.size.y)), {"+y": p["sol"]})
		b.boite(AABB(Vector3(r.position.x, p["h"], r.position.y), Vector3(r.size.x, 0.05, r.size.y)),
			{"-y": "plafond" if p["id"] != "sas" else "beton"}, false)
	# Toit (bloque le soleil au-dessus des plafonds) et dalle extérieure.
	b.boite(AABB(Vector3(-0.2, 4.1, 5.8), Vector3(40.4, 0.3, 22.4)), {"+y": "beton", "-y": "beton"}, false)
	# Frontières verticales (lignes x = constante) puis horizontales (z = constante).
	var segs := []
	for k in range(1, nx):
		var x := origine.x + k * PAS
		var j := 0
		while j < nz:
			var a := grille[j * nx + k - 1]
			var c := grille[j * nx + k]
			if a == c:
				j += 1
				continue
			var j0 := j
			while j < nz and grille[j * nx + k - 1] == a and grille[j * nx + k] == c:
				j += 1
			segs.append({"axe": "z", "c": x, "a": origine.y + j0 * PAS, "b": origine.y + j * PAS, "moins": a, "plus": c})
	for j in range(1, nz):
		var z := origine.y + j * PAS
		var k := 0
		while k < nx:
			var a := grille[(j - 1) * nx + k]
			var c := grille[j * nx + k]
			if a == c:
				k += 1
				continue
			var k0 := k
			while k < nx and grille[(j - 1) * nx + k] == a and grille[j * nx + k] == c:
				k += 1
			segs.append({"axe": "x", "c": z, "a": origine.x + k0 * PAS, "b": origine.x + k * PAS, "moins": a, "plus": c})
	for s in segs:
		_mur(b, s, ouv)


func _mur(b: Batisseur, s: Dictionary, ouv: Array) -> void:
	var pm: Dictionary = PIECES[s["moins"]] if s["moins"] >= 0 else {}
	var pp: Dictionary = PIECES[s["plus"]] if s["plus"] >= 0 else {}
	var h: float = maxf(pm.get("h", 0.0), pp.get("h", 0.0))
	var mat_moins: String = pm.get("mur", "facade")
	var mat_plus: String = pp.get("mur", "facade")
	# Prolonge le mur d'une demi-épaisseur aux deux bouts (angles fermés).
	var a: float = s["a"] - EP * 0.5
	var bb: float = s["b"] + EP * 0.5
	var trous := []
	for o in ouv:
		if o["axe"] != s["axe"] or absf(o["c"] - s["c"]) > 0.01:
			continue
		var oa: float = maxf(o["a"], a)
		var ob: float = minf(o["b"], bb)
		if ob <= oa:
			continue
		if o.get("libre", false):
			trous.append({"debut": oa - a, "fin": ob - a, "bas": 0.0, "haut": h + 1.0})
		else:
			trous.append({"debut": oa - a, "fin": ob - a, "bas": o.get("bas", 0.0), "haut": o.get("haut", h)})
	var debut := Vector3(a, 0, s["c"]) if s["axe"] == "x" else Vector3(s["c"], 0, a)
	b.mur(debut, bb - a, s["axe"], h, EP, mat_plus, mat_moins, trous, mat_plus if s["plus"] >= 0 else mat_moins)
