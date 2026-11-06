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
	"6": [0, 4, 7, 9],
}

## How loud the biome tracks sit on average, so they match the other music. Bass needs a little
## more than the rest to sound as loud.
const TARGET_RMS := { "music_grassy": 0.19, "music_isles": 0.17, "music_swamp": 0.24, "music_swamp_boss": 0.26 }

enum Wave { PULSE, TRIANGLE, NOISE, SAW, SINE, KEYS }

var _rng := RandomNumberGenerator.new()
var _report: Array[String] = []


func _initialize() -> void:
	_rng.seed = 2026
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_make_music()
	_make_jingles()
	_make_sfx()
	# Written last, so the noise in everything above comes out the same as it always has.
	_make_biome_music()
	for line in _report:
		print(line)
	print("audio finished")
	quit()


# --- Music ---


func _make_music() -> void:
	_save("music_title", _song_title(), MUSIC_RATE, true)
	_save("music_shop", _song_shop(), MUSIC_RATE, true)
	_save("music_boss", _song_boss(), MUSIC_RATE, true)


func _make_biome_music() -> void:
	_save("music_grassy", _song_grassy(), MUSIC_RATE, true)
	_save("music_swamp", _song_swamp(), MUSIC_RATE, true)
	_save("music_swamp_boss", _song_swamp_boss(), MUSIC_RATE, true)
	_save("music_isles", _song_isles(), MUSIC_RATE, true)
	_sfx("bounce_mud", _layer([_blip(120.0, 70.0, 0.09, Wave.TRIANGLE, 0.8), _noise_hit(0.08, 0.45, 0.2, 0.05)]))
	_sfx("frog", _croak())
	_sfx("vent", _whoosh(0.5, 0.55, 0.25, 0.5))
	# A snap of jaws over a low growl.
	_sfx("gator", _layer([_blip(95.0, 50.0, 0.3, Wave.TRIANGLE, 0.9), _noise_hit(0.05, 0.8, 0.9, 0.3), _blip(620.0, 240.0, 0.05, Wave.PULSE, 0.45)]))
	_save("ambience_swamp", _swamp_ambience(), MUSIC_RATE, true)


# Three quick, rough pulses, falling in pitch.
func _croak() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.32 * float(SFX_RATE)))
	for start: float in [0.0, 0.1, 0.2]:
		var count: int = int(0.08 * float(SFX_RATE))
		var phase: float = 0.0
		for i in count:
			var u: float = float(i) / float(count)
			var step: float = lerpf(210.0 - start * 120.0, 150.0 - start * 90.0, u) / float(SFX_RATE)
			phase = fmod(phase + step, 1.0)
			out[int(start * float(SFX_RATE)) + i] += _pulse(phase, 0.18, step) * sin(u * PI) * 0.5
	return out


# A warm, buzzing night: low air, crickets pulsing, and frogs answering each other. It all
# wraps, so the loop has no seam.
func _swamp_ambience() -> PackedFloat32Array:
	var count: int = 14 * MUSIC_RATE
	var out := PackedFloat32Array()
	out.resize(count)
	# Runs on past the end, and the start fades in from that overrun, so the loop has no seam.
	var overlap: int = MUSIC_RATE
	var air := PackedFloat32Array()
	air.resize(count + overlap)
	var low: float = 0.0
	for i in air.size():
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.02)
		air[i] = low
	for i in count:
		var u: float = float(i) / float(count)
		var value: float = air[i]
		if i < overlap:
			value = lerpf(air[count + i], air[i], float(i) / float(overlap))
		out[i] = value * (0.75 + 0.25 * sin(u * TAU * 2.0)) * 0.9
	var song: Dictionary = { "buffer": out, "rate": MUSIC_RATE }
	# Crickets: fast pulses, in bursts.
	for start: float in [0.4, 3.1, 5.7, 8.2, 11.0]:
		for j in 14:
			_note(song, start + float(j) * 0.055, 0.03, 3100.0, Wave.SINE, 0.018, 0.5, 0.004, 0.01, 0.7, 0.01, 0.0)
	# Frogs, far off.
	for croak: Array in [[1.5, 150.0], [1.72, 138.0], [6.4, 190.0], [6.62, 176.0], [6.84, 164.0], [10.2, 140.0], [12.5, 170.0], [12.72, 155.0]]:
		_note(song, float(croak[0]), 0.13, float(croak[1]), Wave.PULSE, 0.07, 0.18, 0.015, 0.05, 0.6, 0.04, 0.0)
	return song["buffer"]


