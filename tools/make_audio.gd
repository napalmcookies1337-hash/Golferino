extends SceneTree
## Writes every sound in the game to res://audio, all synthesized here from scratch.
## Run with: Godot --headless --path . -s tools/make_audio.gd
## The game only loads the finished files, so this never runs during play.

const OUT_DIR := "res://audio"
const MUSIC_RATE := 24000
const SFX_RATE := 32000
const PEAK := 0.82
const NOTE_NAMES := { "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11 }
const CHORD_SHAPES := {
	"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
}

enum Wave { PULSE, TRIANGLE, NOISE }

var _rng := RandomNumberGenerator.new()
var _report: Array[String] = []


func _initialize() -> void:
	_rng.seed = 2026
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_make_music()
	_make_jingles()
	_make_sfx()
	for line in _report:
		print(line)
	print("audio finished")
	quit()


# --- Music ---


func _make_music() -> void:
	_save("music_course", _song_course(), MUSIC_RATE, true)
	_save("music_shop", _song_shop(), MUSIC_RATE, true)
	_save("music_boss", _song_boss(), MUSIC_RATE, true)


# A breezy shuffle in F major.
func _song_course() -> PackedFloat32Array:
	var a_start := "A4/2 C5/1 D5/1 C5/2 A4/2|F5/3 E5/1 D5/2 A4/2|Bb4/2 D5/1 F5/1 E5/2 D5/2|C5/3 Bb4/1 G4/2 E4/2"
	var a_one := a_start + "|F4/1 A4/1 C5/1 F5/1 E5/1 F5/1 G5/2|E5/2 C5/1 A4/1 E5/2 R/2|D5/2 F5/1 D5/1 Bb4/2 D5/2|C5/2 E5/1 G5/1 E5/2 C5/2"
	var a_two := a_start + "|D5/1 F5/1 Bb5/2 A5/1 G5/1 F5/2|E5/1 G5/1 C6/2 Bb5/1 G5/1 E5/2|F5/3 C5/1 A4/2 C5/2|F5/4 R/4"
	var bridge := "D5/3 F5/1 D5/2 Bb4/2|C5/2 E5/2 G5/2 E5/2|C5/3 E5/1 A5/2 E5/2|F5/2 D5/1 A4/1 D5/2 F5/2|G5/3 F5/1 D5/2 Bb4/2|E5/2 C5/1 E5/1 G5/2 Bb5/2|A5/2 F5/1 C5/1 A4/2 C5/2|E5/1 F5/1 G5/1 E5/1 C5/2 R/2"
	var chords_one := "F Dm Gm C7 F Am Bb C7"
	var chords_two := "F Dm Gm C7 Bb C7 F F"
	var chords_bridge := "Bb C7 Am Dm Gm C7 F C7"
	var melody: String = "|".join([a_one, a_two, bridge, a_two])
	var chords: String = " ".join([chords_one, chords_two, chords_bridge, chords_two])
	var song := _new_song(chords, 126.0, 0.33)
	_add_melody(song, melody, 0.30, 0.25, 0.0)
	_add_melody(song, melody, 0.09, 0.125, 3.0)
	_add_walking_bass(song, 0.36)
	_add_offbeat_stabs(song, 0.075, range(16, 24))
	_add_arpeggio(song, 0.085, 4, range(16, 24))
	_add_drums(song, [0, 4], [2, 6], [0, 1, 2, 3, 4, 5, 6, 7], 0.34, 0.1, 0.05)
	return _finish_song(song)


# A relaxed bossa in C major.
func _song_shop() -> PackedFloat32Array:
	var one := "E5/3 G5/1 E5/2 C5/2|A4/2 C5/1 E5/1 G5/2 E5/2|F5/3 A4/1 C5/2 D5/2|B4/2 D5/1 F5/1 D5/4|G5/3 E5/1 B4/2 D5/2|C#5/2 E5/1 G5/1 A5/2 G5/2|F5/2 D5/1 A4/1 F5/2 E5/2|D5/2 B4/1 G4/1 D5/2 R/2"
	var two := "C5/2 E5/1 G5/1 B5/2 G5/2|A5/3 G5/1 E5/2 C5/2|D5/2 F5/1 A5/1 C6/2 A5/2|G5/2 F5/1 D5/1 B4/2 R/2|E5/3 G5/1 B5/2 G5/2|A5/2 G5/1 E5/1 C#5/2 A4/2|D5/2 F5/1 A5/1 G5/2 F5/2|D5/2 B4/1 G4/1 B4/2 D5/2"
	var chords_row := "Cmaj7 Am7 Dm7 G7 Em7 A7 Dm7 G7"
	var song := _new_song(chords_row + " " + chords_row, 104.0, 0.0)
	_add_melody(song, one + "|" + two, 0.24, 0.5, 0.0)
	_add_bossa_bass(song, 0.34)
	_add_comp(song, [0, 3, 6], 0.075)
	_add_drums(song, [], [3, 6], [0, 2, 4, 6], 0.0, 0.05, 0.035)
	return _finish_song(song)


# A driving, tense chase in D minor.
func _song_boss() -> PackedFloat32Array:
	var verse := "D5/2 F5/1 A5/1 G#5/1 A5/1 F5/2|D5/1 E5/1 F5/1 G5/1 A5/2 D5/2|Bb5/2 A5/1 G5/1 F5/2 D5/2|C#5/2 E5/1 G5/1 A5/2 E5/2|D5/2 F5/1 A5/1 D6/2 A5/2|C6/2 A5/1 F5/1 C5/2 F5/2|G5/2 Bb5/1 G5/1 D5/2 G5/2|A5/1 G5/1 F5/1 E5/1 C#5/2 A4/2"
	var middle := "Bb4/3 D5/1 G5/2 Bb5/2|A5/3 F5/1 D5/2 A4/2|G5/3 Eb5/1 Bb4/2 G4/2|A4/2 C#5/1 E5/1 G5/2 A5/2|Bb5/3 A5/1 G5/2 D5/2|F5/3 E5/1 D5/2 A4/2|D5/2 F5/1 Bb5/1 A5/2 F5/2|E5/1 F5/1 G5/1 A5/1 C#6/2 A5/2"
	var chords_verse := "Dm Dm Bb A7 Dm F Gm A7"
	var chords_middle := "Gm Dm Eb A7 Gm Dm Bb A7"
	var melody: String = "|".join([verse, middle, verse])
	var chords: String = " ".join([chords_verse, chords_middle, chords_verse])
	var song := _new_song(chords, 152.0, 0.0)
	_add_melody(song, melody, 0.25, 0.25, 0.0)
	_add_melody(song, melody, 0.07, 0.5, 2.0)
	_add_pumping_bass(song, 0.36)
	_add_arpeggio(song, 0.08, 3, range(0, 24))
	_add_drums(song, [0, 2, 4, 6], [2, 6], [0, 1, 2, 3, 4, 5, 6, 7], 0.42, 0.17, 0.05)
	return _finish_song(song)


func _new_song(chords_text: String, bpm: float, swing: float) -> Dictionary:
	var chords: PackedStringArray = chords_text.split(" ", false)
	var eighth: float = 30.0 / bpm
	var total: float = float(chords.size()) * 8.0 * eighth
	var buffer := PackedFloat32Array()
	buffer.resize(int(round(total * float(MUSIC_RATE))))
	return { "chords": chords, "eighth": eighth, "swing": swing, "buffer": buffer, "rate": MUSIC_RATE }


# Where a step falls, in seconds: every odd eighth is pushed late when the song shuffles.
func _step_time(song: Dictionary, step: float) -> float:
	var eighth: float = song["eighth"]
	var at: float = step * eighth
	if posmod(int(floor(step)), 2) == 1:
		at += float(song["swing"]) * eighth
	return at


func _add_melody(song: Dictionary, text: String, volume: float, duty: float, delay_steps: float) -> void:
	var bars: PackedStringArray = text.split("|")
	if bars.size() != song["chords"].size():
		push_error("melody has %d bars but the song has %d" % [bars.size(), song["chords"].size()])
	var step: float = delay_steps
	for b in bars.size():
		var bar_steps: float = 0.0
		for token: String in bars[b].split(" ", false):
			var parts: PackedStringArray = token.split("/")
			var length: float = float(parts[1])
			if parts[0] != "R":
				var start: float = _step_time(song, step + bar_steps)
				var finish: float = _step_time(song, step + bar_steps + length)
				_note(song, start, finish - start, _freq(parts[0]), Wave.PULSE, volume, duty, 0.004, 0.09, 0.62, 0.05, 0.0035)
			bar_steps += length
		if not is_equal_approx(bar_steps, 8.0):
			push_error("bar %d of a melody lasts %s eighths" % [b + 1, bar_steps])
		step += 8.0


func _add_walking_bass(song: Dictionary, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		var tones: Array[float] = _chord_freqs(chords[bar], 2)
		var next_root: float = _chord_freqs(chords[(bar + 1) % chords.size()], 2)[0]
		var line: Array[float] = [tones[0], tones[1], tones[2], next_root * pow(2.0, 1.0 / 12.0) if next_root < tones[2] else next_root / pow(2.0, 1.0 / 12.0)]
		for beat in 4:
			var start: float = _step_time(song, float(bar * 8 + beat * 2))
			_note(song, start, float(song["eighth"]) * 1.7, line[beat], Wave.TRIANGLE, volume, 0.5, 0.003, 0.05, 0.8, 0.03, 0.0)


func _add_bossa_bass(song: Dictionary, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	var pattern: Array = [[0, 0, 3.0], [3, 2, 1.0], [4, 2, 3.0], [7, 0, 1.0]]
	for bar in chords.size():
		var tones: Array[float] = _chord_freqs(chords[bar], 2)
		for hit: Array in pattern:
			var start: float = _step_time(song, float(bar * 8 + int(hit[0])))
			_note(song, start, float(song["eighth"]) * float(hit[2]) * 0.92, tones[int(hit[1])], Wave.TRIANGLE, volume, 0.5, 0.004, 0.06, 0.75, 0.04, 0.0)


func _add_pumping_bass(song: Dictionary, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		var root: float = _chord_freqs(chords[bar], 2)[0]
		for step in 8:
			var freq: float = root * 2.0 if step % 4 == 3 else root
			var start: float = _step_time(song, float(bar * 8 + step))
			_note(song, start, float(song["eighth"]) * 0.8, freq, Wave.TRIANGLE, volume, 0.5, 0.002, 0.03, 0.7, 0.02, 0.0)


func _add_offbeat_stabs(song: Dictionary, volume: float, skip_bars: Array) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		if bar in skip_bars:
			continue
		for step in [1, 3, 5, 7]:
			for freq in _chord_freqs(chords[bar], 4).slice(0, 3):
				var start: float = _step_time(song, float(bar * 8 + step))
				_note(song, start, float(song["eighth"]) * 0.55, freq, Wave.PULSE, volume, 0.125, 0.002, 0.05, 0.3, 0.03, 0.0)


func _add_comp(song: Dictionary, steps: Array, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		for step: int in steps:
			for freq in _chord_freqs(chords[bar], 4):
				var start: float = _step_time(song, float(bar * 8 + step))
				_note(song, start, float(song["eighth"]) * 0.9, freq, Wave.PULSE, volume, 0.25, 0.006, 0.09, 0.35, 0.07, 0.0)


func _add_arpeggio(song: Dictionary, volume: float, octave: int, only_bars: Array) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		if not bar in only_bars:
			continue
		var tones: Array[float] = _chord_freqs(chords[bar], octave)
		tones.append(tones[0] * 2.0)
		for step in 8:
			var climb: int = step % (tones.size() * 2 - 2)
			var index: int = climb if climb < tones.size() else tones.size() * 2 - 2 - climb
			var start: float = _step_time(song, float(bar * 8 + step))
			_note(song, start, float(song["eighth"]) * 0.7, tones[index], Wave.PULSE, volume, 0.125, 0.002, 0.04, 0.45, 0.02, 0.0)


func _add_drums(song: Dictionary, kicks: Array, snares: Array, hats: Array, kick_volume: float, snare_volume: float, hat_volume: float) -> void:
	var bars: int = song["chords"].size()
	for bar in bars:
		for step: int in kicks:
			_kick(song, _step_time(song, float(bar * 8 + step)), kick_volume)
		for step: int in snares:
			_burst(song["buffer"], int(song["rate"]), _step_time(song, float(bar * 8 + step)), 0.11, snare_volume, 0.55, 0.3)
		for step: int in hats:
			var accent: float = 1.0 if step % 2 == 0 else 0.65
			_burst(song["buffer"], int(song["rate"]), _step_time(song, float(bar * 8 + step)), 0.03, hat_volume * accent, 1.0, 1.0)


func _finish_song(song: Dictionary) -> PackedFloat32Array:
	return song["buffer"]


func _chord_freqs(chord: String, octave: int) -> Array[float]:
	var split: int = 2 if chord.length() > 1 and (chord[1] == "b" or chord[1] == "#") else 1
	var root: int = _semitone(chord.substr(0, split), octave)
	var result: Array[float] = []
	for interval: int in CHORD_SHAPES[chord.substr(split)]:
		result.append(_semitone_freq(root + interval))
	return result


func _freq(note: String) -> float:
	var octave: int = int(note.substr(note.length() - 1))
	return _semitone_freq(_semitone(note.substr(0, note.length() - 1), octave))


func _semitone(name_part: String, octave: int) -> int:
	var value: int = int(NOTE_NAMES[name_part[0]])
	if name_part.length() > 1:
		value += 1 if name_part[1] == "#" else -1
	return value + (octave + 1) * 12


func _semitone_freq(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


# One note mixed into a song. Anything running past the end wraps round, so the loop is seamless.
func _note(song: Dictionary, start: float, length: float, freq: float, wave: int, volume: float, duty: float, attack: float, decay: float, sustain: float, release: float, vibrato: float) -> void:
	var buffer: PackedFloat32Array = song["buffer"]
	var rate: int = song["rate"]
	var first: int = int(start * float(rate))
	var count: int = int((length + release) * float(rate))
	var size: int = buffer.size()
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(rate)
		var vib: float = 1.0
		if vibrato > 0.0 and t > 0.12:
			vib = 1.0 + sin(t * TAU * 5.5) * vibrato
		var step: float = freq * vib / float(rate)
		phase = fmod(phase + step, 1.0)
		var env: float = _envelope(t, length, attack, decay, sustain, release)
		var sample: float = _pulse(phase, duty, step) if wave == Wave.PULSE else _triangle(phase)
		var at: int = posmod(first + i, size)
		buffer[at] += sample * env * volume
	song["buffer"] = buffer


func _kick(song: Dictionary, start: float, volume: float) -> void:
	if volume <= 0.0:
		return
	var buffer: PackedFloat32Array = song["buffer"]
	var rate: int = song["rate"]
	var first: int = int(start * float(rate))
	var count: int = int(0.13 * float(rate))
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(rate)
		var freq: float = lerpf(150.0, 48.0, minf(t / 0.06, 1.0))
		phase += freq / float(rate)
		var env: float = pow(1.0 - float(i) / float(count), 2.0)
		var at: int = posmod(first + i, buffer.size())
		buffer[at] += sin(phase * TAU) * env * volume
	song["buffer"] = buffer


# A short burst of low-pass noise. Wraps round, like the notes.
func _burst(buffer: PackedFloat32Array, rate: int, start: float, length: float, volume: float, open_from: float, open_to: float) -> void:
	var first: int = int(start * float(rate))
	var count: int = int(length * float(rate))
	var low: float = 0.0
	for i in count:
		var u: float = float(i) / float(count)
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), lerpf(open_from, open_to, u))
		var at: int = posmod(first + i, buffer.size())
		buffer[at] += low * pow(1.0 - u, 2.0) * volume


func _envelope(t: float, length: float, attack: float, decay: float, sustain: float, release: float) -> float:
	var level: float = 0.0
	if t < attack:
		level = t / attack
	elif t < attack + decay:
		level = lerpf(1.0, sustain, (t - attack) / decay)
	else:
		level = sustain
	if t > length:
		level *= maxf(1.0 - (t - length) / maxf(release, 0.001), 0.0)
	return level


# A pulse wave with its edges smoothed, so high notes don't turn harsh.
func _pulse(phase: float, duty: float, step: float) -> float:
	var value: float = 1.0 if phase < duty else -1.0
	value += _edge(phase, step)
	value -= _edge(fmod(phase - duty + 1.0, 1.0), step)
	return value


func _edge(t: float, step: float) -> float:
	if t < step:
		var x: float = t / step
		return x + x - x * x - 1.0
	if t > 1.0 - step:
		var x: float = (t - 1.0) / step
		return x * x + x + x + 1.0
	return 0.0


# Stepped into 16 levels, like an old sound chip.
func _triangle(phase: float) -> float:
	var value: float = 4.0 * absf(phase - 0.5) - 1.0
	return round(value * 7.5) / 7.5


# --- Short tunes ---


func _make_jingles() -> void:
	_save("jingle_holed", _jingle("C5/1 E5/1 G5/1 C6/3", "C4/3 G3/3", 150.0), SFX_RATE, false)
	_save("jingle_bogey", _jingle("E5/1 D5/1 C5/3", "C4/2 G3/3", 130.0), SFX_RATE, false)
	_save("jingle_birdie", _jingle("G5/1 C6/1 E6/1 G6/1 E6/1 G6/3", "C4/2 E4/2 G4/4", 170.0), SFX_RATE, false)
	_save("jingle_ace", _jingle("C5/1 C5/1 C5/1 E5/2 C5/1 G5/2 A5/1 B5/1 C6/1 D6/1 E6/1 G6/1 C7/6", "C4/2 G3/2 C4/2 G3/2 F3/2 G3/2 C4/6", 190.0), SFX_RATE, false)
	_save("jingle_win", _jingle("G4/1 C5/1 E5/1 G5/2 E5/1 G5/3 A5/1 G5/1 F5/1 E5/1 D5/1 E5/1 C5/1 E5/1 G5/1 C6/6", "C3/3 G3/3 C3/3 F3/3 G3/3 C3/1 G3/1 C4/4", 170.0), SFX_RATE, false)
	_save("jingle_lose", _jingle("A4/2 G#4/2 G4/2 F#4/6", "D3/2 C#3/2 C3/2 B2/6", 96.0), SFX_RATE, false)
	_save("jingle_game_over", _jingle("E5/2 C5/2 A4/2 F4/2 E4/6", "A2/4 F2/4 E2/6", 110.0), SFX_RATE, false)


func _jingle(lead: String, low: String, bpm: float) -> PackedFloat32Array:
	var eighth: float = 30.0 / bpm
	var song: Dictionary = { "eighth": eighth, "swing": 0.0, "rate": SFX_RATE, "chords": PackedStringArray() }
	var total: float = maxf(_steps_in(lead), _steps_in(low)) * eighth + 0.5
	var buffer := PackedFloat32Array()
	buffer.resize(int(total * float(SFX_RATE)))
	song["buffer"] = buffer
	_jingle_voice(song, lead, Wave.PULSE, 0.4)
	_jingle_voice(song, low, Wave.TRIANGLE, 0.45)
	return song["buffer"]


func _steps_in(text: String) -> float:
	var steps: float = 0.0
	for token: String in text.split(" ", false):
		steps += float(token.split("/")[1])
	return steps


func _jingle_voice(song: Dictionary, text: String, wave: int, volume: float) -> void:
	var step: float = 0.0
	for token: String in text.split(" ", false):
		var parts: PackedStringArray = token.split("/")
		var length: float = float(parts[1])
		var start: float = step * float(song["eighth"])
		_note(song, start, length * float(song["eighth"]), _freq(parts[0]), wave, volume, 0.25, 0.003, 0.05, 0.7, 0.09, 0.0)
		step += length


# --- Sound effects ---


func _make_sfx() -> void:
	_sfx("swing", _whoosh(0.24, 0.5, 0.1, 0.5))
	_sfx("hit_driver", _layer([_blip(620.0, 150.0, 0.09, Wave.TRIANGLE, 0.9), _noise_hit(0.05, 0.75, 1.0, 0.2)]))
	_sfx("hit_iron", _layer([_blip(1500.0, 800.0, 0.05, Wave.PULSE, 0.3), _blip(420.0, 220.0, 0.06, Wave.TRIANGLE, 0.7), _noise_hit(0.03, 0.6, 1.0, 0.4)]))
	_sfx("hit_putt", _layer([_blip(1100.0, 760.0, 0.035, Wave.TRIANGLE, 0.7), _noise_hit(0.012, 0.3, 1.0, 0.6)]))
	_sfx("hit_perfect", _sequence([[880.0, 0.06], [1319.0, 0.13]], Wave.PULSE, 0.5))
	_sfx("hit_full", _layer([_blip(180.0, 60.0, 0.22, Wave.TRIANGLE, 1.0), _noise_hit(0.14, 0.8, 0.9, 0.1), _sweep_up(500.0, 1700.0, 0.2, 0.28)]))
	_sfx("hit_miss", _layer([_blip(240.0, 110.0, 0.09, Wave.TRIANGLE, 0.8), _noise_hit(0.04, 0.5, 0.35, 0.1)]))
	_sfx("meter_press", _blip(740.0, 740.0, 0.04, Wave.PULSE, 0.5))
	_sfx("meter_tick", _blip(520.0, 520.0, 0.018, Wave.PULSE, 0.4))
	_sfx("bounce_grass", _layer([_blip(170.0, 85.0, 0.07, Wave.TRIANGLE, 0.9), _noise_hit(0.04, 0.3, 0.3, 0.08)]))
	_sfx("bounce_sand", _noise_hit(0.13, 0.7, 0.32, 0.04))
	_sfx("bounce_green", _layer([_blip(280.0, 160.0, 0.05, Wave.TRIANGLE, 0.85), _noise_hit(0.02, 0.2, 0.35, 0.1)]))
	_sfx("splash", _layer([_noise_hit(0.42, 0.85, 0.75, 0.05), _blip(320.0, 90.0, 0.14, Wave.TRIANGLE, 0.5)]))
	_sfx("cup", _cup_rattle())
	_sfx("pin", _layer([_blip(1760.0, 1740.0, 0.32, Wave.TRIANGLE, 0.7), _blip(2640.0, 2620.0, 0.2, Wave.TRIANGLE, 0.28)]))
	_sfx("coin", _sequence([[988.0, 0.06], [1319.0, 0.17]], Wave.PULSE, 0.45))
	_sfx("pad", _boing())
	_sfx("cart", _sequence([[392.0, 0.11], [0.0, 0.05], [392.0, 0.2]], Wave.PULSE, 0.55))
	_sfx("goose", _honk())
	_sfx("windmill", _layer([_blip(300.0, 120.0, 0.06, Wave.PULSE, 0.5), _noise_hit(0.05, 0.6, 0.5, 0.15)]))
	_sfx("sprinkler", _whoosh(0.3, 0.32, 0.9, 0.95))
	_sfx("door", _sequence([[523.0, 0.05], [784.0, 0.05], [1047.0, 0.12]], Wave.TRIANGLE, 0.7))
	_sfx("penalty", _sequence([[220.0, 0.12], [165.0, 0.26]], Wave.PULSE, 0.45))
	_sfx("mulligan", _sequence([[523.0, 0.07], [659.0, 0.07], [523.0, 0.07], [784.0, 0.16]], Wave.PULSE, 0.42))
	_sfx("trick", _sequence([[659.0, 0.05], [784.0, 0.05], [988.0, 0.05], [1319.0, 0.18]], Wave.PULSE, 0.45))
	_sfx("menu_move", _blip(620.0, 620.0, 0.03, Wave.PULSE, 0.38))
	_sfx("menu_ok", _sequence([[659.0, 0.05], [988.0, 0.1]], Wave.PULSE, 0.45))
	_sfx("menu_back", _sequence([[523.0, 0.05], [392.0, 0.09]], Wave.PULSE, 0.42))
	_sfx("denied", _sequence([[147.0, 0.08], [0.0, 0.03], [147.0, 0.12]], Wave.PULSE, 0.5))
	_sfx("buy", _sequence([[784.0, 0.05], [988.0, 0.05], [1175.0, 0.05], [1568.0, 0.2]], Wave.PULSE, 0.45))
	_sfx("equip", _sequence([[392.0, 0.05], [587.0, 0.09]], Wave.TRIANGLE, 0.75))
	_sfx("rival_cheat", _sequence([[622.0, 0.09], [587.0, 0.09], [554.0, 0.09], [523.0, 0.09], [494.0, 0.28]], Wave.PULSE, 0.45))
	_sfx("rival_turn", _sequence([[147.0, 0.1], [156.0, 0.18]], Wave.TRIANGLE, 0.85))
	_sfx("score_tick", _blip(1100.0, 1100.0, 0.02, Wave.PULSE, 0.3))
	_save("ambience", _ambience(), MUSIC_RATE, true)


func _sfx(sound_name: String, samples: PackedFloat32Array) -> void:
	_save("sfx_" + sound_name, samples, SFX_RATE, false)


func _blip(from_freq: float, to_freq: float, length: float, wave: int, volume: float) -> PackedFloat32Array:
	var count: int = int(length * float(SFX_RATE))
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i in count:
		var u: float = float(i) / float(count)
		var step: float = lerpf(from_freq, to_freq, u) / float(SFX_RATE)
		phase = fmod(phase + step, 1.0)
		var sample: float = _pulse(phase, 0.25, step) if wave == Wave.PULSE else _triangle(phase)
		var attack: float = minf(float(i) / 24.0, 1.0)
		out[i] = sample * attack * pow(1.0 - u, 1.4) * volume
	return out


func _sweep_up(from_freq: float, to_freq: float, length: float, volume: float) -> PackedFloat32Array:
	return _blip(from_freq, to_freq, length, Wave.PULSE, volume)


func _noise_hit(length: float, volume: float, open_from: float, open_to: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(length * float(SFX_RATE)))
	_burst(out, SFX_RATE, 0.0, length, volume, open_from, open_to)
	return out


# Noise that swells and fades, as a club or spray moves through the air.
func _whoosh(length: float, volume: float, open_from: float, open_to: float) -> PackedFloat32Array:
	var count: int = int(length * float(SFX_RATE))
	var out := PackedFloat32Array()
	out.resize(count)
	var low: float = 0.0
	for i in count:
		var u: float = float(i) / float(count)
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), lerpf(open_from, open_to, sin(u * PI)))
		out[i] = low * sin(u * PI) * volume
	return out


func _sequence(steps: Array, wave: int, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for step: Array in steps:
		var freq: float = step[0]
		var length: float = step[1]
		if freq <= 0.0:
			var gap := PackedFloat32Array()
			gap.resize(int(length * float(SFX_RATE)))
			out.append_array(gap)
		else:
			out.append_array(_blip(freq, freq, length, wave, volume))
	return out


func _layer(parts: Array) -> PackedFloat32Array:
	var longest: int = 0
	for part: PackedFloat32Array in parts:
		longest = maxi(longest, part.size())
	var out := PackedFloat32Array()
	out.resize(longest)
	for part: PackedFloat32Array in parts:
		for i in part.size():
			out[i] += part[i]
	return out


func _place(out: PackedFloat32Array, part: PackedFloat32Array, at_seconds: float) -> void:
	var first: int = int(at_seconds * float(SFX_RATE))
	for i in part.size():
		if first + i < out.size():
			out[first + i] += part[i]


# The ball rattling round the cup, then dropping in.
func _cup_rattle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.5 * float(SFX_RATE)))
	_place(out, _blip(1500.0, 1300.0, 0.03, Wave.TRIANGLE, 0.6), 0.0)
	_place(out, _blip(1250.0, 1100.0, 0.03, Wave.TRIANGLE, 0.55), 0.08)
	_place(out, _blip(1050.0, 900.0, 0.03, Wave.TRIANGLE, 0.5), 0.15)
	_place(out, _blip(320.0, 130.0, 0.2, Wave.TRIANGLE, 0.9), 0.22)
	return out


func _boing() -> PackedFloat32Array:
	var count: int = int(0.3 * float(SFX_RATE))
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i in count:
		var u: float = float(i) / float(count)
		var freq: float = lerpf(180.0, 620.0, sqrt(u)) * (1.0 + sin(u * TAU * 7.0) * 0.14)
		phase = fmod(phase + freq / float(SFX_RATE), 1.0)
		out[i] = _triangle(phase) * pow(1.0 - u, 1.1) * 0.85
	return out


func _honk() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.34 * float(SFX_RATE)))
	for start: float in [0.0, 0.17]:
		var count: int = int(0.13 * float(SFX_RATE))
		var phase: float = 0.0
		for i in count:
			var u: float = float(i) / float(count)
			var step: float = lerpf(430.0, 330.0, u) / float(SFX_RATE)
			phase = fmod(phase + step, 1.0)
			var rough: float = 0.9 + _rng.randf_range(-0.1, 0.1)
			var at: int = int(start * float(SFX_RATE)) + i
			out[at] += _pulse(phase, 0.32, step) * sin(u * PI) * 0.5 * rough
	return out


