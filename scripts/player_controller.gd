extends CharacterBody2D


# Movement
@export var base_speed: float = 300.0
@export var speed_multiplier: float = 1.0

# Health
@export var max_hearts: int = 5
var current_hearts: int
@export var iframe_duration: float = 0.8
var iframe_timer: float = 0.0

signal health_changed(new_health: int, max_health: int)
signal xp_changed(current_xp: float, max_xp: float)
signal energy_changed(current_energy: float, max_energy: float)
signal level_up_ready
signal game_over(stats: Dictionary)
signal combo_changed(combo: int, time_left: float)
@export var dash_speed: float = 600.0
@export var max_energy: float = 100.0
@export var energy_consumption: float = 75.0 # Per second
@export var energy_recovery: float = 22.0 # Per second (Reduced from 25.0)
var current_energy: float = 100.0
var regen_delay_timer: float = 0.0 # NEW: Delay after running out
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO

# Boss Nerf state
var dash_nerf_active: bool = false
var base_energy_consumption: float = 60.0
var base_energy_recovery: float = 22.0

# Shape progression
var current_shape: int = 0  # 0 = circle, 3 = triangle, 4 = square, etc.
var level: int = 1
var xp: float = 0.0
var xp_to_next_level: float = 100.0
var next_evolution_level: int = 4

# Shooting
@export var bullet_scene: PackedScene  # Drag bullet.tscn here in inspector
@export var bullet_damage: float = 10.0
@export var bullet_speed: float = 400.0
@export var fire_rate: float = 0.4  # Time between shots (Slightly faster start)
var fire_timer: float = 0.0
var rotation_speed: float = 2.0  # Radians per second
var current_rotation: float = 0.0
var combo_count: int = 0
var combo_timer: float = 0.0
var highest_combo_run: int = 0
var combo_speed_boost: float = 0.0
const COMBO_MAX_TIME: float = 1.4 # Reduced from 1.8 to make it even harder

# Upgrades
var damage_multiplier: float = 1.0
var bullet_pierce: int = 0
var dash_trail_damage: float = 0.0
var bullet_bounces: int = 0
var bullet_homing: float = 0.0
var bullet_explosive: bool = false
var explosion_radius: float = 50.0

# Visuals
@onready var sprite: Polygon2D = $ShapeSprite
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var dash_particles: CPUParticles2D = $DashParticles
@onready var camera: Camera2D = $Camera2D

# Ghosting effect
var ghost_timer: float = 0.0
@export var ghost_delay: float = 0.05

var tutorial_tween: Tween = null
var is_tutorial_active: bool = false

var shake_intensity: float = 0.0
var is_unpausing: bool = false # NEW: Prevent movement during unpause animation

# Meta Upgrade Tracking
var overdrive_available: bool = false
var is_in_overdrive: bool = false

# Shield Meta Progression
var has_shield: bool = false
var shield_node: Node2D = null
var shield_regen_timer: float = 0.0
const SHIELD_REGEN_TIME: float = 15.0

func _ready():
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_hearts = max_hearts
	current_energy = max_energy
	update_shape_visuals()
	
	# Initial Meta-Upgrades
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		if gd.is_upgrade_active("energy_shield"):
			spawn_shield()
	
	# Set Player Palette
	sprite.color = Color(0.0, 0.8, 1.0) # Neon Cyan
	
	# Reset Run Stats
	if has_node("/root/GlobalData"):
		var _gd = get_node("/root/GlobalData")
		_gd.run_kills = 0
		_gd.run_score = 0
		_gd.run_level = 1
		_gd.run_time = 0.0
		overdrive_available = _gd.is_upgrade_active("emergency_overdrive")
		
		# RECURSIVE EVOLUTION
		# (Removed)
	
	# Apply Permanent Stat Boosts
	apply_upgrade("init_permanent", 0)
	
	# Apply Dash Mastery
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_upgrade_active("dash_mastery"):
		energy_consumption *= 0.75 # 25% reduction
	
	# Intro Particle Burst
	spawn_intro_particles()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("player_spawn")
	
	# PHYSICS SETUP (Fixes sticking)
	# Player is Layer 2. Mask 1 (World). NO Mask 3 (Enemies).
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	
	# Initial UI update
	health_changed.emit(current_hearts, max_hearts)
	xp_changed.emit(xp, xp_to_next_level)
	energy_changed.emit(current_energy, max_energy)
	
	# WEB-ONLY GLOW BOOST
	# Browsers need much stronger settings to see the neon effect
	if OS.get_name() == "Web":
		var world_env = get_parent().get_node_or_null("WorldEnvironment")
		if world_env and world_env.environment:
			# We must DUPLICATE the environment resource, otherwise 
			# we change the file on disk/globally
			world_env.environment = world_env.environment.duplicate()
			var env = world_env.environment
			env.glow_intensity = 2.0
			env.glow_bloom = 0.5
			env.glow_hdr_threshold = 0.5
			env.set("glow_levels/1", 1.0)
			env.set("glow_levels/2", 1.0)
			env.set("glow_levels/3", 1.0)
			env.set("glow_levels/4", 1.0)
			env.set("glow_levels/5", 1.0)
	
	# DASH TUTORIAL
	get_tree().paused = false # Ensure game is unpaused at start
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").show_tutorial:
		show_full_tutorial()
	else:
		# If no tutorial, tell spawner it's okay to start
		var spawner = get_tree().get_first_node_in_group("spawner")
		if spawner:
			spawner.tutorial_finished = true
	
	# Spawn Protection
	iframe_timer = 2.0 
	
	if has_node("Area2D"):
		$Area2D.body_entered.connect(_on_area_2d_body_entered)

