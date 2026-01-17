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
@export var dash_speed: float = 600.0
@export var max_energy: float = 100.0
@export var energy_consumption: float = 50.0 # Per second
@export var energy_recovery: float = 25.0 # Per second
var current_energy: float = 100.0
var regen_delay_timer: float = 0.0 # NEW: Delay after running out
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO

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
@export var fire_rate: float = 0.15  # Time between shots
var fire_timer: float = 0.0
var rotation_speed: float = 2.0  # Radians per second
var current_rotation: float = 0.0

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

var shake_intensity: float = 0.0
var is_unpausing: bool = false # NEW: Prevent movement during unpause animation

func _ready():
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_hearts = max_hearts
	current_energy = max_energy
	update_shape_visuals()
	
	# Set Player Palette
	sprite.color = Color(0.0, 0.8, 1.0) # Neon Cyan
	
	# Intro Particle Burst
	spawn_intro_particles()
	
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
	
	# DASH TUTORIAL
	if has_node("/root/GlobalData") and get_node("/root/GlobalData").show_tutorial:
		show_dash_tutorial()
	
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

func show_dash_tutorial():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var label = Label.new()
	var use_mouse = get_node("/root/GlobalData").use_mouse_controls
	label.text = "SPACE or LEFT CLICK to DASH" if use_mouse else "SPACE to DASH"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.position.y -= 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(label)
	
	# Fade in and out
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(canvas.queue_free)

func _physics_process(delta: float):
	# Pause Input (Always check this first)
	if Input.is_action_just_pressed("ui_cancel"):
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
	if iframe_timer <= 0 and not is_dashing:
		check_contact_damage()
	
	# DASH/BOOST INPUT
	if (Input.is_action_pressed("dash") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and current_energy > 0:
		if not is_dashing:
			is_dashing = true
			modulate = Color(1.2, 1.8, 2.0, 1.0) # Cyber Cyan
		
		# Screen rumble for dashing
		add_shake(2.0)
		
		current_energy -= energy_consumption * delta
		if current_energy <= 0: 
			current_energy = 0
			is_dashing = false
			modulate = Color(1, 1, 1, 1)
			regen_delay_timer = 0.5 # Set delay only on full depletion
		energy_changed.emit(current_energy, max_energy)
	else:
		if is_dashing:
			is_dashing = false
			modulate = Color(1, 1, 1, 1)
		
		if current_energy < max_energy:
			if regen_delay_timer > 0:
				regen_delay_timer -= delta
			else:
				current_energy += energy_recovery * delta
				if current_energy > max_energy: current_energy = max_energy
				energy_changed.emit(current_energy, max_energy)

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
	var speed = dash_speed if is_dashing else (base_speed * speed_multiplier)
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

func add_xp(amount: float):
	xp += amount
	xp_changed.emit(xp, xp_to_next_level)
	if xp >= xp_to_next_level:
		level_up()

func level_up():
	level += 1
	xp -= xp_to_next_level
	xp_to_next_level *= 1.15  # Scaling XP requirement
	xp_changed.emit(xp, xp_to_next_level)
	
	# Slowly unzoom camera
	if camera:
		var target_zoom = camera.zoom * 0.95
		create_tween().tween_property(camera, "zoom", target_zoom, 1.0).set_trans(Tween.TRANS_SINE)
	
	# Shape progression: Update shape based on current level
	if level >= next_evolution_level:
		trigger_evolution_visual()
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
	
	# Open Upgrade UI via Autoload
	if has_node("/root/UpgradeManager"):
		get_node("/root/UpgradeManager")._on_player_level_up()
	
	level_up_ready.emit()

func trigger_evolution_visual():
	# 1. Freeze game briefly
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.3).timeout
	Engine.time_scale = 1.0
	
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
	var timer = get_tree().create_timer(0.15 * Engine.time_scale)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	# 2. Visual Shockwave (Scale pop)
	var blast_visual = Polygon2D.new()
	get_parent().add_child(blast_visual)
	blast_visual.global_position = global_position
	
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
			unpause_tween.tween_interval(0.1) 
			unpause_tween.tween_callback(func():
				get_tree().paused = false
				is_unpausing = false # Re-enable movement
				
				# Prevent camera "catch-up" sweep
				if camera:
					camera.reset_smoothing()
					
				canvas.queue_free()
			)
		else:
			get_tree().paused = false
			is_unpausing = false
	else:
		pause_game_fractured()

