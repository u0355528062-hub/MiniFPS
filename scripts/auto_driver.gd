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
	bot.bot_squeeze = 0.0
	if bot.held:
		bot.put_back_requested.emit(bot)
	await _frames(2)


func tip_to(p: Vector3, frames_n := 12) -> void:
	var from := bot.bot_tip
	for i in frames_n:
		bot.bot_tip = from.lerp(p, float(i + 1) / frames_n)
		await _frames(1)


func squeeze(v: float) -> void:
	bot.bot_squeeze = v


func held_id() -> String:
	return bot.held.id if bot.held else ""


func debug_state() -> String:
	var t := bot.tip()
	return "tenu=%s tip=%s brut=%s prof=%.4f corr=%.4f cut=[%.2f %.2f] st=%s" % [held_id(), t, bot.bot_tip, bot.held.tip_depth if bot.held else 0.0, bot.held.correction if bot.held else 0.0, patient.cut0, patient.cut1, proc.st]


func lift_clear() -> void:
	bot.bot_tip = Vector3(bot.bot_tip.x, maxf(bot.bot_tip.y, Patient.TABLE_TOP + 0.35), bot.bot_tip.z)
	await _frames(2)


func held_inst() -> Instrument:
	return bot.held
