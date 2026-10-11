extends SceneTree
## Exporte toutes les répliques parlées en JSON pour la synthèse vocale :
## godot --headless --script tools/sons/extraire_repliques.gd   → tools/sons/repliques.json

func _initialize() -> void:
	var patho = load("res://scripts/medical/pathologies.gd")
	var rep = load("res://scripts/jeu/repliques.gd")
	var textes := {}
	for d in patho.LISTE:
		for k in d.get("reponses", {}):
			textes[d["reponses"][k]] = true
	for t in rep.toutes():
		textes[t] = true
	var liste := []
	for t in textes:
		liste.append({"texte": t, "md5": String(t).md5_text().substr(0, 12)})
	var f := FileAccess.open("res://tools/sons/repliques.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(liste, "\t"))
	f.close()
	print("répliques : ", liste.size())
	quit()
