extends Node
## Profileur léger (autoload « Profileur ») : chaque système mesure son coût par image.
##   var t := Profileur.debut()
##   … travail …
##   Profileur.fin("moniteurs", t)
## Les totaux par image (µs) sont lissés et lisibles par le test de performance et le HUD (F3).

var couts := {}       # nom -> µs moyens par image (moyenne glissante)
var _image := {}      # nom -> µs accumulés pendant l'image en cours
var _compte := {}     # nom -> nombre d'appels pendant l'image


func _ready() -> void:
	process_priority = 1000  # passe après tout le monde : clôture l'image


static func debut() -> int:
	return Time.get_ticks_usec()


func fin(nom: String, t0: int) -> void:
	_image[nom] = _image.get(nom, 0) + (Time.get_ticks_usec() - t0)
	_compte[nom] = _compte.get(nom, 0) + 1


func _process(_delta: float) -> void:
	for k in _image:
		couts[k] = lerpf(couts.get(k, float(_image[k])), float(_image[k]), 0.1)
	for k in couts:
		if not _image.has(k):
			couts[k] = lerpf(couts[k], 0.0, 0.1)
	_image.clear()
	_compte.clear()


func resume() -> String:
	var lignes := []
	var noms := couts.keys()
	noms.sort()
	for k in noms:
		lignes.append("%s : %.0f µs" % [k, couts[k]])
	return "\n".join(lignes)
