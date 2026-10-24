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
	},
	{
		"id": "pierce",
		"name": "Piercing Rounds",
		"description": "Bullets pass through +1 enemy",
		"value": 1.0,
		"no_diminish": true,
		"max_picks": 3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_002.png"
	},
	{
		"id": "homing",
		"name": "Seeker Rounds",
		"description": "Bullets curve toward the nearest enemy",
		"value": 0.5,
		"no_diminish": true,
		"max_picks": 3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_004.png"
	},
	{
		"id": "dash_trail",
		"name": "Plasma Wake",
		"description": "Dashing leaves plasma that burns enemies",
		"value": 6.0,
		"no_diminish": true,
		"max_picks": 3,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_006.png"
	},
	{
		"id": "heal",
		"name": "Repair Nanites",
		"description": "Restore 1 heart",
		"value": 1.0,
		"no_diminish": true,
		"needs_missing_heart": true,
		"icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_008.png"
	},
	{
		"id": "breaker",
		"name": "BREAKER ROUNDS",
		"description": "Bullets crack Aegis shields (60% damage) instead of being absorbed",
		"value": 1.0,
		"max_picks": 1,
		"counters": "aegis",
		"icon": ""
	},
	{
		"id": "nova",
		"name": "SHOCKWAVE KILLS",
		"description": "Kills release a shockwave that hurts nearby enemies",
		"value": 1.0,
		"no_diminish": true,
		"max_picks": 3,
		"counters": "splitter",
		"icon": ""
	},
	{
		"id": "deflector",
		"name": "DEFLECTOR",
		"description": "Enemy bullets that reach you are reflected back - snipers' shots hit 4x",
		"value": 1.0,
		"max_picks": 1,
		"counters": "sniper",
		"icon": ""
	},
	{
		"id": "corrupt",
		"name": "CORRUPT ROUNDS",
		"description": "Hits disrupt healing for 3s, so Menders can't pulse or be healed",
		"value": 1.0,
		"max_picks": 1,
		"counters": "healer",
		"icon": ""
	},
	{
		"id": "split",
		"name": "FRACTURE ROUNDS",
		"description": "SPECIAL: Bullets split into two fragments on hit",
		"value": 1.0,
		"is_special": true,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_002.png"
	},
	{
		"id": "chain",
		"name": "ARC LIGHTNING",
		"description": "SPECIAL: Hits arc lightning to 3 nearby enemies",
		"value": 140.0,
		"is_special": true,
		"icon": "res://assets/kenney_rune-pack/PNG/Black/Tile (outline)/runeBlack_tileOutline_004.png"
	}
]

# Combos: owning every id in `needs` unlocks a bonus. Effects live in bullet.gd / player_controller.gd.
const SYNERGIES = [
	{"id": "storm_front", "name": "STORM FRONT", "needs": ["split", "chain"], "description": "fragments arc lightning too"},
	{"id": "chain_reaction", "name": "CHAIN REACTION", "needs": ["explosive", "chain"], "description": "explosions arc lightning"},
	{"id": "hunter_killer", "name": "HUNTER-KILLER", "needs": ["homing", "pierce"], "description": "bullets retarget after each pierce, +1 pierce"},
	{"id": "siege_breaker", "name": "SIEGE BREAKER", "needs": ["breaker", "pierce"], "description": "rounds punch through Aegis shields at full damage"},
	{"id": "cascade", "name": "CASCADE", "needs": ["nova", "explosive"], "description": "shockwaves are 60% wider and 50% stronger"},
	{"id": "return_to_sender", "name": "RETURN TO SENDER", "needs": ["deflector", "homing"], "description": "reflected bullets home in on enemies"},
	{"id": "plague_arc", "name": "PLAGUE ARC", "needs": ["corrupt", "chain"], "description": "lightning arcs spread corruption"},
	{"id": "plasma_slipstream", "name": "PLASMA SLIPSTREAM", "needs": ["dash_trail", "gravity_well"], "description": "plasma lasts longer and hits 50% harder"},
]

const BULLET_MODS = ["pierce", "homing", "split", "chain", "breaker", "corrupt"]
const COUNTER_OFFER_WEIGHT = 2.5 # A counter to a threat you have met is this much more likely

