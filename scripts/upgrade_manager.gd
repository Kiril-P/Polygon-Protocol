extends Node

# Signal to tell the UI to show up
signal request_upgrade_ui(options: Array)

# Definitions of all possible upgrades
var upgrade_pool = [
	{
		"id": "speed",
		"name": "Swiftness",
		"description": "+25% Movement Speed",
		"value": 0.25,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_001.png"
	},
	{
		"id": "damage",
		"name": "Sharp Edges",
		"description": "+50% Bullet Damage",
		"value": 0.5,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_003.png"
	},
	{
		"id": "dash_charge",
		"name": "Energy Battery",
		"description": "+25% Dash Energy",
		"value": 0.25,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_005.png"
	},
	{
		"id": "dash_cooldown",
		"name": "Quick Reflow",
		"description": "+30% Energy Recovery",
		"value": 0.3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_007.png"
	},
	{
		"id": "pierce",
		"name": "Drilling Rounds",
		"description": "Bullets pierce +1 enemy",
		"value": 1.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_009.png"
	},
	{
		"id": "fire_rate",
		"name": "Rapid Fire",
		"description": "+30% Fire Rate",
		"value": 0.3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_011.png"
	},
	{
		"id": "bounce",
		"name": "Rubber Bullets",
		"description": "Bullets bounce off screen edges",
		"value": 1.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_015.png"
	},
	{
		"id": "max_hearts",
		"name": "Body Armor",
		"description": "+1 Heart Slot",
		"value": 1.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_021.png"
	},
	{
		"id": "bullet_speed",
		"name": "Aero Rounds",
		"description": "+20% Bullet Speed",
		"value": 0.2,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_023.png"
	},
	{
		"id": "rotation_speed",
		"name": "Centrifuge",
		"description": "+30% Rotation Speed",
		"value": 0.3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_025.png"
	},
	{
		"id": "explosive",
		"name": "Volatile Core",
		"description": "Every bullet explodes on hit",
		"value": 50.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_027.png"
	}
]

func get_random_upgrades(count: int = 3) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	var is_circle = player and player.current_shape == 0
	
	var pool = []
	for upgrade in upgrade_pool:
		if is_circle:
			# Added 'explosive', 'bullet_speed', and 'rotation_speed' to the forbidden list
			if upgrade["id"] in ["damage", "pierce", "fire_rate", "homing", "bounce", "explosive", "bullet_speed", "rotation_speed"]:
				continue
		pool.append(upgrade)
	
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
func _ready():
	# Find player and connect to level_up_ready signal
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.level_up_ready.connect(_on_player_level_up)

func _on_player_level_up():
	var options = get_random_upgrades(3)
	# Pause the game and show UI
	get_tree().paused = true
	request_upgrade_ui.emit(options)

func apply_upgrade(upgrade_data: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_upgrade(upgrade_data["id"], upgrade_data["value"])
	
	# Resume the game
	get_tree().paused = false
