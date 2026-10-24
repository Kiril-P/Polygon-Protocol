extends Node
## Global audio: synthesized SFX (assets/audio/sfx, rendered by tools/audio),
## a voice-limited SFX pool, and an adaptive music system:
##   menu  -> calm tracks (assets/music for game)
##   game  -> neon gameplay loops (assets/audio/music/game_*.ogg)
##   boss  -> layered stems per boss, phases fade extra layers in.
## Usage: AudioManager.play_sfx("player_fire")

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const MENU_DIR := "res://assets/music for game/"
const POOL_SIZE := 28
const SILENT := -80.0

## name -> files (variants are picked at random), db (base level), pitch range,
## cooldown (min seconds between plays), voices (max simultaneous), ui (plays while paused).
var SFX := {
	"player_fire": {"files": ["player_fire_0", "player_fire_1", "player_fire_2", "player_fire_3"], "db": -11.0, "pitch": [0.95, 1.06], "cooldown": 0.03, "voices": 5},
	"enemy_hit": {"files": ["enemy_hit_0", "enemy_hit_1", "enemy_hit_2"], "db": -10.0, "pitch": [0.92, 1.1], "cooldown": 0.03, "voices": 5},
	"enemy_death": {"files": ["enemy_death_0", "enemy_death_1", "enemy_death_2"], "db": -7.0, "pitch": [0.9, 1.12], "cooldown": 0.04, "voices": 6},
	"enemy_death_big": {"files": ["enemy_death_big"], "db": -4.0, "pitch": [0.9, 1.05], "cooldown": 0.1, "voices": 3},
	"enemy_fire": {"files": ["enemy_fire"], "db": -15.0, "pitch": [0.9, 1.1], "cooldown": 0.08, "voices": 3},
	"bullet_bounce": {"files": ["bullet_bounce"], "db": -14.0, "pitch": [0.9, 1.2], "cooldown": 0.05, "voices": 3},
	"bullet_explosion": {"files": ["bullet_explosion"], "db": -8.0, "pitch": [0.92, 1.08], "cooldown": 0.06, "voices": 3},
	"kamikaze_alert": {"files": ["kamikaze_alert"], "db": -9.0, "pitch": [0.95, 1.05], "cooldown": 0.2, "voices": 2},
	"player_hit": {"files": ["player_hit"], "db": -4.0, "pitch": [0.97, 1.03], "cooldown": 0.15, "voices": 2, "ui": true},
	"shield_break": {"files": ["shield_break"], "db": -6.0, "pitch": [0.97, 1.03], "cooldown": 0.2, "voices": 2},
	"shield_regen": {"files": ["shield_regen"], "db": -10.0, "pitch": [1.0, 1.0], "cooldown": 0.3, "voices": 1},
	"heal": {"files": ["heal"], "db": -8.0, "pitch": [1.0, 1.0], "cooldown": 0.3, "voices": 1},
	"player_dash": {"files": ["dash_start"], "db": -7.0, "pitch": [0.98, 1.04], "cooldown": 0.12, "voices": 2},
	"dash_end": {"files": ["dash_end"], "db": -12.0, "pitch": [0.98, 1.04], "cooldown": 0.12, "voices": 2},
	"dash_empty": {"files": ["dash_empty"], "db": -8.0, "pitch": [1.0, 1.0], "cooldown": 0.4, "voices": 1},
	"dash_ready": {"files": ["dash_ready"], "db": -12.0, "pitch": [1.0, 1.0], "cooldown": 0.5, "voices": 1},
	"dash_loop": {"files": ["dash_loop"], "db": -13.0, "pitch": [1.0, 1.0], "cooldown": 0.0, "voices": 1, "loop": true},
	"player_spawn": {"files": ["player_spawn"], "db": -8.0, "pitch": [1.0, 1.0], "cooldown": 0.0, "voices": 1},
	"level_up": {"files": ["level_up"], "db": -6.0, "pitch": [1.0, 1.0], "cooldown": 0.3, "voices": 1, "ui": true},
	"upgrade_select": {"files": ["upgrade_select"], "db": -8.0, "pitch": [1.0, 1.0], "cooldown": 0.2, "voices": 1, "ui": true},
	"combo_tick": {"files": ["combo_tick"], "db": -16.0, "pitch": [1.0, 1.0], "cooldown": 0.06, "voices": 2},
	"combo_break": {"files": ["combo_break"], "db": -12.0, "pitch": [0.96, 1.04], "cooldown": 0.2, "voices": 1},
	"click": {"files": ["ui_click"], "db": -9.0, "pitch": [0.98, 1.02], "cooldown": 0.04, "voices": 3, "ui": true},
	"hover": {"files": ["ui_hover"], "db": -17.0, "pitch": [0.96, 1.04], "cooldown": 0.05, "voices": 2, "ui": true},
	"pause": {"files": ["pause"], "db": -9.0, "pitch": [1.0, 1.0], "cooldown": 0.2, "voices": 1, "ui": true},
	"unpause": {"files": ["unpause"], "db": -10.0, "pitch": [1.0, 1.0], "cooldown": 0.2, "voices": 1, "ui": true},
	"game_over": {"files": ["game_over"], "db": -4.0, "pitch": [1.0, 1.0], "cooldown": 0.0, "voices": 1, "ui": true},
	"boss_spawn": {"files": ["boss_spawn"], "db": -3.0, "pitch": [1.0, 1.0], "cooldown": 0.5, "voices": 1},
	"boss_phase": {"files": ["boss_phase"], "db": -3.0, "pitch": [0.97, 1.03], "cooldown": 0.3, "voices": 1},
	"boss_warning": {"files": ["boss_warning"], "db": -7.0, "pitch": [1.0, 1.0], "cooldown": 1.0, "voices": 1},
	"boss_death": {"files": ["boss_death"], "db": -2.0, "pitch": [1.0, 1.0], "cooldown": 1.0, "voices": 1},
	"elite_spawn": {"files": ["boss_phase"], "db": -11.0, "pitch": [1.25, 1.4], "cooldown": 0.5, "voices": 1},
	"glitch": {"files": ["glitch"], "db": -9.0, "pitch": [0.9, 1.1], "cooldown": 0.12, "voices": 2},
	"pillar_hit": {"files": ["pillar_hit"], "db": -7.0, "pitch": [0.9, 1.1], "cooldown": 0.1, "voices": 2},
	"heartbeat": {"files": ["heartbeat"], "db": -8.0, "pitch": [1.0, 1.0], "cooldown": 0.3, "voices": 1},
}

