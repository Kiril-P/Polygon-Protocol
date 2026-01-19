extends CharacterBody2D

@export var health: float = 30000.0
@export var max_health: float = 30000.0
@export var xp_value: int = 1500
@export var shard_reward: int = 300 # Even larger reward for second boss

var player: Node2D = null
var is_dying: bool = false
var phase: int = 1
var laser_rotation: float = 0.0
var laser_speed: float = 1.0
var laser_nodes: Array[Line2D] = []
var warning_tweens: Array[Tween] = []
var platform_nodes: Array[Area2D] = []
var platform_angle: float = 0.0
@export var platform_speed: float = 0.3 # Slow enough to follow easily
var lasers_active: bool = true
var lasers_charging: bool = false

var arena_barrier: StaticBody2D = null
var border_radius: float = 1450.0
var heart_color: Color = Color(0.0, 1.0, 1.0) # Pulsar hearts: Cyan

# Enemy variety
var spawn_timer: float = 2.0
var fairy_scene = load("res://scenes/enemy_fairy.tscn")
var shooter_scene = load("res://scenes/enemy_shooter.tscn")

@onready var poly = $Polygon2D

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.dash_nerf_active = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_dash_nerf_warning()
	
	setup_visuals()
	setup_arena_border()
	setup_lasers()
	setup_platforms()
	
	# Spawn initial enemies ONCE at the start of the boss fight
	# If this is the final fight (multiple bosses), spawn fewer each
	var bosses = get_tree().get_nodes_in_group("bosses")
	spawn_variety_enemies(5 if bosses.size() > 1 else 10)

func setup_visuals():
	# Massive Eye Core
	var pts = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32.0) * i
		pts.append(Vector2(100, 0).rotated(angle))
	poly.polygon = pts
	poly.color = Color(0.05, 0.05, 0.1) # Dark Void
	poly.modulate = Color(0, 1.5, 2.0) # Neon Cyan Glow
	
	# Pupils/Inner Core
	var inner = Polygon2D.new()
	var in_pts = PackedVector2Array()
	for i in range(16):
		in_pts.append(Vector2(40, 0).rotated((TAU / 16.0) * i))
	inner.polygon = in_pts
	inner.color = Color(1, 1, 1)
	poly.add_child(inner)

func setup_arena_border():
	# If another boss already has an arena, don't create a second one
	var existing_borders = get_tree().get_nodes_in_group("boss_arena")
	if existing_borders.size() > 0:
		return
		
	var border = Line2D.new()
	border.name = "ArenaBorder"
	border.add_to_group("boss_arena")
	var pts = PackedVector2Array()
	for i in range(65):
		pts.append(Vector2(border_radius, 0).rotated((TAU / 64.0) * i))
	border.points = pts
	border.width = 15.0
	border.default_color = Color(0, 1, 1, 0.6)
	add_child(border)
	
	var static_body = StaticBody2D.new()
	static_body.name = "Barrier"
	static_body.collision_layer = 1
	get_parent().add_child.call_deferred(static_body)
	static_body.global_position = global_position
	arena_barrier = static_body
	
	var segment_count = 16
	for i in range(segment_count):
		var p1 = Vector2(border_radius, 0).rotated((TAU / segment_count) * i)
		var p2 = Vector2(border_radius, 0).rotated((TAU / segment_count) * (i + 1))
		var coll = CollisionShape2D.new()
		var segment = SegmentShape2D.new()
		segment.a = p1
		segment.b = p2
		coll.shape = segment
		static_body.add_child(coll)