# Grassy Greens: an upbeat small-group swing in Bb, played as a head and then a solo chorus.
func _song_grassy() -> PackedFloat32Array:
	var open_a := "D5/1 F5/1 G5/2 F5/1 D5/3|Bb4/1 D5/1 G5/3 F5/1 D5/2|Eb5/1 G5/1 Bb5/2 A5/1 G5/1 Eb5/2|F5/3 Eb5/1 C5/2 A4/2|D5/1 F5/1 A5/2 G5/1 F5/1 B4/2|C5/1 Eb5/1 G5/2 A5/1 F5/1 Eb5/2"
	var a_one := open_a + "|D5/1 F5/1 Bb5/2 B4/1 D5/1 F5/2|Eb5/1 C5/1 G4/2 A4/1 C5/1 Eb5/2"
	var a_two := open_a + "|D5/3 F5/1 Bb5/4|Ab5/1 F5/1 D5/1 Bb4/1 Ab4/2 R/2"
	var bridge := "G5/2 Bb5/1 G5/1 D5/2 Eb5/2|C5/1 Eb5/1 Gb5/2 F5/1 Eb5/1 C5/2|F5/2 A5/1 F5/1 D5/2 C5/2|B4/1 D5/1 F5/1 A5/1 G5/3 R/1|Eb5/2 G5/1 Eb5/1 C5/2 Bb4/2|A4/1 C5/1 Eb5/1 G5/1 F5/3 R/1|G5/1 F5/1 Eb5/1 D5/1 C5/2 Eb5/2|F5/1 A5/1 C6/2 A5/1 F5/1 Eb5/2"
	var solo_a := "F5/1 G5/1 A5/1 Bb5/1 D6/2 Bb5/2|G5/1 A5/1 Bb5/1 D6/1 C6/2 Bb5/2|G5/1 Bb5/1 Eb6/2 D6/1 C6/1 Bb5/2|A5/1 C6/1 F6/2 Eb6/1 C6/1 A5/2|F5/1 A5/1 C6/1 A5/1 B5/1 G5/1 F5/1 D5/1|Eb5/1 G5/1 C6/1 G5/1 F5/1 A5/1 C6/1 Eb6/1|D6/2 Bb5/1 F5/1 G5/1 B5/1 D6/1 F6/1|Eb6/1 C6/1 G5/1 Eb5/1 C6/1 A5/1 F5/1 Eb5/1"
	var chords_one := "Bbmaj7 Gm7 Cm7 F7 Dm7/G7 Cm7/F7 Bb6/G7 Cm7/F7"
	var chords_two := "Bbmaj7 Gm7 Cm7 F7 Dm7/G7 Cm7/F7 Bbmaj7 Bb7"
	var chords_bridge := "Ebmaj7 Ab7 Dm7 G7 Cm7 F7 Cm7 F7"
	var chords: String = " ".join([chords_one, chords_two, chords_bridge, chords_one, chords_one, chords_bridge])
	var song := _new_song(chords, 168.0, 0.3)
	var horns: Dictionary = _stem(song)
	var head: String = "|".join([a_one, a_two, bridge, a_one])
	var horn_shape: Array = [0.012, 0.07, 0.72, 0.05]
	_line(horns, head, 0, Wave.SAW, 0.34, 0.5, 0.86, horn_shape, 0.004)
	# A second horn an octave down fills out the head.
	_line(horns, head, 0, Wave.SAW, 0.13, 0.5, 0.86, horn_shape, 0.0, 0.5)
	# The solo chorus's bridge goes to the horn, with the piano answering it on the A.
	_line(horns, bridge, 40, Wave.SAW, 0.3, 0.5, 0.8, horn_shape, 0.004)
	_lowpass(horns["buffer"], 0.42)
	_mix(song, horns, 1.0)
	_line(song, solo_a, 32, Wave.KEYS, 0.27, 0.5, 0.8, [0.003, 0.14, 0.45, 0.07])
	_add_jazz_bass(song, 0.5)
	_add_jazz_comp(song, 0.085)
	_add_jazz_drums(song)
	_soft_clip(song["buffer"], 1.1)
	return _finish_song(song)