## One-time intel card shown the first time each new enemy type ever appears.
const INTEL = {
	"aegis": {"name": "AEGIS", "title": "NEW THREAT: AEGIS", "text": "The shield absorbs shots from the front. Flank it, dash through it, or use blasts and arcs.", "color": Color(0.3, 0.85, 1.0)},
	"splitter": {"name": "SPLITTER", "title": "NEW THREAT: SPLITTER", "text": "Bursts into fast shards when killed. Clear them with area damage.", "color": Color(1.0, 0.6, 0.15)},
	"sniper": {"name": "SNIPER", "title": "NEW THREAT: SNIPER", "text": "Its aim locks when the beam flashes white. Move, dash, or reflect the shot.", "color": Color(0.9, 0.4, 1.0)},
	"healer": {"name": "MENDER", "title": "NEW THREAT: MENDER", "text": "Pulses healing into nearby enemies. Kill it first.", "color": Color(0.35, 1.0, 0.7)},
}
var seen_enemies: Array = [] # Enemy ids met this run: unlocks their counter upgrades
const SYNERGY_OFFER_WEIGHT = 3.0 # Offers that complete a synergy are this much more likely

var active_synergies: Array = []
var applied_special_upgrades = []
var upgrade_counts = {} # Track how many times each upgrade was picked
var first_upgrade_of_run: bool = true # Track if this is the first level up of the session
var level_up_pending: int = 0
var is_ui_active: bool = false

func get_random_upgrades(count: int = 3) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	var is_circle = player and player.current_shape == 0
	var gd = GlobalData
	var force_specials = first_upgrade_of_run and gd and gd.is_first_run
	
	var pool = []
	for upgrade in upgrade_pool:
		var is_special = upgrade.get("is_special", false)
		
		# If forcing specials, skip anything that isn't special
		if force_specials and not is_special:
			continue
			
		# Check if already applied (only for special ones)
		if is_special and upgrade["id"] in applied_special_upgrades:
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

		# Bullet mods do nothing for a circle (it cannot shoot) or the beam
		if upgrade["id"] in BULLET_MODS and (is_circle or (player and player.prismatic_beam_active)):
			continue
		if upgrade.has("max_picks") and upgrade_counts.get(upgrade["id"], 0) >= upgrade["max_picks"]:
			continue
		if upgrade.has("counters") and not upgrade["counters"] in seen_enemies:
			continue
		if upgrade["id"] == "heal" and GlobalData.protocol_active("no_repairs"):
			continue
		if upgrade.get("needs_missing_heart", false) and player and player.current_hearts >= player.max_hearts:
			continue

		if is_circle:
			# Removed 'pierce' from the forbidden list as the upgrade itself is removed
			if upgrade["id"] in ["damage", "fire_rate", "homing", "bounce", "explosive", "bullet_speed", "rotation_speed"]:
				continue
		
		# Rarity check for special upgrades (e.g. 20% chance to even be in the pool this time)
		if is_special and not force_specials:
			if randf() > 0.2: # 75% chance to skip a special upgrade from the available pool
				continue
		
		# APPLY DIMINISHING RETURNS TO THE DISPLAY DATA
		var pick_count = upgrade_counts.get(upgrade["id"], 0)
		var diminished_upgrade = upgrade.duplicate()
		
		if pick_count > 0 and upgrade.get("no_diminish", false):
			diminished_upgrade["name"] += " (Level %d)" % (pick_count + 1)
		elif pick_count > 0:
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

		var synergy = _completed_synergy(upgrade["id"])
		if not synergy.is_empty():
			diminished_upgrade["description"] += "\nSYNERGY: " + synergy["name"] + " (" + synergy["description"] + ")"
			diminished_upgrade["synergy"] = synergy["id"]

		pool.append(diminished_upgrade)
	
	return _weighted_sample(pool, count)

## Synergy that picking `upgrade_id` would complete (and is not active yet), or {}.
func _completed_synergy(upgrade_id: String) -> Dictionary:
	for syn in SYNERGIES:
		if syn["id"] in active_synergies or not upgrade_id in syn["needs"]:
			continue
		var complete := true
		for need in syn["needs"]:
			if need != upgrade_id and upgrade_counts.get(need, 0) == 0:
				complete = false
		if complete:
			return syn
	return {}

