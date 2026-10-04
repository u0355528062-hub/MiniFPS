class_name Sfx
extends Node
## Sons synthétisés au lancement (aucun fichier) : bips du moniteur, instruments, réussite,
## erreur, incision, coup de ciseaux, ambiance du bloc (ventilation).

const RATE := 44100

static var instance: Sfx

var streams := {}
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
