extends Button

@onready var title_label = $VBoxContainer/Title
@onready var desc_label = $VBoxContainer/Description

func setup(upgrade_data: Dictionary):
	var is_special = upgrade_data.get("is_special", false)
	
	if has_node("VBoxContainer/Title"):
		$VBoxContainer/Title.text = upgrade_data["name"]
		if is_special:
			$VBoxContainer/Title.modulate = Color(1.0, 0.8, 0.0) # Gold for special
			$VBoxContainer/Title.add_theme_font_size_override("font_size", 28)
		else:
			$VBoxContainer/Title.modulate = Color(0.0, 0.8, 1.0) # Palette Cyan
		
	if has_node("VBoxContainer/Description"):
		$VBoxContainer/Description.text = upgrade_data["description"]
		$VBoxContainer/Description.modulate = Color(0.8, 0.8, 0.8) # Palette Grey
	
	if has_node("VBoxContainer/Icon") and upgrade_data.has("icon"):
		var icon_rect = $VBoxContainer/Icon
		if icon_rect is TextureRect:
			icon_rect.texture = load(upgrade_data["icon"])
			# Make icons pop a bit
			if is_special:
				icon_rect.modulate = Color(1.5, 1.2, 0.5) # Glowing gold icon
				icon_rect.custom_minimum_size = Vector2(180, 180)
			else:
				icon_rect.modulate = Color(0.5, 1.0, 1.0) # Palette Light Cyan
	
	if is_special:
		custom_minimum_size = Vector2(300, 450) # Larger button
		if has_node("BG/Border"):
			$BG/Border.border_color = Color(1.0, 0.8, 0.0) # Gold border
			$BG/Border.border_width = 6.0
		if has_node("BG"):
			$BG.color = Color(0.2, 0.15, 0.05, 0.8) # Darker gold/bronze bg
	
	style_menu_button(self, is_special)
	
	# Clear the default button text as we use the container labels now
	text = ""
	
	# Hover logic for the new visual elements
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)

func _on_button_down():
	scale = Vector2(0.95, 0.95)

func _on_button_up():
	scale = Vector2(1.1, 1.1)

func style_menu_button(btn: Button, is_special: bool):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.2, 0.6) if not is_special else Color(0.2, 0.15, 0.05, 0.8)
	normal.border_width_left = 4
	normal.border_color = Color(0.0, 0.8, 1.0, 0.6) if not is_special else Color(1.0, 0.8, 0.0, 0.8)
	normal.corner_radius_top_left = 2
	normal.corner_radius_bottom_right = 15
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.4, 0.8) if not is_special else Color(0.3, 0.2, 0.1, 0.9)
	hover.border_color = Color(0.0, 1.0, 1.0, 1.0) if not is_special else Color(1.0, 1.0, 0.5, 1.0)
	hover.shadow_color = Color(0.0, 1.0, 1.0, 0.2) if not is_special else Color(1.0, 0.8, 0.0, 0.2)
	hover.shadow_size = 8
	
	var style_pressed = hover.duplicate()
	style_pressed.bg_color = Color(0.3, 0.1, 0.4, 0.9)
	style_pressed.border_color = Color(1.0, 0.0, 1.0, 1.0)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_mouse_entered():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("hover")
		
	pivot_offset = size / 2
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.4), 0.2)

func _on_mouse_exited():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
