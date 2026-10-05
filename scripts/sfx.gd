class_name Sfx
extends Node
## Sons synthétisés au lancement (aucun fichier) : bips du moniteur, instruments, réussite,
## erreur, incision, coup de ciseaux, ambiance du bloc (ventilation).

const RATE := 44100

static var instance: Sfx

var streams := {}
var loops := {}  ## sons continus : nom -> [lecteur, niveau voulu, rafraîchi cette image]
var _players: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	instance = self
	streams["bip"] = _tone([[1000.0, 1.0]], 0.09, 0.004, 0.02, 0.25)
	streams["bip_alarme"] = _tone([[880.0, 1.0], [1760.0, 0.2]], 0.16, 0.005, 0.03, 0.3)
	streams["prise"] = _metal(2400.0, 0.35, 0.3)
	streams["pose"] = _metal(1700.0, 0.25, 0.25)
	streams["succes"] = _chime([659.25, 987.77], 0.5)
	streams["etape"] = _chime([523.25, 659.25, 783.99], 0.6)
	streams["fin"] = _chime([523.25, 659.25, 783.99, 1046.5], 1.1)
	streams["erreur"] = _tone([[196.0, 1.0], [233.0, 0.6]], 0.32, 0.01, 0.08, 0.28)
	streams["incision"] = _noise(0.16, 2200.0, 0.22)
	streams["ciseaux"] = _snip()
	streams["badigeon"] = _noise(0.12, 900.0, 0.08)
	streams["fil"] = _noise(0.25, 3500.0, 0.06)
	streams["souffle"] = _noise(1.3, 5000.0, 0.16)
	streams["bulles"] = _bubbles()
	streams["aspiration"] = _noise(0.45, 1600.0, 0.14)
	streams["pique"] = _metal(5200.0, 0.06, 0.12)
	streams["plop"] = _thud()
	streams["ecarte"] = _squelch(0.35, 7)
	streams["survol"] = _tone([[2400.0, 1.0]], 0.03, 0.002, 0.02, 0.06)
	streams["clic"] = _tone([[1300.0, 1.0], [2600.0, 0.3]], 0.06, 0.002, 0.03, 0.12)
	streams["vue"] = _tone([[660.0, 1.0], [990.0, 0.5]], 0.18, 0.01, 0.1, 0.1)
	# Sons continus (en boucle, volume réglé à chaque image par le geste)
	streams["loop_badigeon"] = _loop_noise(900.0, 0.5, 11, 9.0)
	streams["loop_incision"] = _loop_noise(2600.0, 0.35, 12, 23.0)
	streams["loop_ecarte"] = _loop_noise(350.0, 0.6, 13, 5.0)
	streams["loop_piston"] = _squeak()
	streams["loop_fil"] = _loop_noise(4200.0, 0.18, 14, 17.0)
	streams["loop_aspiration"] = _loop_noise(1600.0, 0.4, 15, 3.0)
	streams["loop_sifflement"] = _loop_noise(6200.0, 0.4, 16, 29.0)
	streams["loop_ciseaux_coupe"] = _loop_noise(3200.0, 0.28, 17, 14.0)
	streams["loop_scie"] = _saw_buzz()
	streams["loop_bistouri_elec"] = _loop_noise(7000.0, 0.22, 19, 41.0)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 1.5
		p.max_db = 0.0
		add_child(p)
		_players.append(p)
	for i in 4:
		var f := AudioStreamPlayer.new()
		add_child(f)
		_flat.append(f)
	_ambience()


static func play(sound: String, at := Vector3.INF, volume_db := 0.0, pitch := 1.0) -> void:
	if instance == null or not instance.streams.has(sound):
		return
	instance._play(sound, at, volume_db, pitch)


func _play(sound: String, at: Vector3, volume_db: float, pitch: float) -> void:
	if at == Vector3.INF:
		for f in _flat:
			if not f.playing:
				f.stream = streams[sound]
				f.volume_db = volume_db
				f.pitch_scale = pitch
				f.play()
				return
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[sound]
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Son continu : à appeler à chaque image avec le niveau voulu (0 = silence). S'arrête tout seul.
static func loop(sound: String, at: Vector3, level: float) -> void:
	if instance == null or not instance.streams.has("loop_" + sound):
		return
	instance._loop(sound, at, level)


func _loop(sound: String, at: Vector3, level: float) -> void:
	if not loops.has(sound):
		var p := AudioStreamPlayer3D.new()
		p.stream = streams["loop_" + sound]
		p.unit_size = 1.5
		p.volume_db = -60.0
		add_child(p)
		loops[sound] = [p, 0.0, false, 0.0]
	var l: Array = loops[sound]
	l[1] = maxf(l[1], level) if l[2] else level
	l[2] = true
	(l[0] as AudioStreamPlayer3D).global_position = at


func _process(delta: float) -> void:
	for k in loops:
		var l: Array = loops[k]
		var p: AudioStreamPlayer3D = l[0]
		var want: float = l[1] if l[2] else 0.0
		l[2] = false
		var cur: float = move_toward(l[3], want, delta * (8.0 if want > l[3] else 4.0))
		l[3] = cur
		if cur > 0.01:
			p.volume_db = linear_to_db(cur) - 6.0
			if not p.playing:
				p.play()
		elif p.playing:
			p.stop()


