class_name Records
extends RefCounted
## Meilleur résultat de chaque intervention (user://records.cfg) : note, points et temps, affichés
## sur la carte de l'intervention au menu ; l'écran de fin signale un nouveau record.

const PATH := "user://records.cfg"
const RANKS := ["D", "C", "B", "A", "S"]


static func best(op_id: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section(op_id):
		return {}
	return {"grade": str(cfg.get_value(op_id, "note", "")), "score": float(cfg.get_value(op_id, "points", 0.0)),
		"time": float(cfg.get_value(op_id, "temps", 0.0))}


## Enregistre le résultat s'il bat le meilleur (note, puis points, puis temps) ; vrai si record.
static func submit(op_id: String, grade: String, score: float, time: float) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	if cfg.has_section(op_id):
		var old_rank := RANKS.find(str(cfg.get_value(op_id, "note", "D")))
		var rank := RANKS.find(grade)
		var old_score := float(cfg.get_value(op_id, "points", 0.0))
		var old_time := float(cfg.get_value(op_id, "temps", INF))
		if rank < old_rank:
			return false
		if rank == old_rank:
			if score < old_score - 0.5:
				return false
			if absf(score - old_score) <= 0.5 and time >= old_time:
				return false
	cfg.set_value(op_id, "note", grade)
	cfg.set_value(op_id, "points", snappedf(score, 0.1))
	cfg.set_value(op_id, "temps", snappedf(time, 0.1))
	cfg.save(PATH)
	return true
