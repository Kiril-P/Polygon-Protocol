extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var upgrade_button = $VBoxContainer/UpgradeButton
@onready var options_button = $VBoxContainer/OptionsButton
@onready var quit_button = $QuitButton 
@onready var splash_label = %SplashLabel

var options_scene = preload("res://scenes/options_menu.tscn")

func _ready():
	# Set music to menu mode
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_music_menu_mode(true)
		get_node("/root/AudioManager").set_muffled(false)
		
	# Leaderboard Button
	var lb_button = Button.new()
	lb_button.text = "LEADERBOARD"
	lb_button.name = "LeaderboardButton"
	lb_button.custom_minimum_size = Vector2(350, 70)
	lb_button.add_theme_font_size_override("font_size", 30)
	$VBoxContainer.add_child(lb_button)
	# Position it below options or upgrades
	$VBoxContainer.move_child(lb_button, 2)
	lb_button.pressed.connect(_on_leaderboard_pressed)
	
	if quit_button:
		if OS.get_name() == "Web":
			quit_button.text = "FULLSCREEN"
		else:
			quit_button.text = "QUIT"
			
	create_menu_juice()
	setup_button_animations()
	style_all_buttons()
	animate_splash_text()

func animate_splash_text():
	if not splash_label: return
	
	var t = create_tween().set_loops()
	t.tween_property(splash_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(splash_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func style_all_buttons():
	var buttons = [start_button, upgrade_button, options_button, quit_button]
	var lb_btn = $VBoxContainer.get_node_or_null("LeaderboardButton")
	if lb_btn: buttons.append(lb_btn)
	
	for btn in buttons:
		if not btn: continue
		style_menu_button(btn)

func style_menu_button(btn: Button):
	# Normal Style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.2, 0.4)
	normal.border_width_left = 4
	normal.border_color = Color(0.0, 0.8, 1.0, 0.6) # Cyan edge
	normal.corner_radius_top_left = 2
	normal.corner_radius_bottom_right = 15
	normal.content_margin_left = 20
	
	# Hover Style
	var hover = normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.4, 0.6)
	hover.border_color = Color(0.0, 1.0, 1.0, 1.0) # Bright Cyan
	hover.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
	hover.shadow_size = 10
	
	# Pressed Style
	var pressed = hover.duplicate()
	pressed.bg_color = Color(0.3, 0.1, 0.4, 0.8)
	pressed.border_color = Color(1.0, 0.0, 1.0, 1.0) # Magenta flash
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Text styling
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

func setup_button_animations():
	var buttons = [start_button, upgrade_button, options_button, quit_button]
	var lb_btn = $VBoxContainer.get_node_or_null("LeaderboardButton")
	if lb_btn:
		buttons.append(lb_btn)
		
	for btn in buttons:
		if not btn: continue
		
		# Set pivot for scaling from center
		btn.pivot_offset = btn.size / 2
		btn.focus_mode = Control.FOCUS_NONE # Remove the white selection border
		
		btn.mouse_entered.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("hover")
			var tween = create_tween().set_parallel(true)
			tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "modulate", Color(1.5, 1.5, 2.0), 0.2)
		)
		
		btn.mouse_exited.connect(func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
			tween.tween_property(btn, "modulate", Color.WHITE, 0.2)
		)
		
		btn.button_down.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
			btn.scale = Vector2(0.95, 0.95)
		)
		
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)

func create_menu_juice():
	# Background elements: Mix of shapes and "Enemies"
	for i in range(20): # Increased from 12
		spawn_menu_shape()
	
	# Spawn a few "Preview Enemies"
	for i in range(15): # Increased count for more hectic feel
		spawn_menu_enemy()

func spawn_menu_shape():
	var poly = Polygon2D.new()
	add_child(poly)
	move_child(poly, 1) # Just above Background
	
	var pts = PackedVector2Array()
	var sides = randi_range(3, 8)
	var poly_size = randf_range(30, 100)
	for s in range(sides):
		pts.append(Vector2(poly_size, 0).rotated(TAU/sides * s))
	
	poly.polygon = pts
	# Palette: Neon Cyan, Neon Magenta, Neon Purple
	var colors = [Color(0.0, 0.8, 1.0, 0.1), Color(1.0, 0.0, 1.0, 0.1), Color(0.7, 0.2, 1.0, 0.1)]
	poly.color = colors[randi() % colors.size()]
	# Add Glow to background shapes
	poly.modulate = Color(1.5, 1.5, 1.5, 1.0)
	
	var screen_size = get_viewport_rect().size
	poly.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
	
	animate_menu_shape(poly)