## Boss music: id -> highest phase (that phase gets every layer, including the lead).
const BOSS_MAX_PHASE := {"fortress": 2, "pulsar": 3, "singularity": 3, "prism": 3}
const BOSS_LAYERS := ["found", "drums", "arp", "lead"]

var sfx_streams: Dictionary = {}          # file base name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _voice_name: Dictionary = {}          # player -> sfx name
var _voice_start: Dictionary = {}         # player -> start time (ms)
var _last_play: Dictionary = {}           # sfx name -> last time (ms)
var _serial: Dictionary = {}              # player -> play id (for delayed cut-offs)
var active_persistent_sfx: Dictionary = {}

# Music state
var music_bus_index: int
var low_pass_effect: AudioEffectLowPassFilter = null
var _decks: Array[AudioStreamPlayer] = []
var _active_deck: int = 0
var _context: String = "menu"             # menu | game | boss
var _menu_tracks: Array[AudioStream] = []
var _game_tracks: Array[AudioStream] = []
var _menu_index: int = -1
var _game_index: int = -1
var _boss_streams: Dictionary = {}        # id -> AudioStreamSynchronized
var _boss_id: String = ""
var _boss_phase: int = 1
var _boss_tween: Tween = null
var _fading_next: bool = false
var _duck_tween: Tween = null
var _duck_db: float = 0.0

# Low-health heartbeat
var _low_health: bool = false
var _heartbeat_timer: float = 0.0

func _ready():
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_sfx()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var d := AudioStreamPlayer.new()
		d.bus = "Music"
		d.volume_db = SILENT
		add_child(d)
		_decks.append(d)
	_load_music()
	_play_playlist("menu", 0.0)

