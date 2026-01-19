extends CharacterBody2D

@export var speed: float = 60.0
@export var health: float = 12000.0
@export var max_health: float = 12000.0
@export var damage: float = 20.0
@export var xp_value: int = 500
@export var shard_reward: int = 150 # Large shard reward for boss

var player: Node2D = null
var is_dying: bool = false
var phase: int = 1
var fire_timer: float = 0.0
var pillar_spawn_timer: float = 5.0 # Increased initial delay
var border_radius: float = 1450.0 # Standardized for boss fights
var arena_barrier: StaticBody2D = null
var heart_color: Color = Color(1.0, 0.2, 0.4) # Fortress hearts: Pink/Red

# Enemy variety
var spawn_timer: float = 2.0
var chaser_scene = load("res://scenes/enemy.tscn")
var shooter_scene = load("res://scenes/enemy_shooter.tscn")

@onready var poly = $Polygon2D
@onready var shield_container = $Shields

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.dash_nerf_active = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_dash_nerf_warning()
	
	setup_boss_visuals()
	setup_arena_border()
	spawn_entrance_effect()
	
	# Spawn initial enemies ONCE at the start of the boss fight
	# If this is the final fight (multiple bosses), spawn fewer each
	var bosses = get_tree().get_nodes_in_group("bosses")
	spawn_variety_enemies(5 if bosses.size() > 1 else 10)

func setup_arena_border():
	# If another boss already has an arena, don't create a second one
	var existing_borders = get_tree().get_nodes_in_group("boss_arena")
	if existing_borders.size() > 0:
		return
		
	var border = Line2D.new()
	border.name = "ArenaBorder"
	border.add_to_group("boss_arena")
	var pts = PackedVector2Array()
	var collision_pts = PackedVector2Array()
	
	# Create circular points for Line2D and Collision
	for i in range(65):
		var angle = TAU/64 * i
		var p = Vector2(border_radius, 0).rotated(angle)
		pts.append(p)
		collision_pts.append(p)
		
	border.points = pts
	border.width = 12.0 # Thicker neon border
	border.default_color = Color(1.0, 0.2, 0.4, 0.8) # Neon Pink
	add_child(border)
	
	# Physics Barrier: Use SegmentShapes for a guaranteed "wall"
	var static_body = StaticBody2D.new()
	static_body.name = "Barrier"
	static_body.collision_layer = 1
	get_parent().add_child.call_deferred(static_body)
	static_body.global_position = global_position
	arena_barrier = static_body
	
	# Create 16 segments to form a solid circular wall
	var segment_count = 16
	for i in range(segment_count):
		var angle1 = (TAU / segment_count) * i
		var angle2 = (TAU / segment_count) * (i + 1)
		
		var p1 = Vector2(border_radius, 0).rotated(angle1)
		var p2 = Vector2(border_radius, 0).rotated(angle2)
		
		var coll = CollisionShape2D.new()
		var segment = SegmentShape2D.new()
		segment.a = p1
		segment.b = p2
		coll.shape = segment
		static_body.add_child(coll)
	
	# Glow effect
	var t_glow = create_tween().set_loops().bind_node(border)
	t_glow.tween_property(border, "default_color:a", 1.0, 0.5)
	t_glow.tween_property(border, "default_color:a", 0.4, 0.5)

func setup_boss_visuals():
	# Revert to normal scale
	poly.scale = Vector2(1.0, 1.0)
	shield_container.scale = Vector2(1.0, 1.0)
	
	# Large Octagon for the core
	var pts = PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(60, 0).rotated(TAU/8 * i))
	poly.polygon = pts
	poly.color = Color(0.1, 0.1, 0.15) # Dark Core
	poly.modulate = Color(2.0, 0.2, 0.2) # Red Glow
	
	# Add orbiting shields
	for i in range(6):
		var shield = Polygon2D.new()
		var s_pts = PackedVector2Array([
			Vector2(20, -30), Vector2(40, 0), Vector2(20, 30), Vector2(10, 0)
		])
		shield.polygon = s_pts
		shield.position = Vector2(120, 0).rotated(TAU/6 * i)
		shield.rotation = TAU/6 * i
		shield.color = Color(1.0, 0.1, 0.4) # Neon Pink
		shield_container.add_child(shield)

