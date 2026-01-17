extends CanvasLayer

@onready var container = $Control/HBoxContainer
@onready var upgrade_button_scene = preload("res://scenes/upgrade_button.tscn")

func _ready():
	visible = false
	process_mode = PROCESS_MODE_ALWAYS # This UI must work while game is paused
	
	# Connect to the UpgradeManager
	var manager = get_node("/root/UpgradeManager") # Assuming it's an Autoload
	if manager:
		manager.request_upgrade_ui.connect(_show_upgrade_options)

func _show_upgrade_options(options: Array):
	# Clear previous buttons
	for child in container.get_children():
		child.queue_free()
	
	# Create a button for each option
	for upgrade_data in options:
		var btn = upgrade_button_scene.instantiate()
		container.add_child(btn)
		btn.setup(upgrade_data)
		btn.pressed.connect(_on_upgrade_selected.bind(upgrade_data))
	
	visible = true

func _on_upgrade_selected(upgrade_data: Dictionary):
	visible = false
	var manager = get_node("/root/UpgradeManager")
	if manager:
		manager.apply_upgrade(upgrade_data)
