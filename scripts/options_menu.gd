extends Control

@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider
@onready var mouse_controls_btn = %MouseControlsButton
@onready var tutorial_btn = %TutorialButton
@onready var back_button = %BackButton

var is_setting_up: bool = true

func _ready():
	setup_initial_values()
	setup_button_animations()
	
	# Connect slider signals
	if master_slider: master_slider.value_changed.connect(_on_master_volume_changed)
	if music_slider: music_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_slider: sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	is_setting_up = false

func setup_initial_values():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		if master_slider: master_slider.value = gd.audio_settings.master
		if music_slider: music_slider.value = gd.audio_settings.music
		if sfx_slider: sfx_slider.value = gd.audio_settings.sfx
		if tutorial_btn: tutorial_btn.visible = true
		update_button_texts()

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

func _on_back_button_pressed():
	play_menu_sfx("click")
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
		btn.pivot_offset = btn.size / 2
		btn.mouse_entered.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
			t.tween_property(btn, "modulate", Color(1.2, 1.2, 1.5), 0.1)
			play_menu_sfx("hover")
		)
		btn.mouse_exited.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
			t.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)

func play_menu_sfx(sfx_name: String):
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx(sfx_name)