func setup_lasers():
	# Clear existing
	for l in laser_nodes:
		l.queue_free()
	laser_nodes.clear()
	
	for t in warning_tweens:
		if t: t.kill()
	warning_tweens.clear()
	
	var count = 2
	if phase == 2: count = 3
	elif phase == 3: count = 5
	
	lasers_charging = true
	
	for i in range(count):
		var laser = Line2D.new()
		laser.width = 4.0 
		laser.default_color = Color(0, 1, 1, 0.2) # Transparent Cyan warning
		laser.points = PackedVector2Array([Vector2.ZERO, Vector2(border_radius, 0)])
		add_child(laser)
		laser_nodes.append(laser)
		
		# Add a very thin "Core" for the warning too, but keep it faint
		var core = Line2D.new()
		core.name = "Core"
		core.width = 1.0
		core.default_color = Color(1, 1, 1, 0.1)
		core.points = laser.points
		laser.add_child(core)
		
		# Warning Flash (Transparent to slightly visible)
		var t_warn = create_tween().set_loops().bind_node(laser)
		t_warn.tween_property(laser, "default_color:a", 0.5, 0.15).set_trans(Tween.TRANS_SINE)
		t_warn.tween_property(laser, "default_color:a", 0.1, 0.15).set_trans(Tween.TRANS_SINE)
		warning_tweens.append(t_warn)
	
	# Delay before lasers become active
	var t_activate = create_tween().bind_node(self)
	t_activate.tween_interval(2.0)
	t_activate.tween_callback(func():
		lasers_charging = false
		for t in warning_tweens:
			if t: t.kill()
		warning_tweens.clear()
		
		for laser in laser_nodes:
			if not is_instance_valid(laser): continue
			
			# DAMAGING STATE: Bright, Opaque, Glowing
			laser.width = 12.0
			laser.default_color = Color(0, 0.8, 1.0, 1.0) # Solid Neon Cyan
			# High HDR values for intense glow
			laser.modulate = Color(2.5, 3.5, 4.0, 1.0) 
			
			var core = laser.get_node_or_null("Core")
			if core:
				core.width = 4.0
				core.default_color = Color(1, 1, 1, 1.0) # Pure white core
				core.modulate = Color(2, 2, 2, 1) # Extra bright core
			
			# Menacing Pulse animation (Thicker and faster)
			var pulse = create_tween().set_loops().bind_node(laser)
			pulse.tween_property(laser, "width", 18.0, 0.08).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(laser, "width", 12.0, 0.08).set_trans(Tween.TRANS_SINE)
			
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("glitch", 5.0, 1.2, 1.5)
	)

func setup_platforms():
	for p in platform_nodes:
		p.queue_free()
	platform_nodes.clear()
	
	for i in range(2):
		var platform = Area2D.new()
		platform.name = "ShelterPlatform"
		# Set collision mask to detect player (layer 2)
		platform.collision_layer = 0
		platform.collision_mask = 2 
		add_child(platform)
		platform_nodes.append(platform)
		
		# Visuals
		var platform_poly = Polygon2D.new()
		var width = 180.0 # Slightly shorter as requested
		var thickness = 50.0
		platform_poly.polygon = PackedVector2Array([
			Vector2(-width/2, -thickness/2),
			Vector2(width/2, -thickness/2),
			Vector2(width/2, thickness/2),
			Vector2(-width/2, thickness/2)
		])
		platform_poly.color = Color(0.0, 1.0, 0.5, 0.4) # Slightly more opaque
		platform_poly.modulate = Color(1.2, 2.0, 1.5) # Neon Glow
		platform.add_child(platform_poly)
		
		# Inner "Battery" Core Visual
		var core = Polygon2D.new()
		core.polygon = PackedVector2Array([
			Vector2(-width/2 + 15, -10),
			Vector2(width/2 - 15, -10),
			Vector2(width/2 - 15, 10),
			Vector2(-width/2 + 15, 10)
		])
		core.color = Color(1, 1, 1, 0.8)
		platform.add_child(core)
		
		# Collision for the Area2D (Refueling/Shelter Detection)
		var coll = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(width, thickness)
		coll.shape = shape
		platform.add_child(coll)
		
		# PHYSICAL COLLISION: Add a StaticBody2D so it blocks bullets
		var static_body = StaticBody2D.new()
		platform.add_child(static_body)
		# Set to Layer 1 (World) so bullets/enemies treat it as a wall
		static_body.collision_layer = 1
		static_body.collision_mask = 0 # It doesn't need to move based on anything
		
		var physical_coll = CollisionShape2D.new()
		physical_coll.shape = shape # Reuse the same shape
		static_body.add_child(physical_coll)