func animate_menu_shape(poly: Node2D):
	if not is_instance_valid(poly): return
	
	var screen_size = get_viewport_rect().size
	var target = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
	var duration = randf_range(15, 25)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(poly, "position", target, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "rotation", poly.rotation + PI * 2.0, duration)
	
	tween.set_parallel(false)
	tween.tween_interval(1.0) # Small pause
	tween.tween_callback(func(): animate_menu_shape(poly))

func spawn_menu_enemy():
	var enemy = Button.new() # Use Button to detect clicks easily
	enemy.flat = true # Hide the default button look
	enemy.focus_mode = Control.FOCUS_NONE # Remove white selection border
	add_child(enemy)
	move_child(enemy, 1) # Just above Background
	
	var poly = Polygon2D.new()
	enemy.add_child(poly)
	
	# Triangle (Shooter) or Square (Tank) preview
	var is_tank = randf() > 0.5
	var pts = PackedVector2Array()
	var sides = 4 if is_tank else 3
	var e_size = 40 if is_tank else 25
	for s in range(sides):
		pts.append(Vector2(e_size, 0).rotated(TAU/sides * s))
	
	poly.polygon = pts
	poly.color = Color(1, 0.2, 0.2, 0.3) if not is_tank else Color(0.2, 0.8, 0.2, 0.3)
	# Add Glow to menu enemies
	poly.modulate = Color(2.0, 1.5, 1.5, 1.0) if not is_tank else Color(1.5, 2.0, 1.5, 1.0)
	
	var screen_size = get_viewport_rect().size
	enemy.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
	enemy.custom_minimum_size = Vector2(e_size * 2, e_size * 2)
	poly.position = Vector2(e_size, e_size) # Center poly in button
	
	# Detect Click
	enemy.pressed.connect(func():
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3)
		spawn_menu_death_particles(enemy.position + poly.position, poly.color)
		enemy.queue_free()
		# Respawn another after a delay to keep the menu busy
		get_tree().create_timer(0.5).timeout.connect(spawn_menu_enemy)
	)
	
	animate_menu_enemy(enemy, poly)
	
	# Firing logic
	var fire_timer = Timer.new()
	enemy.add_child(fire_timer) # Child of enemy so it dies with it
	fire_timer.wait_time = randf_range(0.5, 1.5)
	fire_timer.timeout.connect(func(): 
		if not is_instance_valid(enemy): return
		spawn_menu_bullet(enemy.position + poly.position, poly.rotation, poly.color)
	)
	fire_timer.start()

func animate_menu_enemy(enemy: Control, poly: Node2D):
	if not is_instance_valid(enemy): return
	
	var duration = randf_range(5, 10)
	var screen_size = get_viewport_rect().size
	var target = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(enemy, "position", target, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "rotation", poly.rotation + TAU * 3.0, duration) # Faster rotation
	
	tween.set_parallel(false)
	tween.tween_callback(func(): animate_menu_enemy(enemy, poly))

func spawn_menu_death_particles(pos: Vector2, col: Color):
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.amount = 60 # Even more particles
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 200.0 # Even faster
	particles.initial_velocity_max = 400.0 # Even faster
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 10.0 # Larger max scale
	particles.hue_variation_min = -0.1
	particles.hue_variation_max = 0.1
	# Add some color variation to particles
	particles.color = col
	particles.emitting = true
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

func spawn_menu_bullet(pos: Vector2, rot: float, col: Color):
	var bullet = Polygon2D.new()
	add_child(bullet)
	move_child(bullet, 1)
	
	var pts = PackedVector2Array([Vector2(8,0), Vector2(-4,4), Vector2(-4,-4)])
	bullet.polygon = pts
	bullet.color = col
	bullet.modulate.a = 0.6
	bullet.position = pos
	bullet.rotation = rot
	
	var tween = create_tween()
	var dir = Vector2.RIGHT.rotated(rot)
	tween.tween_property(bullet, "position", pos + dir * 800.0, 2.0)
	tween.parallel().tween_property(bullet, "modulate:a", 0.0, 2.0)
	tween.tween_callback(bullet.queue_free)

