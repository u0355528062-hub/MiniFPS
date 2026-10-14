class_name Interactable
extends StaticBody3D
## Objet que le joueur peut viser et utiliser (zone du patient, appareil, chariot, ordinateur...).
## Le viseur le trouve par un rayon physique (couche Patient.LAYER_INTERACT) ; le jeu décide quoi
## faire de son identifiant.

var id := ""
var label := ""
var verb := "Utiliser"
var zone := ""  ## zone du patient (vue rapprochée), vide sinon
var enabled := true


static func make(parent: Node3D, p_id: String, p_label: String, p_verb: String, size: Vector3, center: Vector3, layer := 4) -> Interactable:
	var it := Interactable.new()
	it.id = p_id
	it.label = p_label
	it.verb = p_verb
	it.name = p_id.replace(":", "_")
	it.collision_layer = layer
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	parent.add_child(it)
	it.global_position = center
	return it
