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
		"description": "+25% Bullet Damage",
		"value": 0.25,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_003.png"
	},
	{
		"id": "dash_charge",
		"name": "Energy Battery",
		"description": "+10% Dash Energy",
		"value": 0.1,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_005.png"
	},
	{
		"id": "dash_cooldown",
		"name": "Quick Reflow",
		"description": "+15% Energy Recovery",
		"value": 0.15,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_007.png"
	},
	{
		"id": "fire_rate",
		"name": "Rapid Fire",
		"description": "+10% Fire Rate",
		"value": 0.1,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_011.png"
	},
	{
		"id": "bounce",
		"name": "RECOIL MATRIX",
		"description": "CRITICAL: Bullets bounce off screen edges",
		"value": 1.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_015.png",
		"is_special": true
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
		"description": "+40% Bullet Speed",
		"value": 0.4,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_023.png"
	},
	{
		"id": "rotation_speed",
		"name": "Centrifuge",
		"description": "+50% Rotation Speed",
		"value": 0.5,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_025.png"
	},
	{
		"id": "explosive",
		"name": "VOLATILE SINGULARITY",
		"description": "ULTRA: Every bullet explodes on contact",
		"value": 50.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_027.png",
		"is_special": true
	}
]

var applied_special_upgrades = []
var level_up_pending: int = 0
var is_ui_active: bool = false

func get_random_upgrades(count: int = 3) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	var is_circle = player and player.current_shape == 0
	
	var pool = []
	for upgrade in upgrade_pool:
		# Check if already applied (only for special ones)
		if upgrade.get("is_special", false) and upgrade["id"] in applied_special_upgrades:
			continue
			
		if is_circle:
			# Removed 'pierce' from the forbidden list as the upgrade itself is removed
			if upgrade["id"] in ["damage", "fire_rate", "homing", "bounce", "explosive", "bullet_speed", "rotation_speed"]:
				continue
		
		# Rarity check for special upgrades (e.g. 10% chance to even be in the pool this time)
		if upgrade.get("is_special", false):
			if randf() > 0.1: # 90% chance to skip a special upgrade from the available pool
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
	level_up_pending += 1
	if is_ui_active:
		return
		
	show_next_upgrade()

func show_next_upgrade():
	if level_up_pending <= 0:
		is_ui_active = false
		get_tree().paused = false
		return
		
	is_ui_active = true
	var options = get_random_upgrades(3)
	# Pause the game and show UI
	get_tree().paused = true
	request_upgrade_ui.emit(options)

func apply_upgrade(upgrade_data: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_upgrade(upgrade_data["id"], upgrade_data["value"])
		
		# Track if this was a special upgrade to prevent repeat appearances
		if upgrade_data.get("is_special", false):
			applied_special_upgrades.append(upgrade_data["id"])
	
	level_up_pending -= 1
	if level_up_pending > 0:
		# Show next upgrade immediately
		show_next_upgrade()
	else:
		# Resume the game
		is_ui_active = false
		get_tree().paused = false
