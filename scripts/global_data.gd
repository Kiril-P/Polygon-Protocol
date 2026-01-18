extends Node

# Persistent data file path
const SAVE_PATH = "user://save_game.dat"

# Meta-progression variables
var total_shards: int = 0
var high_score: float = 0.0 # Persistent survival time
var high_score_points: int = 0 # Persistent score points
var best_kills: int = 0
var best_level: int = 1
var total_kills: int = 0 # Lifetime kills
var run_kills: int = 0 # Current run kills
var run_score: int = 0 # Current run score
var run_level: int = 1 # Current run level
var run_time: float = 0.0 # Current run survival time
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
	"shard_multiplier": 0,
	"repulsive_armor": 0
}

var leaderboard: Array = [] # Array of dictionaries: {name, score, kills, level, time}
var player_name: String = "Player"
var player_id: String = "" # Unique ID to identify the local player's entry

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
var next_scene_path: String = ""
var is_quick_start: bool = false

func has_upgrade(id: String) -> bool:
	return permanent_upgrades.get(id, 0) > 0

func get_upgrade_level(id: String) -> int:
	return permanent_upgrades.get(id, 0)

func _ready():
	load_game()
	# Set custom cursor if you want it everywhere
	set_custom_cursor()
	
	# SilentWolf Configuration
	if Engine.has_singleton("SilentWolf") or has_node("/root/SilentWolf"):
		var sw_config = {
			"api_key": "GGZx7MArqd4A7QjZVOBy52ZoZzRV36Ks1fskPtAT",
			"game_id": "polygonprotocol",
			"log_level": 1
		}
		# Using the SilentWolf Autoload to configure
		get_node("/root/SilentWolf").configure(sw_config)

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

func add_score(base_points: int, combo: int):
	var multiplier = 1.0 + (combo * 0.1)
	run_score += int(base_points * multiplier)

func update_leaderboard(p_name: String, score: int, kills: int, level: int, time: float):
	player_name = p_name
	var new_entry = {
		"id": player_id, # Track by ID
		"name": p_name,
		"score": score,
		"kills": kills,
		"level": level,
		"time": time
	}
	
	# Check if local player already exists in leaderboard by ID
	var found_idx = -1
	for i in range(leaderboard.size()):
		if leaderboard[i].get("id") == player_id:
			found_idx = i
			break
	
	if found_idx != -1:
		# Always update name if it changed
		leaderboard[found_idx]["name"] = p_name
		
		# Only update stats if it's a new personal best
		if score >= leaderboard[found_idx]["score"]:
			leaderboard[found_idx] = new_entry
	else:
		leaderboard.append(new_entry)
	
	# Sort leaderboard by score descending
	leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Keep only top 10
	if leaderboard.size() > 10:
		leaderboard = leaderboard.slice(0, 10)
		
	save_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"total_shards": total_shards,
			"high_score": high_score,
			"high_score_points": high_score_points,
			"best_kills": best_kills,
			"best_level": best_level,
			"total_kills": total_kills,
			"permanent_upgrades": permanent_upgrades,
			"deactivated_upgrades": deactivated_upgrades,
			"use_mouse_controls": use_mouse_controls,
			"show_tutorial": show_tutorial,
			"difficulty_level": difficulty_level,
			"audio_settings": audio_settings,
			"leaderboard": leaderboard,
			"player_name": player_name,
			"player_id": player_id,
			"is_quick_start": is_quick_start
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
				high_score_points = data.get("high_score_points", 0)
				best_kills = data.get("best_kills", 0)
				best_level = data.get("best_level", 1)
				total_kills = data.get("total_kills", 0)
				permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
				deactivated_upgrades = data.get("deactivated_upgrades", [])
				use_mouse_controls = data.get("use_mouse_controls", true)
				show_tutorial = data.get("show_tutorial", true)
				difficulty_level = data.get("difficulty_level", 2)
				audio_settings = data.get("audio_settings", audio_settings)
				leaderboard = data.get("leaderboard", [])
				player_name = data.get("player_name", "Player")
				player_id = data.get("player_id", "")
				is_quick_start = data.get("is_quick_start", false)
				
				# Generate ID if missing
				if player_id == "":
					player_id = str(randi()) + str(Time.get_unix_time_from_system())
					save_game()
				
				# Apply audio settings on load
				apply_audio_settings()
	else:
		# Initial setup
		player_id = str(randi()) + str(Time.get_unix_time_from_system())
		save_game()

func apply_audio_settings():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(audio_settings.master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(audio_settings.music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(audio_settings.sfx))
