extends Node

# Persistent data file path
const SAVE_PATH = "user://save_game.dat"

# Meta-progression variables
var total_shards: int = 0
var use_mouse_controls: bool = true
var show_tutorial: bool = true
var permanent_upgrades = {
	"starting_hearts": 0,
	"dash_mastery": 0,
	"sharp_edges": 0
}

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
			"permanent_upgrades": permanent_upgrades,
			"use_mouse_controls": use_mouse_controls,
			"show_tutorial": show_tutorial
		}
		file.store_var(data)

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data:
				total_shards = data.get("total_shards", 0)
				permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
				use_mouse_controls = data.get("use_mouse_controls", true)
				show_tutorial = data.get("show_tutorial", true)