func _physics_process(delta: float):
	if is_dying: return
	
	# Orbiting Shields rotation
	shield_container.rotation += 1.5 * delta
	poly.rotation -= 1.5 * delta # INCREASED core rotation speed
	rotation += 0.2 * delta # ROTATE the whole boss node
	
	if not player or not is_instance_valid(player): return
	
	# Movement: Stationary (as requested)
	# move_and_slide()
	
	# Attack Patterns
	fire_timer -= delta
	if fire_timer <= 0:
		if phase == 1:
			fire_radial_burst()
			fire_timer = 2.0
		else:
			# Phase 2: Hectic Radial Burst (Multiple rings)
			fire_hectic_burst()
			fire_timer = 0.8 # Much faster fire rate
			
	# Pillar Spawning (Hearts)
	var active_hearts = get_tree().get_nodes_in_group("boss_hearts")
	var has_own_heart = false
	for h in active_hearts:
		if h.get("boss") == self:
			has_own_heart = true
			break
			
	if not has_own_heart and not is_dying:
		pillar_spawn_timer -= delta
		if pillar_spawn_timer <= 0:
			spawn_pillar()
			pillar_spawn_timer = 2.0 # Short delay before next wave spawns
			
	# Enemy spawning during fight (Normal spawning but limited)
	spawn_timer -= delta
	if spawn_timer <= 0 and not is_dying:
		var boss_enemies = get_tree().get_nodes_in_group("boss_minions")
		var is_final = get_tree().get_nodes_in_group("bosses").size() > 1
		var max_minions = 10 if phase == 1 else 5
		# Final fight has specific limits
		if is_final:
			max_minions = 10 if phase == 1 else 5
			
		if boss_enemies.size() < max_minions:
			spawn_variety_enemies(3 if phase == 1 else 2)
		spawn_timer = randf_range(3.5, 5.5)

func spawn_variety_enemies(count: int = -1):
	if count == -1:
		var is_final = get_tree().get_nodes_in_group("bosses").size() > 1
		count = 3 if phase == 1 else (2 if is_final else 2) # Use smaller bursts for P2
	
	for i in range(count):
		# Border is 1200. Spawn far from player but within border.
		var spawn_pos = Vector2.ZERO
		var valid_spawn = false
		var attempts = 0
		while not valid_spawn and attempts < 10:
			var dist = randf_range(400, border_radius - 150)
			spawn_pos = global_position + Vector2(dist, 0).rotated(randf() * TAU)
			# Ensure it's at least 400 pixels from player
			if player and spawn_pos.distance_to(player.global_position) > 400.0:
				valid_spawn = true
			attempts += 1
		
		var roll = randf()
		var enemy
		if roll < 0.6:
			enemy = chaser_scene.instantiate()
		else:
			enemy = shooter_scene.instantiate()
			
		get_parent().add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.add_to_group("boss_minions")
		
		if enemy.has_method("set_xp_value"):
			enemy.set_xp_value(1)

func spawn_pillar():
	# Spawn 3 hearts
	# ADD VARIATION: Pulsar tends to spawn closer, Fortress further
	var is_duo = get_tree().get_nodes_in_group("bosses").size() > 1
	var start_angle = randf() * TAU
	
	for i in range(3):
		var angle = start_angle + (TAU / 3.0) * i + randf_range(-0.2, 0.2) # Added jitter
		
		# Fortress hearts: Middle to outer range
		var min_dist = border_radius * 0.5
		var max_dist = border_radius - 150.0
		
		if is_duo:
			# Push them further out if Pulsar is also present
			min_dist = border_radius * 0.6
			
		var dist = randf_range(min_dist, max_dist)
		var pos = global_position + Vector2(dist, 0).rotated(angle)
		
		var pillar_script = load("res://scripts/boss_pillar.gd")
		var heart = Area2D.new()
		heart.set_script(pillar_script)
		heart.set("boss", self)
		get_parent().add_child(heart)
		heart.global_position = pos
		
		# Spawn Particles for heart entrance
		spawn_heart_particles(pos)

func spawn_heart_particles(pos: Vector2):
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = pos
	p.amount = 15
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1, 0.2, 0.6) # Match heart color
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func fire_radial_burst():
	# Large spreading ring
	for i in range(12):
		spawn_boss_bullet(Vector2.RIGHT.rotated(TAU/12 * i), 300.0)

func fire_hectic_burst():
	# Two rings, one rotating offset
	for i in range(16):
		spawn_boss_bullet(Vector2.RIGHT.rotated(TAU/16 * i), 400.0)
	
	# Small delay for second ring effect within the same pattern
	var t_hectic = create_tween().bind_node(self)
	t_hectic.tween_interval(0.2)
	t_hectic.tween_callback(func():
		for i in range(12):
			spawn_boss_bullet(Vector2.RIGHT.rotated((TAU/12 * i) + 0.2), 350.0)
	)