func spawn_intro_particles():
	var particles = CPUParticles2D.new()
	get_parent().add_child.call_deferred(particles)
	particles.global_position = global_position
	
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 250.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.5, 1.0, 1.0, 0.8) # Cyan burst
	
	particles.emitting = true
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

func show_full_tutorial():
	var canvas = CanvasLayer.new()
	canvas.name = "TutorialCanvas"
	add_child(canvas)
	
	is_tutorial_active = true
	
	# Start spawner immediately so movement and spawning aren't blocked by tutorial labels
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		spawner.tutorial_finished = true
		spawner.time_passed = 0.0
	
	var label = Label.new()
	var use_mouse = get_node("/root/GlobalData").use_mouse_controls
	
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	
	var skip_label = Label.new()
	skip_label.text = "[SPACE TO SKIP]"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.add_theme_font_size_override("font_size", 18)
	skip_label.modulate.a = 0.5
	skip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skip_label.offset_left = -300
	skip_label.offset_right = 300
	skip_label.offset_bottom = -100
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(skip_label)
	
	var lines = [
		"USE MOUSE TO MOVE" if use_mouse else "USE WASD TO MOVE",
		"DASH INTO ENEMIES TO KILL",
		"EVOLVE BEFORE YOU ARE OVERWHELMED"
	]
	
	tutorial_tween = create_tween()
	for i in range(lines.size()):
		var line = lines[i]
		tutorial_tween.tween_callback(func(): 
			label.text = line
			label.modulate = Color(2.0, 2.0, 2.5, 0.0) # Bright neon glow
			label.scale = Vector2(0.5, 0.5)
			# Need to wait for label to size itself
			label.pivot_offset = label.size / 2
		)
		# Pop animation
		tutorial_tween.tween_property(label, "modulate:a", 1.0, 0.3)
		tutorial_tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
		
		tutorial_tween.tween_interval(2.5) # Increased from 1.5 for better readability
		
		# Out animation
		tutorial_tween.tween_property(label, "modulate:a", 0.0, 0.4) # Slower fade
		tutorial_tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
		
	tutorial_tween.tween_callback(finish_tutorial)

func _input(event):
	if is_tutorial_active:
		if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
			skip_tutorial()

func skip_tutorial():
	if tutorial_tween:
		tutorial_tween.kill()
	finish_tutorial()

func finish_tutorial():
	is_tutorial_active = false
	if has_node("TutorialCanvas"):
		$TutorialCanvas.queue_free()
	
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and not spawner.tutorial_finished:
		spawner.tutorial_finished = true
		spawner.time_passed = 0.0 
		spawner.spawn_timer = 10.0 # Force immediate spawn after safety window