func _offer_weight(u: Dictionary) -> float:
	var w := 1.0
	if u.has("synergy"):
		w = SYNERGY_OFFER_WEIGHT
	if u.has("counters"):
		w = maxf(w, COUNTER_OFFER_WEIGHT)
	return w

func note_enemy_seen(id: String):
	if id in seen_enemies:
		return
	seen_enemies.append(id)
	if INTEL.has(id) and not id in GlobalData.seen_intel:
		GlobalData.seen_intel.append(id)
		GlobalData.save_game()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_intel"):
			hud.show_intel(INTEL[id]["title"], INTEL[id]["text"], INTEL[id]["color"])

func _weighted_sample(pool: Array, count: int) -> Array:
	var remaining = pool.duplicate()
	var picked = []
	while picked.size() < count and not remaining.is_empty():
		var total := 0.0
		for u in remaining:
			total += _offer_weight(u)
		var roll := randf() * total
		for i in remaining.size():
			roll -= _offer_weight(remaining[i])
			if roll <= 0.0 or i == remaining.size() - 1:
				picked.append(remaining[i])
				remaining.remove_at(i)
				break
	return picked

func _check_synergies(player: Node):
	for syn in SYNERGIES:
		if syn["id"] in active_synergies:
			continue
		var complete := true
		for need in syn["needs"]:
			if upgrade_counts.get(need, 0) == 0:
				complete = false
		if complete:
			active_synergies.append(syn["id"])
			if player:
				player.activate_synergy(syn["id"], syn["name"])

func _on_player_level_up():
	level_up_pending += 1
	if is_ui_active:
		return
		
	show_next_upgrade()

func reset_upgrades():
	applied_special_upgrades.clear()
	upgrade_counts.clear() # Clear counts for new run
	active_synergies.clear()
	seen_enemies.clear()
	first_upgrade_of_run = true
	level_up_pending = 0
	is_ui_active = false

func show_next_upgrade():
	if level_up_pending <= 0:
		is_ui_active = false
		get_tree().paused = false
		return
		
	var options = get_random_upgrades(3)
	if options.is_empty():
		# Nothing eligible (everything capped): fall back to the basic stat upgrades so a level-up never soft-locks
		for u in upgrade_pool:
			if u["id"] in ["speed", "damage", "fire_rate", "dash_charge"]:
				options.append(u.duplicate())
		options = options.slice(0, 3)
	is_ui_active = true
	# Pause the game and show UI
	get_tree().paused = true
	request_upgrade_ui.emit(options)

func apply_upgrade(upgrade_data: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	
	# Increment the pick count
	var upgrade_id = upgrade_data["id"]
	upgrade_counts[upgrade_id] = upgrade_counts.get(upgrade_id, 0) + 1
	var gd = GlobalData
	Telemetry.note_pick(str(upgrade_id), int(gd.run_level))

	var is_first_run_evolution = false
	if first_upgrade_of_run:
		first_upgrade_of_run = false
		if gd and gd.is_first_run:
			is_first_run_evolution = true
			gd.is_first_run = false
			gd.save_game()
	
	if player:
		# Use the diminished value already calculated in get_random_upgrades
		player.apply_upgrade(upgrade_id, upgrade_data["value"])
		_check_synergies(player)
		
	# Track if this was a special upgrade to prevent repeat appearances
	if upgrade_data.get("is_special", false):
		# Some special upgrades can be picked multiple times
		var multi_pick_specials = ["gravity_well", "bounce", "explosive", "prismatic_beam"]
		if not upgrade_data["id"] in multi_pick_specials:
			applied_special_upgrades.append(upgrade_data["id"])
	
	level_up_pending = maxi(level_up_pending - 1, 0)
	if level_up_pending > 0:
		# Show next upgrade immediately
		show_next_upgrade()
	else:
		# Resume the game
		is_ui_active = false
		get_tree().paused = false
		
		# EVOLVE TO TRIANGLE: On the first ever upgrade of the first ever run
		# We do this AFTER unpausing to ensure trigger_evolution_visual works correctly
		if is_first_run_evolution and player:
			if player.current_shape == 0:
				player.current_shape = 3
				player.next_evolution_level = player.level + (player.current_shape + 1)
				player.update_shape_visuals()
				# Trigger the visual effect without blocking the rest of the application
				if player.has_method("trigger_evolution_visual"):
					player.trigger_evolution_visual()
