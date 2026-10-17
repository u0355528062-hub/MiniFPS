class_name Records
extends RefCounted
## Sauvegarde (user://records.cfg) : meilleur résultat de chaque cas (note, points et temps, affichés
## sur la carte du cas en entraînement ; l'écran de fin signale un nouveau record) et progression
## de l'histoire « Première garde ».

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


# ---------------------------------------------------------------- Mode histoire

## Progression de l'histoire « Première garde » : prochain patient (0 à 3), histoire finie au moins
## une fois, résultat de chaque patient {note, points, vivant}.
static func story() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {"chapter": 0, "done": false, "results": {}}
	if cfg.load(PATH) != OK or not cfg.has_section("histoire"):
		return out
	out["chapter"] = int(cfg.get_value("histoire", "chapitre", 0))
	out["done"] = bool(cfg.get_value("histoire", "terminee", false))
	out["results"] = cfg.get_value("histoire", "resultats", {})
	return out


static func save_story(chapter: int, results: Dictionary, done := false) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("histoire", "chapitre", chapter)
	cfg.set_value("histoire", "resultats", results)
	cfg.set_value("histoire", "terminee", done or bool(cfg.get_value("histoire", "terminee", false)))
	cfg.save(PATH)
