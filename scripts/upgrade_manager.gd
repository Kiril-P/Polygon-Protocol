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
		"description": "CRITICAL: Bullets | Lasers bounce off screen edges | enemies",
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
		"description": "+40% Bullet Speed & Kinetic Damage",
		"value": 0.4,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_023.png"
	},
	{
		"id": "rotation_speed",
		"name": "Centrifuge",
		"description": "+50% Rotation Speed & Saw Damage",
		"value": 0.5,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_025.png"
	},
	{
		"id": "dash_lifesteal",
		"name": "SANGUINE DASH",
		"description": "SPECIAL: Chance to heal 1 heart when killing enemies with a dash",
		"value": 0.1,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_012.png",
		"is_special": true
	},
	{
		"id": "gravity_well",
		"name": "GRAVITY WELL",
		"description": "SPECIAL: Dashing sucks nearby enemies into your wake",
		"value": 400.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_020.png",
		"is_special": true
	},
	{
		"id": "prismatic_beam",
		"name": "PRISMATIC BEAM",
		"description": "ULTRA: Replace bullets with continuous neon lasers",
		"value": 1.0,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_027.png",
		"is_special": true
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
var upgrade_counts = {} # Track how many times each upgrade was picked
var level_up_pending: int = 0
var is_ui_active: bool = false

func get_random_upgrades(count: int = 3) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	var is_circle = player and player.current_shape == 0
	
	var pool = []
	for upgrade in upgrade_pool:
		# Check if already applied (only for special ones)
		if upgrade.get("is_special", false) and upgrade["id"] in applied_special_upgrades:
			# Some multi-pick specials are handled in apply_upgrade, 
			# but we still want to diminish them.
			var multi_pick_specials = ["gravity_well", "bounce", "explosive", "prismatic_beam"]
			if not upgrade["id"] in multi_pick_specials:
				continue
			
		# MUTUAL EXCLUSION: Explosive vs Prismatic Beam
		if upgrade["id"] == "prismatic_beam" and "explosive" in applied_special_upgrades:
			continue
		if upgrade["id"] == "explosive" and "prismatic_beam" in applied_special_upgrades:
			continue

		if is_circle:
			# Removed 'pierce' from the forbidden list as the upgrade itself is removed
			if upgrade["id"] in ["damage", "fire_rate", "homing", "bounce", "explosive", "bullet_speed", "rotation_speed"]:
				continue
		
		# Rarity check for special upgrades (e.g. 20% chance to even be in the pool this time)
		if upgrade.get("is_special", false):
			if randf() > 0.2: # 75% chance to skip a special upgrade from the available pool
				continue
		
		# APPLY DIMINISHING RETURNS TO THE DISPLAY DATA
		var pick_count = upgrade_counts.get(upgrade["id"], 0)
		var diminished_upgrade = upgrade.duplicate()
		
		if pick_count > 0:
			var multiplier = pow(0.7, pick_count) # 30% reduction per level
			diminished_upgrade["value"] = upgrade["value"] * multiplier
			
			# Dynamically update description if it contains a percentage
			if "%" in diminished_upgrade["description"]:
				# Extract the base percentage from the original description
				# Assuming format like "+25% ..."
				var base_percent = int(upgrade["value"] * 100)
				var new_percent = int(diminished_upgrade["value"] * 100)
				diminished_upgrade["description"] = diminished_upgrade["description"].replace(str(base_percent) + "%", str(new_percent) + "%")
				diminished_upgrade["name"] += " (Level %d)" % (pick_count + 1)
			else:
				diminished_upgrade["name"] += " (Level %d)" % (pick_count + 1)
				if upgrade["id"] != "max_hearts":
					diminished_upgrade["description"] += " (Reduced Effectiveness)"

		pool.append(diminished_upgrade)
	
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

func reset_upgrades():
	applied_special_upgrades.clear()
	upgrade_counts.clear() # Clear counts for new run
	level_up_pending = 0
	is_ui_active = false

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
	
	# Increment the pick count
	var upgrade_id = upgrade_data["id"]
	upgrade_counts[upgrade_id] = upgrade_counts.get(upgrade_id, 0) + 1
	
	if player:
		# Use the diminished value already calculated in get_random_upgrades
		player.apply_upgrade(upgrade_id, upgrade_data["value"])
		
	# Track if this was a special upgrade to prevent repeat appearances
	if upgrade_data.get("is_special", false):
		# Some special upgrades can be picked multiple times
		var multi_pick_specials = ["gravity_well", "bounce", "explosive", "prismatic_beam"]
		if not upgrade_data["id"] in multi_pick_specials:
			applied_special_upgrades.append(upgrade_data["id"])
	
	level_up_pending -= 1
	if level_up_pending > 0:
		# Show next upgrade immediately
		show_next_upgrade()
	else:
		# Resume the game
		is_ui_active = false
		get_tree().paused = false