func _on_start_button_pressed():
	_start_game(false)

func _start_game(is_quick: bool):
	# Cool "Warp" Animation
	
	# 1. Disable buttons
	start_button.disabled = true
	upgrade_button.disabled = true
	options_button.disabled = true
	
	# 2. Zoom everything out
	var duration = 0.3 if is_quick else 0.5
	var tween = create_tween().set_parallel(true)
	
	# Display High Score before warping (If not quick)
	if not is_quick:
		var gd = get_node("/root/GlobalData")
		if gd and gd.high_score > 0:
			var hs_label = Label.new()
			hs_label.text = "BEST TIME: %d:%02d" % [int(gd.high_score / 60), int(gd.high_score) % 60]
			hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hs_label.add_theme_font_size_override("font_size", 24)
			hs_label.modulate.a = 0
			add_child(hs_label)
			hs_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			hs_label.position.y -= 50
			tween.tween_property(hs_label, "modulate:a", 1.0, 0.3)
	
	# Buttons fly off
	tween.tween_property($VBoxContainer, "position:y", 1000, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Title zooms into camera
	var title = get_node_or_null("Title")
	if title:
		tween.tween_property(title, "scale", Vector2(10, 10), duration + 0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tween.tween_property(title, "modulate:a", 0.0, duration + 0.1)
	
	# White flash or Warp effect
	var flash = ColorRect.new()
	add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.modulate.a = 0
	tween.tween_property(flash, "modulate:a", 1.0, duration).set_delay(duration * 0.4)
	
	tween.set_parallel(false)
	tween.tween_callback(func():
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").set_music_menu_mode(false)
		if has_node("/root/GlobalData"):
			get_node("/root/GlobalData").next_scene_path = "res://scenes/game.tscn"
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
	)

func _on_upgrade_button_pressed():
	# Transition to the dedicated Evolution Vault scene
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_property($VBoxContainer, "position:x", -500, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(func():
		if has_node("/root/GlobalData"):
			get_node("/root/GlobalData").next_scene_path = "res://scenes/evolution_vault.tscn"
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
	)

func _on_leaderboard_pressed():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	
	# Cool "Warp" Animation like Evolution Vault
	start_button.disabled = true
	upgrade_button.disabled = true
	options_button.disabled = true
	var lb_btn = $VBoxContainer.get_node_or_null("LeaderboardButton")
	if lb_btn: lb_btn.disabled = true
	
	var duration = 0.5
	var tween = create_tween().set_parallel(true)
	
	# Buttons fly off
	tween.tween_property($VBoxContainer, "position:y", 1000, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Title zooms into camera
	var title = get_node_or_null("Title")
	if title:
		tween.tween_property(title, "scale", Vector2(10, 10), duration + 0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tween.tween_property(title, "modulate:a", 0.0, duration + 0.1)
	
	# White flash or Warp effect
	var flash = ColorRect.new()
	add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.modulate.a = 0
	tween.tween_property(flash, "modulate:a", 1.0, duration).set_delay(duration * 0.4)
	
	tween.set_parallel(false)
	tween.tween_callback(func():
		if has_node("/root/GlobalData"):
			get_node("/root/GlobalData").next_scene_path = "res://scenes/leaderboard.tscn"
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
	)

func _on_options_button_pressed():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	
	var options = options_scene.instantiate()
	add_child(options)
	
	# Hide background if overlaying
	if options.has_node("Background"):
		options.get_node("Background").visible = false
	
	# Entry animation
	options.modulate.a = 0
	options.scale = Vector2(0.8, 0.8)
	options.pivot_offset = get_viewport_rect().size / 2
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(options, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(options, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Handle closing without scene change
	if options.has_method("setup_as_overlay"):
		options.setup_as_overlay(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(options, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
			t.tween_property(options, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_SINE)
			t.set_parallel(false)
			t.tween_callback(options.queue_free)
		)

func _on_quit_button_pressed():
	if OS.get_name() == "Web":
		# Toggle Fullscreen on web is often better than trying to quit
		var is_full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		get_tree().quit()