func _physics_process(delta: float):
	if is_dying: return
	
	# Laser Rotation (Never stops)
	laser_rotation += laser_speed * delta
	var count = laser_nodes.size()
	var angle_step = TAU / float(count)
	
	for i in range(count):
		var dir = 1.0
		# In Phase 1 (2 lasers), make them rotate in opposite directions
		if count == 2 and i == 1:
			dir = -1.0
			
		var angle = (laser_rotation * dir) + (angle_step * i)
		laser_nodes[i].rotation = angle
		check_laser_collision(laser_nodes[i])

	# Platform Rotation & Refueling
	platform_angle += platform_speed * delta
	var player_in_platform = false
	for i in range(platform_nodes.size()):
		var angle = platform_angle + (PI * i) # Opposite sides
		var radius = border_radius * 0.55 # Positioned between boss and player typical range
		platform_nodes[i].position = Vector2(radius, 0).rotated(angle)
		platform_nodes[i].rotation = angle + PI/2 # Perpendicular to radius
		
		if player and is_instance_valid(player) and platform_nodes[i].overlaps_body(player):
			player_in_platform = true
			# REFUEL DASH ENERGY
			if "current_energy" in player and "max_energy" in player:
				var refill_rate = 70.0 # Even faster refill
				player.current_energy = min(player.max_energy, player.current_energy + refill_rate * delta)
				player.energy_changed.emit(player.current_energy, player.max_energy)
				
				# Visual feedback: Make the player glow green while refueling
				player.modulate = Color(0.8, 2.5, 1.0)
	
	if player and is_instance_valid(player) and not player_in_platform:
		# Reset modulate if not dashing (player_controller handles dashing modulate)
		if "is_dashing" in player and not player.is_dashing:
			player.modulate = Color(1, 1, 1, 1)
			
	# Heart Spawning logic
	var active_hearts = get_tree().get_nodes_in_group("boss_hearts")
	var has_own_heart = false
	for h in active_hearts:
		if h.get("boss") == self:
			has_own_heart = true
			break
			
	if not has_own_heart and not is_dying:
		spawn_three_hearts()
		
	# Variety enemy spawning during fight for Pulsar (Pressure)
	spawn_timer -= delta
	if spawn_timer <= 0 and not is_dying:
		var boss_enemies = get_tree().get_nodes_in_group("boss_minions")
		var is_final = get_tree().get_nodes_in_group("bosses").size() > 1
		var max_minions = 10 if phase == 1 else 5
		# Final fight overriding limits
		if is_final:
			max_minions = 10 if phase == 1 else 5
			
		if boss_enemies.size() < max_minions:
			spawn_variety_enemies()
		# More frequent spawns for pressure
		spawn_timer = randf_range(3.0, 5.0)

func spawn_variety_enemies(count: int = -1):
	# More enemies based on phase
	if count == -1:
		var is_final = get_tree().get_nodes_in_group("bosses").size() > 1
		if is_final:
			count = 2 if phase == 1 else 1
		else:
			count = 3 if phase == 1 else 4
	
	for i in range(count):
		# Ensure they spawn WELL within the arena (border is 1450). Spawn far from player.
		var spawn_pos = Vector2.ZERO
		var valid_spawn = false
		var attempts = 0
		while not valid_spawn and attempts < 10:
			var dist = randf_range(400, border_radius - 200)
			spawn_pos = global_position + Vector2(dist, 0).rotated(randf() * TAU)
			if player and spawn_pos.distance_to(player.global_position) > 450.0:
				valid_spawn = true
			attempts += 1
		
		var roll = randf()
		var enemy
		if roll < 0.5:
			enemy = fairy_scene.instantiate()
		else:
			enemy = shooter_scene.instantiate()
			
		get_parent().add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.add_to_group("boss_minions")
		
		# Low XP to prevent boss-farming level ups
		if enemy.has_method("set_xp_value"):
			enemy.set_xp_value(1)