func _physics_process(delta: float):
	# Pause Input (Always check this first)
	if Input.is_action_just_pressed("ui_cancel"):
		if not is_unpausing:
			toggle_pause()
		return # Stop processing this frame to avoid double-triggers
	
	if get_tree().paused or is_unpausing:
		return
		
	iframe_timer -= delta
	
	# Low health tremble & flash
	if current_hearts == 1:
		add_shake(5.0) # Very noticeable panicked tremble
		sprite.modulate.a = 0.5 + abs(sin(Time.get_ticks_msec() * 0.01)) * 0.5
		
		# Occasional glitch red color
		if randf() < 0.05:
			sprite.color = Color.RED
		else:
			update_health_visuals() # Re-apply dimmed color
	
	# Camera shake
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, 7.0 * delta) # Slower decay for more impact
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		camera.offset = Vector2.ZERO
	
	# Constant contact damage check
	if iframe_timer <= 0:
		var vulnerable = true
		if is_dashing:
			# Dashing is permanently invulnerable
			vulnerable = false
		
		if vulnerable:
			check_contact_damage()
	
	# DASH/BOOST INPUT
	if (Input.is_action_pressed("dash") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and current_energy > 0:
		if not is_dashing:
			is_dashing = true
			modulate = Color(1.2, 1.8, 2.0, 1.0) # Cyber Cyan
			
			# DASH IMPACT POLISH
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("trigger_dash_effect"):
				hud.trigger_dash_effect(0.2)
			
			# Camera kick (Zoom IN slightly for impact)
			var base_zoom = camera.zoom
			var kick_tween = create_tween()
			kick_tween.tween_property(camera, "zoom", base_zoom * 1.05, 0.1).set_trans(Tween.TRANS_BACK)
			kick_tween.tween_property(camera, "zoom", base_zoom, 0.2).set_delay(0.1)
			
			if has_node("/root/AudioManager"):
				# Lower volume (-10db) and start persistent loop
				get_node("/root/AudioManager").start_persistent_sfx("player_dash", "dash", -10.0)
		
		# Screen rumble for dashing
		add_shake(2.0)
		
		# REDUCED consumption mult from 2.5 to 1.8 for better feel
		var consumption_mult = 1.8 if dash_nerf_active else 1.0
		current_energy -= energy_consumption * consumption_mult * delta
		
		if current_energy <= 0: 
			current_energy = 0
			is_dashing = false
			modulate = Color(1, 1, 1, 1)
			regen_delay_timer = 1.0 if dash_nerf_active else 0.5
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").stop_persistent_sfx("dash")
		energy_changed.emit(current_energy, max_energy)
	else:
		if is_dashing:
			is_dashing = false
			modulate = Color(1, 1, 1, 1)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").stop_persistent_sfx("dash")
		
	if current_energy < max_energy:
			if regen_delay_timer > 0:
				regen_delay_timer -= delta
			else:
				var current_recovery = energy_recovery
				if dash_nerf_active:
					current_recovery *= 0.4 # Recovery is 60% slower
				current_energy += current_recovery * delta
				if current_energy > max_energy: current_energy = max_energy
				energy_changed.emit(current_energy, max_energy)

	# Combo Timer
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()
		else:
			combo_changed.emit(combo_count, combo_timer / COMBO_MAX_TIME)

	handle_movement(delta)
	handle_rotation(delta)
	handle_shooting(delta)
	
	move_and_slide()
	
	# Particles for dash
	if dash_particles:
		dash_particles.emitting = is_dashing
	
	# Ghosting effect while dashing
	if is_dashing:
		ghost_timer -= delta
		if ghost_timer <= 0:
			spawn_ghost()
			ghost_timer = ghost_delay

	# Shield Regeneration logic
	if not has_shield and has_node("/root/GlobalData") and get_node("/root/GlobalData").is_upgrade_active("shield_regen"):
		shield_regen_timer += delta
		if shield_regen_timer >= SHIELD_REGEN_TIME:
			spawn_shield()
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("shield_regen")

func spawn_shield():
	has_shield = true
	shield_regen_timer = 0.0
	
	shield_node = Node2D.new()
	add_child(shield_node)
	
	# Visual for shield (a rotating ring or circle)
	var visual = Polygon2D.new()
	shield_node.add_child(visual)
	
	var points = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32) * i
		points.append(Vector2(45, 0).rotated(angle))
	visual.polygon = points
	visual.color = Color(0.2, 0.6, 1.0, 0.3)
	
	# Rotating animation
	var tween = create_tween().set_loops(9999)
	tween.tween_property(shield_node, "rotation", TAU, 2.0).as_relative()
	
	# Pulse effect
	var pulse = create_tween().set_loops(9999)
	pulse.tween_property(visual, "modulate:a", 0.6, 0.5)
	pulse.tween_property(visual, "modulate:a", 0.2, 0.5)

func spawn_ghost():
	var ghost = Polygon2D.new()
	get_parent().add_child(ghost)
	
	# Match current shape and rotation
	ghost.polygon = sprite.polygon
	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.scale = scale
	
	# Match color but make it transparent
	ghost.color = sprite.color
	ghost.modulate.a = 0.5
	
	# Fade out and delete
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)

func handle_movement(delta: float):
	var speed = (dash_speed if is_dashing else base_speed) * speed_multiplier
	var input_dir = Vector2.ZERO
	
	var use_mouse = false
	if has_node("/root/GlobalData"):
		use_mouse = get_node("/root/GlobalData").use_mouse_controls
	
	if use_mouse:
		var mouse_pos = get_global_mouse_position()
		var to_mouse = mouse_pos - global_position
		var distance = to_mouse.length()
		
		if distance > 15: # Slightly larger deadzone
			input_dir = to_mouse.normalized()
			
			# Soft Arrival: Slow down as we get very close to the cursor
			# to prevent "overshooting" and jittering
			if distance < 50:
				speed *= (distance / 50.0)
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() > 0:
		velocity = input_dir.normalized() * speed
	else:
		# Faster deceleration for snappier stop
		velocity = velocity.move_toward(Vector2.ZERO, speed * 15 * delta)
	
	# DEBUG: Press 'L' to level up instantly
	if OS.is_debug_build() and Input.is_key_pressed(KEY_L):
		add_xp(xp_to_next_level)

func handle_rotation(delta: float):
	# Auto-rotate the shape
	current_rotation += rotation_speed * delta
	rotation = current_rotation

