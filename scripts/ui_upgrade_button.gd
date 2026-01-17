extends Button

@onready var title_label = $VBoxContainer/Title
@onready var desc_label = $VBoxContainer/Description

func setup(upgrade_data: Dictionary):
	# Assuming your button scene has these labels
	if has_node("VBoxContainer/Title"):
		$VBoxContainer/Title.text = upgrade_data["name"]
		$VBoxContainer/Title.modulate = Color(0.0, 0.8, 1.0) # Palette Cyan
		
	if has_node("VBoxContainer/Description"):
		$VBoxContainer/Description.text = upgrade_data["description"]
		$VBoxContainer/Description.modulate = Color(0.8, 0.8, 0.8) # Palette Grey
	
	if has_node("VBoxContainer/Icon") and upgrade_data.has("icon"):
		var icon_rect = $VBoxContainer/Icon
		if icon_rect is TextureRect:
			icon_rect.texture = load(upgrade_data["icon"])
			# Make icons pop a bit
			icon_rect.modulate = Color(0.5, 1.0, 1.0) # Palette Light Cyan
	
	# Clear the default button text as we use the container labels now
	text = ""
	
	# Hover logic for the new visual elements
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if has_node("BG/Border"):
		$BG/Border.border_color = Color(1, 1, 1, 1) # Flash white border
		$BG/Border.border_width = 5.0
	if has_node("BG/Glow"):
		$BG/Glow.visible = true
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property($BG, "color", Color(0.1, 0.1, 0.2, 0.95), 0.1)

func _on_mouse_exited():
	if has_node("BG/Border"):
		$BG/Border.border_color = Color(0.0, 0.9, 1.0, 1) # Palette Cyan
		$BG/Border.border_width = 3.0
	if has_node("BG/Glow"):
		$BG/Glow.visible = false
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property($BG, "color", Color(0.05, 0.05, 0.1, 0.8), 0.1) # Palette Navy