# Swampy Shores: a slow, heavy head-nod in E, all dirty bass and booming kick.
func _song_swamp() -> PackedFloat32Array:
	var first := "E2/1.5 E2/0.5 R/1 G2/1 E2/1.5 D2/0.5 R/2"
	var second := "E2/1.5 E2/0.5 R/1 Bb2/1 A2/1 G2/1 E2/2"
	var last := "E2/1.5 E2/0.5 R/1 G2/0.5 A2/0.5 Bb2/1 A2/0.5 G2/0.5 F2/1 D2/1"
	var riff: String = "|".join([first, second, first, last])
	var turn := "C2/1.5 C2/0.5 R/1 E2/1 C2/1.5 Bb1/0.5 R/2|A1/1.5 A1/0.5 R/1 C2/1 A1/1.5 G1/0.5 R/2|C2/1.5 C2/0.5 R/1 E2/1 C2/1.5 Bb1/0.5 R/2|Bb1/1.5 Bb1/0.5 R/1 D2/0.5 F2/0.5 Bb2/1 F2/1 D2/1 B1/1"
	var bass_line: String = "|".join([riff, riff, riff, turn, riff, riff])
	var chords: String = " ".join(["Em Em Em Em", "Em Em Em Em", "Em Em Em Em", "C Am C Bb", "Em Em Em Em", "Em Em Em Em"])
	var song := _new_song(chords, 92.0, 0.0)
	var bars: int = song["chords"].size()
	var kick_steps: Array[float] = [0.0, 1.5, 3.5, 4.5]
	var kicks: Array[float] = []

	var drums: Dictionary = _stem(song)
	for bar in bars:
		for step: float in kick_steps:
			# The first four bars hold back, so the full beat lands as an arrival.
			if bar >= 2 or step == 0.0 or step == 4.5:
				var at: float = _step_time(song, float(bar * 8) + step)
				_boom(drums, at, 0.85, 0.34, 125.0, 44.0)
				kicks.append(at)
		for step: float in [2.0, 6.0]:
			_snare(drums, _step_time(song, float(bar * 8) + step), 0.42, 0.17, 0.55)
		for i in 16:
			# A gap every so often keeps the hats from ticking like a clock.
			if bar >= 2 and i % 8 != 7:
				var strong: float = 1.0 if i % 2 == 0 else 0.55
				_hat(drums, _step_time(song, float(bar * 8) + float(i) * 0.5), 0.05 * strong, 0.028)
		if bar >= 2 and bar % 2 == 1:
			_hat(drums, _step_time(song, float(bar * 8) + 7.5), 0.09, 0.16)
	_drive(drums["buffer"], 1.5)

	var grit: Dictionary = _stem(song)
	var bass_shape: Array = [0.006, 0.08, 0.8, 0.03]
	_line(grit, bass_line, 0, Wave.SAW, 0.5, 0.5, 0.92, bass_shape)
	_line(grit, bass_line, 0, Wave.SAW, 0.5, 0.5, 0.92, bass_shape, 0.0, 1.007)
	_drive(grit["buffer"], 3.2)
	_lowpass(grit["buffer"], 0.16)
	_sidechain(grit, kicks, 0.3, 0.16)
	var sub: Dictionary = _stem(song)
	_line(sub, bass_line, 0, Wave.SINE, 0.55, 0.5, 0.92, bass_shape, 0.0, 0.5)
	_sidechain(sub, kicks, 0.55, 0.12)

	# Dub stabs from down the tunnel, only once the beat has landed.
	var stabs: Dictionary = _stem(song)
	for bar in range(4, bars):
		if bar % 2 == 0:
			for step: float in [3.5, 7.0]:
				var token: String = str(song["chords"][bar])
				for freq in _chord_freqs(token, 3):
					_note(stabs, _step_time(song, float(bar * 8) + step), 0.09, freq, Wave.SAW, 0.12, 0.5, 0.003, 0.06, 0.3, 0.05, 0.0)
	_lowpass(stabs["buffer"], 0.14)
	_echo(stabs, song, 3.0, 0.5, 4)

	# A sour little hook over the last stretch.
	var hook: Dictionary = _stem(song)
	var hook_text := "E4/3 G4/1 Bb4/2 A4/2|G4/4 E4/2 R/2|E4/3 G4/1 B4/2 C5/2|Bb4/2 A4/2 G4/2 F4/2|E4/3 G4/1 Bb4/2 A4/2|G4/4 E4/2 R/2|D5/2 C5/2 Bb4/2 G4/2|F4/2 E4/4 R/2"
	_line(hook, hook_text, 16, Wave.PULSE, 0.17, 0.14, 0.82, [0.01, 0.1, 0.6, 0.08], 0.006)
	_lowpass(hook["buffer"], 0.3)
	_echo(hook, song, 1.5, 0.3, 2)

	_add_crackle(song, 90, 0.05)
	_add_ribbit(song, _step_time(song, 7.0 * 8.0 + 4.0), 0.1)
	_add_ribbit(song, _step_time(song, 15.0 * 8.0 + 4.5), 0.1)
	_add_ribbit(song, _step_time(song, 23.0 * 8.0 + 2.0), 0.1)
	_mix(song, sub, 0.9)
	_mix(song, grit, 0.72)
	_mix(song, drums, 0.85)
	_mix(song, stabs, 0.7)
	_mix(song, hook, 0.8)
	_soft_clip(song["buffer"], 0.8)
	return _finish_song(song)


