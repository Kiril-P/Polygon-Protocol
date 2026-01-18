extends Node

# Persistent data file path
const SAVE_PATH = "user://save_game.dat"

# Meta-progression variables
var total_shards: int = 0
var high_score: float = 0.0 # Persistent survival time
var total_kills: int = 0 # Lifetime kills
var run_kills: int = 0 # Current run kills
var use_mouse_controls: bool = true
var show_tutorial: bool = true
var audio_settings = {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.7
}
var permanent_upgrades = {
	"starting_hearts": 0,
	"dash_mastery": 0,
	"sharp_edges": 0,
	"blast_cleaning": 0,  # Deletes bullets on level up
	"energy_shield": 0,   # Absorbs one shot
	"shield_regen": 0,    # Regenerates shield
	"emergency_overdrive": 0,
	"kinetic_reflector": 0,
	"shard_multiplier": 0,
	"recursive_evolution": 0,
	"repulsive_armor": 0
}

var deactivated_upgrades = [] # IDs of upgrades the player turned off

func is_upgrade_active(id: String) -> bool:
	return has_upgrade(id) and not deactivated_upgrades.has(id)

func toggle_upgrade(id: String):
	if deactivated_upgrades.has(id):
		deactivated_upgrades.erase(id)
	else:
		deactivated_upgrades.append(id)
	save_game()

var difficulty_level: int = 2 # 1-5, 2 is normal

# Scene Management
var next_scene_path: String = "res://scenes/game.tscn"
var is_quick_start: bool = false

func has_upgrade(id: String) -> bool:
	return permanent_upgrades.get(id, 0) > 0

func get_upgrade_level(id: String) -> int:
	return permanent_upgrades.get(id, 0)

func _ready():
	load_game()
	# Set custom cursor if you want it everywhere
	set_custom_cursor()

func set_custom_cursor():
	# Replace with the path to your favorite cursor from the pack
	var cursor_path = "res://assets/kenney_cursor-pack/PNG/Basic/Default/pointer_c_shaded.png"
	var cursor_img = load(cursor_path)
	if cursor_img:
		# Use Input.CURSOR_ARROW as the default
		Input.set_custom_mouse_cursor(cursor_img, Input.CURSOR_ARROW, Vector2(0, 0))

func add_shards(amount: int):
	total_shards += amount
	save_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"total_shards": total_shards,
			"high_score": high_score,
			"total_kills": total_kills,
			"permanent_upgrades": permanent_upgrades,
			"deactivated_upgrades": deactivated_upgrades,
			"use_mouse_controls": use_mouse_controls,
			"show_tutorial": show_tutorial,
			"difficulty_level": difficulty_level,
			"audio_settings": audio_settings
		}
		file.store_var(data)

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data:
				total_shards = data.get("total_shards", 0)
				high_score = data.get("high_score", 0.0)
				total_kills = data.get("total_kills", 0)
				permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
				deactivated_upgrades = data.get("deactivated_upgrades", [])
				use_mouse_controls = data.get("use_mouse_controls", true)
				show_tutorial = data.get("show_tutorial", true)
				difficulty_level = data.get("difficulty_level", 2)
				audio_settings = data.get("audio_settings", audio_settings)
				
				# Apply audio settings on load
				apply_audio_settings()

func apply_audio_settings():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(audio_settings.master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(audio_settings.music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(audio_settings.sfx))
