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
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_show_death_screen)
	
	setup_button_animations()

func setup_button_animations():
	for btn in [restart_btn, menu_btn]:
		btn.pivot_offset = btn.custom_minimum_size / 2
		btn.focus_mode = Control.FOCUS_NONE # Remove selection border
		
		btn.mouse_entered.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
			t.tween_property(btn, "modulate", Color(1.5, 1.2, 1.2), 0.1)
		)
		btn.mouse_exited.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
			t.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)

func _show_death_screen(stats: Dictionary):
	# Wait a tiny bit for the player death explosion to finish
	await get_tree().create_timer(1.0).timeout
	
	visible = true
	stats_label.text = "LEVEL REACHED: " + str(stats["level"]) + "\nSHARDS EARNED: " + str(stats["shards"])
	
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

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