func fire_targeted_barrage():
	var dir = (player.global_position - global_position).normalized()
	for i in range(-2, 3):
		spawn_boss_bullet(dir.rotated(i * 0.2), 500.0)

func spawn_boss_bullet(dir: Vector2, b_speed: float):
	var bullet_scene = load("res://scenes/bullet.tscn")
	if not bullet_scene: return
	var b = bullet_scene.instantiate()
	
	# Set properties BEFORE add_child so _ready works correctly
	b.fired_by_enemy = true
	b.direction = dir
	b.speed = b_speed
	b.damage = 10.0 # Boss bullets now damage the player again
	
	b.global_position = global_position + dir * 80.0
	get_parent().add_child(b)
	
	b.scale = Vector2(3.0, 3.0)
	b.add_to_group("enemy_bullets")
	
	if b.has_node("BulletSprite"):
		b.get_node("BulletSprite").color = Color(1.0, 0.2, 0.2)

func take_damage(amount: float):
	if is_dying: return
	
	health -= amount
	
	if health < max_health * 0.67 and phase == 1:
		phase = 2
		# Drastic visual change for Phase 2
		poly.color = Color(0.3, 0.0, 0.0) # Blood Red Core
		poly.modulate = Color(5.0, 0.2, 1.0) # Purplish Rage Glow
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn", 1.2) # Re-use spawn sound for phase change
			get_node("/root/AudioManager").set_boss_music_mode(true, 2)
	
	# Visual Flash
	var t = create_tween()
	poly.modulate = Color(5, 5, 5, 1)
	t.tween_property(poly, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.1)
	
	if health <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return
	is_dying = true
	
	# 1. Stop all attacks and movement
	fire_timer = 9999.0
	spawn_timer = 9999.0
	pillar_spawn_timer = 9999.0
	
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
	# Muffle music/SFX for impact
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(true)
		get_node("/root/AudioManager").play_sfx("boss_spawn", 1.5, 0.5) # Low pitch boom
	
	var hectic_tween = create_tween()
	# Series of violent shakes and flashes
	for i in range(12):
		var pos_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		hectic_tween.tween_callback(func(): 
			spawn_small_explosion(global_position + pos_offset)
			if player: player.add_shake(8.0)
			poly.modulate = Color(10, 10, 10, 1) # Pure white flash
		)
		hectic_tween.tween_interval(0.1)
		hectic_tween.tween_property(poly, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.05)
	
	# 4. Final massive explosion and reward
	hectic_tween.tween_callback(die)

func spawn_small_explosion(pos: Vector2):
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = pos
	p.amount = 20
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.5, 0.0) # Orange/Fire
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", -5.0, 1.5, 2.0)

func die():
	# Final cleanup and rewards
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_muffled(false)
		get_node("/root/AudioManager").play_sfx("enemy_death", 10.0, 0.3, 0.6)
	
	# Screen shake
	if player and player.has_method("add_shake"):
		player.add_shake(30.0)
	
	# Big explosion particles
	spawn_death_particles()
	
	# Rewards
	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
		
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.total_kills += 1
		gd.run_kills += 1
		gd.add_score(xp_value * 20, player.combo_count if player else 0)
		gd.add_shards(shard_reward) # AWARD SHARDS
		gd.save_game()
		
	# REMOVE ARENA BARRIER AND HEARTS ONLY IF LAST BOSS
	var other_bosses = get_tree().get_nodes_in_group("bosses")
	if other_bosses.size() <= 1: # We are the last one (group includes us until next frame)
		if is_instance_valid(arena_barrier):
			arena_barrier.queue_free()
		
		# Also cleanup any orphaned borders
		for b in get_tree().get_nodes_in_group("boss_arena"):
			b.queue_free()
		
	if player:
		player.dash_nerf_active = false
		
	var active_hearts = get_tree().get_nodes_in_group("boss_hearts")
	for heart in active_hearts:
		if is_instance_valid(heart) and heart.get("boss") == self:
			heart.queue_free()
		
	queue_free()

func spawn_entrance_effect():
	# TODO: Teleport in/Glitch effect
	pass

func spawn_death_particles():
	for i in range(5):
		var p = CPUParticles2D.new()
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		p.amount = 50
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 2.0
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 200.0
		p.initial_velocity_max = 500.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 15.0
		p.color = Color(1.0, 0.2, 0.2)
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)
