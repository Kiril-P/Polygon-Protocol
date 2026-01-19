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

func _ready():
	add_to_group("spawner")
	player = get_tree().get_first_node_in_group("player")
	
	# Check if tutorial is disabled to start spawning immediately
	if has_node("/root/GlobalData") and not get_node("/root/GlobalData").show_tutorial:
		tutorial_finished = true

func _process(delta: float):
	if not tutorial_finished:
		return
		
	# BOSS MILESTONES: Pause timer at 80s (1:20) and 180s (3:00) and 300s (5:00)
	var milestone_times = [80, 180, 300]
	for m in milestone_times:
		# Show warning 10 seconds before (Trigger only once)
		if int(time_passed) == m - 10 and not bosses_spawned.has(m):
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_boss_warning"):
				hud.show_boss_warning(10)
		
		if int(time_passed) == m and not bosses_spawned.has(m):
			if m == 300:
				# Spawn BOTH bosses at 5 minutes
				spawn_major_boss(80) # Fortress
				spawn_major_boss(180) # Pulsar
			else:
				spawn_major_boss(m)
			
			bosses_spawned.append(m)
			boss_active = true
			
	# Update boss_active state based on actual nodes in group
	var active_bosses = get_tree().get_nodes_in_group("bosses")
	boss_active = active_bosses.size() > 0
	
	if not boss_active:
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

func spawn_major_boss(milestone: int):
	# KILL ALL ENEMIES ON BOSS SPAWN (Staggered for visual impact, but quieter)
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	
	# Play a single "Sweep" sound if we had a lot of enemies
	if existing_enemies.size() > 5 and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("glitch", -5.0, 0.8, 1.2)

	for enemy in existing_enemies:
		if is_instance_valid(enemy):
			# Stagger the deaths slightly for a "wave" effect
			var delay = randf_range(0.0, 0.5)
			var kill_lambda = func(e):
				if is_instance_valid(e):
					# Create death particles but NO SOUND for mass-kill
					if e.has_method("spawn_death_particles"):
						e.spawn_death_particles()
					e.queue_free()
			
			get_tree().create_timer(delay).timeout.connect(kill_lambda.bind(enemy))

	var boss = CharacterBody2D.new()
	boss.add_to_group("bosses") # Add to group immediately
	
	# Connect death signal to resume timer only if it's the last boss
	boss.tree_exited.connect(func(): 
		# SAFETY: If we are restarting or changing scenes, the tree might be null
		var tree = get_tree()
		if not tree: return
		
		# Wait a frame to ensure the group size is updated
		await tree.process_frame
		
		# Check tree again after await
		tree = get_tree()
		if not tree: return
		
		var active_bosses = tree.get_nodes_in_group("bosses")
		if active_bosses.size() == 0:
			boss_active = false
			if player:
				player.dash_nerf_active = false
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").set_boss_music_mode(false, 1)
	)
	
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
	var angle = randf() * TAU
	boss.global_position = player.global_position + Vector2(spawn_radius * 1.2, 0).rotated(angle)
	boss.set_collision_layer_value(3, true) # Enemy layer
	boss.set_collision_mask_value(1, true) # World
	boss.set_collision_mask_value(2, true) # Player (to avoid overlapping too much if desired)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("boss_spawn", 10.0) 
		get_node("/root/AudioManager").set_boss_music_mode(true, 1) 
		
	get_parent().add_child(boss)