# A soft outdoor loop: moving air and the odd bird. Both wrap, so the loop has no seam.
func _ambience() -> PackedFloat32Array:
	var count: int = 12 * MUSIC_RATE
	var out := PackedFloat32Array()
	out.resize(count)
	var low: float = 0.0
	for i in count * 2:
		var u: float = float(i % count) / float(count)
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.035)
		# The first pass only lets the filter settle, so the seam matches.
		if i >= count:
			var gust: float = 0.55 + 0.25 * sin(u * TAU * 2.0) + 0.2 * sin(u * TAU * 3.0 + 1.0)
			out[i % count] = low * gust * 0.7
	var song: Dictionary = { "buffer": out, "rate": MUSIC_RATE }
	for chirp: Array in [[1.2, 2350.0], [1.34, 2640.0], [1.48, 2350.0], [5.6, 2960.0], [5.72, 2640.0], [9.1, 2200.0], [9.24, 2490.0], [9.38, 2790.0]]:
		_note(song, float(chirp[0]), 0.07, float(chirp[1]), Wave.TRIANGLE, 0.05, 0.5, 0.01, 0.03, 0.6, 0.03, 0.012)
	return song["buffer"]


# --- Saving ---


func _save(file_name: String, samples: PackedFloat32Array, rate: int, loops: bool) -> void:
	var peak: float = 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain: float = PEAK / peak if peak > 0.0 else 1.0
	# Music and jingles share one level. Effects keep the balance they were written with, so a
	# meter tick stays quieter than a splash, and are only turned down if they'd clip.
	if file_name == "ambience":
		gain = minf(gain, 0.5)
	elif file_name.begins_with("sfx_"):
		gain = minf(gain, 1.0)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	var path: String = "%s/%s.res" % [OUT_DIR, file_name]
	var error: int = ResourceSaver.save(stream, path)
	if error != OK:
		push_error("couldn't save %s: %d" % [path, error])
	var seam: float = absf(samples[0] - samples[samples.size() - 1]) * gain if loops else 0.0
	_report.append("%-20s %6.2fs  raw peak %.2f%s" % [file_name, float(samples.size()) / float(rate), peak, "  seam jump %.3f" % seam if loops else ""])
