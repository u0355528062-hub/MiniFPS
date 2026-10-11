class_name Bibliotheque
extends RefCounted
## Accès aux modèles et matériaux du jeu.
## Les GLB générés par Blender portent des matériaux nommés : on les remplace UNE FOIS par mesh
## (ressource partagée) par le .tres de même nom dans assets/materials/. Toutes les instances
## d'un même modèle partagent donc maillage et matériaux (bon pour le regroupement des appels).

const DOSSIER_MAT := "res://assets/materials/"
const DOSSIER_MOBILIER := "res://assets/models/mobilier/"

static var _materiaux := {}
static var _scenes := {}


static func materiau(nom: String) -> Material:
	if _materiaux.has(nom):
		return _materiaux[nom]
	var chemin := DOSSIER_MAT + nom + ".tres"
	var m: Material = null
	if ResourceLoader.exists(chemin):
		m = load(chemin)
	_materiaux[nom] = m
	return m


## Instancie un meuble (assets/models/mobilier/<nom>.glb) avec ses matériaux du jeu.
static func meuble(nom: String) -> Node3D:
	var ps: PackedScene = _scenes.get(nom)
	if ps == null:
		ps = load(DOSSIER_MOBILIER + nom + ".glb")
		_scenes[nom] = ps
	var n: Node3D = ps.instantiate()
	n.name = nom
	appliquer_materiaux(n)
	return n


## Ajoute une collision en boîte (enveloppe du modèle) : le joueur ne traverse pas le mobilier.
static func ajouter_collision(n: Node3D, marge := 0.0) -> void:
	var total := AABB()
	var premier := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.transform * mi.get_aabb()
		total = a if premier else total.merge(a)
		premier = false
	if premier:
		return
	var corps := StaticBody3D.new()
	corps.name = "Collision"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = total.size + Vector3.ONE * marge
	cs.shape = b
	cs.position = total.get_center()
	corps.add_child(cs)
	n.add_child(corps)


static func appliquer_materiaux(racine: Node) -> void:
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null or mesh.has_meta("mat_ok"):
			continue
		for s in mesh.get_surface_count():
			var actuel := mesh.surface_get_material(s)
			if actuel == null:
				continue
			var nom := actuel.resource_name
			# Blender suffixe parfois les doublons (« inox.001 »).
			var p := nom.find(".")
			if p > 0:
				nom = nom.substr(0, p)
			var m := materiau(nom)
			if m != null:
				mesh.surface_set_material(s, m)
		mesh.set_meta("mat_ok", true)
