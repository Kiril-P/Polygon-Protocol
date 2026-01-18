extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var upgrade_button = $VBoxContainer/UpgradeButton
@onready var options_button = $VBoxContainer/OptionsButton

@onready var options_menu = $OptionsMenu
@onready var controls_button = $OptionsMenu/VBoxContainer/ControlsButton
@onready var tutorial_button = $OptionsMenu/VBoxContainer/TutorialButton # You might need to add this in editor
@onready var quit_button = $QuitButton # You might need to add this in editor
@onready var close_options_button = $OptionsMenu/VBoxContainer/CloseOptionsButton
var difficulty_buttons: Array[Button] = []

func _ready():
	# Set music to menu mode
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_music_menu_mode(true)
		get_node("/root/AudioManager").set_muffled(false)
		
	options_menu.visible = false
	
	# Display High Score on Main Menu
	var gd = get_node("/root/GlobalData")
	if gd and gd.high_score > 0:
		var hs_label = Label.new()
		hs_label.text = "BEST TIME: %d:%02d" % [int(gd.high_score / 60), int(gd.high_score) % 60]
		hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_label.add_theme_font_size_override("font_size", 18)
		hs_label.modulate = Color(0.0, 0.8, 1.0, 0.6) # Cyan glow
		$VBoxContainer.add_child(hs_label)
		$VBoxContainer.move_child(hs_label, 0) # Top of buttons
	
	setup_difficulty_selector()
	if quit_button:
		if OS.get_name() == "Web":
			quit_button.text = "FULLSCREEN"
		else:
			quit_button.text = "QUIT"
	update_controls_button_text()
	update_tutorial_button_text()
	create_menu_juice()
	setup_button_animations()

func setup_button_animations():
	var buttons = [start_button, upgrade_button, options_button, controls_button, tutorial_button, quit_button, close_options_button]
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

func setup_difficulty_selector():
	var container = $OptionsMenu/VBoxContainer
	if not container: return
	
	var label = Label.new()
	label.text = "DIFFICULTY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	container.add_child(label)
	# Move above close button
	container.move_child(label, container.get_child_count() - 2)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	container.add_child(hbox)
	container.move_child(hbox, container.get_child_count() - 2)
	
	var gd = get_node("/root/GlobalData")
	var current_diff = gd.difficulty_level if gd else 2
	
	for i in range(1, 6):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(40, 40)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		
		if i == 2:
			btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Gold-ish for Normal
			btn.tooltip_text = "NORMAL"
		
		btn.pressed.connect(func(): _on_difficulty_selected(i))
		hbox.add_child(btn)
		difficulty_buttons.append(btn)
		
		# Simple hover effect for difficulty buttons
		btn.mouse_entered.connect(func():
			create_tween().tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1)
		)
		btn.mouse_exited.connect(func():
			var base_scale = Vector2(1.1, 1.1) if btn.button_pressed else Vector2(1.0, 1.0)
			create_tween().tween_property(btn, "scale", base_scale, 0.1)
		)
	
	update_difficulty_buttons(current_diff)

func _on_difficulty_selected(level: int):
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.difficulty_level = level
		gd.save_game()
		update_difficulty_buttons(level)

func update_difficulty_buttons(selected_level: int):
	for i in range(difficulty_buttons.size()):
		var btn = difficulty_buttons[i]
		var level = i + 1
		btn.button_pressed = (level == selected_level)
		
		# Visual feedback for selection
		if level == selected_level:
			btn.modulate = Color(1.5, 1.5, 2.0) # Glowing selected
			btn.scale = Vector2(1.1, 1.1)
		else:
			btn.modulate = Color.WHITE
			btn.scale = Vector2(1.0, 1.0)
		
		# Highlight Normal (2) even when not selected, but more when selected
		if level == 2:
			if level == selected_level:
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.0))

func update_controls_button_text():
	if controls_button and has_node("/root/GlobalData"):
		var use_mouse = get_node("/root/GlobalData").use_mouse_controls
		controls_button.text = "INPUT: MOUSE" if use_mouse else "INPUT: WASD"

func update_tutorial_button_text():
	if tutorial_button and has_node("/root/GlobalData"):
		var show = get_node("/root/GlobalData").show_tutorial
		tutorial_button.text = "TUTORIAL: ON" if show else "TUTORIAL: OFF"

func create_menu_juice():
	# Background elements: Mix of shapes and "Enemies"
	for i in range(12):
		spawn_menu_shape()
	
	# Spawn a few "Preview Enemies"
	for i in range(8): # Increased count
		spawn_menu_enemy()

func spawn_menu_shape():
	var poly = Polygon2D.new()
	add_child(poly)
	move_child(poly, 1)
	
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
	
	poly.position = Vector2(randf_range(0, 1152), randf_range(0, 648))
	
	animate_menu_shape(poly)

func animate_menu_shape(poly: Node2D):
	if not is_instance_valid(poly): return
	
	var travel = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	var duration = randf_range(10, 20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(poly, "position", poly.position + travel, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "rotation", poly.rotation + PI, duration)
	
	tween.set_parallel(false)
	tween.tween_interval(1.0) # Small pause
	tween.tween_callback(func(): animate_menu_shape(poly))

func spawn_menu_enemy():
	var enemy = Button.new() # Use Button to detect clicks easily
	enemy.flat = true # Hide the default button look
	enemy.focus_mode = Control.FOCUS_NONE # Remove white selection border
	add_child(enemy)
	move_child(enemy, 2)
	
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
	
	enemy.position = Vector2(randf_range(0, 1152), randf_range(0, 648))
	enemy.custom_minimum_size = Vector2(e_size * 2, e_size * 2)
	poly.position = Vector2(e_size, e_size) # Center poly in button
	
	# Detect Click
	enemy.pressed.connect(func():
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("enemy_death")
		spawn_menu_death_particles(enemy.position + poly.position, poly.color)
		enemy.queue_free()
		# Respawn another after a delay to keep the menu busy
		get_tree().create_timer(2.0).timeout.connect(spawn_menu_enemy)
	)
	
	animate_menu_enemy(enemy, poly)
	
	# Firing logic
	var fire_timer = Timer.new()
	enemy.add_child(fire_timer) # Child of enemy so it dies with it
	fire_timer.wait_time = randf_range(1.5, 3.0)
	fire_timer.timeout.connect(func(): 
		if not is_instance_valid(enemy): return
		spawn_menu_bullet(enemy.position + poly.position, poly.rotation, poly.color)
	)
	fire_timer.start()

func animate_menu_enemy(enemy: Control, poly: Node2D):
	if not is_instance_valid(enemy): return
	
	var duration = randf_range(5, 10)
	var target = Vector2(randf_range(0, 1152), randf_range(0, 648))
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(enemy, "position", target, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "rotation", poly.rotation + TAU, duration)
	
	tween.set_parallel(false)
	tween.tween_callback(func(): animate_menu_enemy(enemy, poly))

func spawn_menu_death_particles(pos: Vector2, col: Color):
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = col
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

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

func _on_options_button_pressed():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")

func _on_close_options_button_pressed():
	var tween = create_tween()
	tween.tween_property(options_menu, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): options_menu.visible = false)

func _on_controls_button_pressed():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.use_mouse_controls = !gd.use_mouse_controls
		gd.save_game()
		update_controls_button_text()

func _on_tutorial_button_pressed():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.show_tutorial = !gd.show_tutorial
		gd.save_game()
		update_tutorial_button_text()

func _on_quit_button_pressed():
	if OS.get_name() == "Web":
		# Toggle Fullscreen on web is often better than trying to quit
		var is_full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		get_tree().quit()
