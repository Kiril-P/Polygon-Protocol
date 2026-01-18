extends Node

# A simple global Audio Manager for playing SFX easily
# Usage: AudioManager.play_sfx("player_fire")

var sfx_pool = {}
var active_persistent_sfx = {} # NEW: Track sounds that can be stopped
var music_player: AudioStreamPlayer = null
var current_music_index: int = 0
var music_tracks: Array[AudioStream] = []

# Audio Effects
var music_bus_index: int
var low_pass_effect: AudioEffectLowPassFilter = null

var sound_definitions = {
	"player_fire": "res://assets/kenney_sci-fi-sounds/Audio/laserSmall_000.ogg",
	"enemy_hit": "res://assets/kenney_impact-sounds/Audio/impactMetal_light_004.ogg", # Punchier, shorter
	"enemy_death": "res://assets/kenney_sci-fi-sounds/Audio/explosionCrunch_004.ogg", # Shorter, punchier sound
	"player_dash": "res://assets/kenney_sci-fi-sounds/Audio/thrusterFire_001.ogg",
	"player_hit": "res://assets/sfx/hurt.wav", # Increased volume for better feedback
	"player_spawn": "res://assets/kenney_interface-sounds/Audio/select_001.ogg",
	"bullet_bounce": "res://assets/kenney_interface-sounds/Audio/drop_003.ogg",
	"bullet_explosion": "res://assets/kenney_sci-fi-sounds/Audio/explosionCrunch_001.ogg",
	"shield_break": "res://assets/kenney_sci-fi-sounds/Audio/forceField_000.ogg",
	"shield_regen": "res://assets/kenney_sci-fi-sounds/Audio/powerUp_001.ogg",
	"level_up": "res://assets/kenney_sci-fi-sounds/Audio/powerUp_000.ogg",
	"pause": "res://assets/sfx/fracture_menu.wav",
	"click": "res://assets/kenney_ui-audio/Audio/click1.ogg",
	"hover": "res://assets/kenney_ui-audio/Audio/rollover2.ogg",
	"boss_spawn": "res://assets/kenney_sci-fi-sounds/Audio/laserSmall_002.ogg",
	"game_over": "res://assets/sfx/lose.wav"
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pre-load sounds
	for key in sound_definitions:
		var stream = load(sound_definitions[key])
		if stream:
			sfx_pool[key] = stream
	
	# Setup Music Player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music" # Make sure to create this bus in Godot!
	music_player.finished.connect(_on_music_finished)
	
	# Setup Effects
	setup_audio_effects()
	
	# Load Music Tracks from the folder
	load_music_tracks()
	play_next_track()

func setup_audio_effects():
	music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		# If Music bus doesn't exist, use Master
		music_bus_index = AudioServer.get_bus_index("Master")
	
	# Try to find existing LowPass, or create one
	for i in range(AudioServer.get_bus_effect_count(music_bus_index)):
		if AudioServer.get_bus_effect(music_bus_index, i) is AudioEffectLowPassFilter:
			low_pass_effect = AudioServer.get_bus_effect(music_bus_index, i)
			break
	
	if not low_pass_effect:
		low_pass_effect = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(music_bus_index, low_pass_effect)
		# Start disabled
		AudioServer.set_bus_effect_enabled(music_bus_index, AudioServer.get_bus_effect_count(music_bus_index) - 1, false)

func set_muffled(enabled: bool):
	var effect_idx = -1
	for i in range(AudioServer.get_bus_effect_count(music_bus_index)):
		if AudioServer.get_bus_effect(music_bus_index, i) is AudioEffectLowPassFilter:
			effect_idx = i
			break
	
	if effect_idx != -1:
		AudioServer.set_bus_effect_enabled(music_bus_index, effect_idx, enabled)
		if enabled:
			low_pass_effect.cutoff_hz = 800 # Muffled frequency
		else:
			low_pass_effect.cutoff_hz = 20000 # Clear frequency

func set_music_menu_mode(is_menu: bool):
	if is_menu:
		# Maybe slightly lower volume or different vibe for menu
		var tween = create_tween()
		tween.tween_property(music_player, "pitch_scale", 0.9, 1.0)
	else:
		var tween = create_tween()
		tween.tween_property(music_player, "pitch_scale", 1.0, 1.0)

func load_music_tracks():
	var music_dir = "res://assets/music for game/"
	var dir = DirAccess.open(music_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".mp3"):
				var track = load(music_dir + file_name)
				if track:
					music_tracks.append(track)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Shuffle tracks for variety
	music_tracks.shuffle()

func play_next_track():
	if music_tracks.is_empty(): return
	
	current_music_index = (current_music_index + 1) % music_tracks.size()
	music_player.stream = music_tracks[current_music_index]
	
	# Fade in music
	music_player.volume_db = -80
	music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0, 2.0)

func _on_music_finished():
	play_next_track()

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.1):
	if not sfx_pool.has(sfx_name):
		print("Warning: SFX not found: ", sfx_name)
		return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = sfx_pool[sfx_name]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.bus = "SFX"
	player.play()
	player.finished.connect(player.queue_free)

# NEW: Start a sound that persists until stop_persistent_sfx is called
func start_persistent_sfx(sfx_name: String, id: String, volume_db: float = 0.0):
	if not sfx_pool.has(sfx_name): return
	
	# If already playing, don't start another
	if active_persistent_sfx.has(id): return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = sfx_pool[sfx_name]
	player.volume_db = volume_db
	player.bus = "SFX"
	player.play()
	active_persistent_sfx[id] = player

func stop_persistent_sfx(id: String, fade_out: float = 0.1):
	if not active_persistent_sfx.has(id): return
	
	var player = active_persistent_sfx[id]
	active_persistent_sfx.erase(id)
	
	if fade_out > 0:
		var tween = create_tween()
		tween.tween_property(player, "volume_db", -80, fade_out)
		tween.tween_callback(player.queue_free)
	else:
		player.queue_free()
