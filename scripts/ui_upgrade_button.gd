extends Button

@onready var title_label = $VBoxContainer/Title
@onready var desc_label = $VBoxContainer/Description

func setup(upgrade_data: Dictionary):
	var is_special = upgrade_data.get("is_special", false)
	var accent: Color = NeonUI.GOLD if is_special else NeonUI.CYAN
	
	if has_node("VBoxContainer/Title"):
		$VBoxContainer/Title.text = upgrade_data["name"]
		NeonUI.style_title($VBoxContainer/Title, accent)
		$VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
		$VBoxContainer/Title.add_theme_constant_override("shadow_outline_size", 12)
		if is_special:
			$VBoxContainer/Title.add_theme_font_size_override("font_size", 28)
		
	if has_node("VBoxContainer/Description"):
		$VBoxContainer/Description.text = upgrade_data["description"]
		$VBoxContainer/Description.modulate = Color(0.82, 0.88, 0.95)
	
	if has_node("VBoxContainer/Icon") and upgrade_data.has("icon"):
		var icon_rect = $VBoxContainer/Icon
		if icon_rect is TextureRect:
			icon_rect.texture = load(upgrade_data["icon"])
			# Tint stays under the bloom threshold so the rune remains legible
			icon_rect.modulate = accent * Color(0.75, 0.75, 0.75, 1.0)
			if is_special:
				icon_rect.custom_minimum_size = Vector2(180, 180)
			NeonUI.add_halo(icon_rect, accent, 0.45, 44.0)
	
	if is_special:
		custom_minimum_size = Vector2(300, 450) # Larger button
	
	# Neon card replaces the old flat ColorRect background
	flat = false
	if has_node("BG"):
		$BG.visible = false
	for sep_name in ["HSeparator", "HSeparator2"]:
		var sep := get_node_or_null("VBoxContainer/" + sep_name) as HSeparator
		if sep:
			var line := StyleBoxFlat.new()
			line.bg_color = Color(accent.r, accent.g, accent.b, 0.55)
			line.content_margin_top = 1
			line.content_margin_bottom = 1
			sep.add_theme_stylebox_override("separator", line)
	style_menu_button(self, is_special)
	NeonUI.add_halo(self, accent, 0.10, 26.0)
	
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
	var accent: Color = NeonUI.GOLD if is_special else NeonUI.CYAN
	var normal := NeonUI.panel_style(accent, 0.8, 2, 8, 6)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.8)
	var hover := NeonUI.panel_style(accent, 0.9, 3, 22, 6)
	hover.border_color = accent.lerp(Color.WHITE, 0.55)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.border_color = NeonUI.MAGENTA.lerp(Color.WHITE, 0.3)
	pressed.shadow_color = Color(NeonUI.MAGENTA.r, NeonUI.MAGENTA.g, NeonUI.MAGENTA.b, 0.5)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_mouse_entered():
	AudioManager.play_sfx("hover")
	
	pivot_offset = size / 2
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.4), 0.2)

func _on_mouse_exited():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
