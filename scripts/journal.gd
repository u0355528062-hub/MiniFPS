class_name Journal
extends RefCounted
## Tout ce que le soignant a fait et constaté, horodaté : sert au dossier (observations), à
## l'évaluation du cas et au compte rendu de fin.

var entries: Array[Dictionary] = []  ## {t, kind, text, data}


func add(time: float, kind: String, text := "", data := {}) -> void:
	entries.append({"t": time, "kind": kind, "text": text, "data": data})


func has(kind: String) -> bool:
	for e in entries:
		if e["kind"] == kind:
			return true
	return false


## Instant de la première occurrence (INF si jamais).
func first(kind: String) -> float:
	for e in entries:
		if e["kind"] == kind:
			return e["t"]
	return INF


func count(kind: String) -> int:
	var n := 0
	for e in entries:
		if e["kind"] == kind:
			n += 1
	return n


func last(kind: String) -> Dictionary:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i]["kind"] == kind:
			return entries[i]
	return {}


func all(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if e["kind"] == kind:
			out.append(e)
	return out


## Observations à montrer (celles qui ont un texte).
func notes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if String(e["text"]) != "":
			out.append(e)
	return out
