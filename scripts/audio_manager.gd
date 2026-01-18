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
	"game_over": "res://assets/sfx/lose.wav",
	"glitch": "res://assets/kenney_sci-fi-sounds/Audio/laserRetro_004.ogg",
	"combo_break": "res://assets/kenney_sci-fi-sounds/Audio/impactMetal_001.ogg"
}

func _ready():
	randomize() # Ensure shuffle is different every launch
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pre-load sounds
	for key in sound_definitions:
		var path = sound_definitions[key]
		if not FileAccess.file_exists(path):
			# Fallback if specific Kenney sounds are missing
			if "powerUp_001" in path:
				path = "res://assets/kenney_interface-sounds/Audio/maximize_001.ogg"
			elif "powerUp_000" in path:
				path = "res://assets/kenney_interface-sounds/Audio/confirmation_001.ogg"
		
		var stream = load(path)
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

func _input(event):
	# Web Audio fix: Play a silent sound on first click to resume AudioContext
	if event is InputEventMouseButton and event.pressed:
		if AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) > -80:
			# Just calling any play function on a user gesture usually fixes web audio
			pass

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
	music_tracks.clear()
	var dir = DirAccess.open("res://assets/music for game/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
				var track_path = "res://assets/music for game/" + file_name
				var track = load(track_path)
				if track:
					music_tracks.append(track)
			file_name = dir.get_next()
	
	# Fallback if DirAccess fails or folder is empty
	if music_tracks.is_empty():
		var fallback_tracks = [
			"res://assets/music for game/Little-Wishes-chosic.com_.mp3",
			"res://assets/music for game/tokyo-music-walker-sunset-drive-chosic.com_.mp3"
		]
		for path in fallback_tracks:
			var track = load(path)
			if track:
				music_tracks.append(track)
	
	# Shuffle once at game start as requested
	music_tracks.shuffle()
	current_music_index = -1 # So the first play_next_track starts at 0

func set_boss_music_mode(enabled: bool):
	var target_pitch = 1.15 if enabled else 1.0
	var base_vol = 0.0
	if has_node("/root/GlobalData"):
		base_vol = linear_to_db(get_node("/root/GlobalData").audio_settings.music)
	
	var target_volume = base_vol + 2.0 if enabled else base_vol
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(music_player, "pitch_scale", target_pitch, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(music_player, "volume_db", target_volume, 1.5).set_trans(Tween.TRANS_SINE)
	
	# If boss starts, maybe disable muffled effect if it was on
	if enabled:
		set_muffled(false)

func play_next_track():
	if music_tracks.is_empty(): return
	
	current_music_index += 1
	if current_music_index >= music_tracks.size():
		# Loop back: Re-shuffle to ensure variety, but avoid playing same song twice
		var last_track = music_tracks[music_tracks.size() - 1]
		music_tracks.shuffle()
		# If the first song of new shuffle is the same as the last song played, swap it
		if music_tracks.size() > 1 and music_tracks[0] == last_track:
			var temp = music_tracks[0]
			music_tracks[0] = music_tracks[1]
			music_tracks[1] = temp
		current_music_index = 0
		
	music_player.stream = music_tracks[current_music_index]
	
	# Fade in music
	music_player.volume_db = -80
	music_player.play()
	var tween = create_tween()
	# Respect global volume settings if they exist
	var target_vol = 0.0
	if has_node("/root/GlobalData"):
		target_vol = linear_to_db(get_node("/root/GlobalData").audio_settings.music)
	
	tween.tween_property(music_player, "volume_db", target_vol, 2.0)

func _on_music_finished():
	play_next_track()

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.1, max_duration: float = 0.0):
	if not sfx_pool.has(sfx_name):
		print("Warning: SFX not found: ", sfx_name)
		return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# Determine if this should be pausable (most game sounds should)
	# UI sounds should probably stay PROCESS_MODE_ALWAYS
	var is_ui = sfx_name in ["click", "hover", "pause", "level_up", "game_over"]
	if not is_ui:
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		
	player.stream = sfx_pool[sfx_name]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.bus = "SFX"
	player.play()
	
	if max_duration > 0.0:
		get_tree().create_timer(max_duration).timeout.connect(func():
			if is_instance_valid(player):
				var tween = create_tween()
				tween.tween_property(player, "volume_db", -80, 0.05) # Quick fade out
				tween.tween_callback(player.queue_free)
		)
	else:
		player.finished.connect(player.queue_free)

# NEW: Start a sound that persists until stop_persistent_sfx is called
func start_persistent_sfx(sfx_name: String, id: String, volume_db: float = 0.0):
	if not sfx_pool.has(sfx_name): return
	
	# If already playing, don't start another
	if active_persistent_sfx.has(id): return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE # Ensure it pauses with game!
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
