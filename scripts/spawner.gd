extends Node2D

@export var enemy_types: Array[PackedScene] = []
@export var spawn_rate: float = 2.0
@export var spawn_radius: float = 700.0 # Distance from player to spawn

var spawn_timer: float = 0.0
var time_passed: float = 0.0
var player: Node2D = null
var spawn_delay: float = 3.0 # 3 second safety window at start
var tutorial_finished: bool = false

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	
	# Check if tutorial is disabled to start spawning immediately
	if has_node("/root/GlobalData") and not get_node("/root/GlobalData").show_tutorial:
		tutorial_finished = true

func _process(delta: float):
	if not tutorial_finished:
		return
		
	time_passed += delta
	
	# Reduced safety window after tutorial/start
	var current_delay = spawn_delay
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_quick_start:
		current_delay = 0.5 # Start almost immediately
	elif tutorial_finished:
		current_delay = 0.2 # Start spawning almost immediately after tutorial/start
	
	if time_passed < current_delay:
		return

	# Gradually increase spawn rate (Aggressive scaling after 60s)
	var time_factor = (time_passed - spawn_delay) / 60.0 # Normalized to 1.0 at 60s
	var scaling = 1.0 + (time_factor * 0.5) # Base scaling
	
	if time_passed > 60.0:
		# Add exponential component after 60s
		var post_60_time = (time_passed - 60.0) / 60.0
		scaling += pow(post_60_time, 1.5) * 1.5 
		
	var difficulty_mult = 1.0
	if has_node("/root/GlobalData"):
		var level = get_node("/root/GlobalData").difficulty_level
		# 1: 0.7x, 2: 1.0x, 3: 1.5x, 4: 2.0x, 5: 3.0x
		var multipliers = [0.0, 0.7, 1.0, 1.5, 2.0, 3.0]
		difficulty_mult = multipliers[level]
		
	var current_spawn_rate = spawn_rate * difficulty_mult * scaling
	
	spawn_timer += delta
	if spawn_timer >= 1.0 / current_spawn_rate:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	if enemy_types.is_empty():
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	var available_indices = []
	
	# 0: Chaser, 1: Fairy, 2: Shooter, 3: Spinner, 4: Tank, 5: Zigzagger, 6: Kamikaze
	if time_passed < 50: # Phase 1: Early Game Stagger (Extended to 50s)
		available_indices.append(0) # Chasers
		if time_passed >= 15:
			available_indices.append(1) # Fairies at 15s (was 10s)
		if time_passed >= 30:
			available_indices.append(6) # Kamikazes at 30s
		if time_passed >= 40:
			available_indices.append(5) # Zigzaggers at 40s
			
	elif time_passed < 100: # Phase 2: Mid Game Stagger (Extended to 100s)
		available_indices.append_array([0, 1, 5, 6])
		
		# Introduce mid/late enemies one by one with lower initial weights
		if time_passed >= 55:
			available_indices.append(2) # Spinners at 55s (was 42s)
		if time_passed >= 75:
			available_indices.append(4) # Tanks at 75s (was 55s)
		if time_passed >= 90:
			available_indices.append(3) # Shooters at 90s (was 65s)
	else: # Phase 3: Total Chaos (Now starts at 100s instead of 80s)
		# Full weighted mix
		available_indices = [0, 0, 1, 1, 5, 5, 6, 6, 2, 3, 4]
	
	var index = available_indices[randi() % available_indices.size()]
	
	# BOSS SPAWN: Every 3 minutes (180s), spawn a giant tank
	if int(time_passed) % 180 == 0 and int(time_passed) > 0:
		# Just spawn an extra tank for now but make it bigger
		index = 4 
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn")
	
	# Safety check for array size
	index = clamp(index, 0, enemy_types.size() - 1)
	
	var enemy_scene = enemy_types[index]
	if not enemy_scene: return

	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(spawn_radius, 0).rotated(angle)
	
	var enemy = enemy_scene.instantiate()
	# SET POSITION BEFORE ADD_CHILD
	enemy.global_position = spawn_pos
	
	# BOSS SCALING: If this is a boss (giant tank), scale it up
	if int(time_passed) % 180 == 0 and int(time_passed) > 0 and enemy.is_in_group("enemies"):
		enemy.scale = Vector2(4.0, 4.0)
		if "health" in enemy: enemy.health *= 10.0
		if "xp_value" in enemy: enemy.xp_value *= 50
	
	# Scale XP based on time passed
	var base_xp = enemy.xp_value if "xp_value" in enemy else 10
	var scaled_xp = base_xp * (1.0 + (time_passed / 60.0)) # Increase XP over time
	if enemy.has_method("set_xp_value"):
		enemy.set_xp_value(int(scaled_xp))
		
	get_parent().add_child(enemy)
