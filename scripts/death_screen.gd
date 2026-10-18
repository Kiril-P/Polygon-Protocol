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
	_decorate()

## Neon red "system failure" look: dim wash, glowing panel, glitch-split title.
func _decorate():
	bg.color = Color(0.06, 0.0, 0.02, 0.84)
	var panel := Panel.new()
	panel.name = "NeonPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", NeonUI.panel_style(NeonUI.RED, 0.78, 2, 22, 6))
	control.add_child(panel)
	control.move_child(panel, 1)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -345
	panel.offset_bottom = 345
	
	var title: Label = $Control/VBoxContainer/TitleLabel
	NeonUI.style_title(title, NeonUI.RED, 64)
	# Chromatic split copies behind the title for a glitchy look
	for spec in [[Vector2(-4, 0), Color(0.0, 1.0, 1.0, 0.45)], [Vector2(4, 0), Color(1.0, 0.0, 0.5, 0.45)]]:
		var ghost := Label.new()
		ghost.text = title.text
		ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.add_theme_font_size_override("font_size", 64)
		ghost.add_theme_color_override("font_color", spec[1])
		ghost.material = Neon.additive_material()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.show_behind_parent = true
		title.add_child(ghost)
		ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ghost.position = spec[0]
		var t := ghost.create_tween().set_loops()
		t.tween_interval(randf_range(0.6, 1.4))
		t.tween_property(ghost, "position", spec[0] * 3.0 + Vector2(0, randf_range(-3, 3)), 0.05)
		t.tween_property(ghost, "position", spec[0], 0.07)
	
	stats_label.add_theme_font_size_override("font_size", 26)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stats_label.add_theme_constant_override("line_spacing", 8)
	total_shards_label.add_theme_color_override("font_color", NeonUI.GOLD.lerp(Color.WHITE, 0.4))
	NeonUI.style_title(total_shards_label, NeonUI.GOLD, 20)
	total_shards_label.add_theme_constant_override("outline_size", 3)
	total_shards_label.add_theme_constant_override("shadow_outline_size", 8)

func style_all_buttons():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn: buttons.append(lb_btn)
	
	for btn in buttons:
		if not btn: continue
		style_menu_button(btn)
	if restart_btn:
		NeonUI.style_button(restart_btn, NeonUI.GREEN)

func style_menu_button(btn: Button):
	NeonUI.style_button(btn)

func setup_button_animations():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn:
		buttons.append(lb_btn)
		
	for btn in buttons:
		btn.pivot_offset = btn.custom_minimum_size / 2
		btn.focus_mode = Control.FOCUS_NONE # Remove selection border
		
		btn.mouse_entered.connect(func():
			AudioManager.play_sfx("hover")
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
			AudioManager.play_sfx("click")
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
	stats_label.text = "LEVEL REACHED: " + str(stats["level"]) + "\nSCORE: " + str(GlobalData.run_score) + "\nTIME SURVIVED: " + time_str + "\nSHARDS EARNED: " + str(stats["shards"]) + "\nHIGHEST COMBO: " + str(stats.get("highest_combo", 0))
	
	total_shards_label.text = "TOTAL SHARDS: " + str(GlobalData.total_shards)

	# Stylish Fade In
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	# Title "glitch" pop
	var title = $Control/VBoxContainer/TitleLabel
	var t2 = create_tween()
	t2.tween_property(title, "scale", Vector2(1.2, 1.2), 0.1)
	t2.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	
	add_vault_splash()
	VFX.shockwave(get_viewport().get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size / 2.0), 2.0, NeonUI.RED, 500.0)

func add_vault_splash():
	var splash = Label.new()
	splash.text = "SPEND SHARDS IN EVOLUTION VAULT"
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.add_theme_font_size_override("font_size", 22)
	NeonUI.style_title(splash, NeonUI.GOLD, 22)
	splash.add_theme_constant_override("outline_size", 4)
	
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
	GlobalData.next_scene_path = "res://scenes/leaderboard.tscn"
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
