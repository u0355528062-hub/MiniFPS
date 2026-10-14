class_name Inventory
extends RefCounted
## Ce que l'urgentiste a sur lui (stéthoscope, lampe) et ce qu'il a pris au chariot (électrodes,
## cathéter, seringues préparées...). Un objet est sélectionné (touches 1 à 9) : c'est lui qu'on
## utilise en vue rapprochée. Les objets posés sur le patient ou à usage unique disparaissent.

signal changed

## id -> nom, nombre d'utilisations (0 = illimité), modèle montré sous la souris
const ITEMS := {
	"main": {"name": "Mains", "uses": 0},
	"stetho": {"name": "Stéthoscope", "uses": 0, "model": "stethoscope"},
	"lampe": {"name": "Lampe stylo", "uses": 0, "model": "lampe"},
	"electrodes": {"name": "Électrodes du scope", "uses": 3},
	"spo2": {"name": "Capteur de SpO2", "uses": 1},
	"brassard": {"name": "Brassard à tension", "uses": 1},
	"pads": {"name": "Électrodes de défibrillation", "uses": 2, "model": "electrode_defib"},
	"ecg12": {"name": "Électrodes ECG (10)", "uses": 10},
	"garrot": {"name": "Garrot", "uses": 0, "model": "garrot"},
	"antiseptique": {"name": "Compresses + antiseptique", "uses": 0},
	"catheter18": {"name": "Cathéter 18G (vert)", "uses": 1},
	"catheter20": {"name": "Cathéter 20G (rose)", "uses": 1},
	"tubes": {"name": "Tubes de prélèvement", "uses": 1},
	"perfuseur": {"name": "NaCl 0,9 % 500 mL + tubulure", "uses": 1, "model": "poche"},
	"seringue": {"name": "Seringue", "uses": 1, "model": "seringue"},
	"bavu": {"name": "BAVU (ballon + masque)", "uses": 0, "model": "bavu"},
	"masque_o2": {"name": "Masque haute concentration", "uses": 1},
	"lunettes_o2": {"name": "Lunettes à oxygène", "uses": 1},
	"nebuliseur": {"name": "Masque de nébulisation", "uses": 1},
	"glucometre": {"name": "Lecteur de glycémie", "uses": 0, "model": "glucometre"},
	"thermometre": {"name": "Thermomètre tympanique", "uses": 0, "model": "thermometre"},
	"lucas": {"name": "LUCAS (massage automatique)", "uses": 1},
}
const MAX := 9

var items: Array[Dictionary] = []
var selected := 0


func _init() -> void:
	for id in ["main", "stetho", "lampe"]:
		items.append(_make(id))


func _make(id: String, data := {}) -> Dictionary:
	var d: Dictionary = ITEMS[id]
	var it := {"id": id, "name": d["name"], "uses": d["uses"], "data": data}
	if data.has("name"):
		it["name"] = data["name"]
	return it


func has(id: String) -> bool:
	return find(id) >= 0


func find(id: String) -> int:
	for i in items.size():
		if items[i]["id"] == id:
			return i
	return -1


func full() -> bool:
	return items.size() >= MAX


## Prendre un objet (une seringue préparée a ses données : médicament, dose, voie).
func add(id: String, data := {}) -> bool:
	if items.size() >= MAX:
		return false
	if id != "seringue" and id != "nebuliseur" and has(id):
		return false
	items.append(_make(id, data))
	selected = items.size() - 1
	changed.emit()
	return true


func current() -> Dictionary:
	return items[selected] if selected < items.size() else items[0]


func current_id() -> String:
	return String(current()["id"])


func select(i: int) -> void:
	if i >= 0 and i < items.size():
		selected = i
		changed.emit()


func select_id(id: String) -> void:
	var i := find(id)
	if i >= 0:
		select(i)


## Une utilisation de l'objet sélectionné (il disparaît quand il n'en a plus).
func use_current() -> void:
	var it := current()
	if int(it["uses"]) <= 0:
		return
	it["uses"] = int(it["uses"]) - 1
	if int(it["uses"]) <= 0:
		remove_at(selected)
	changed.emit()


func remove_at(i: int) -> void:
	if i < 0 or i >= items.size() or i < 3:
		return
	items.remove_at(i)
	selected = clampi(selected, 0, items.size() - 1)
	if selected >= items.size():
		selected = 0
	changed.emit()


func remove_id(id: String) -> void:
	remove_at(find(id))


func label(i: int) -> String:
	var it := items[i]
	var d: Dictionary = ITEMS[it["id"]]
	var s := String(it["name"])
	if int(d["uses"]) > 1:
		s += " (%d)" % int(it["uses"])
	return s
