extends CanvasLayer

@onready var control = $Control
@onready var bg = $Control/BG
@onready var menu_ui = $Control/VBoxContainer
@onready var stats_label = $Control/VBoxContainer/StatsLabel
@onready var total_shards_label = $Control/VBoxContainer/TotalShardsLabel
@onready var restart_btn = $Control/VBoxContainer/RestartButton
@onready var menu_btn = $Control/VBoxContainer/MenuButton

func _ready():
	visible = false
	control.modulate.a = 0
	
	# Add Leaderboard Button
	var lb_btn = Button.new()
	lb_btn.text = "LEADERBOARD"
	lb_btn.name = "LeaderboardButton"
	
	# Match other button sizes
	lb_btn.custom_minimum_size = Vector2(250, 50)
	lb_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if restart_btn:
		lb_btn.add_theme_font_size_override("font_size", restart_btn.get_theme_font_size("font_size"))
		
	menu_ui.add_child(lb_btn)
	# Move between restart and menu
	menu_ui.move_child(lb_btn, 4)
	lb_btn.pressed.connect(_on_leaderboard_pressed)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_show_death_screen)
	
	style_all_buttons()
	setup_button_animations()

func style_all_buttons():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn: buttons.append(lb_btn)
	
	for btn in buttons:
		if not btn: continue
		style_menu_button(btn)

func style_menu_button(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	normal.border_width_left = 4
	normal.border_color = Color(0.0, 0.8, 1.0, 0.6)
	normal.corner_radius_top_left = 2
	normal.corner_radius_bottom_right = 15
	normal.content_margin_left = 20
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.4, 0.8)
	hover.border_color = Color(0.0, 1.0, 1.0, 1.0)
	hover.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
	hover.shadow_size = 10
	
	var style_pressed = hover.duplicate()
	style_pressed.bg_color = Color(0.3, 0.1, 0.4, 0.9)
	style_pressed.border_color = Color(1.0, 0.0, 1.0, 1.0)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

func setup_button_animations():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn:
		buttons.append(lb_btn)
		
	for btn in buttons:
		btn.pivot_offset = btn.custom_minimum_size / 2
		btn.focus_mode = Control.FOCUS_NONE # Remove selection border
		
		btn.mouse_entered.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("hover")
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "modulate", Color(1.5, 1.5, 2.0), 0.2)
		)
		btn.mouse_exited.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
			t.tween_property(btn, "modulate", Color.WHITE, 0.2)
		)
		
		btn.button_down.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
			btn.scale = Vector2(0.95, 0.95)
		)
		
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)

func _show_death_screen(stats: Dictionary):
	# Wait a tiny bit for the player death explosion to finish
	await get_tree().create_timer(1.0).timeout
	
	visible = true
	var time_val = stats.get("time", 0.0)
	var time_str = "%d:%02d" % [int(time_val / 60), int(time_val) % 60]
	stats_label.text = "LEVEL REACHED: " + str(stats["level"]) + "\nSCORE: " + str(get_node("/root/GlobalData").run_score if has_node("/root/GlobalData") else 0) + "\nTIME SURVIVED: " + time_str + "\nSHARDS EARNED: " + str(stats["shards"]) + "\nHIGHEST COMBO: " + str(stats.get("highest_combo", 0))
	
	if has_node("/root/GlobalData"):
		total_shards_label.text = "TOTAL SHARDS: " + str(get_node("/root/GlobalData").total_shards)
	
	# Stylish Fade In
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	# Title "glitch" pop
	var title = $Control/VBoxContainer/TitleLabel
	var t2 = create_tween()
	t2.tween_property(title, "scale", Vector2(1.2, 1.2), 0.1)
	t2.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	
	add_vault_splash()

func add_vault_splash():
	var splash = Label.new()
	splash.text = "SPEND SHARDS IN EVOLUTION VAULT"
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.add_theme_font_size_override("font_size", 22)
	splash.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8)) # Teal/Neon
	splash.add_theme_constant_override("outline_size", 6)
	splash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	
	control.add_child(splash)
	splash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Center it horizontally using grow direction
	splash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	splash.position.y -= 120 # Above buttons
	
	# Entry animation
	splash.scale = Vector2.ZERO
	splash.pivot_offset = splash.size / 2
	var t = create_tween()
	t.tween_interval(0.5)
	t.tween_property(splash, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	t.tween_property(splash, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Pulsing
	var t2 = create_tween().set_loops()
	t2.tween_property(splash, "modulate", Color(1.5, 1.5, 2.0), 0.8)
	t2.tween_property(splash, "modulate", Color.WHITE, 0.8)

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_leaderboard_pressed():
	get_tree().paused = false
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").next_scene_path = "res://scenes/leaderboard.tscn"
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