func handle_shooting(delta: float):
	if current_shape < 3:  # Circle has no shooting
		return
	
	fire_timer -= delta
	if fire_timer <= 0:
		shoot()
		fire_timer = fire_rate

func shoot():
	if not bullet_scene:
		return
	
	# Play SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("player_fire")
	
	# Fire bullets from each edge
	var angle_step = TAU / current_shape
	for i in range(current_shape):
		var bullet_angle = current_rotation + (angle_step * i)
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		
		# Position bullet at edge of shape
		var spawn_offset = Vector2(30, 0).rotated(bullet_angle)
		bullet.global_position = global_position + spawn_offset
		
		# Set bullet properties
		bullet.direction = Vector2.RIGHT.rotated(bullet_angle)
		bullet.speed = bullet_speed
		bullet.damage = bullet_damage * damage_multiplier
		bullet.pierce = bullet_pierce
		
		# Apply special upgrades
		if bullet.has_method("apply_upgrade"):
			if bullet_bounces > 0:
				bullet.apply_upgrade("bounce", bullet_bounces)
			if bullet_homing > 0:
				bullet.apply_upgrade("homing", bullet_homing)
			if bullet_explosive:
				bullet.apply_upgrade("explode", explosion_radius)

func reset_combo():
	if combo_count > 10 and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("combo_break", -10.0, 0.8, 1.2)
	combo_count = 0
	combo_timer = 0
	speed_multiplier -= combo_speed_boost
	combo_speed_boost = 0.0
	combo_changed.emit(0, 0)

func add_xp(amount: float):
	xp += amount
	
	# Reset combo if it expired
	if combo_timer <= 0:
		combo_count = 0
		speed_multiplier -= combo_speed_boost
		combo_speed_boost = 0.0
	
	# Increment Combo
	combo_count += 1
	if combo_count > highest_combo_run:
		highest_combo_run = combo_count
	combo_timer = COMBO_MAX_TIME
	
	# Speed boost based on combo (max 50% boost)
	speed_multiplier -= combo_speed_boost
	combo_speed_boost = min(0.5, combo_count * 0.01)
	speed_multiplier += combo_speed_boost
	
	combo_changed.emit(combo_count, 1.0)
	
	xp_changed.emit(xp, xp_to_next_level)
	if xp >= xp_to_next_level:
		level_up()

func level_up():
	level += 1
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").run_level = level
	xp -= xp_to_next_level
	xp_to_next_level *= 1.15  # Scaling XP requirement
	xp_changed.emit(xp, xp_to_next_level)
	
	# Slowly unzoom camera with exponential decay and a limit
	if camera:
		var min_zoom = 0.6 # Slightly decreased from 0.7 to allow more zoom-out
		var current_zoom = camera.zoom.x
		# Each level-up moves 12% of the way toward min_zoom (slightly faster zoom out)
		var new_zoom_val = lerp(current_zoom, min_zoom, 0.12)
		var target_zoom = Vector2(new_zoom_val, new_zoom_val)
		create_tween().tween_property(camera, "zoom", target_zoom, 1.0).set_trans(Tween.TRANS_SINE)
	
	# Shape progression: Update shape based on current level
	if level >= next_evolution_level:
		await trigger_evolution_visual()
		if current_shape == 0:
			current_shape = 3
		else:
			current_shape += 1
		
		next_evolution_level = level + (current_shape + 1)
		update_shape_visuals()
	
	# Camera shake for level up
	add_shake(15.0)
	
	# LEVEL UP BLAST: Visual and physical impact
	trigger_level_up_blast()
	
	# Play SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("level_up")
	
	# Open Upgrade UI via Autoload
	if has_node("/root/UpgradeManager"):
		get_node("/root/UpgradeManager")._on_player_level_up()
	
	level_up_ready.emit()

func trigger_evolution_visual():
	# 1. Freeze game briefly
	var old_pause = get_tree().paused
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().paused = old_pause
	
	# 2. Flash/Shine
	var shine = Polygon2D.new()
	get_parent().add_child(shine)
	shine.polygon = sprite.polygon
	shine.global_position = global_position
	shine.scale = Vector2(1, 1)
	shine.color = Color(2, 2, 2, 1) # Super bright
	
	var tween = create_tween()
	tween.tween_property(shine, "scale", Vector2(5, 5), 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shine, "modulate:a", 0.0, 0.4)
	tween.tween_callback(shine.queue_free)
	
	add_shake(20.0)

