extends Node2D

@export var enemy_types: Array[PackedScene] = []
@export var spawn_rate: float = 2.0
@export var spawn_radius: float = 700.0 # Distance from player to spawn

var spawn_timer: float = 0.0
var time_passed: float = 0.0
var player: Node2D = null
var spawn_delay: float = 3.0 # 3 second safety window at start
var tutorial_finished: bool = false
var hazard_timer: float = 0.0
const HAZARD_INTERVAL: float = 12.0

var boss_active: bool = false
var bosses_spawned: Array[int] = [] # Track which milestones were hit
var corruption_warning_shown: bool = false
var choice_active: bool = false
var choice_made_360: bool = false

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	
	# Check if tutorial is disabled to start spawning immediately
	if has_node("/root/GlobalData") and not get_node("/root/GlobalData").show_tutorial:
		tutorial_finished = true

func _process(delta: float):
	if not tutorial_finished:
		return
		
	# BOSS MILESTONES: Pause timer at 80s (1:20), 180s (3:00), and 360s (6:00)
	var milestone_times = [80, 180, 360]
	for m in milestone_times:
		# Show warning 10 seconds before (Trigger only once)
		if int(time_passed) == m - 10 and not bosses_spawned.has(m):
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_boss_warning"):
				hud.show_boss_warning(10)
		
		if int(time_passed) == m and not bosses_spawned.has(m):
			if m == 360 and not choice_made_360:
				if not choice_active:
					spawn_6min_choice()
				return # Stop here until choice is made
			
			if m == 360:
				# Spawn BOTH bosses at 6 minutes in the same spot
				var angle = randf() * TAU
				var spawn_pos = player.global_position + Vector2(spawn_radius * 1.2, 0).rotated(angle)
				spawn_major_boss(80, spawn_pos) # Fortress
				spawn_major_boss(180, spawn_pos) # Pulsar
			else:
				spawn_major_boss(m)
			
			bosses_spawned.append(m)
			boss_active = true
			
	# Update boss_active state based on actual nodes in group
	var active_bosses = get_tree().get_nodes_in_group("bosses")
	boss_active = active_bosses.size() > 0 or choice_active
	
	if not boss_active:
		time_passed += delta
	
	# Reduced safety window after tutorial/start
	var current_delay = spawn_delay
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_first_run:
		current_delay = 0.5 # Start almost immediately
	elif tutorial_finished:
		current_delay = 0.2 # Start spawning almost immediately after tutorial/start
	
	if time_passed < current_delay:
		return

	# Gradually increase spawn rate (Aggressive scaling after 60s)
	var time_factor = (time_passed - spawn_delay) / 60.0 # Normalized to 1.0 at 60s
	var scaling = 1.0 + (time_factor * 0.5) # Base scaling
	
	if time_passed > 60.0:
		# Add exponential component after 60s (Slightly nerfed scaling)
		var post_60_time = (time_passed - 60.0) / 60.0
		scaling += pow(post_60_time, 1.4) * 1.2 
		
	var difficulty_mult = 1.0
	if has_node("/root/GlobalData"):
		var level = get_node("/root/GlobalData").difficulty_level
		# 1: 0.7x, 2: 1.0x, 3: 1.5x, 4: 2.0x, 5: 3.0x
		var multipliers = [0.0, 0.7, 1.0, 1.5, 2.0, 3.0]
		difficulty_mult = multipliers[level]
		
	var current_spawn_rate = spawn_rate * difficulty_mult * scaling
	
	if not boss_active:
		spawn_timer += delta
		if spawn_timer >= 1.0 / current_spawn_rate:
			spawn_enemy()
			spawn_timer = 0.0

	if not boss_active:
		# Hazard Spawning
		hazard_timer += delta
		if hazard_timer >= HAZARD_INTERVAL:
			spawn_hazard()
			hazard_timer = 0.0

func spawn_hazard():
	if not player: return
	
	# Show warning on first hazard if tutorial is on
	if not corruption_warning_shown:
		if has_node("/root/GlobalData") and get_node("/root/GlobalData").show_tutorial:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_corruption_warning"):
				hud.show_corruption_warning()
		corruption_warning_shown = true

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("glitch", 5.0, 0.5, 0.8) # Increased volume from -5.0 to 5.0
	
	# Spawn hazard somewhere nearby but not right on top of player
	var angle = randf() * TAU
	var dist = randf_range(200, 500)
	var pos = player.global_position + Vector2(dist, 0).rotated(angle)
	
	var hazard = Area2D.new()
	hazard.script = load("res://scripts/data_corruption.gd")
	
	# Add components needed by script BEFORE add_child so _ready works
	var poly = Polygon2D.new()
	poly.name = "Polygon2D"
	hazard.add_child(poly)
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 1.0 
	collision.shape = shape
	hazard.add_child(collision)
	
	hazard.global_position = pos
	get_parent().add_child(hazard)
	
	# Set collision mask to detect player, enemies, AND bullets
	hazard.collision_layer = 0
	hazard.collision_mask = 0
	hazard.set_collision_mask_value(2, true) # Player
	hazard.set_collision_mask_value(3, true) # Enemies
	hazard.monitorable = true
	hazard.monitoring = true