# ------------------------------------------------------------------ setup
func _setup_buses():
	var master := AudioServer.get_bus_index("Master")
	# Safety limiter on Master so stacked explosions never clip
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		lim.threshold_db = -4.0
		AudioServer.add_bus_effect(master, lim)
	# Gentle glue compressor on SFX
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		var has_comp := false
		for i in AudioServer.get_bus_effect_count(sfx_bus):
			if AudioServer.get_bus_effect(sfx_bus, i) is AudioEffectCompressor:
				has_comp = true
		if not has_comp:
			var comp := AudioEffectCompressor.new()
			comp.threshold = -14.0
			comp.ratio = 3.0
			comp.attack_us = 3000.0
			comp.release_ms = 140.0
			AudioServer.add_bus_effect(sfx_bus, comp)
	# Low-pass on the music bus (muffles music under pause / death screens)
	music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		music_bus_index = master
	for i in AudioServer.get_bus_effect_count(music_bus_index):
		if AudioServer.get_bus_effect(music_bus_index, i) is AudioEffectLowPassFilter:
			low_pass_effect = AudioServer.get_bus_effect(music_bus_index, i)
			break
	if not low_pass_effect:
		low_pass_effect = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(music_bus_index, low_pass_effect)
		AudioServer.set_bus_effect_enabled(music_bus_index, AudioServer.get_bus_effect_count(music_bus_index) - 1, false)

func _load_sfx():
	for key in SFX:
		for f in SFX[key]["files"]:
			if sfx_streams.has(f):
				continue
			var s = load(SFX_DIR + f + ".wav")
			if s:
				sfx_streams[f] = s
				if SFX[key].get("loop", false) and s is AudioStreamWAV:
					s.loop_mode = AudioStreamWAV.LOOP_FORWARD
					s.loop_begin = 0
					s.loop_end = int(s.get_length() * s.mix_rate)
			else:
				push_warning("AudioManager: missing SFX file " + f)

func _load_music():
	for f in ["game_neon_drive", "game_vector_run", "game_glass_grid"]:
		var s = load(MUSIC_DIR + f + ".ogg")
		if s:
			_game_tracks.append(s)
	_game_tracks.shuffle()
	var dir := DirAccess.open(MENU_DIR)
	if dir:
		for file_name in dir.get_files():
			var fn := file_name.replace(".import", "")
			if fn.ends_with(".mp3") or fn.ends_with(".ogg"):
				var track = load(MENU_DIR + fn)
				if track and not _menu_tracks.has(track):
					_menu_tracks.append(track)
	_menu_tracks.shuffle()
	for id in BOSS_MAX_PHASE:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = BOSS_LAYERS.size()
		var ok := true
		for i in BOSS_LAYERS.size():
			var s = load("%sboss_%s_%s.ogg" % [MUSIC_DIR, id, BOSS_LAYERS[i]])
			if not s:
				ok = false
				break
			s = s.duplicate()
			s.loop = true
			sync.set_sync_stream(i, s)
		if ok:
			_boss_streams[id] = sync

# ------------------------------------------------------------------ music
func set_muffled(enabled: bool):
	for i in AudioServer.get_bus_effect_count(music_bus_index):
		if AudioServer.get_bus_effect(music_bus_index, i) is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(music_bus_index, i, enabled)
			low_pass_effect.cutoff_hz = 900 if enabled else 20000
			return

## Main menu = calm tracks, in a run = neon gameplay tracks.
func set_music_menu_mode(is_menu: bool):
	set_low_health(false)
	if is_menu:
		if _context != "menu":
			_play_playlist("menu", 1.5)
	else:
		if _context == "menu":
			_play_playlist("game", 1.5)

## Boss encounter music. `boss` is the boss id ("fortress", "pulsar",
## "singularity"); phase raises the intensity by fading layers in.
func set_boss_music_mode(enabled: bool, phase: int = 1, boss: String = ""):
	if not enabled:
		if _context == "boss":
			_boss_id = ""
			_play_playlist("game", 2.5)
		return
	if boss != "":
		_boss_id = boss
	if _boss_id == "" or not _boss_streams.has(_boss_id):
		return
	set_muffled(false)
	if _context != "boss" or _decks[_active_deck].stream != _boss_streams[_boss_id]:
		_context = "boss"
		_crossfade_to(_boss_streams[_boss_id], 0.8, 0.0)
	_boss_phase = phase
	_apply_boss_layers(phase, 1.0 if phase <= 1 else 1.5)