func trigger_level_up_blast():
	# 1. Hit Stop & Flash
	Engine.time_scale = 0.05
	# Force reset after real-time delay
	var timer = get_tree().create_timer(0.15, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	# 2. Visual Shockwave (Scale pop)
	var blast_visual = Polygon2D.new()
	get_parent().add_child(blast_visual)
	blast_visual.global_position = global_position
	
	# Dust Explosion Particles
	var dust = CPUParticles2D.new()
	get_parent().add_child(dust)
	dust.global_position = global_position
	dust.amount = 40
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.spread = 180.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 300.0
	dust.initial_velocity_max = 600.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 5.0
	dust.color = Color(1, 1, 1, 0.6)
	dust.emitting = true
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)
	
	# Create circle points
	var points = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32) * i
		points.append(Vector2(10, 0).rotated(angle))
	blast_visual.polygon = points
	blast_visual.color = Color(1.5, 1.5, 2.0, 0.8) # Bright blue-white
	
	var tween = create_tween()
	tween.tween_property(blast_visual, "scale", Vector2(60, 60), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(blast_visual, "modulate:a", 0.0, 0.5)
	tween.tween_callback(blast_visual.queue_free)
	
	# 3. Push back enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is CharacterBody2D:
			# BOSS IMMUNITY: Don't push back bosses
			if enemy.is_in_group("bosses"):
				continue
				
			var push_dir = (enemy.global_position - global_position).normalized()
			var distance = global_position.distance_to(enemy.global_position)
			# Reduced pushback strength from 600 to 350
			var push_strength = 350.0 * (1.0 - clamp(distance / 800.0, 0, 0.8))
			var target_pos = enemy.global_position + push_dir * push_strength
			
			var push_tween = create_tween()
			push_tween.tween_property(enemy, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	# Blast Cleaning: Delete bullets if upgrade is purchased
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_upgrade_active("blast_cleaning"):
		var bullets = get_tree().get_nodes_in_group("enemy_bullets")
		for b in bullets:
			# Visual effect for bullet deletion
			var b_tween = create_tween()
			b_tween.tween_property(b, "scale", Vector2.ZERO, 0.2)
			b_tween.tween_callback(b.queue_free)

func add_shake(intensity: float):
	shake_intensity = intensity

func toggle_pause():
	# NEVER allow unpausing if the Upgrade UI is open
	var upgrade_ui = get_tree().get_first_node_in_group("upgrade_ui")
	if upgrade_ui and upgrade_ui.visible:
		return
		
	if get_tree().paused:
		# Unpausing: Animate fragments back together
		is_unpausing = true # Prevent movement during animation
		
		# Clear muffled effect
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").set_muffled(false)
			
		if has_node("PauseCanvas"):
			var canvas = $PauseCanvas
			var menu_ui = canvas.get_node_or_null("PauseMenuUI")
			var bg = canvas.get_node_or_null("PauseBG")
			var shard_container = canvas.get_node_or_null("ShardContainer")
			
			var unpause_tween = canvas.create_tween().set_parallel(true)
			
			if menu_ui:
				unpause_tween.tween_property(menu_ui, "modulate:a", 0.0, 0.2)
			if bg:
				unpause_tween.tween_property(bg, "modulate:a", 0.0, 0.3)
				
			if shard_container:
				for piece in shard_container.get_children():
					if piece is Sprite2D:
						# Original position is based on its region_rect
						var original_pos = piece.region_rect.position + piece.region_rect.size / 2.0
						unpause_tween.tween_property(piece, "position", original_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
						unpause_tween.tween_property(piece, "rotation", 0.0, 0.4)
						# Fade back in to full opacity during movement
						unpause_tween.parallel().tween_property(piece, "modulate:a", 1.0, 0.3)
			
			unpause_tween.set_parallel(false)
			# Brief delay to let the eye register the "snap" before resuming
			unpause_tween.tween_interval(0.05) 
			unpause_tween.tween_callback(func():
				# 1. Unpause the game engine first
				get_tree().paused = false
				
				# 2. Keep the shards visible for 2 more frames while fading
				# This masks the transition from the static screenshot back to live game
				if bg:
					var final_fade = create_tween()
					final_fade.tween_property(bg, "modulate:a", 0.0, 0.1)
					final_fade.tween_callback(func():
						is_unpausing = false # Finally re-enable movement/input
						canvas.queue_free()
					)
				else:
					is_unpausing = false
					canvas.queue_free()
			)
		else:
			get_tree().paused = false
			is_unpausing = false
	else:
		pause_game_fractured()

func pause_game_fractured():
	# Capture screen EXACTLY as it is (including camera smoothing lag)
	var image = get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)
	
	# Get player's position on screen to make them the center of the fracture
	var screen_pos = get_global_transform_with_canvas().get_origin()
	
	# Zero out velocity to prevent "teleporting" on unpause
	velocity = Vector2.ZERO
	
	# Play SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("pause")
		get_node("/root/AudioManager").set_muffled(true)
	
	get_tree().paused = true
	
	# Create Canvas Layer for the overlay
	var canvas = CanvasLayer.new()
	canvas.name = "PauseCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	
	# Dark Background
	var bg = ColorRect.new()
	bg.name = "PauseBG"
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	# Pause Menu UI Container
	var menu_ui = VBoxContainer.new()
	menu_ui.name = "PauseMenuUI"
	menu_ui.set_anchors_preset(Control.PRESET_CENTER)
	menu_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_ui.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_ui.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_ui.add_theme_constant_override("separation", 20)
	canvas.add_child(menu_ui)
	
	# Run Stats (New addition)
	var gd = get_node("/root/GlobalData") if has_node("/root/GlobalData") else null
	if gd:
		var stats_box = VBoxContainer.new()
		stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
		menu_ui.add_child(stats_box)
		
		var score_label = Label.new()
		score_label.text = "SCORE: " + str(gd.run_score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", 32)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Gold
		score_label.modulate = Color(2.0, 2.0, 1.5) # Strong Glow
		stats_box.add_child(score_label)
		
		var kills_label = Label.new()
		kills_label.text = "KILLS: " + str(gd.run_kills)
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kills_label.add_theme_font_size_override("font_size", 28)
		kills_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4)) # Neon Pink
		kills_label.modulate = Color(2.0, 1.2, 1.5) # Strong Glow
		stats_box.add_child(kills_label)
		
		var time_label = Label.new()
		var spawner = get_tree().get_first_node_in_group("spawner")
		var t = spawner.time_passed if spawner else 0.0
		time_label.text = "TIME: %02d:%02d" % [int(t / 60), int(t) % 60]
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 28)
		time_label.add_theme_color_override("font_color", Color(0, 1, 1)) # Cyan
		time_label.modulate = Color(1.5, 2.0, 2.0) # Strong Glow
		stats_box.add_child(time_label)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		menu_ui.add_child(spacer)
	
	# Title
	var label = Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 16)
	menu_ui.add_child(label)
	
	# Create Buttons helper function for animations
	var style_btn = func(btn: Button):
		var normal = StyleBoxFlat.new()
		normal.bg_color = Color(0.1, 0.1, 0.2, 0.6)
		normal.border_width_left = 4
		normal.border_color = Color(0.0, 0.8, 1.0, 0.6)
		normal.corner_radius_top_left = 2
		normal.corner_radius_bottom_right = 15
		normal.content_margin_left = 20
		normal.content_margin_right = 20
		
		var hover = normal.duplicate()
		hover.bg_color = Color(0.2, 0.2, 0.4, 0.8)
		hover.border_color = Color(0.0, 1.0, 1.0, 1.0)
		hover.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
		hover.shadow_size = 10
		
		var pressed = hover.duplicate()
		pressed.bg_color = Color(0.3, 0.1, 0.4, 0.9)
		pressed.border_color = Color(1.0, 0.0, 1.0, 1.0)
		
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_constant_override("outline_size", 4)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

	var setup_btn = func(btn: Button, size: int):
		style_btn.call(btn)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", size)
		btn.pivot_offset = Vector2(100, 25) # Approximate
		btn.focus_mode = Control.FOCUS_NONE
		
		btn.mouse_entered.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("hover")
			var t = canvas.create_tween()
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(btn, "modulate", Color(1.5, 1.5, 2.0), 0.2)
		)
		btn.mouse_exited.connect(func():
			var t = canvas.create_tween()
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(btn, "modulate", Color.WHITE, 0.2)
		)
		btn.button_down.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
			btn.scale = Vector2(0.9, 0.9)
		)
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)
	
	# Resume Button
	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	setup_btn.call(resume_btn, 32)
	resume_btn.pressed.connect(toggle_pause)
	menu_ui.add_child(resume_btn)
	
	# Main Menu Button
	var main_menu_btn = Button.new()
	main_menu_btn.text = "BACK TO MAIN MENU"
	setup_btn.call(main_menu_btn, 24)
	main_menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	menu_ui.add_child(main_menu_btn)
	
	# Shard Container (Must be on top of UI to hide it initially)
	var shard_container = Control.new()
	shard_container.name = "ShardContainer"
	shard_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	shard_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shard_container)
	
	# Fracture logic (Grid based)
	var cols = 8
	var rows = 6
	var screen_size = get_viewport().get_visible_rect().size
	var piece_size = screen_size / Vector2(cols, rows)
	
	for y in range(rows):
		for x in range(cols):
			var piece = Sprite2D.new()
			shard_container.add_child(piece)
			piece.texture = texture
			piece.region_enabled = true
			piece.region_rect = Rect2(Vector2(x, y) * piece_size, piece_size)
			piece.position = Vector2(x, y) * piece_size + piece_size / 2.0
			
			# Direction away from player's screen position
			var dir_from_player = (piece.position - screen_pos).normalized()
			if piece.position.distance_to(screen_pos) < 10:
				dir_from_player = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			
			# Animate out to open the middle
			var tween = canvas.create_tween()
			var target_pos = piece.position + dir_from_player * 500.0
			var target_rot = randf_range(-0.5, 0.5)
			tween.tween_property(piece, "position", target_pos, 0.7).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(piece, "rotation", target_rot, 0.7)
			tween.parallel().tween_property(piece, "modulate:a", 0.0, 0.7)
			
	# Fade in the UI slightly after shards start moving
	menu_ui.modulate.a = 0
	bg.modulate.a = 0
	var ui_tween = canvas.create_tween()
	ui_tween.tween_property(bg, "modulate:a", 1.0, 0.4)
	ui_tween.parallel().tween_property(menu_ui, "modulate:a", 1.0, 0.4).set_delay(0.2)