# The swamp's rival: the same dirt at nearly double the speed, with nowhere to breathe.
func _song_swamp_boss() -> PackedFloat32Array:
	var run_one: String = _sixteenths("E2 E2 E3 E2 G2 E2 Bb2 E2 A2 E2 G2 E2 F2 E2 D2 E2")
	var run_two: String = _sixteenths("E2 E2 E3 E2 G2 E2 Bb2 A2 G2 E2 D2 E2 F2 F2 G2 Bb2")
	var run_up: String = _sixteenths("E2 F2 G2 Bb2 E2 F2 G2 Bb2 E3 D3 C3 Bb2 G2 F2 E2 D2")
	var on_c: String = _sixteenths("C2 C2 C3 C2 Eb2 C2 G2 C2 F2 C2 Eb2 C2 D2 C2 B1 C2")
	var on_bb: String = _sixteenths("Bb1 Bb1 Bb2 Bb1 D2 Bb1 F2 Bb1 Eb2 Bb1 D2 Bb1 C2 Bb1 A1 Bb1")
	var on_b: String = _sixteenths("B1 B1 B2 B1 D#2 B1 F#2 B1 A2 B1 F#2 B1 D#2 B1 C2 D2")
	var verse: String = "|".join([run_one, run_two, run_one, run_two, run_one, run_two, run_one, run_up])
	var middle: String = "|".join([on_c, on_c, on_bb, on_bb, on_c, on_c, on_b, on_b])
	var bass_line: String = "|".join([verse, middle, verse, middle])
	var chords_verse := "Em Em Em Em Em Em Em Em"
	var chords_middle := "C C Bb Bb C C B7 B7"
	var chords: String = " ".join([chords_verse, chords_middle, chords_verse, chords_middle])
	var song := _new_song(chords, 172.0, 0.0)
	var bars: int = song["chords"].size()
	var kicks: Array[float] = []

	var drums: Dictionary = _stem(song)
	for bar in bars:
		var fill: bool = bar % 8 == 7
		for step: float in [0.0, 1.5, 3.5, 5.0]:
			var at: float = _step_time(song, float(bar * 8) + step)
			_boom(drums, at, 0.85, 0.16, 170.0, 52.0)
			kicks.append(at)
		for step: float in [2.0, 6.0]:
			_snare(drums, _step_time(song, float(bar * 8) + step), 0.46, 0.11, 0.65)
		for step: float in [4.5, 7.5]:
			_snare(drums, _step_time(song, float(bar * 8) + step), 0.13, 0.05, 0.7)
		for i in 16:
			var strong: float = 1.0 if i % 2 == 0 else 0.6
			_hat(drums, _step_time(song, float(bar * 8) + float(i) * 0.5), 0.05 * strong, 0.022)
		if fill:
			for i in 8:
				_snare(drums, _step_time(song, float(bar * 8) + 4.0 + float(i) * 0.5), 0.14 + 0.035 * float(i), 0.05, 0.7)
	_drive(drums["buffer"], 1.8)

	var grit: Dictionary = _stem(song)
	var bass_shape: Array = [0.003, 0.05, 0.75, 0.015]
	_line(grit, bass_line, 0, Wave.SAW, 0.5, 0.5, 0.9, bass_shape)
	_line(grit, bass_line, 0, Wave.SAW, 0.5, 0.5, 0.9, bass_shape, 0.0, 1.009)
	_drive(grit["buffer"], 4.5)
	_lowpass(grit["buffer"], 0.2)
	_sidechain(grit, kicks, 0.5, 0.08)
	var sub: Dictionary = _stem(song)
	_line(sub, bass_line, 0, Wave.SINE, 0.45, 0.5, 0.9, bass_shape, 0.0, 0.5)

	# An alarm of a lead that never settles: two notes a half step apart, then a scramble.
	var alarm: Dictionary = _stem(song)
	var alarm_one: String = _sixteenths("E5 F5 E5 F5 E5 F5 G5 F5 E5 F5 E5 F5 Bb5 A5 G5 F5")
	var alarm_two: String = _sixteenths("E5 G5 Bb5 E6 Bb5 G5 E5 G5 F5 A5 C6 F6 C6 A5 F5 D5")
	var alarm_c: String = _sixteenths("C5 Eb5 G5 C6 G5 Eb5 C5 Eb5 D5 F5 Bb5 D6 Bb5 F5 D5 B4")
	var alarm_verse: String = "|".join([alarm_one, alarm_one, alarm_two, alarm_one, alarm_one, alarm_one, alarm_two, alarm_two])
	var alarm_middle: String = "|".join([alarm_c, alarm_c, alarm_c, alarm_c, alarm_c, alarm_c, alarm_c, alarm_c])
	_line(alarm, alarm_verse, 16, Wave.PULSE, 0.13, 0.3, 0.75, [0.002, 0.03, 0.55, 0.015])
	_line(alarm, alarm_middle, 8, Wave.PULSE, 0.09, 0.3, 0.75, [0.002, 0.03, 0.55, 0.015])
	_line(alarm, alarm_middle, 24, Wave.PULSE, 0.13, 0.3, 0.75, [0.002, 0.03, 0.55, 0.015])
	_drive(alarm["buffer"], 2.0)
	_lowpass(alarm["buffer"], 0.38)

	_add_crackle(song, 80, 0.04)
	_mix(song, sub, 0.85)
	_mix(song, grit, 0.72)
	_mix(song, drums, 0.85)
	_mix(song, alarm, 0.65)
	_soft_clip(song["buffer"], 0.7)
	return _finish_song(song)


