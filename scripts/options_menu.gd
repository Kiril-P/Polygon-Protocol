extends Control

@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider
@onready var mouse_controls_btn = %MouseControlsButton
@onready var tutorial_btn = %TutorialButton
@onready var back_button = %BackButton
@onready var difficulty_container = %DifficultyButtons

var is_setting_up: bool = true
var difficulty_buttons: Array[Button] = []
var close_callback: Callable

func _ready():
	setup_initial_values()
	setup_difficulty_selector()
	setup_button_animations()
	style_all_buttons()
	
	# Connect slider signals
	if master_slider: master_slider.value_changed.connect(_on_master_volume_changed)
	if music_slider: music_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_slider: sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	is_setting_up = false

func style_all_buttons():
	var btns = [mouse_controls_btn, tutorial_btn, back_button]
	for btn in btns:
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

func setup_initial_values():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		if master_slider: master_slider.value = gd.audio_settings.master
		if music_slider: music_slider.value = gd.audio_settings.music
		if sfx_slider: sfx_slider.value = gd.audio_settings.sfx
		update_button_texts()

func setup_difficulty_selector():
	if not difficulty_container: return
	
	var gd = get_node("/root/GlobalData")
	var current_diff = gd.difficulty_level if gd else 2
	
	for i in range(1, 6):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(45, 45)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		
		# Apply cyber style
		style_menu_button(btn)
		btn.get_theme_stylebox("normal").content_margin_left = 5
		
		if i == 2:
			btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			btn.tooltip_text = "NORMAL"
		
		btn.pressed.connect(func(): _on_difficulty_selected(i))
		difficulty_container.add_child(btn)
		difficulty_buttons.append(btn)
		
		btn.mouse_entered.connect(func():
			play_menu_sfx("hover")
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
		
		if level == selected_level:
			btn.modulate = Color(1.5, 1.5, 2.0)
			btn.scale = Vector2(1.1, 1.1)
		else:
			btn.modulate = Color.WHITE
			btn.scale = Vector2(1.0, 1.0)

func _on_master_volume_changed(value: float):
	if is_setting_up: return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").audio_settings.master = value
		get_node("/root/GlobalData").save_game()

func _on_music_volume_changed(value: float):
	if is_setting_up: return
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").audio_settings.music = value
		get_node("/root/GlobalData").save_game()

func _on_sfx_volume_changed(value: float):
	if is_setting_up: return
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").audio_settings.sfx = value
		get_node("/root/GlobalData").save_game()
		# Play a tiny test sound when moving SFX slider
		play_menu_sfx("enemy_hit")

func _on_mouse_controls_button_pressed():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.use_mouse_controls = !gd.use_mouse_controls
		gd.save_game()
		update_button_texts()
		play_menu_sfx("click")

func _on_tutorial_button_pressed():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.show_tutorial = !gd.show_tutorial
		gd.save_game()
		update_button_texts()
		play_menu_sfx("click")

func setup_as_overlay(callback: Callable):
	close_callback = callback
	if back_button:
		back_button.text = "CLOSE"

func _on_back_button_pressed():
	play_menu_sfx("click")
	if close_callback.is_valid():
		close_callback.call()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_button_texts():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		if mouse_controls_btn: mouse_controls_btn.text = "INPUT: MOUSE" if gd.use_mouse_controls else "INPUT: WASD"
		if tutorial_btn: tutorial_btn.text = "TUTORIAL: ON" if gd.show_tutorial else "TUTORIAL: OFF"

func setup_button_animations():
	var btns = [mouse_controls_btn, tutorial_btn, back_button]
	for btn in btns:
		if not btn: continue
		btn.focus_mode = Control.FOCUS_NONE
		
		btn.mouse_entered.connect(func():
			btn.pivot_offset = btn.size / 2
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "modulate", Color(1.5, 1.5, 2.0), 0.2)
			play_menu_sfx("hover")
		)
		btn.mouse_exited.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
			t.tween_property(btn, "modulate", Color.WHITE, 0.2)
		)
		
		btn.button_down.connect(func():
			btn.scale = Vector2(0.95, 0.95)
		)
		
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)

func play_menu_sfx(sfx_name: String):
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx(sfx_name)
