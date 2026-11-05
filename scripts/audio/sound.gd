extends Node
## Plays everything the player hears, and remembers the volume settings. Loaded for the whole
## game as "Sound". The sounds themselves come from tools/make_audio.gd.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const DEFAULT_SETTINGS_PATH := "user://settings.json"
const LEVELS := 10
const DEFAULT_MUSIC_LEVEL := 6
const DEFAULT_SFX_LEVEL := 8
const VOICES := 14
const FADE_TIME := 0.7
## The same effect can't restart sooner than this, so a burst of bounces doesn't turn harsh.
const MIN_GAP_MSEC := 45
## Music dips under a jingle, then comes back.
const DUCK_DB := -16.0
const DUCK_TIME := 0.15
const MUSIC_BASE_DB := -3.0
const AMBIENCE_DB := -6.0

const MUSIC_NAMES := ["course", "shop", "boss"]
const JINGLE_NAMES := ["holed", "bogey", "birdie", "ace", "win", "lose", "game_over"]
const SFX_NAMES := [
	"swing", "hit_driver", "hit_iron", "hit_putt", "hit_perfect", "hit_full", "hit_miss",
	"meter_press", "meter_tick", "bounce_grass", "bounce_sand", "bounce_green", "splash", "cup",
	"pin", "coin", "pad", "cart", "goose", "windmill", "sprinkler", "door", "penalty", "mulligan",
	"trick", "menu_move", "menu_ok", "menu_back", "denied", "buy", "equip", "rival_cheat",
	"rival_turn", "score_tick",
]

var music_level: int = DEFAULT_MUSIC_LEVEL
var sfx_level: int = DEFAULT_SFX_LEVEL
## Tests point this at their own file, so they never change the player's settings.
var settings_path: String = DEFAULT_SETTINGS_PATH
## The track playing now, or empty for silence.
var current_music: String = ""

var _sfx: Dictionary = {}
var _jingles: Dictionary = {}
var _tracks: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _duck: Tween
var _fade: Tween
var _jingle_serial: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus(MUSIC_BUS)
	_make_bus(SFX_BUS)
	for sound_name: String in SFX_NAMES:
		_sfx[sound_name] = load("res://audio/sfx_%s.res" % sound_name)
	for jingle_name: String in JINGLE_NAMES:
		_jingles[jingle_name] = load("res://audio/jingle_%s.res" % jingle_name)
	for i in VOICES:
		_voices.append(_make_player(SFX_BUS))
	_music_a = _make_player(MUSIC_BUS)
	_music_b = _make_player(MUSIC_BUS)
	_jingle = _make_player(SFX_BUS)
	_ambience = _make_player(SFX_BUS)
	_ambience.stream = load("res://audio/ambience.res")
	_ambience.volume_db = AMBIENCE_DB
	_load_settings()
	_apply_levels()


# Anything still sounding when the game quits would otherwise be left holding its stream.
func _exit_tree() -> void:
	_jingle_serial += 1
	for voice in _voices:
		voice.stream = null
	for player: AudioStreamPlayer in [_music_a, _music_b, _jingle, _ambience]:
		player.stream = null


## Plays one effect. Pitch changes it for variety, and volume is in decibels.
func sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sfx.has(sound_name):
		push_warning("no sound called %s" % sound_name)
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -100000)) < MIN_GAP_MSEC:
		return
	_last_played[sound_name] = now
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _sfx[sound_name]
	voice.pitch_scale = pitch
	voice.volume_db = volume_db
	voice.play()


## Moves to a track, fading across. The same track carries on, and an empty name fades out.
func music(track: String) -> void:
	if track == current_music:
		return
	current_music = track
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	var outgoing: AudioStreamPlayer = _music_a if _music_a.playing else _music_b
	var incoming: AudioStreamPlayer = _music_b if outgoing == _music_a else _music_a
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", -60.0, FADE_TIME)
		_fade.chain().tween_callback(outgoing.stop)
	if track == "":
		incoming.stop()
		return
	incoming.stream = _track(track)
	incoming.volume_db = -30.0
	incoming.play()
	_fade.parallel().tween_property(incoming, "volume_db", MUSIC_BASE_DB, FADE_TIME)


## A short tune over the music, which dips out of its way. It can wait a moment to start.
func jingle(jingle_name: String, delay: float = 0.0) -> void:
	if not _jingles.has(jingle_name):
		push_warning("no jingle called %s" % jingle_name)
		return
	_jingle_serial += 1
	var serial: int = _jingle_serial
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
		if serial != _jingle_serial:
			return
	var stream: AudioStream = _jingles[jingle_name]
	_jingle.stream = stream
	_jingle.play()
	_duck_music(stream.get_length())


func stop_jingle() -> void:
	_jingle_serial += 1
	_jingle.stop()


## The soft sound of being outdoors, under the music on the course.
func set_outdoors(on: bool) -> void:
	if on and not _ambience.playing:
		_ambience.play()
	elif not on and _ambience.playing:
		_ambience.stop()


func set_music_level(level: int) -> void:
	music_level = clampi(level, 0, LEVELS)
	_apply_levels()
	_save_settings()


func set_sfx_level(level: int) -> void:
	sfx_level = clampi(level, 0, LEVELS)
	_apply_levels()
	_save_settings()


func _track(track: String) -> AudioStream:
	if not _tracks.has(track):
		_tracks[track] = load("res://audio/music_%s.res" % track)
	return _tracks[track]


func _duck_music(length: float) -> void:
	var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	var base: float = _level_db(music_level)
	if _duck != null:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_method(_set_bus_db.bind(bus), AudioServer.get_bus_volume_db(bus), base + DUCK_DB, DUCK_TIME)
	_duck.tween_interval(maxf(length - DUCK_TIME * 2.0, 0.0))
	_duck.tween_method(_set_bus_db.bind(bus), base + DUCK_DB, base, DUCK_TIME * 3.0)


func _set_bus_db(db: float, bus: int) -> void:
	AudioServer.set_bus_volume_db(bus, db)


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, "Master")


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


# Squared, so each step sounds about as big as the last.
func _level_db(level: int) -> float:
	var amount: float = float(level) / float(LEVELS)
	return linear_to_db(amount * amount) if level > 0 else -80.0


func _apply_levels() -> void:
	if _duck != null:
		_duck.kill()
	var music_bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_bus: int = AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_volume_db(music_bus, _level_db(music_level))
	AudioServer.set_bus_mute(music_bus, music_level == 0)
	AudioServer.set_bus_volume_db(sfx_bus, _level_db(sfx_level))
	AudioServer.set_bus_mute(sfx_bus, sfx_level == 0)


func _load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var text: String = FileAccess.get_file_as_string(settings_path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	music_level = clampi(int(data.get("music", DEFAULT_MUSIC_LEVEL)), 0, LEVELS)
	sfx_level = clampi(int(data.get("sfx", DEFAULT_SFX_LEVEL)), 0, LEVELS)


func _save_settings() -> void:
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({ "music": music_level, "sfx": sfx_level }))