# Floating Isles: slow bells and soft air in D, with no drums at all.
func _song_isles() -> PackedFloat32Array:
	var a := "F#5/3 A5/1 D6/4|B5/3 A5/1 F#5/4|D5/2 F#5/2 B5/4|A5/3 G5/1 D5/4|E5/2 G5/2 B5/4|A5/3 C#6/1 E6/4|F#6/4 D6/2 A5/2|E6/3 C#6/1 A5/4"
	var b := "D6/3 B5/1 G5/4|C#6/3 A5/1 F#5/4|B5/2 G5/2 E5/4|C#5/2 E5/2 A5/4|D6/3 F#6/1 B5/4|G5/2 B5/2 D6/4|E6/3 D6/1 B5/4|A5/3 G5/1 E5/4"
	var chords_a := "Dmaj7 Gmaj7 Bm7 Gmaj7 Em7 A7 Dmaj7 A7"
	var chords_b := "Gmaj7 F#m7 Em7 A7 Bm7 Gmaj7 Em7 A7"
	var song := _new_song(" ".join([chords_a, chords_b, chords_a]), 84.0, 0.0)
	var bars: int = song["chords"].size()

	var pad: Dictionary = _stem(song)
	var bar_time: float = float(song["eighth"]) * 8.0
	for bar in bars:
		var start: float = _step_time(song, float(bar * 8))
		var chord: String = song["chords"][bar]
		for freq in _chord_freqs(chord, 3):
			_note(pad, start, bar_time, freq, Wave.SINE, 0.16, 0.5, 0.75, 0.2, 0.9, 0.8, 0.0)
			_note(pad, start, bar_time, freq * 2.006, Wave.SINE, 0.05, 0.5, 0.9, 0.2, 0.9, 0.8, 0.0)
		_note(pad, start, bar_time * 0.85, _chord_freqs(chord, 2)[0], Wave.SINE, 0.2, 0.5, 0.25, 0.4, 0.7, 0.6, 0.0)

	var bells: Dictionary = _stem(song)
	var bell_shape: Array = [0.004, 0.7, 0.12, 0.5]
	_line(bells, "|".join([a, b, a]), 0, Wave.KEYS, 0.3, 0.5, 1.0, bell_shape)
	# High, quiet notes drifting through the middle.
	for bar in range(8, 16):
		var tones: Array[float] = _chord_freqs(song["chords"][bar], 5)
		for i in 4:
			var at: float = _step_time(song, float(bar * 8) + 1.0 + float(i) * 2.0)
			_note(bells, at, 0.3, tones[(bar + i) % tones.size()], Wave.KEYS, 0.07, 0.5, 0.004, 0.4, 0.08, 0.4, 0.0)
	_echo(bells, song, 3.0, 0.42, 4)

	_mix(song, pad, 1.0)
	_mix(song, bells, 0.9)
	_add_air(song, 0.1)
	_soft_clip(song["buffer"], 1.05)
	return _finish_song(song)


