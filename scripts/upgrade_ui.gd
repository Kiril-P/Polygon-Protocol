extends CanvasLayer

@onready var control = $Control
@onready var container = $Control/HBoxContainer
@onready var title = $Control/Title
@onready var upgrade_button_scene = preload("res://scenes/upgrade_button.tscn")

func _ready():
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	
	var manager = get_node("/root/UpgradeManager")
	if manager:
		manager.request_upgrade_ui.connect(_show_upgrade_options)

func _show_upgrade_options(options: Array):
	# Clear previous
	for child in container.get_children():
		child.queue_free()
	
	# Initial UI state for animation
	visible = true
	control.modulate.a = 0
	container.scale = Vector2(0.8, 0.8)
	title.position.y -= 100
	
	# Create buttons
	for i in range(options.size()):
		var upgrade_data = options[i]
		var btn = upgrade_button_scene.instantiate()
		container.add_child(btn)
		btn.setup(upgrade_data)
		btn.pressed.connect(_on_upgrade_selected.bind(upgrade_data))
		
		# Individual button animation (pop in sequence)
		btn.modulate.a = 0
		btn.scale = Vector2(0.5, 0.5)
		var btn_tween = create_tween()
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(0.1 * i)
		btn_tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.1 * i)
	
	# Overall UI fade/slide in
	var main_tween = create_tween().set_parallel(true)
	main_tween.tween_property(control, "modulate:a", 1.0, 0.4)
	main_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_QUINT)
	main_tween.tween_property(title, "position:y", 50, 0.5).set_trans(Tween.TRANS_BACK)

func _on_upgrade_selected(upgrade_data: Dictionary):
	# Selection animation before closing
	var manager = get_node("/root/UpgradeManager")
	if manager:
		manager.apply_upgrade(upgrade_data)
	
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)
