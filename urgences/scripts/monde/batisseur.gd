class_name Batisseur
extends RefCounted
## Construit la coque des pièces (sols, murs, plafonds) en géométrie FUSIONNÉE :
## un seul maillage par matériau, UV en mètres (textures à l'échelle réelle), collisions en
## boîtes simples et occulteurs pour l'élimination des objets cachés derrière les murs.

const FACES := ["+x", "-x", "+y", "-y", "+z", "-z"]

var _outils := {}          # nom de matériau -> SurfaceTool
var _collisions: Array[AABB] = []
var _occulteurs: Array[AABB] = []


## Ajoute une boîte alignée sur les axes. mats : {"+x": "mur_blanc", ...} ou un nom unique.
## Les faces absentes du dictionnaire ne sont pas générées (faces cachées).
func boite(aabb: AABB, mats, collision := true, occulteur := false) -> void:
	for f in FACES:
		var nom := ""
		if mats is String:
			nom = mats
		elif mats.has(f):
			nom = mats[f]
		elif mats.has("*"):
			nom = mats["*"]
		if nom != "":
			_face(aabb, f, nom)
	if collision:
		_collisions.append(aabb)
	if occulteur:
		_occulteurs.append(aabb)


## Mur aligné sur X (de x0 à x1) ou sur Z, avec des ouvertures [{"debut", "fin", "bas", "haut"}]
## exprimées le long du mur (mètres depuis son début). mat_int = face côté « + », mat_ext = côté « - ».
func mur(debut: Vector3, longueur: float, axe: String, hauteur: float, epaisseur: float,
		mat_plus: String, mat_moins: String, ouvertures: Array = [], mat_tranche := "") -> void:
	if mat_tranche == "":
		mat_tranche = mat_plus
	var segments := _decouper(longueur, hauteur, ouvertures)
	for s in segments:
		var a: float = s[0]
		var b: float = s[1]
		var z0: float = s[2]
		var z1: float = s[3]
		var aabb: AABB
		var mats := {}
		if axe == "x":
			aabb = AABB(debut + Vector3(a, z0, -epaisseur * 0.5), Vector3(b - a, z1 - z0, epaisseur))
			mats = {"+z": mat_plus, "-z": mat_moins, "+x": mat_tranche, "-x": mat_tranche, "+y": mat_tranche, "-y": mat_tranche}
		else:
			aabb = AABB(debut + Vector3(-epaisseur * 0.5, z0, a), Vector3(epaisseur, z1 - z0, b - a))
			mats = {"+x": mat_plus, "-x": mat_moins, "+z": mat_tranche, "-z": mat_tranche, "+y": mat_tranche, "-y": mat_tranche}
		boite(aabb, mats, true, z0 < 0.01 and z1 > hauteur - 0.01)


## Découpe un mur autour des ouvertures : renvoie des rectangles [a, b, bas, haut].
func _decouper(longueur: float, hauteur: float, ouvertures: Array) -> Array:
	var res := []
	var tri := ouvertures.duplicate()
	tri.sort_custom(func(p, q): return p["debut"] < q["debut"])
	var x := 0.0
	for o in tri:
		if o["debut"] > x:
			res.append([x, o["debut"], 0.0, hauteur])
		if o.get("bas", 0.0) > 0.0:
			res.append([o["debut"], o["fin"], 0.0, o["bas"]])
		if o.get("haut", hauteur) < hauteur:
			res.append([o["debut"], o["fin"], o["haut"], hauteur])
		x = o["fin"]
	if x < longueur:
		res.append([x, longueur, 0.0, hauteur])
	return res


func _face(aabb: AABB, f: String, nom: String) -> void:
	var st: SurfaceTool = _outils.get(nom)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_outils[nom] = st
	var p := aabb.position
	var q := aabb.end
	var c: Array[Vector3] = []
	var n := Vector3.ZERO
	match f:
		"+x":
			n = Vector3.RIGHT
			c = [Vector3(q.x, p.y, q.z), Vector3(q.x, p.y, p.z), Vector3(q.x, q.y, p.z), Vector3(q.x, q.y, q.z)]
		"-x":
			n = Vector3.LEFT
			c = [Vector3(p.x, p.y, p.z), Vector3(p.x, p.y, q.z), Vector3(p.x, q.y, q.z), Vector3(p.x, q.y, p.z)]
		"+y":
			n = Vector3.UP
			c = [Vector3(p.x, q.y, q.z), Vector3(q.x, q.y, q.z), Vector3(q.x, q.y, p.z), Vector3(p.x, q.y, p.z)]
		"-y":
			n = Vector3.DOWN
			c = [Vector3(p.x, p.y, p.z), Vector3(q.x, p.y, p.z), Vector3(q.x, p.y, q.z), Vector3(p.x, p.y, q.z)]
		"+z":
			n = Vector3.BACK
			c = [Vector3(p.x, p.y, q.z), Vector3(q.x, p.y, q.z), Vector3(q.x, q.y, q.z), Vector3(p.x, q.y, q.z)]
		"-z":
			n = Vector3.FORWARD
			c = [Vector3(q.x, p.y, p.z), Vector3(p.x, p.y, p.z), Vector3(p.x, q.y, p.z), Vector3(q.x, q.y, p.z)]
	var uv: Array[Vector2] = []
	for v in c:
		uv.append(_uv(v, n))
	# Deux triangles (ordre horaire vu de face = face avant dans Godot).
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(c[i])


static func _uv(v: Vector3, n: Vector3) -> Vector2:
	if absf(n.y) > 0.5:
		return Vector2(v.x, v.z)
	if absf(n.x) > 0.5:
		return Vector2(v.z * -n.x, -v.y)
	return Vector2(v.x * n.z, -v.y)


## Crée les nœuds : un MeshInstance3D (multi-surfaces), un StaticBody3D, un OccluderInstance3D.
func finir(parent: Node3D, nom := "Coque") -> Node3D:
	var racine := Node3D.new()
	racine.name = nom
	parent.add_child(racine)
	var mesh := ArrayMesh.new()
	var noms := _outils.keys()
	noms.sort()
	for m in noms:
		var st: SurfaceTool = _outils[m]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Bibliotheque.materiau(m))
	var mi := MeshInstance3D.new()
	mi.name = "Geometrie"
	mi.mesh = mesh
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	racine.add_child(mi)
	var corps := StaticBody3D.new()
	corps.name = "Collisions"
	racine.add_child(corps)
	for a in _collisions:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = a.size
		cs.shape = bs
		cs.position = a.get_center()
		corps.add_child(cs)
	if not _occulteurs.is_empty():
		var occ := ArrayOccluder3D.new()
		var sommets := PackedVector3Array()
		var indices := PackedInt32Array()
		for a in _occulteurs:
			var base := sommets.size()
			for i in 8:
				sommets.append(a.get_endpoint(i))
			for t in [0, 1, 3, 0, 3, 2, 4, 6, 7, 4, 7, 5, 0, 4, 5, 0, 5, 1, 2, 3, 7, 2, 7, 6, 0, 2, 6, 0, 6, 4, 1, 5, 7, 1, 7, 3]:
				indices.append(base + t)
		occ.set_arrays(sommets, indices)
		var oi := OccluderInstance3D.new()
		oi.name = "Occulteurs"
		oi.occluder = occ
		racine.add_child(oi)
	return racine
