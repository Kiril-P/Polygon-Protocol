extends Node

# Persistent data file path
const SAVE_PATH = "user://save_game.dat"
const CURRENT_SAVE_VERSION = 2 # Increment this to force a reset for all players

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
var run_boss_shards: int = 0 # Shards from bosses this run (already banked when earned)
var bosses_killed: int = 0 # Bosses killed this run
var run_endless_bonus: float = 1.0 # Score and shard bonus for declining the 6:00 boss fight
var use_mouse_controls: bool = false # WASD by default
var show_tutorial: bool = true
var audio_settings = {
	"master": 0.35,
	"music": 0.25,
	"sfx": 0.30
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
	"repulsive_armor": 0,
	"dash_resistance": 0
}

var leaderboard: Array = [] # Array of dictionaries: {name, score, kills, level, time}
var player_name: String = "Player"
var player_id: String = "" # Unique ID to identify the local player's entry

var seen_intel: Array = [] # Enemy types whose intro card was shown (never shown twice)
# Personal records over all runs (separate from the best-score run kept in high_score_*)
var records := {"score": 0, "time": 0.0, "kills": 0, "level": 1, "combo": 0}
var daily_submit_state: String = "" # "", "pending", "ok", "failed" for the run just played
## The trailer capture sets this so scripted footage never touches the real save.
var saving_disabled: bool = false
var title_seen: bool = false # Opening title plays once per launch (not saved)
# --- Run setup (protocols / daily). run_* is per run, the rest is saved.
var run_mode: String = "standard" # "standard" or "daily"
var run_protocols: Array = []
var run_daily_key: String = ""
var last_protocols: Array = [] # Protocols ticked in the pre-run screen last time
var daily_best_key: String = "" # Date of the stored daily best
var daily_best_score: int = 0
var daily_streak: int = 0
var daily_last_played: String = ""
# --- Starting shapes (see PlayerShapes): bought with shards, picked on the pre-run screen
var unlocked_shapes: Array = ["circle"]
var selected_shape: String = "circle"
## Set once the scripted first run (FirstRun) was finished or skipped.
var first_run_done: bool = false
signal daily_submit_finished(success: bool)
## Tests flip this off so automated runs never post to the live leaderboard.
var online_submit_enabled := true
var _daily_submit_open := false

func protocol_active(id: String) -> bool:
	return id in run_protocols

func protocol_multiplier() -> float:
	return Protocols.multiplier(run_protocols)

## The starting shape for the run about to begin. The Daily Protocol always starts as the
## circle so every score on its board comes from the same starting kit.
func run_shape() -> String:
	if run_mode == "daily" or not selected_shape in unlocked_shapes:
		return "circle"
	return selected_shape

func has_shape(id: String) -> bool:
	return id in unlocked_shapes

## Spends shards on a shape if its prerequisites are owned. Returns true on success.
func buy_shape(id: String) -> bool:
	var def := PlayerShapes.get_def(id)
	if def.is_empty() or has_shape(id) or total_shards < int(def["cost"]):
		return false
	for req in def["requires"]:
		if not has_shape(req):
			return false
	total_shards -= int(def["cost"])
	unlocked_shapes.append(id)
	save_game()
	return true

func select_shape(id: String):
	if has_shape(id):
		selected_shape = id
		save_game()

func set_run(mode: String, protocols: Array):
	run_mode = mode
	run_protocols = protocols.duplicate()
	run_daily_key = Protocols.daily_key() if mode == "daily" else ""
	if mode == "standard":
		last_protocols = run_protocols.duplicate()
		save_game()

## Folds a finished run into the records. Returns the list of record keys it broke.
func update_records(run: Dictionary) -> Array:
	var broken: Array = []
	for k in records.keys():
		if run.has(k) and run[k] > records[k]:
			records[k] = run[k]
			broken.append(k)
	save_game()
	return broken

## Called when a run ends. Returns {daily_best: bool, streak: int} (empty for standard runs).
func record_daily_result(score: int) -> Dictionary:
	if run_mode != "daily":
		return {}
	var key := run_daily_key
	var is_best := false
	if daily_best_key != key or score > daily_best_score:
		is_best = true
		daily_best_key = key
		daily_best_score = score
	if daily_last_played != key:
		var yesterday := Protocols.daily_key(Time.get_unix_time_from_system() - 86400.0)
		daily_streak = daily_streak + 1 if daily_last_played == yesterday else 1
		daily_last_played = key
	save_game()
	return {"daily_best": is_best, "streak": daily_streak}

## Posts a daily score to SilentWolf board "daily_<date>". Emits daily_submit_finished once,
## also when offline (a timeout stops the run-end screen waiting forever).
func submit_daily_score(score: int, kills: int, level: int, time: float):
	if run_mode != "daily" or _daily_submit_open:
		return
	_daily_submit_open = true
	daily_submit_state = "pending"
	var key := run_daily_key
	var sw := get_node_or_null("/root/SilentWolf")
	if sw == null or not online_submit_enabled:
		_finish_daily_submit(false)
		return
	get_tree().create_timer(8.0, true, false, true).timeout.connect(func(): _finish_daily_submit(false))
	var meta := {"kills": kills, "level": level, "time": time, "player_id": player_id, "protocols": ",".join(run_protocols)}
	var res = await sw.Scores.save_score(player_name, score, "daily_" + key, meta).sw_save_score_complete
	_finish_daily_submit(res.get("success", false))