## Scie sternale : moteur aigu (fondamentale et harmoniques) et crissement de l'os.
func _saw_buzz() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var motor := sin(TAU * 220.0 * t) * 0.35 + sin(TAU * 440.0 * t) * 0.22 + sin(TAU * 660.0 * t) * 0.12
		lp += (rng.randf_range(-1, 1) - lp) * 0.35
		var grind := lp * (0.6 + 0.4 * sin(TAU * 37.0 * t))
		d[i] = motor * 0.5 + grind * 0.5
	return _make_loop(d, 0.9)


func _loop_noise(cutoff: float, gain: float, seed_value: int, wobble: float) -> AudioStreamWAV:
	var n := int(RATE * 1.5)
	var d := PackedFloat32Array()
	d.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var lp := 0.0
	var lp2 := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in n:
		lp += (rng.randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		var t := float(i) / RATE
		d[i] = (lp - lp2 * 0.5) * (0.7 + 0.3 * sin(TAU * wobble * t + sin(TAU * 1.3 * t) * 2.0))
	return _make_loop(d, gain * 3.0)


func _squeak() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var d := PackedFloat32Array()
	d.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (640.0 + 60.0 * sin(TAU * 3.0 * t) + 25.0 * sin(TAU * 11.0 * t)) / RATE
		d[i] = (sin(ph) + 0.35 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)) * (0.6 + 0.4 * sin(TAU * 6.0 * t))
	return _make_loop(d, 0.05)


func _make_loop(data: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var n := data.size()
	var fade := 2000
	for i in fade:
		var k := float(i) / fade
		data[i] = data[i] * k + data[n - fade + i] * (1.0 - k)
	var s := _to_wav(data.slice(0, n - fade), gain)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n - fade
	return s


func _thud() -> AudioStreamWAV:
	var n := int(0.18 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t := float(i) / RATE
		d[i] = sin(TAU * (180.0 - 300.0 * t) * t) * exp(-t * 30.0) + rng.randf_range(-1, 1) * exp(-t * 90.0) * 0.3
	return _to_wav(d, 0.5)


## Bruit humide (tissus qui s'écartent).
func _squelch(dur: float, seed_value: int) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.06
		var crackle := 1.0 if rng.randf() < 0.004 else 0.0
		d[i] = (lp * 2.0 + crackle * rng.randf_range(-0.6, 0.6)) * _env(i, n, 0.02, dur * 0.7) * (0.6 + 0.4 * sin(TAU * 13.0 * t))
	return _to_wav(d, 0.5)


func _ambience() -> void:
	# Souffle du flux laminaire + ronronnement grave, en boucle
	var n := RATE * 4
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.05
		lp2 += (lp - lp2) * 0.08
		var hum := sin(TAU * 100.0 * i / RATE) * 0.05 + sin(TAU * 50.0 * i / RATE) * 0.07
		data[i] = lp2 * 0.9 + hum * 0.4
	# Fondu de bouclage
	var fade := 4000
	for i in fade:
		var k := float(i) / fade
		data[i] = data[i] * k + data[n - fade + i] * (1.0 - k)
	var s := _to_wav(data.slice(0, n - fade), 0.5)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n - fade
	var amb := AudioStreamPlayer.new()
	amb.stream = s
	amb.volume_db = -14.0
	amb.autoplay = true
	add_child(amb)


func _env(i: int, n: int, attack: float, release: float) -> float:
	var t := float(i) / RATE
	var dur := float(n) / RATE
	return minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))


func _tone(partials: Array, dur: float, attack: float, release: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var v := 0.0
		for p in partials:
			v += sin(TAU * p[0] * i / RATE) * p[1]
		d[i] = v * _env(i, n, attack, release)
	return _to_wav(d, gain)


func _metal(base: float, dur: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var ratios := [1.0, 2.76, 5.4, 8.93]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in ratios.size():
			v += sin(TAU * base * ratios[k] * t) * exp(-t * (18.0 + k * 14.0)) / (k + 1)
		d[i] = v * minf(1.0, t / 0.001)
	return _to_wav(d, gain)


func _chime(notes: Array, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var gap := 0.09
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var tk := t - k * gap
			if tk > 0.0:
				v += (sin(TAU * notes[k] * tk) + 0.3 * sin(TAU * notes[k] * 2.0 * tk)) * exp(-tk * 4.5) * minf(1.0, tk / 0.004)
		d[i] = v
	return _to_wav(d, 0.22)


func _noise(dur: float, cutoff: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff)
	for i in n:
		lp += (rng.randf_range(-1, 1) - lp) * a
		d[i] = lp * _env(i, n, 0.01, dur * 0.6)
	return _to_wav(d, gain * 3.0)


func _bubbles() -> AudioStreamWAV:
	var n := int(0.6 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var starts := []
	for k in 7:
		starts.append([rng.randf_range(0.0, 0.5), rng.randf_range(300.0, 700.0)])
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for b in starts:
			var tb: float = t - b[0]
			if tb > 0.0:
				v += sin(TAU * b[1] * (1.0 + tb * 3.0) * tb) * exp(-tb * 40.0)
		d[i] = v
	return _to_wav(d, 0.25)


func _snip() -> AudioStreamWAV:
	var n := int(0.12 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / RATE
		var click := exp(-t * 300.0) + 0.7 * exp(-maxf(t - 0.035, 0.0) * 260.0) * float(t > 0.035)
		d[i] = rng.randf_range(-1, 1) * click + sin(TAU * 3100.0 * t) * exp(-t * 60.0) * 0.4
	return _to_wav(d, 0.35)


func _to_wav(data: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