func spawn_three_hearts():
	# ADD VARIATION: Pulsar tends to spawn closer, Fortress further
	var is_duo = get_tree().get_nodes_in_group("bosses").size() > 1
	var start_angle = randf() * TAU
	
	for i in range(3):
		var angle = start_angle + (TAU / 3.0) * i + randf_range(-0.2, 0.2) # Added jitter
		
		# Pulsar hearts: Inner to middle range
		var min_dist = border_radius * 0.3
		var max_dist = border_radius * 0.7
		
		if is_duo:
			# Keep them tighter to the center if Fortress is also present
			max_dist = border_radius * 0.55
			
		var dist = randf_range(min_dist, max_dist)
		var pos = Vector2(dist, 0).rotated(angle)
		
		var heart_script = load("res://scripts/boss_pillar.gd")
		var heart = Area2D.new()
		heart.set_script(heart_script)
		heart.set("boss", self)
		get_parent().add_child(heart)
		heart.global_position = global_position + pos
		heart.add_to_group("boss_hearts")

func check_laser_collision(laser: Line2D):
	if not player or not is_instance_valid(player) or lasers_charging: return
	
	var laser_dir = Vector2.RIGHT.rotated(laser.rotation)
	var max_len = border_radius
	var is_blocked = false
	
	# SHELTER CHECK: Check if any platform is blocking this laser
	for platform in platform_nodes:
		var to_platform = platform.global_position - global_position
		var platform_angle_val = to_platform.angle()
		var dist_to_platform = to_platform.length()
		
		# If laser hits the platform
		if abs(angle_difference(laser.rotation, platform_angle_val)) < 0.15: # Tight angle for the platform width
			max_len = dist_to_platform
			is_blocked = true
			break # Assuming platforms don't overlap in a way that matters for the first hit
	
	# Update visual length
	laser.points = PackedVector2Array([Vector2.ZERO, Vector2(max_len, 0)])
	var core = laser.get_node_or_null("Core")
	if core:
		core.points = laser.points

	if is_blocked:
		return # Laser is blocked by shelter!

	var to_player = player.global_position - global_position
	var projection = to_player.dot(laser_dir)
	if projection > 0 and projection < max_len:
		var closest_point = laser_dir * projection
		if player.global_position.distance_to(global_position + closest_point) < 35.0:
			if player.has_method("take_damage"):
				player.take_damage(1)

func remove_one_platform():
	if platform_nodes.is_empty(): return
	
	# Take the last one added
	var p = platform_nodes.pop_back()
	if is_instance_valid(p):
		# Animation for disappearing
		var t = create_tween()
		# Flash red to warn the player it's failing
		var visuals = p.get_children()
		for v in visuals:
			if v is Polygon2D:
				t.parallel().tween_property(v, "color", Color(1, 0, 0, 0.8), 0.5)
				t.parallel().tween_property(v, "modulate", Color(5, 2, 2), 0.5)
		
		t.tween_interval(0.5) # Hold the warning
		
		# Violent shake before deletion
		for i in range(10):
			t.tween_property(p, "position", p.position + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.05)
		
		# Shrink and fade
		t.parallel().tween_property(p, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.3)
		
		t.tween_callback(p.queue_free)
		
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("glitch", 2.0, 0.8, 1.2)