## Identify a boss from its script path (used by the spawner).
static func boss_id_from_node(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null:
		return ""
	var path := script.resource_path
	for id in BOSS_MAX_PHASE:
		if path.contains("boss_" + id):
			return id
	return ""

func _apply_boss_layers(phase: int, fade_time: float):
	var sync := _decks[_active_deck].stream as AudioStreamSynchronized
	if sync == null:
		return
	var max_phase: int = BOSS_MAX_PHASE.get(_boss_id, 3)
	var full := phase >= max_phase
	# found, drums, arp, lead
	var target := [0.0, 0.0, SILENT, SILENT]
	if phase >= 2 or full:
		target[2] = -1.0
	if full:
		target[3] = 0.0
	elif phase >= 2:
		target[3] = -9.0
	if _boss_tween:
		_boss_tween.kill()
	_boss_tween = create_tween().set_parallel(true)
	for i in BOSS_LAYERS.size():
		var from: float = sync.get_sync_stream_volume(i)
		_boss_tween.tween_method(func(v): sync.set_sync_stream_volume(i, v), from, target[i], fade_time)

func _play_playlist(context: String, fade_time: float):
	_context = context
	var tracks := _menu_tracks if context == "menu" else _game_tracks
	if tracks.is_empty():
		return
	var idx: int
	if context == "menu":
		_menu_index = (_menu_index + 1) % tracks.size()
		idx = _menu_index
	else:
		_game_index = (_game_index + 1) % tracks.size()
		idx = _game_index
	var stream: AudioStream = tracks[idx]
	_set_loop(stream, false)
	_crossfade_to(stream, fade_time, 0.0)

func _set_loop(stream: AudioStream, on: bool):
	if stream is AudioStreamMP3:
		stream.loop = on
	elif stream is AudioStreamOggVorbis:
		stream.loop = on

func _crossfade_to(stream: AudioStream, fade_time: float, target_db: float):
	_fading_next = true
	var old := _decks[_active_deck]
	_active_deck = 1 - _active_deck
	var nw := _decks[_active_deck]
	nw.stop()
	nw.stream = stream
	nw.pitch_scale = 1.0
	nw.volume_db = SILENT if fade_time > 0.0 else target_db
	nw.play()
	var t := create_tween().set_parallel(true)
	if fade_time > 0.0:
		t.tween_property(nw, "volume_db", target_db, fade_time)
	if old.playing:
		t.tween_property(old, "volume_db", SILENT, maxf(fade_time, 0.05))
		t.chain().tween_callback(func():
			if old != _decks[_active_deck]:
				old.stop())
	t.chain().tween_callback(func(): _fading_next = false)

## Briefly lower the music so a big SFX (level-up, boss death) cuts through.
func duck_music(amount_db: float = 6.0, hold: float = 0.6, release: float = 1.2):
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, -absf(amount_db), 0.08)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(_set_duck, -absf(amount_db), 0.0, release)

func _set_duck(db: float):
	_duck_db = db
	AudioServer.set_bus_volume_db(music_bus_index, _music_bus_base_db() + db)

func _music_bus_base_db() -> float:
	return linear_to_db(maxf(GlobalData.audio_settings.music, 0.0001))

func _on_music_tick():
	# Advance playlists shortly before the track ends, with a crossfade.
	if _context == "boss" or _fading_next:
		return
	var deck := _decks[_active_deck]
	if not deck.playing or deck.stream == null:
		if _context != "boss":
			_play_playlist(_context, 0.0)
		return
	var length := deck.stream.get_length()
	if length > 8.0 and deck.get_playback_position() > length - 2.5:
		_play_playlist(_context, 2.5)

# ------------------------------------------------------------------ low health
func set_low_health(on: bool):
	if on == _low_health:
		return
	_low_health = on
	_heartbeat_timer = 0.0