# --- Tools for the biome music ---


# An empty buffer with the song's timing, to be treated on its own and then mixed in.
func _stem(song: Dictionary) -> Dictionary:
	var stem: Dictionary = song.duplicate()
	var buffer := PackedFloat32Array()
	buffer.resize(song["buffer"].size())
	stem["buffer"] = buffer
	return stem


func _mix(song: Dictionary, stem: Dictionary, gain: float) -> void:
	var into: PackedFloat32Array = song["buffer"]
	var from: PackedFloat32Array = stem["buffer"]
	for i in from.size():
		into[i] += from[i] * gain
	song["buffer"] = into


# Plays a written line from a given bar. Notes last their written length times the gate, and a
# ratio other than 1 retunes the line: 0.5 is an octave down, and a hair over 1 thickens it.
func _line(song: Dictionary, text: String, from_bar: int, wave: int, volume: float, duty: float, gate: float, shape: Array, vibrato: float = 0.0, ratio: float = 1.0) -> void:
	var bars: PackedStringArray = text.split("|")
	if from_bar + bars.size() > song["chords"].size():
		push_error("a line runs to bar %d of a %d bar song" % [from_bar + bars.size(), song["chords"].size()])
	for b in bars.size():
		var steps: float = 0.0
		for token: String in bars[b].split(" ", false):
			var parts: PackedStringArray = token.split("/")
			var length: float = float(parts[1])
			if parts[0] != "R":
				var at: float = float((from_bar + b) * 8) + steps
				var start: float = _step_time(song, at)
				var span: float = _step_time(song, at + length) - start
				_note(song, start, span * gate, _freq(parts[0]) * ratio, wave, volume, duty, float(shape[0]), float(shape[1]), float(shape[2]), float(shape[3]), vibrato)
			steps += length
		if not is_equal_approx(steps, 8.0):
			push_error("bar %d of a line lasts %s eighths" % [b + 1, steps])


func _sixteenths(names: String) -> String:
	var tokens: PackedStringArray = PackedStringArray()
	for note_name: String in names.split(" ", false):
		tokens.append(note_name + "/0.5")
	if tokens.size() != 16:
		push_error("expected 16 notes in: %s" % names)
	return " ".join(tokens)


