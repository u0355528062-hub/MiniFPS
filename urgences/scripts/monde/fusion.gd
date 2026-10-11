class_name Fusion
extends RefCounted
## Fusion de la géométrie statique : tous les maillages statiques d'une pièce sont regroupés
## en UN maillage par pièce, avec une surface par matériau. Des dizaines d'objets et des
## centaines d'appels de dessin (multipliés par chaque passe d'ombre) deviennent une poignée.
## Les collisions des meubles (StaticBody3D) sont conservées ; seuls les MeshInstance3D
## disparaissent. Un nœud dans le groupe « dynamique » (et ses enfants) n'est jamais fusionné.


static func fusionner(racine: Node3D, nom := "Fusion") -> MeshInstance3D:
	var par_mat := {}          # Material -> {v, n, t, uv, i}
	var a_supprimer: Array[Node] = []
	var inv := racine.global_transform.affine_inverse()
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		if not _fusionnable(mi, racine):
			continue
		var mesh: Mesh = mi.mesh
		var xf: Transform3D = inv * mi.global_transform
		var base_n := xf.basis.inverse().transposed()
		for s in mesh.get_surface_count():
			if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override if mi.material_override else mesh.surface_get_material(s)
			var arr := mesh.surface_get_arrays(s)
			var d: Dictionary = par_mat.get(mat, {})
			if d.is_empty():
				d = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(),
					"uv": PackedVector2Array(), "i": PackedInt32Array()}
				par_mat[mat] = d
			var decal: int = d["v"].size()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var tans = arr[Mesh.ARRAY_TANGENT]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var idx = arr[Mesh.ARRAY_INDEX]
			d["v"].append_array(xf * verts)
			if norms != null and norms.size() == verts.size():
				var nt: PackedVector3Array = Transform3D(base_n, Vector3.ZERO) * (norms as PackedVector3Array)
				if not base_n.is_conformal() or absf(base_n.get_scale().x - 1.0) > 0.001:
					for k in nt.size():
						nt[k] = nt[k].normalized()
				d["n"].append_array(nt)
			else:
				for k in verts.size():
					d["n"].append(Vector3.UP)
			if tans != null and tans.size() == verts.size() * 4:
				for k in verts.size():
					var tv := (xf.basis * Vector3(tans[k * 4], tans[k * 4 + 1], tans[k * 4 + 2])).normalized()
					d["t"].append_array([tv.x, tv.y, tv.z, tans[k * 4 + 3]])
			else:
				for k in verts.size():
					d["t"].append_array([1.0, 0.0, 0.0, 1.0])
			if uvs != null and uvs.size() == verts.size():
				d["uv"].append_array(uvs)
			else:
				var vide := PackedVector2Array()
				vide.resize(verts.size())
				d["uv"].append_array(vide)
			if idx != null and idx.size() > 0:
				for k in idx.size():
					d["i"].append(idx[k] + decal)
			else:
				for k in verts.size():
					d["i"].append(k + decal)
		a_supprimer.append(mi)
	var am := ArrayMesh.new()
	for mat in par_mat:
		var d: Dictionary = par_mat[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = d["v"]
		arr[Mesh.ARRAY_NORMAL] = d["n"]
		arr[Mesh.ARRAY_TANGENT] = d["t"]
		arr[Mesh.ARRAY_TEX_UV] = d["uv"]
		arr[Mesh.ARRAY_INDEX] = d["i"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	for n in a_supprimer:
		n.get_parent().remove_child(n)
		n.queue_free()
	var res := MeshInstance3D.new()
	res.name = nom
	res.mesh = am
	res.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	racine.add_child(res)
	return res


static func _fusionnable(mi: MeshInstance3D, racine: Node) -> bool:
	if mi.mesh == null or not mi.visible or mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
		return false
	var n: Node = mi
	while n and n != racine:
		if n.is_in_group("dynamique") or n is Skeleton3D:
			return false
		n = n.get_parent()
	return true