func take_damage(amount: float):
	if is_dying: return
	
	health -= amount
	
	# Visual Flash
	var t = create_tween()
	poly.modulate = Color(5, 5, 5, 1)
	var target_col = Color(0, 1.5, 2.0, 1.0) if phase < 3 else Color(2.0, 0.0, 5.0, 1.0)
	t.tween_property(poly, "modulate", target_col, 0.1)
	
	# Phase Transitions based on health (each set of 3 hearts is 1/3 of max health)
	# User wants 3/9 per heart, so 3 hearts = 9/9 = 100%? 
	# Wait, 3/9 damage per heart means 3 hearts = 9/9 damage.
	# So destroying 3 hearts KILLS the boss if we don't have phases.
	# I'll interpret "3/9 damage" as each heart set representing a phase.
	
	var health_percent = health / max_health
	
	if health_percent < 0.67 and phase == 1:
		phase = 2
		laser_speed *= 1.2
		setup_lasers()
		remove_one_platform() # First platform gone
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn", 1.2)
			get_node("/root/AudioManager").set_boss_music_mode(true, 2)
			
	elif health_percent < 0.34 and phase == 2:
		phase = 3
		laser_speed *= 1.2
		poly.color = Color(0.1, 0.0, 0.2) # Deep Purple Void
		setup_lasers()
		remove_one_platform() # Second platform gone
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn", 1.5)
			get_node("/root/AudioManager").set_boss_music_mode(true, 3)
	
	if health <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return
	is_dying = true
	
	# 1. Stop all attacks and movement
	lasers_active = false
	for l in laser_nodes:
		if is_instance_valid(l): l.visible = false
	for p in platform_nodes:
		if is_instance_valid(p): p.queue_free()
	spawn_timer = 9999.0
	
	# 2. Clear all other enemies and enemy bullets
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			if enemy.has_method("spawn_death_particles"):
				enemy.spawn_death_particles()
			enemy.queue_free()
			
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	for b in bullets:
		if is_instance_valid(b):
			b.queue_free()
			
	# 3. Dramatic visual sequence
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(true)
		get_node("/root/AudioManager").play_sfx("boss_spawn", 2.0, 0.4) # Very deep boom
	
	var death_tween = create_tween()
	# Series of violent shakes and flashes (More intense for Pulsar)
	for i in range(16):
		var pos_offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		death_tween.tween_callback(func(): 
			spawn_small_explosion(global_position + pos_offset)
			if player: player.add_shake(12.0)
			poly.modulate = Color(15, 15, 15, 1) # Super white flash
		)
		death_tween.tween_interval(0.08)
		death_tween.tween_property(poly, "modulate", Color(0, 1.5, 2.0, 1.0), 0.04)
	
	# 4. Final massive explosion and reward
	death_tween.tween_callback(die)

func spawn_small_explosion(pos: Vector2):
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = pos
	p.amount = 25
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.0, 1.0, 1.0) # Cyan Fire for Pulsar
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", -2.0, 1.2, 1.8)

func die():
	# Final cleanup and rewards
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(false)
		get_node("/root/AudioManager").play_sfx("enemy_death", 15.0, 0.2, 0.5)
	
	# Screen shake
	if player and player.has_method("add_shake"):
		player.add_shake(45.0)
	
	# Big explosion particles
	spawn_death_particles()
	
	# Rewards
	if player:
		player.dash_nerf_active = false
		if player.has_method("add_xp"):
			player.add_xp(xp_value)
	
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.total_kills += 1
		gd.run_kills += 1
		gd.add_score(xp_value * 30, player.combo_count if player else 0)
		gd.add_shards(shard_reward) # AWARD SHARDS
		gd.save_game()
	
	# REMOVE ARENA BARRIER AND HEARTS ONLY IF LAST BOSS
	var other_bosses = get_tree().get_nodes_in_group("bosses")
	if other_bosses.size() <= 1: # We are the last one
		if is_instance_valid(arena_barrier):
			arena_barrier.queue_free()
			
		# Also cleanup any orphaned borders
		for b in get_tree().get_nodes_in_group("boss_arena"):
			b.queue_free()
		
	var hearts = get_tree().get_nodes_in_group("boss_hearts")
	for h in hearts:
		if h.get("boss") == self:
			h.queue_free()
			
	queue_free()

func spawn_death_particles():
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
	p.amount = 100
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 300.0
	p.initial_velocity_max = 800.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 15.0
	p.color = Color(0.0, 1.0, 1.0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