func evolve_shape():
	if current_shape == 0:
		current_shape = 3  # Circle -> Triangle
	else:
		current_shape += 1  # Add one edge
	
	update_shape_visuals()
	# TODO: Screen shake, particles, sound

func update_shape_visuals():
	var points: PackedVector2Array = []
	
	if current_shape == 0:
		# Circle
		for i in range(32):
			var angle = (TAU / 32) * i
			points.append(Vector2(20, 0).rotated(angle))
	else:
		# Regular polygon
		var angle_step = TAU / current_shape
		for i in range(current_shape):
			var angle = angle_step * i
			points.append(Vector2(25, 0).rotated(angle))
	
	sprite.polygon = points
	collision.polygon = points

func spawn_player_death_particles():
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	
	particles.amount = 50
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color = sprite.color
	
	particles.emitting = true
	
	# Auto-delete particles
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(particles.queue_free)

func take_damage(_amount: float):
	if iframe_timer > 0:
		return
		
	# Dashing is permanently invulnerable
	if is_dashing:
		return
		
	# Check Shield first
	if has_shield:
		has_shield = false
		shield_regen_timer = 0.0
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("shield_break")
		if is_instance_valid(shield_node):
			# Shatter effect
			var shatter_tween = create_tween()
			shatter_tween.tween_property(shield_node, "scale", Vector2(1.5, 1.5), 0.1)
			shatter_tween.parallel().tween_property(shield_node, "modulate:a", 0.0, 0.1)
			shatter_tween.tween_callback(shield_node.queue_free)
		
		# Give full iframes for the shield break
		iframe_timer = iframe_duration
		add_shake(20.0)
		
		# REPULSIVE ARMOR (Also triggers on shield break)
		if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_upgrade_active("repulsive_armor"):
			trigger_repulsive_pushback()
			
		return

	current_hearts -= 1
	health_changed.emit(current_hearts, max_hearts)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("player_hit", 5.0) # Boosted volume
		
	add_shake(60.0) # Massive hit impact
	
	# Dim glow based on health
	update_health_visuals()
	
	# Set iframes here so it applies to ALL damage sources
	iframe_timer = iframe_duration
	
	# HITSTOP & IMPACT FRAMES
	trigger_hit_impact()

	# Extreme Overdriven Red flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 0, 0, 1), 0.1) 
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# EMERGENCY OVERDRIVE
	if current_hearts == 1 and overdrive_available and not is_in_overdrive:
		trigger_emergency_overdrive()
	
	# REPULSIVE ARMOR
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").is_upgrade_active("repulsive_armor"):
		trigger_repulsive_pushback()
	
	if current_hearts <= 0:
		die()