func spawn_enemy():
	if enemy_types.is_empty():
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	var available_indices = []
	
	# 0: Chaser, 1: Fairy, 2: Shooter, 3: Spinner, 4: Tank, 5: Zigzagger, 6: Kamikaze
	if time_passed < 80: # Phase 1: Early Game Stagger (Extended to 80s)
		available_indices.append_array([0, 0, 0, 1, 1, 6]) # Triple weight for chasers
		if time_passed >= 50:
			available_indices.append(5) # Zigzaggers at 50s
			
	elif time_passed < 180: # Phase 2: Mid Game Stagger (Extended to 180s)
		# Fodder base
		available_indices.append_array([0, 0, 0, 0, 1, 1, 1, 6, 6, 6]) 
		available_indices.append(5) # Zigzaggers
		
		# Heavies (Much rarer)
		if time_passed >= 90:
			available_indices.append(2) # Spinners
		if time_passed >= 110:
			# Reduced tanks further
			pass 
		if time_passed >= 140:
			available_indices.append(3) # Shooters
	else: # Phase 3: Total Chaos (180s+)
		# Heavy weight on fodder to prevent tank overcrowding
		# 0: Chaser(x5), 1: Fairy(x4), 6: Kamikaze(x4), 5: Zigzagger(x2), 2: Shooter(x1), 3: Spinner(x1), 4: Tank(x0.5)
		available_indices = [0, 0, 0, 0, 0, 1, 1, 1, 1, 6, 6, 6, 6, 5, 5, 2, 3, 4]
	
	var index = available_indices[randi() % available_indices.size()]
	
	# MINI-BOSS SPAWN: Every 2 minutes (120s), spawn a giant tank
	if int(time_passed) % 120 == 0 and int(time_passed) > 0:
		# Just spawn an extra tank for now but make it bigger
		index = 4 
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn")
	
	# Safety check for array size
	index = clamp(index, 0, enemy_types.size() - 1)
	
	var enemy_scene = enemy_types[index]
	if not enemy_scene: return

	# Calculate dynamic spawn radius based on camera zoom
	var current_radius = spawn_radius
	if player and player.has_node("Camera2D"):
		var zoom = player.get_node("Camera2D").zoom.x
		# If zoom is 1.0, radius is 700. If zoom is 0.5 (zoomed out), radius is 1400.
		# Add a small buffer to ensure they always spawn off-screen
		current_radius = (spawn_radius / zoom) + 100.0
	
	var angle = randf() * TAU
	
	# ANTI-KITING: 30% chance to spawn specifically in front of the player's movement
	if player.velocity.length() > 10.0 and randf() < 0.3:
		var move_dir = player.velocity.normalized()
		# Cone of 90 degrees in front
		angle = move_dir.angle() + randf_range(-PI/4, PI/4)
	
	var spawn_pos = player.global_position + Vector2(current_radius, 0).rotated(angle)
	
	var enemy = enemy_scene.instantiate()
	# SET POSITION BEFORE ADD_CHILD
	enemy.global_position = spawn_pos
	
	# BOSS SCALING: If this is a mini-boss (giant tank), scale it up
	if int(time_passed) % 120 == 0 and int(time_passed) > 0 and enemy.is_in_group("enemies"):
		enemy.scale = Vector2(4.0, 4.0)
		if "health" in enemy: enemy.health *= 10.0
		if "xp_value" in enemy: enemy.xp_value *= 50
	
	# Scale XP based on time passed
	var base_xp = enemy.xp_value if "xp_value" in enemy else 10
	var scaled_xp = base_xp * (1.0 + (time_passed / 60.0)) # Increase XP over time
	if enemy.has_method("set_xp_value"):
		enemy.set_xp_value(int(scaled_xp))
		
	get_parent().add_child(enemy)

