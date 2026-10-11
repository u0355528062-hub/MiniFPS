extends Node
## Chargement des paquets de données (autoload « Paquets », chargé EN PREMIER).
## La version Windows est livrée en plusieurs zips de moins de 30 Mo : l'exécutable, le
## paquet principal (Urgences.pck) et des paquets de ressources « donnees_N.pck ». Tous se
## décompressent dans le même dossier ; ils sont montés ici avant le reste du jeu.

func _init() -> void:
	if OS.has_feature("editor"):
		return
	var dossier := OS.get_executable_path().get_base_dir()
	var d := DirAccess.open(dossier)
	if d == null:
		return
	var fichiers := Array(d.get_files())
	fichiers.sort()
	for f in fichiers:
		if f.begins_with("donnees_") and f.ends_with(".pck"):
			if not ProjectSettings.load_resource_pack(dossier.path_join(f)):
				push_error("Paquet de données illisible : " + f)