# A walking bass. A bar can hold two chords, written "Cm7/F7", and each beat steps toward the
# next chord's root.
func _add_jazz_bass(song: Dictionary, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		var parts: PackedStringArray = chords[bar].split("/")
		var next_root: float = _chord_freqs(chords[(bar + 1) % chords.size()].split("/")[0], 2)[0]
		var tones: Array[float] = _chord_freqs(parts[0], 2)
		var line: Array[float] = []
		if parts.size() > 1:
			var second: Array[float] = _chord_freqs(parts[1], 2)
			line = [tones[0], tones[2], second[0], _approach(next_root, second[0])]
		elif bar % 2 == 0:
			line = [tones[0], tones[1], tones[2], _approach(next_root, tones[2])]
		else:
			line = [tones[0], tones[2], tones[1], _approach(next_root, tones[1])]
		for beat in 4:
			var start: float = _step_time(song, float(bar * 8 + beat * 2))
			_note(song, start, float(song["eighth"]) * 1.75, line[beat], Wave.KEYS, volume, 0.5, 0.004, 0.14, 0.5, 0.04, 0.0)


func _approach(target: float, from: float) -> float:
	var half_step: float = pow(2.0, 1.0 / 12.0)
	return target * half_step if target < from else target / half_step


# Piano stabs on the first beat and the "and" of two. Leaving out the root, which the bass has.
func _add_jazz_comp(song: Dictionary, volume: float) -> void:
	var chords: PackedStringArray = song["chords"]
	for bar in chords.size():
		var parts: PackedStringArray = chords[bar].split("/")
		var hits: Array = [[0, parts[0]], [3, parts[parts.size() - 1]]]
		if bar % 4 == 3:
			hits.append([5, parts[parts.size() - 1]])
		for hit: Array in hits:
			var start: float = _step_time(song, float(bar * 8 + int(hit[0])))
			var tones: Array[float] = _chord_freqs(str(hit[1]), 3)
			for i in range(1, tones.size()):
				_note(song, start, float(song["eighth"]) * 0.8, tones[i] * 2.0 if i == 1 else tones[i], Wave.KEYS, volume, 0.5, 0.003, 0.12, 0.3, 0.05, 0.0)


# Ride cymbal on the swing pattern, the hi-hat closing on two and four, and a light kick.
func _add_jazz_drums(song: Dictionary) -> void:
	var bars: int = song["chords"].size()
	var buffer: PackedFloat32Array = song["buffer"]
	var rate: int = song["rate"]
	for bar in bars:
		for step: int in [0, 2, 3, 4, 6, 7]:
			var strong: float = 1.0 if step == 2 or step == 6 else 0.6
			_burst(buffer, rate, _step_time(song, float(bar * 8 + step)), 0.1, 0.075 * strong, 1.0, 0.85)
		for step: int in [2, 6]:
			_burst(buffer, rate, _step_time(song, float(bar * 8 + step)), 0.035, 0.055, 0.9, 0.5)
		for step: int in [0, 4]:
			_boom(song, _step_time(song, float(bar * 8 + step)), 0.16, 0.1, 110.0, 60.0)
		# A little snare chatter leading into each new eight bars.
		if bar % 8 == 7:
			for step: int in [3, 5, 6, 7]:
				_snare(song, _step_time(song, float(bar * 8 + step)), 0.13, 0.07, 0.55)
		elif bar % 2 == 1:
			_snare(song, _step_time(song, float(bar * 8 + 5)), 0.05, 0.05, 0.5)


# A long, low kick that slides down in pitch.
func _boom(song: Dictionary, start: float, volume: float, length: float, from_freq: float, to_freq: float) -> void:
	var buffer: PackedFloat32Array = song["buffer"]
	var rate: int = song["rate"]
	var first: int = int(start * float(rate))
	var count: int = int(length * float(rate))
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(rate)
		phase += lerpf(from_freq, to_freq, minf(t / 0.05, 1.0)) / float(rate)
		var u: float = float(i) / float(count)
		var attack: float = minf(float(i) / 12.0, 1.0)
		buffer[posmod(first + i, buffer.size())] += sin(phase * TAU) * pow(1.0 - u, 1.6) * attack * volume
	song["buffer"] = buffer


func _snare(song: Dictionary, start: float, volume: float, length: float, open: float) -> void:
	_burst(song["buffer"], int(song["rate"]), start, length, volume, open, open * 0.5)
	_note(song, start, length * 0.5, 185.0, Wave.SINE, volume * 0.55, 0.5, 0.001, 0.04, 0.2, 0.03, 0.0)


func _hat(song: Dictionary, start: float, volume: float, length: float) -> void:
	_burst(song["buffer"], int(song["rate"]), start, length, volume, 1.0, 1.0)


# Saturation: loud parts flatten and grow harmonics, which is where bass grit comes from.
func _drive(buffer: PackedFloat32Array, amount: float) -> void:
	for i in buffer.size():
		buffer[i] = tanh(buffer[i] * amount)


# The same, gentle enough to hold a finished mix together.
func _soft_clip(buffer: PackedFloat32Array, amount: float) -> void:
	_drive(buffer, amount)


# Takes the top off. The first pass only settles the filter, so the loop's seam matches.
func _lowpass(buffer: PackedFloat32Array, open: float) -> void:
	var low: float = 0.0
	for sample in buffer:
		low += (sample - low) * open
	for i in buffer.size():
		low += (buffer[i] - low) * open
		buffer[i] = low


# Dips a stem at each kick, then lets it swell back. That pumping is half of the bump.
func _sidechain(stem: Dictionary, times: Array[float], floor_gain: float, recover: float) -> void:
	var buffer: PackedFloat32Array = stem["buffer"]
	var rate: int = stem["rate"]
	var count: int = int(recover * float(rate))
	for time in times:
		var first: int = int(time * float(rate))
		for i in count:
			buffer[posmod(first + i, buffer.size())] *= lerpf(floor_gain, 1.0, float(i) / float(count))
	stem["buffer"] = buffer


# Repeats fading away. They wrap round, so the tail of the last bar falls into the first.
func _echo(stem: Dictionary, song: Dictionary, steps: float, feedback: float, repeats: int) -> void:
	var buffer: PackedFloat32Array = stem["buffer"]
	var dry: PackedFloat32Array = buffer.duplicate()
	var gap: int = int(steps * float(song["eighth"]) * float(song["rate"]))
	var size: int = buffer.size()
	for r in range(1, repeats + 1):
		var gain: float = pow(feedback, float(r))
		for i in size:
			buffer[(i + gap * r) % size] += dry[i] * gain
	stem["buffer"] = buffer


func _add_crackle(song: Dictionary, count: int, volume: float) -> void:
	var length: float = float(song["buffer"].size()) / float(song["rate"])
	for _i in count:
		_burst(song["buffer"], int(song["rate"]), _rng.randf_range(0.0, length), 0.004, volume * _rng.randf_range(0.4, 1.0), 1.0, 1.0)


# A frog, off in the dark.
func _add_ribbit(song: Dictionary, start: float, volume: float) -> void:
	for i in 3:
		_note(song, start + float(i) * 0.07, 0.04, 190.0 - float(i) * 12.0, Wave.PULSE, volume, 0.15, 0.003, 0.02, 0.6, 0.015, 0.0)


# Slow-moving air under the whole song. Its first pass settles the filter, so it has no seam.
func _add_air(song: Dictionary, volume: float) -> void:
	var buffer: PackedFloat32Array = song["buffer"]
	var count: int = buffer.size()
	var low: float = 0.0
	for i in count * 2:
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.05)
		if i >= count:
			var u: float = float(i - count) / float(count)
			var swell: float = 0.6 + 0.25 * sin(u * TAU * 4.0) + 0.15 * sin(u * TAU * 7.0 + 2.0)
			buffer[i - count] += low * swell * volume
	song["buffer"] = buffer