func spawn_major_boss(milestone: int, forced_pos: Vector2 = Vector2.ZERO):
	var boss = CharacterBody2D.new()
	boss.add_to_group("bosses") # Add to group immediately
	boss.add_to_group("enemies") # Add to enemies group immediately so it's ignored by the clear
	
	# KILL ALL ENEMIES ON BOSS SPAWN (Staggered for visual impact, but quieter)
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	
	# Play a single "Sweep" sound if we had a lot of enemies
	if existing_enemies.size() > 5 and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("glitch", -5.0, 0.8, 1.2)

	for enemy in existing_enemies:
		if is_instance_valid(enemy) and enemy != boss and not enemy.is_in_group("bosses"):
			# Stagger the deaths slightly for a "wave" effect
			var delay = randf_range(0.0, 0.5)
			
			# Use a tween bound to the enemy for safe execution
			var t_kill = enemy.create_tween().bind_node(enemy)
			t_kill.tween_interval(delay)
			t_kill.tween_callback(func():
				if is_instance_valid(enemy):
					if enemy.has_method("spawn_death_particles"):
						enemy.spawn_death_particles()
					enemy.queue_free()
			)

	# Connect death signal to resume timer only if it's the last boss
	boss.tree_exited.connect(_on_boss_tree_exited)
	
	if milestone == 180:
		boss.set_script(load("res://scripts/boss_pulsar.gd"))
	else:
		boss.set_script(load("res://scripts/boss_fortress.gd"))
	
	# Add Components
	var poly = Polygon2D.new()
	poly.name = "Polygon2D"
	boss.add_child(poly)
	
	var shields = Node2D.new()
	shields.name = "Shields"
	boss.add_child(shields)
	
	var coll = CollisionShape2D.new()
	coll.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 80.0 # LARGE hit box for multi-directional shooting
	coll.shape = shape
	boss.add_child(coll)
	
	# Position and Grouping
	if forced_pos != Vector2.ZERO:
		boss.global_position = forced_pos
	else:
		var angle = randf() * TAU
		boss.global_position = player.global_position + Vector2(spawn_radius * 1.2, 0).rotated(angle)
	
	boss.set_collision_layer_value(3, true) # Enemy layer
	boss.set_collision_mask_value(1, true) # World
	boss.set_collision_mask_value(2, true) # Player (to avoid overlapping too much if desired)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("boss_spawn", 4.0) 
		get_node("/root/AudioManager").set_boss_music_mode(true, 1) 
		
	get_parent().add_child(boss)
	
	# Clear bullets
	clear_enemy_bullets()

func clear_enemy_bullets():
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	for bullet in bullets:
		if is_instance_valid(bullet):
			# Visual pop for bullet deletion
			var t = bullet.create_tween()
			t.tween_property(bullet, "scale", Vector2.ZERO, 0.2)
			t.tween_callback(bullet.queue_free)

func spawn_6min_choice():
	choice_active = true
	
	# Clear all enemies first
	clear_all_enemies()
	
	# Pause the game for the choice
	get_tree().paused = true
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("boss_spawn", 2.0)
		get_node("/root/AudioManager").set_muffled(true)
	
	# Spawn Choice 1: Boss Fight
	var choice_boss = _create_choice_node("CHALLENGE BOSS", true)
	choice_boss.global_position = player.global_position + Vector2(-300, 0)
	choice_boss.chosen.connect(_on_choice_boss_selected)
	
	# Spawn Choice 2: Endless
	var choice_endless = _create_choice_node("CONTINUE ENDLESS", false)
	choice_endless.global_position = player.global_position + Vector2(300, 0)
	choice_endless.chosen.connect(_on_choice_endless_selected)

func _create_choice_node(text: String, is_boss: bool):
	var node = Area2D.new()
	node.script = load("res://scripts/boss_choice_node.gd")
	node.label_text = text
	node.is_boss_choice = is_boss
	node.add_to_group("choice_nodes")
	# IMPORTANT: Add to the world root or a node that doesn't get paused 
	# (though we set process_mode = ALWAYS on the node itself)
	get_parent().add_child(node)
	return node

func _on_choice_boss_selected():
	get_tree().paused = false
	choice_active = false
	choice_made_360 = true
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(false)
		
	# The milestone logic in _process will now trigger the boss spawn on next frame
	_cleanup_choices()

func _on_choice_endless_selected():
	get_tree().paused = false
	choice_active = false
	choice_made_360 = true
	bosses_spawned.append(360) # Mark as "spawned" so it doesn't trigger again
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(false)
		
	_cleanup_choices()
	
	# Visual feedback for endless
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("level_up", 2.0)

func _cleanup_choices():
	for node in get_tree().get_nodes_in_group("choice_nodes"):
		node.queue_free()

func clear_all_enemies():
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		if is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			if enemy.has_method("spawn_death_particles"):
				enemy.spawn_death_particles()
			enemy.queue_free()
	
	clear_enemy_bullets()

func _on_boss_tree_exited():
	# SAFETY: Ensure spawner is still alive and in tree
	if not is_inside_tree(): return
	
	# Wait a frame to ensure the group size is updated
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	var active_bosses = get_tree().get_nodes_in_group("bosses")
	if active_bosses.size() == 0:
		boss_active = false
		if player:
			player.dash_nerf_active = false
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").set_boss_music_mode(false, 1)
