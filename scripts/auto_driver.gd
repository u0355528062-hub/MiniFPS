class_name AutoDriver
extends BotDriver
## Robot de test « classique » : une main abstraite (AutoBot) dont on impose la pointe.

var bot: AutoBot


func setup(p_bot: AutoBot, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	bot = p_bot
	proc = p_proc
	patient = p_patient
	tray = p_tray
	prefix = "AUTOTEST"


func take(inst_id: String) -> void:
	bot.take_requested.emit(bot, tray.instruments[inst_id])
	await _frames(2)


func put_back_all() -> void:
	bot.bot_trigger = false
	if bot.held:
		bot.put_back_requested.emit(bot)
	await _frames(2)


func tip_to(p: Vector3, frames_n := 12) -> void:
	var from := bot.bot_tip
	for i in frames_n:
		bot.bot_tip = from.lerp(p, float(i + 1) / frames_n)
		await _frames(1)


func trigger(down: bool) -> void:
	bot.bot_trigger = down


func held_id() -> String:
	return bot.held.id if bot.held else ""
