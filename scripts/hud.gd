extends CanvasLayer

@onready var heart_container = $Control/HeartContainer
@onready var xp_bar = $Control/XPBar
@onready var dash_bar = $Control/DashBar
@onready var level_label = $Control/LevelLabel

func _ready():
	add_to_group("hud")
	# Wait a frame to ensure all nodes are in groups
	await get_tree().process_frame
	
	# Find player and connect signals
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		# Initialize values
		_on_player_health_changed(player.current_hearts, player.max_hearts)
		_on_player_xp_changed(player.xp, player.xp_to_next_level)
		_on_player_energy_changed(player.current_energy, player.max_energy)
		level_label.text = "Level " + str(player.level)
	
	# Create heart container or reposition it
	setup_heart_container()
	
	# Kill Counter UI
	setup_kill_counter()
	
	# Initial Styling
	if xp_bar:
		xp_bar.modulate = Color(0.2, 1.0, 0.2) # Neon Green
	if dash_bar:
		dash_bar.modulate = Color(0.0, 0.8, 1.0) # Neon Cyan
		
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
	var t = create_tween().set_loops()
	t.tween_property(border, "border_color:a", 0.6, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(border, "border_color:a", 0.2, 1.5).set_trans(Tween.TRANS_SINE)
	
	var t2 = create_tween().set_loops()
	t2.tween_property(glow, "border_color:a", 0.3, 2.0).set_trans(Tween.TRANS_SINE)
	t2.tween_property(glow, "border_color:a", 0.05, 2.0).set_trans(Tween.TRANS_SINE)

func setup_heart_container():
	if has_node("Control/HeartContainer"):
		heart_container = $Control/HeartContainer
	else:
		heart_container = HBoxContainer.new()
		heart_container.name = "HeartContainer"
		$Control.add_child(heart_container)
	
	heart_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	heart_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	heart_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	heart_container.offset_bottom = -20 # Almost at the bottom
	heart_container.alignment = BoxContainer.ALIGNMENT_CENTER
	heart_container.add_theme_constant_override("separation", 10)

func setup_kill_counter():
	var kills_label = Label.new()
	kills_label.name = "KillsLabel"
	kills_label.text = "KILLS: 0"
	kills_label.add_theme_font_size_override("font_size", 20)
	kills_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kills_label.offset_left = -150
	kills_label.offset_top = -60
	$Control.add_child(kills_label)
	
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0, 1, 1, 0.8)) # Cyan glow
	timer_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	timer_label.offset_left = -150
	timer_label.offset_top = -100 # Above kills label
	$Control.add_child(timer_label)

func _process(_delta):
	# Update Kill Counter in real-time
	if has_node("/root/GlobalData") and has_node("Control/KillsLabel"):
		$Control/KillsLabel.text = "KILLS: " + str(get_node("/root/GlobalData").run_kills)
	
	# Update Timer
	if has_node("Control/TimerLabel"):
		var spawner = get_tree().get_first_node_in_group("spawner")
		if spawner:
			var t = spawner.time_passed
			$Control/TimerLabel.text = "%02d:%02d" % [int(t / 60), int(t) % 60]

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

func _on_player_health_changed(new_health: int, max_health: int):
	# Update hearts
	if heart_container:
		# Clear existing hearts
		for child in heart_container.get_children():
			child.queue_free()
		
		# Add new hearts
		for i in range(new_health):
			var heart = Label.new()
			heart.text = "♥"
			heart.add_theme_font_size_override("font_size", 32)
			
			# Neon Red Glow
			heart.modulate = Color(2.5, 0.2, 0.2) # Overdriven Red for glow
			heart.add_theme_color_override("font_outline_color", Color.WHITE)
			heart.add_theme_constant_override("outline_size", 2)
			
			# Add a simple pulsing animation to each heart
			var tween = heart.create_tween().set_loops()
			tween.tween_property(heart, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
			tween.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			heart.pivot_offset = Vector2(16, 16) # Center of heart approx
			
			heart_container.add_child(heart)

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
