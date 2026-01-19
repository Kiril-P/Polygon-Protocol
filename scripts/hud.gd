extends CanvasLayer

@onready var heart_container = $Control/HeartContainer
@onready var xp_bar = $Control/XPBar
@onready var dash_bar = $Control/DashBar
@onready var level_label = $Control/LevelLabel

func show_dash_nerf_warning():
	var warn = $Control.get_node_or_null("BossWarning")
	if warn:
		warn.visible = true
		warn.text = "DASH CAPABILITIES CRIPPLED"
		warn.modulate = Color(2.0, 1.0, 0.0, 0.0) # Orange Glow
		warn.scale = Vector2(1.5, 1.5)
		
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(warn, "modulate:a", 1.0, 0.3)
		t.tween_property(warn, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
		
		t.set_parallel(false)
		t.tween_interval(2.0)
		t.tween_property(warn, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): 
			warn.text = "DESTROY HIS HEARTS TO DEAL MASSIVE DAMAGE"
			warn.modulate.a = 0
		)
		t.tween_property(warn, "modulate:a", 1.0, 0.3)
		t.tween_interval(3.0)
		t.tween_property(warn, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): warn.visible = false)

func show_corruption_warning():
	var warn = $Control.get_node_or_null("BossWarning")
	if warn:
		warn.visible = true
		warn.text = "CRITICAL: DATA CORRUPTION"
		warn.modulate = Color(2.5, 0.5, 3.0, 0.0) # Intense Purple/Magenta Glow
		warn.scale = Vector2(0.2, 2.0) # Stretched start
		
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(warn, "modulate:a", 1.0, 0.2)
		t.tween_property(warn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		t.set_parallel(false)
		t.tween_interval(2.0)
		t.tween_property(warn, "modulate:a", 0.0, 0.2)
		t.tween_callback(func(): 
			warn.text = "GLITCH FIELDS DETECTED"
			warn.modulate.a = 0
		)
		t.tween_property(warn, "modulate:a", 1.0, 0.2)
		t.tween_interval(3.0)
		t.tween_property(warn, "modulate:a", 0.0, 0.2)
		t.tween_callback(func(): 
			warn.visible = false
			warn.modulate = Color(1, 1, 1, 1)
			warn.scale = Vector2(1, 1)
		)

func _ready():
	add_to_group("hud")
	# Create nodes first
	setup_boss_pointer()
	setup_combo_ui()
	setup_boss_bar()
	setup_bottom_ui() # This initializes heart_container
	
	# Wait a frame to ensure all nodes are in groups
	await get_tree().process_frame
	
	# Find player and connect signals
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		player.combo_changed.connect(_on_player_combo_changed)
		# Initialize values
		_on_player_health_changed(player.current_hearts, player.max_hearts)
		_on_player_xp_changed(player.xp, player.xp_to_next_level)
		_on_player_energy_changed(player.current_energy, player.max_energy)
		level_label.text = "Level " + str(player.level)
	
	# Kill Counter UI
	setup_kill_counter()
	
	# Initial Styling
	if xp_bar:
		style_neon_bar(xp_bar, Color(0.2, 1.0, 0.2)) # Neon Green
	if dash_bar:
		style_neon_bar(dash_bar, Color(0.0, 0.8, 1.0)) # Neon Cyan
		
	# Setup Arena Border
	setup_arena_border()
	
	# Setup Dash Blur Overlay
	setup_dash_overlay()

	# INTRO ANIMATION: "Reverse Warp"
	trigger_intro_fade()

func setup_dash_overlay():
	var overlay = ColorRect.new()
	overlay.name = "DashBlur"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	
	var shader = load("res://assets/shaders/dash_blur.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		overlay.material = mat
		
	$Control.add_child(overlay)

func trigger_dash_effect(duration: float):
	var overlay = $Control.get_node_or_null("DashBlur")
	if not overlay: return
	
	overlay.visible = true
	var mat = overlay.material as ShaderMaterial
	if mat:
		var t = create_tween()
		t.tween_method(func(v): mat.set_shader_parameter("strength", v), 0.08, 0.0, duration)
		t.tween_callback(func(): overlay.visible = false)

func setup_arena_border():
	var border = ReferenceRect.new()
	border.name = "ArenaBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.editor_only = false
	border.border_color = Color(0.0, 1.0, 1.0, 0.3) # Cyan faint
	border.border_width = 4.0
	$Control.add_child(border)
	$Control.move_child(border, 0) # Behind other HUD elements
	
	# Add a second thicker border for glow
	var glow = ReferenceRect.new()
	glow.name = "ArenaGlow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.editor_only = false
	glow.border_color = Color(0.0, 1.0, 1.0, 0.1)
	glow.border_width = 12.0
	$Control.add_child(glow)
	$Control.move_child(glow, 0)
	
	# Pulse animation
	var t = create_tween().set_loops(9999)
	t.tween_property(border, "border_color:a", 0.6, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(border, "border_color:a", 0.2, 1.5).set_trans(Tween.TRANS_SINE)
	
	var t2 = create_tween().set_loops(9999)
	t2.tween_property(glow, "border_color:a", 0.3, 2.0).set_trans(Tween.TRANS_SINE)
	t2.tween_property(glow, "border_color:a", 0.05, 2.0).set_trans(Tween.TRANS_SINE)

func setup_bottom_ui():
	var bottom_container = VBoxContainer.new()
	bottom_container.name = "BottomUI"
	bottom_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_container.offset_bottom = -20
	bottom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_container.add_theme_constant_override("separation", 10)
	$Control.add_child(bottom_container)
	
	# Combo Section (On top of hearts)
	var combo_container = VBoxContainer.new()
	combo_container.name = "ComboContainer"
	combo_container.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_container.add_theme_constant_override("separation", 2)
	bottom_container.add_child(combo_container)
	
	# Move Combo elements into bottom UI
	var combo_label = $Control.get_node_or_null("ComboLabel")
	var combo_bar = $Control.get_node_or_null("ComboBar")
	
	if combo_label:
		if combo_label.get_parent():
			combo_label.get_parent().remove_child(combo_label)
		combo_container.add_child(combo_label)
		
	if combo_bar:
		if combo_bar.get_parent():
			combo_bar.get_parent().remove_child(combo_bar)
		combo_container.add_child(combo_bar)
	
	# Heart Section (Bottom-most)
	if has_node("Control/HeartContainer"):
		heart_container = $Control/HeartContainer
		if heart_container.get_parent():
			heart_container.get_parent().remove_child(heart_container)
	else:
		heart_container = HBoxContainer.new()
		heart_container.name = "HeartContainer"
	
	bottom_container.add_child(heart_container)
	heart_container.alignment = BoxContainer.ALIGNMENT_CENTER
	heart_container.add_theme_constant_override("separation", 10)

func setup_kill_counter():
	# Removed Kills, Score, and Timer labels from HUD as requested.
	# They are now in the Pause Menu / Options Screen.
	pass

func setup_boss_bar():
	var bar = ProgressBar.new()
	bar.name = "BossBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(600, 20)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_left = -300
	bar.offset_right = 300
	bar.offset_top = 140 # Moved further down to avoid Level/Dash overlap
	bar.visible = false
	style_neon_bar(bar, Color.RED)
	$Control.add_child(bar)
	
	var label = Label.new()
	label.name = "BossLabel"
	label.text = "CORRUPTED PROTOCOL DETECTED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = 110 # Moved down
	label.add_theme_font_size_override("font_size", 18)
	label.visible = false
	$Control.add_child(label)
	
	setup_warning_label()

func setup_warning_label():
	var warn = Label.new()
	warn.name = "BossWarning"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn.set_anchors_preset(Control.PRESET_CENTER)
	warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warn.grow_vertical = Control.GROW_DIRECTION_BOTH
	warn.add_theme_font_size_override("font_size", 48)
	warn.add_theme_color_override("font_color", Color.RED)
	warn.add_theme_constant_override("outline_size", 12)
	warn.visible = false
	$Control.add_child(warn)

func show_boss_warning():
	var warn = $Control.get_node_or_null("BossWarning")
	if warn:
		warn.visible = true
		warn.text = "CORRUPTED PROTOCOL INBOUND"
		warn.modulate = Color(2.0, 0.2, 0.2, 0.0) # Intense Red Glow
		warn.scale = Vector2(0.5, 0.5)
		
		# Menacing Pulse Animation
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(warn, "modulate:a", 1.0, 0.5)
		t.tween_property(warn, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		t.set_parallel(false)
		# Shake while visible
		for i in range(6):
			t.tween_property(warn, "position", warn.position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.05)
			t.tween_property(warn, "position", warn.position, 0.05)
		
		t.tween_interval(2.0)
		t.tween_property(warn, "modulate:a", 0.0, 0.5)
		t.tween_callback(func(): warn.visible = false)

func setup_boss_pointer():
	var arrow = Polygon2D.new()
	arrow.name = "BossPointer"
	# Draw an arrow pointing Right (0 radians)
	var pts = PackedVector2Array([
		Vector2(-10, -15), Vector2(20, 0), Vector2(-10, 15), Vector2(-5, 0)
	])
	arrow.polygon = pts
	arrow.color = Color(1.0, 0.2, 0.2) # Red
	arrow.modulate = Color(2.0, 1.5, 1.5) # Glow
	arrow.visible = false
	$Control.add_child(arrow)
	
	# Add a pulse animation
	var t_boss = create_tween().set_loops(9999)
	t_boss.tween_property(arrow, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	t_boss.tween_property(arrow, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _process(_delta):
	# Update Boss Bar
	var boss = get_tree().get_first_node_in_group("bosses")
	var bar = $Control.get_node_or_null("BossBar")
	var label = $Control.get_node_or_null("BossLabel")
	var pointer = $Control.get_node_or_null("BossPointer")
	
	if boss and is_instance_valid(boss):
		if bar and label:
			bar.visible = true
			label.visible = true
			if "health" in boss and "max_health" in boss:
				bar.max_value = boss.max_health
				bar.value = boss.health
		
		if pointer:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var screen_size = get_viewport().get_visible_rect().size
				var boss_screen_pos = boss.get_global_transform_with_canvas().get_origin()
				
				# Check if boss is on screen with a margin
				var screen_margin = 50.0
				var is_off_screen = boss_screen_pos.x < screen_margin or boss_screen_pos.x > screen_size.x - screen_margin \
								or boss_screen_pos.y < screen_margin or boss_screen_pos.y > screen_size.y - screen_margin
				
				if is_off_screen:
					pointer.visible = true
					var center = screen_size / 2.0
					var to_boss = (boss_screen_pos - center)
					var dir = to_boss.normalized()
					
					# Clamp to screen edges
					var edge_margin = 40.0
					var target_pos = Vector2.ZERO
					
					# Line-box intersection or just simple clamping
					var slope = dir.y / dir.x if dir.x != 0 else 1e10
					
					if abs(dir.x) > abs(dir.y): # Hits left or right
						target_pos.x = (screen_size.x - edge_margin) if dir.x > 0 else edge_margin
						target_pos.y = center.y + (target_pos.x - center.x) * slope
					else: # Hits top or bottom
						target_pos.y = (screen_size.y - edge_margin) if dir.y > 0 else edge_margin
						target_pos.x = center.x + (target_pos.y - center.y) / slope
					
					# Final clamp to ensure it stays within bounds
					target_pos.x = clamp(target_pos.x, edge_margin, screen_size.x - edge_margin)
					target_pos.y = clamp(target_pos.y, edge_margin, screen_size.y - edge_margin)
					
					pointer.position = target_pos
					pointer.rotation = dir.angle()
				else:
					pointer.visible = false
	else:
		if bar and label:
			bar.visible = false
			label.visible = false
		if pointer:
			pointer.visible = false

func trigger_intro_fade():
	var fade = ColorRect.new()
	add_child(fade)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.WHITE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Fade out from white to transparent
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(fade.queue_free)
	
	# If we have a player, zoom the camera back in
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		var original_zoom = cam.zoom
		cam.zoom = original_zoom * 0.5
		create_tween().tween_property(cam, "zoom", original_zoom, 1.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _on_player_health_changed(current_health: int, _max_health: int):
	# Update hearts
	if heart_container:
		# Clear existing hearts
		for child in heart_container.get_children():
			child.queue_free()
		
		# Only add as many hearts as the player currently has
		for i in range(current_health):
			var heart = TextureRect.new()
			# Use the rune icon for the heart visual
			heart.texture = load("res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_007.png")
			heart.custom_minimum_size = Vector2(32, 32)
			heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Neon Red Glow for active hearts
			heart.modulate = Color(2.5, 0.2, 0.2)
			
			# Add a simple pulsing animation
			var tween = heart.create_tween().set_loops(9999)
			tween.tween_property(heart, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
			tween.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			heart.pivot_offset = Vector2(16, 16)
			
			heart_container.add_child(heart)

func setup_combo_ui():
	# We create the nodes here, but they will be reparented in setup_bottom_ui
	var combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = ""
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 24) # Smaller for bottom HUD
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 8)
	$Control.add_child(combo_label)
	
	var combo_bar = ProgressBar.new()
	combo_bar.name = "ComboBar"
	combo_bar.show_percentage = false
	combo_bar.custom_minimum_size = Vector2(200, 6)
	combo_bar.visible = false
	style_neon_bar(combo_bar, Color(1, 0.2, 0.4)) # Magenta
	$Control.add_child(combo_bar)

func style_neon_bar(bar: ProgressBar, color: Color):
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.6) # Dark background
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.border_color = color.lerp(Color.BLACK, 0.5)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = color
	fg.border_width_left = 1
	fg.border_width_top = 1
	fg.border_width_right = 1
	fg.border_width_bottom = 1
	fg.border_color = Color.WHITE
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_left = 4
	fg.corner_radius_bottom_right = 4
	fg.shadow_color = color.lerp(Color.TRANSPARENT, 0.5)
	fg.shadow_size = 8 # Neon Glow
	
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

var combo_label_node: Label = null
var combo_bar_node: ProgressBar = null
var boss_bar_node: ProgressBar = null

func _on_player_combo_changed(combo: int, progress: float):
	if not combo_label_node:
		combo_label_node = find_child("ComboLabel", true, false)
	if not combo_bar_node:
		combo_bar_node = find_child("ComboBar", true, false)
		
	if not combo_label_node or not combo_bar_node:
		return
		
	if combo < 2:
		combo_label_node.text = ""
		combo_bar_node.visible = false
		return
		
	combo_bar_node.visible = true
	combo_bar_node.value = progress * 100
	
	var old_text = combo_label_node.text
	combo_label_node.text = str(combo) + "x COMBO"
	
	# Only pop when the number actually changes
	if combo_label_node.text != old_text:
		combo_label_node.scale = Vector2(1.5, 1.5)
		combo_label_node.modulate = Color(2, 2, 2, 1) # Bright flash
		var tween = create_tween().set_parallel(true)
		tween.tween_property(combo_label_node, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_property(combo_label_node, "modulate", Color.WHITE, 0.2)
		
		# Change color based on combo depth
		if combo > 50: combo_label_node.modulate = Color(1, 0.5, 0) # Orange
		elif combo > 20: combo_label_node.modulate = Color(1, 1, 0) # Yellow
		elif combo > 10: combo_label_node.modulate = Color(0, 1, 1) # Cyan

func _on_player_xp_changed(current_xp: float, max_xp: float):
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp
	
	# Update level label if it exists
	var player = get_tree().get_first_node_in_group("player")
	if player and level_label:
		level_label.text = "Level " + str(player.level)

func _on_player_energy_changed(current: float, max_energy: float):
	if dash_bar:
		dash_bar.max_value = max_energy
		dash_bar.value = current