func _process(delta: float):
	if _low_health and not get_tree().paused:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = 0.9
			play_sfx("heartbeat")
	_music_tick_timer -= delta
	if _music_tick_timer <= 0.0:
		_music_tick_timer = 0.25
		_on_music_tick()

var _music_tick_timer: float = 0.0

# ------------------------------------------------------------------ SFX
## pitch_min/pitch_max < 0 means "use the sound's own range".
func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_min: float = -1.0, pitch_max: float = -1.0, max_duration: float = 0.0):
	if not SFX.has(sfx_name):
		push_warning("AudioManager: unknown SFX " + sfx_name)
		return
	var cfg: Dictionary = SFX[sfx_name]
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sfx_name, -100000)) < int(cfg["cooldown"] * 1000.0):
		return
	var file: String = cfg["files"][randi() % cfg["files"].size()]
	var stream: AudioStream = sfx_streams.get(file)
	if stream == null:
		return
	var player := _acquire(sfx_name, int(cfg["voices"]))
	if player == null:
		return
	_last_play[sfx_name] = now
	var pr: Array = cfg["pitch"]
	var lo: float = pitch_min if pitch_min > 0.0 else pr[0]
	var hi: float = pitch_max if pitch_max > 0.0 else (pitch_min if pitch_min > 0.0 else pr[1])
	player.stream = stream
	player.pitch_scale = randf_range(minf(lo, hi), maxf(lo, hi))
	player.volume_db = float(cfg["db"]) + clampf(volume_db, -40.0, 3.0)
	player.process_mode = Node.PROCESS_MODE_ALWAYS if cfg.get("ui", false) else Node.PROCESS_MODE_PAUSABLE
	player.play()
	_voice_name[player] = sfx_name
	_voice_start[player] = now
	var id: int = int(_serial.get(player, 0)) + 1
	_serial[player] = id
	if max_duration > 0.0:
		get_tree().create_timer(max_duration, true, false, true).timeout.connect(func():
			if is_instance_valid(player) and _serial.get(player, 0) == id and player.playing:
				var tw := create_tween()
				tw.tween_property(player, "volume_db", SILENT, 0.05)
				tw.tween_callback(player.stop))

## Free voice, else steal this sound's oldest voice if it is at its cap,
## else steal the globally oldest voice.
func _acquire(sfx_name: String, max_voices: int) -> AudioStreamPlayer:
	var same: Array[AudioStreamPlayer] = []
	var free: AudioStreamPlayer = null
	var oldest: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			if free == null:
				free = p
			continue
		if _voice_name.get(p, "") == sfx_name:
			same.append(p)
		if oldest == null or _voice_start.get(p, 0) < _voice_start.get(oldest, 0):
			oldest = p
	if same.size() >= max_voices:
		var o: AudioStreamPlayer = same[0]
		for p in same:
			if _voice_start.get(p, 0) < _voice_start.get(o, 0):
				o = p
		o.stop()
		return o
	if free:
		return free
	if oldest:
		oldest.stop()
	return oldest

## Looping sound that runs until stop_persistent_sfx(id).
func start_persistent_sfx(sfx_name: String, id: String, volume_db: float = 0.0):
	if active_persistent_sfx.has(id):
		return
	# Legacy name -> loop version
	if sfx_name == "player_dash":
		sfx_name = "dash_loop"
	if not SFX.has(sfx_name):
		return
	var cfg: Dictionary = SFX[sfx_name]
	var stream: AudioStream = sfx_streams.get(cfg["files"][0])
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = stream
	player.volume_db = SILENT
	player.bus = "SFX"
	player.play()
	create_tween().tween_property(player, "volume_db", float(cfg["db"]) + clampf(volume_db + 10.0, -20.0, 3.0), 0.05)
	active_persistent_sfx[id] = player

func stop_persistent_sfx(id: String, fade_out: float = 0.1):
	if not active_persistent_sfx.has(id):
		return
	var player: AudioStreamPlayer = active_persistent_sfx[id]
	active_persistent_sfx.erase(id)
	if fade_out > 0.0:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", SILENT, fade_out)
		tween.tween_callback(player.queue_free)
	else:
		player.queue_free()