func _finish_daily_submit(success: bool):
	if not _daily_submit_open:
		return
	_daily_submit_open = false
	daily_submit_state = "ok" if success else "failed"
	daily_submit_finished.emit(success)

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
var is_first_run: bool = true # Track if this is the first ever run

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

## Boss kills pay out immediately and get the same multipliers as the end-of-run shards.
## Returns what was actually paid.
func add_boss_shards(base: int) -> int:
	var amount := base
	if has_upgrade("shard_multiplier"):
		amount = int(amount * 1.5)
	amount = int(amount * protocol_multiplier() * run_endless_bonus)
	run_boss_shards += amount
	add_shards(amount)
	return amount

func reset_run_stats():
	run_kills = 0
	run_score = 0
	run_level = 1
	run_time = 0.0
	run_boss_shards = 0
	bosses_killed = 0
	run_endless_bonus = 1.0

func add_score(base_points: int, combo: int):
	var multiplier = 1.0 + (combo * 0.1)
	run_score += int(base_points * multiplier * protocol_multiplier() * run_endless_bonus)

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
	if saving_disabled:
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"version": CURRENT_SAVE_VERSION,
			"total_shards": total_shards,
			"high_score": high_score,
			"high_score_points": high_score_points,
			"best_kills": best_kills,
			"best_level": best_level,
			"total_kills": total_kills,
			"permanent_upgrades": permanent_upgrades,
			"deactivated_upgrades": deactivated_upgrades,
			"seen_intel": seen_intel,
			"last_protocols": last_protocols,
			"records": records,
			"daily_best_key": daily_best_key,
			"daily_best_score": daily_best_score,
			"daily_streak": daily_streak,
			"daily_last_played": daily_last_played,
			"unlocked_shapes": unlocked_shapes,
			"selected_shape": selected_shape,
			"first_run_done": first_run_done,
			"use_mouse_controls": use_mouse_controls,
			"show_tutorial": show_tutorial,
			"difficulty_level": difficulty_level,
			"audio_settings": audio_settings,
			"leaderboard": leaderboard,
			"player_name": player_name,
			"player_id": player_id,
			"is_first_run": is_first_run
		}
		file.store_var(data)

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data:
				# VERSION CHECK: If the save is old, we reset progression stats
				var saved_version = data.get("version", 1)
				if saved_version < CURRENT_SAVE_VERSION:
					print("Old save version detected. Resetting progression.")
					# We keep audio and control settings but reset progression
					_load_settings_only(data)
					save_game() # Overwrite with new version
					return

				total_shards = data.get("total_shards", 0)
				high_score = data.get("high_score", 0.0)
				high_score_points = data.get("high_score_points", 0)
				best_kills = data.get("best_kills", 0)
				best_level = data.get("best_level", 1)
				total_kills = data.get("total_kills", 0)
				permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
				deactivated_upgrades = data.get("deactivated_upgrades", [])
				seen_intel = data.get("seen_intel", [])
				last_protocols = data.get("last_protocols", [])
				records = data.get("records", {"score": high_score_points, "time": high_score, "kills": best_kills, "level": best_level, "combo": 0})
				daily_best_key = data.get("daily_best_key", "")
				daily_best_score = data.get("daily_best_score", 0)
				daily_streak = data.get("daily_streak", 0)
				daily_last_played = data.get("daily_last_played", "")
				unlocked_shapes = data.get("unlocked_shapes", ["circle"])
				if not "circle" in unlocked_shapes:
					unlocked_shapes.append("circle")
				selected_shape = data.get("selected_shape", "circle")
				use_mouse_controls = data.get("use_mouse_controls", false)
				show_tutorial = data.get("show_tutorial", true)
				difficulty_level = data.get("difficulty_level", 2)
				audio_settings = data.get("audio_settings", audio_settings)
				leaderboard = data.get("leaderboard", [])
				player_name = data.get("player_name", "Player")
				player_id = data.get("player_id", "")
				is_first_run = data.get("is_first_run", true)
				# Saves from before the scripted first run: anyone who already picked an upgrade has seen enough
				first_run_done = data.get("first_run_done", not is_first_run)
				
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
		apply_audio_settings()

func apply_audio_settings():
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(audio_settings.master))
		
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(audio_settings.music))
		
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(audio_settings.sfx))

func _load_settings_only(data: Dictionary):
	# Helper to keep user preferences while resetting game stats
	use_mouse_controls = data.get("use_mouse_controls", false)
	show_tutorial = data.get("show_tutorial", true)
	audio_settings = data.get("audio_settings", audio_settings)
	player_name = data.get("player_name", "Player")
	player_id = data.get("player_id", "")
	apply_audio_settings()
