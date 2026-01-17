extends CanvasLayer

@onready var heart_container = $Control/HeartContainer
@onready var xp_bar = $Control/XPBar
@onready var dash_bar = $Control/DashBar
@onready var level_label = $Control/LevelLabel
var vignette: TextureRect

func _ready():
	# Create true Vignette texture
	setup_vignette()
	
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
	
	# Hide heart container as requested
	if heart_container:
		heart_container.visible = false
	
	# Initial Styling
	if xp_bar:
		xp_bar.modulate = Color(0.2, 1.0, 0.2) # Neon Green
	if dash_bar:
		dash_bar.modulate = Color(0.0, 0.8, 1.0) # Neon Cyan
		
	# INTRO ANIMATION: "Reverse Warp"
	trigger_intro_fade()

func setup_vignette():
	vignette = TextureRect.new()
	vignette.name = "VignetteNode"
	$Control.add_child(vignette)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	
	# Create a Radial Gradient for the vignette
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.7, 1.0] # More pervasive red
	gradient.colors = [Color(0.8, 0, 0, 0), Color(0.9, 0, 0, 0.4), Color(1.0, 0, 0, 1.0)] 
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 512
	tex.height = 512
	
	vignette.texture = tex
	vignette.modulate.a = 0 # Start invisible
	
	# Move to front
	vignette.z_index = 10 

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
	# Update vignette alpha based on health - MUCH more aggressive
	if vignette:
		var health_percent = float(new_health) / float(max_health)
		
		# Start appearing immediately and ramp up fast
		var target_alpha = (1.0 - health_percent) * 1.5 
		target_alpha = clamp(target_alpha, 0.0, 1.0) # Full coverage at low HP
		
		# Ensure it's visible and on top
		vignette.visible = target_alpha > 0.01
		vignette.z_index = 10
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(vignette, "modulate:a", target_alpha, 0.2).set_trans(Tween.TRANS_SINE)
		
		# "Closing in" scale effect on hit
		vignette.scale = Vector2(1.2, 1.2)
		vignette.pivot_offset = get_viewport().get_visible_rect().size / 2.0
		tween.tween_property(vignette, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
		
		# Extra bright red hit flash pulse on the vignette itself
		var pulse_tween = create_tween()
		vignette.modulate = Color(5.0, 1.0, 1.0, target_alpha) 
		pulse_tween.tween_property(vignette, "modulate", Color(1, 1, 1, target_alpha), 0.3)

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