# A breezy shuffle in F major. Now the title screen's own tune.
func _song_title() -> PackedFloat32Array:
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
		var sample: float = 0.0
		match wave:
			Wave.PULSE:
				sample = _pulse(phase, duty, step)
			Wave.SAW:
				sample = _saw(phase, step)
			Wave.SINE:
				sample = sin(phase * TAU)
			Wave.KEYS:
				sample = _keys(phase, t)
			_:
				sample = _triangle(phase)
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


# A rising ramp, its jump smoothed like the pulse wave's edges.
func _saw(phase: float, step: float) -> float:
	return 2.0 * phase - 1.0 - _edge(phase, step)


# A struck tone: bright harmonics at the start, fading to something rounder.
func _keys(phase: float, t: float) -> float:
	var bright: float = exp(-t * 7.0)
	return sin(phase * TAU) + sin(phase * TAU * 2.0) * (0.12 + 0.3 * bright) + sin(phase * TAU * 4.0) * 0.14 * bright


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
	elif TARGET_RMS.has(file_name):
		var energy: float = 0.0
		for s in samples:
			energy += s * s
		gain = minf(gain, float(TARGET_RMS[file_name]) / sqrt(energy / float(samples.size())))
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
	var level_text: String = _level_text(samples, gain) if file_name.begins_with("music_") else ""
	_report.append("%-20s %6.2fs  raw peak %.2f%s%s" % [file_name, float(samples.size()) / float(rate), peak, "  seam jump %.3f" % seam if loops else "", level_text])


# How loud a song is on average, and how much of that is under roughly 150 Hz. Nobody here can
# hear the songs while writing them, so these keep the mix honest.
func _level_text(samples: PackedFloat32Array, gain: float) -> String:
	var low: float = 0.0
	var total_energy: float = 0.0
	var low_energy: float = 0.0
	for sample in samples:
		var value: float = sample * gain
		low += (value - low) * 0.04
		total_energy += value * value
		low_energy += low * low
	var rms: float = sqrt(total_energy / float(samples.size()))
	return "  rms %.3f  bass share %.0f%%" % [rms, 100.0 * low_energy / maxf(total_energy, 0.000001)]