func trigger_repulsive_pushback():
	# Visual Shockwave
	var blast = Polygon2D.new()
	get_parent().add_child(blast)
	blast.global_position = global_position
	
	var points = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32) * i
		points.append(Vector2(10, 0).rotated(angle))
	blast.polygon = points
	blast.color = Color(1.0, 0.2, 0.4, 0.6) # Reddish shockwave
	
	var tween = create_tween()
	tween.tween_property(blast, "scale", Vector2(25, 25), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(blast.queue_free)
	
	# Push back nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# Don't push bosses
		if enemy.is_in_group("bosses"):
			continue
			
		var dist = global_position.distance_to(enemy.global_position)
		if dist < 250.0:
			var push_dir = (enemy.global_position - global_position).normalized()
			var push_strength = 300.0 * (1.0 - (dist / 250.0))
			var target_pos = enemy.global_position + push_dir * push_strength
			
			var push_tween = create_tween()
			push_tween.tween_property(enemy, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func trigger_emergency_overdrive():
	overdrive_available = false
	is_in_overdrive = true
	
	# Visual/Sound
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("level_up", 5.0, 1.5, 2.0)
	
	# Boost stats
	var original_speed = speed_multiplier
	var original_rate = fire_rate
	
	speed_multiplier += 0.5
	fire_rate *= 0.5
	
	# Glow effect
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate", Color(5, 2, 5, 1), 0.5) # Neon Purple/Pink glow
	
	# Duration
	await get_tree().create_timer(5.0).timeout
	
	# Restore stats
	speed_multiplier = original_speed
	fire_rate = original_rate
	is_in_overdrive = false
	
	var t2 = create_tween()
	t2.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.5)

func trigger_hit_impact():
	# 1. Hit-stop: Set time scale to slow
	if Engine.time_scale < 1.0: return # Prevent overlapping hitstop
	Engine.time_scale = 0.05
	
	# 2. Impact Frame: White flash on HUD
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add to HUD or a global layer
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_child(flash)
	else:
		get_parent().add_child(flash)
		
	# Delay to restore time and remove flash
	# Using true for ignore_time_scale ensures this ALWAYS finishes in 0.08s real time
	var timer = get_tree().create_timer(0.08, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0 # Force back to normal
		if is_instance_valid(flash):
			flash.queue_free()
	)

func update_health_visuals():
	var health_percent = float(current_hearts) / float(max_hearts)
	var base_col = Color(0.0, 0.8, 1.0)
	var dimmed_col = base_col.lerp(Color(0.2, 0.2, 0.2), 1.0 - health_percent)
	sprite.color = dimmed_col
	
	# Reset alpha if not at 1 heart
	if current_hearts > 1:
		sprite.modulate.a = 1.0

func die():
	# Reset time scale in case we died during hitstop
	Engine.time_scale = 1.0
	
	# Calculate shards earned this run (e.g., 10 per level)
	var shards_earned = level * 10
	
	# Update High Score
	var time_survived = 0.0
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		time_survived = spawner.time_passed
	
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.run_time = spawner.time_passed if spawner else 0.0
		if gd.has_upgrade("shard_multiplier"):
			shards_earned = int(shards_earned * 1.5)
			
		gd.add_shards(shards_earned)
		if gd.run_score > gd.high_score_points:
			gd.high_score_points = gd.run_score
			gd.best_kills = gd.run_kills
			gd.best_level = gd.run_level
			gd.high_score = time_survived
		gd.save_game()
	
	# Play SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("game_over")
		get_node("/root/AudioManager").set_muffled(true) # Muffle on death screen too
	
	add_shake(100.0) # Screen-shattering death shake
	emit_signal("game_over", {
		"level": level,
		"shards": shards_earned,
		"highest_combo": highest_combo_run,
		"time": spawner.time_passed if spawner else 0.0
	})
	
	# Pause the game instead of reloading
	get_tree().paused = true

func apply_upgrade(upgrade_type: String, value: float):
	print("Applying Upgrade: ", upgrade_type, " with value ", value)
	
	# Visual "Pop" to show it worked
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	match upgrade_type:
		"speed":
			speed_multiplier += value
		"damage":
			damage_multiplier += value
		"dash_charge":
			max_energy *= (1.0 + value)
			current_energy *= (1.0 + value)
			energy_changed.emit(current_energy, max_energy)
		"dash_cooldown":
			energy_recovery *= (1.0 + value)
		"pierce":
			bullet_pierce += int(value)
		"fire_rate":
			fire_rate *= (1.0 - value)
		"dash_trail":
			dash_trail_damage = value
		"heal":
			current_hearts += 1
			if current_hearts > max_hearts:
				max_hearts = current_hearts
			health_changed.emit(current_hearts, max_hearts)
			update_health_visuals()
		"bounce":
			bullet_bounces += int(value)
		"homing":
			bullet_homing += value
		"max_hearts":
			max_hearts += 1
			current_hearts += 1
			health_changed.emit(current_hearts, max_hearts)
			update_health_visuals()
		"bullet_speed":
			bullet_speed *= (1.0 + value)
		"rotation_speed":
			rotation_speed *= (1.0 + value)
		"explosive":
			bullet_explosive = true
			explosion_radius = value
		"init_permanent":
			if has_node("/root/GlobalData"):
				var gd = get_node("/root/GlobalData")
				
				var extra_hearts = 0
				if gd.is_upgrade_active("starting_hearts"):
					extra_hearts = gd.get_upgrade_level("starting_hearts")
					
				if extra_hearts > 0:
					max_hearts += extra_hearts
					current_hearts = max_hearts
					health_changed.emit(current_hearts, max_hearts)
					update_health_visuals()
				
				var bonus_damage = 0
				if gd.is_upgrade_active("sharp_edges"):
					bonus_damage = gd.get_upgrade_level("sharp_edges")
					
				if bonus_damage > 0:
					damage_multiplier += 0.2 # 20% base boost

func check_contact_damage():
	if not has_node("Area2D") or iframe_timer > 0: return
	
	# Check for enemy bullets (Areas)
	var overlapping_areas = $Area2D.get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("enemy_bullets"):
			take_damage(1)
			area.queue_free()
			return # Exit after taking damage

	# Check for enemies (Bodies)
	var bodies = $Area2D.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			# Only take damage if the enemy isn't already dying
			if "is_dying" in body and body.is_dying:
				continue
			
			take_damage(1)
			break

# Collision with enemies (mostly for Dash now)
func _on_area_2d_body_entered(body):
	if body.is_in_group("enemies"):
		# PREVENT hitting already dying enemies
		if "is_dying" in body and body.is_dying:
			return
			
		if is_dashing:
			# Dash does high damage (enough to kill basic enemies)
			body.take_damage(50.0 * damage_multiplier) 
			add_shake(5.0)
			
			# Visual pop on hit
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.05)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