func pause_game_fractured():
	# Capture screen
	var image = get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)
	
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
	
	# Title
	var label = Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 16)
	menu_ui.add_child(label)
	
	# Create Buttons helper function for animations
	var setup_btn = func(btn: Button, size: int):
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", size)
		btn.pivot_offset = Vector2(100, 25) # Approximate, will adjust after frame
		btn.focus_mode = Control.FOCUS_NONE # Remove the white selection border
		
		btn.mouse_entered.connect(func():
			var t = canvas.create_tween()
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
			t.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.5), 0.1)
		)
		btn.mouse_exited.connect(func():
			var t = canvas.create_tween()
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
			t.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
		)
		btn.button_down.connect(func():
			btn.scale = Vector2(0.9, 0.9)
		)
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)
	
	# Resume Button
	var resume_btn = Button.new()
	resume_btn.text = " RESUME "
	setup_btn.call(resume_btn, 32)
	resume_btn.pressed.connect(toggle_pause)
	menu_ui.add_child(resume_btn)
	
	# Main Menu Button
	var main_menu_btn = Button.new()
	main_menu_btn.text = " BACK TO MAIN MENU "
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
	var center = screen_size / 2.0
	
	for y in range(rows):
		for x in range(cols):
			var piece = Sprite2D.new()
			shard_container.add_child(piece)
			piece.texture = texture
			piece.region_enabled = true
			piece.region_rect = Rect2(Vector2(x, y) * piece_size, piece_size)
			piece.position = Vector2(x, y) * piece_size + piece_size / 2.0
			
			# Direction away from center
			var dir_from_center = (piece.position - center).normalized()
			if piece.position.distance_to(center) < 10:
				dir_from_center = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			
			# Animate out to open the middle
			var tween = canvas.create_tween()
			var target_pos = piece.position + dir_from_center * 500.0
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
		
	current_hearts -= 1
	health_changed.emit(current_hearts, max_hearts)
	add_shake(60.0) # Massive hit impact
	
	# Dim glow based on health
	update_health_visuals()
	
	# Set iframes here so it applies to ALL damage sources
	iframe_timer = iframe_duration
	
	# Extreme Overdriven Red flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 0, 0, 1), 0.1) 
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if current_hearts <= 0:
		die()

func update_health_visuals():
	var health_percent = float(current_hearts) / float(max_hearts)
	var base_col = Color(0.0, 0.8, 1.0)
	var dimmed_col = base_col.lerp(Color(0.2, 0.2, 0.2), 1.0 - health_percent)
	sprite.color = dimmed_col
	
	# Reset alpha if not at 1 heart
	if current_hearts > 1:
		sprite.modulate.a = 1.0

func die():
	# Calculate shards earned this run (e.g., 10 per level)
	var shards_earned = level * 10
	
	add_shake(100.0) # Screen-shattering death shake
	spawn_player_death_particles()
	
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").add_shards(shards_earned)
	
	# Signal game over (HUD will show death screen)
	emit_signal("game_over", {
		"level": level,
		"shards": shards_earned
	})
	
	# Pause the game instead of reloading
	get_tree().paused = true

signal game_over(stats: Dictionary)

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
			current_hearts = min(current_hearts + 1, max_hearts)
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

func check_contact_damage():
	if not has_node("Area2D") or iframe_timer > 0: return
	
	# Check for enemy bullets (Areas)
	var overlapping_areas = $Area2D.get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("enemy_bullets"):
			print("Hit by bullet!")
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
			
			print("Hit by enemy: ", body.name)
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
			
			if current_shape == 0:  # Circle specific logic if needed
				pass 
