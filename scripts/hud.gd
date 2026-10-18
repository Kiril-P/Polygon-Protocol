extends CanvasLayer

@onready var xp_bar = $Control/XPBar
@onready var level_label = $Control/LevelLabel

var vitals: HudVitals
var alert: HudAlert

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
	setup_boss_pointer()
	setup_vitals()
	setup_top_bar()
	setup_combo_ui()
	setup_boss_bar()
	
	# Wait a frame to ensure all nodes are in groups
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		player.combo_changed.connect(_on_player_combo_changed)
		_on_player_health_changed(player.current_hearts, player.max_hearts)
		_on_player_xp_changed(player.xp, player.xp_to_next_level)
		_on_player_energy_changed(player.current_energy, player.max_energy)
	
	# Corner brackets framing the playfield
	var frame := Control.new()
	frame.set_script(load("res://scripts/hud_frame.gd"))
	$Control.add_child(frame)
	$Control.move_child(frame, 0)
	
	setup_dash_overlay()
	trigger_intro_fade()

## Hearts + dash stamina: a single dark plate at the bottom centre.
func setup_vitals():
	alert = HudAlert.new()
	alert.name = "Alert"
	$Control.add_child(alert)
	$Control.move_child(alert, 0)
	vitals = HudVitals.new()
	vitals.name = "Vitals"
	vitals.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vitals.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals.offset_left = -HudVitals.PANEL_SIZE.x / 2.0
	vitals.offset_right = HudVitals.PANEL_SIZE.x / 2.0
	vitals.offset_top = -HudVitals.PANEL_SIZE.y - 22.0
	vitals.offset_bottom = -22.0
	$Control.add_child(vitals)

## XP is a thin strip along the very top edge; level sits quietly beside it.
func setup_top_bar():
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_left = 0
	xp_bar.offset_right = 0
	xp_bar.offset_top = 0
	xp_bar.offset_bottom = 7
	xp_bar.custom_minimum_size = Vector2(0, 7)
	style_neon_bar(xp_bar, Color(0.25, 1.0, 0.45))
	xp_bar.get_theme_stylebox("fill").shadow_size = 0
	xp_bar.get_theme_stylebox("background").bg_color = Color(0, 0, 0, 0.55)
	level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	level_label.offset_left = 24
	level_label.offset_top = 16
	level_label.offset_right = 160
	level_label.offset_bottom = 46
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.82))
	level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	level_label.add_theme_constant_override("outline_size", 6)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

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

func setup_kill_counter():
	# Removed Kills, Score, and Timer labels from HUD as requested.
	# They are now in the Pause Menu / Options Screen.
	pass

func setup_boss_bar():
	var boss_container = VBoxContainer.new()
	boss_container.name = "BossBarsContainer"
	boss_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_container.offset_top = 22
	boss_container.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_container.add_theme_constant_override("separation", 4)
	$Control.add_child(boss_container)
	
	setup_warning_label()

func setup_warning_label():
	var warn = Label.new()
	warn.name = "BossWarning"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warn.offset_top = 150
	warn.add_theme_font_size_override("font_size", 48)
	NeonUI.style_title(warn, NeonUI.RED, 48)
	warn.visible = false
	$Control.add_child(warn)

## Big callout when a boss changes phase (own label so it never fights the warning tweens).
func show_boss_phase(text: String):
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(label, Color(0.85, 0.35, 1.0), 56)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position.y = 210
	label.pivot_offset = Vector2(label.size.x / 2.0, 30)
	label.modulate = Color(1.6, 1.0, 1.8, 0.0)
	label.scale = Vector2(1.6, 1.6)
	$Control.add_child(label)
	var t := label.create_tween().set_parallel(true)
	t.tween_property(label, "modulate:a", 1.0, 0.25)
	t.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	t.set_parallel(false)
	t.tween_interval(1.6)
	t.tween_property(label, "modulate:a", 0.0, 0.4)
	t.tween_callback(label.queue_free)

func show_boss_warning(seconds: int = 0):
	var warn = $Control.get_node_or_null("BossWarning")
	if warn:
		warn.visible = true
		if seconds > 0:
			warn.text = "CORRUPTED PROTOCOL INBOUND - %ds" % seconds
		else:
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
	var t_boss_pointer = create_tween().set_loops().bind_node(arrow)
	t_boss_pointer.tween_property(arrow, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	t_boss_pointer.tween_property(arrow, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _process(_delta):
	# Update Boss Bars
	var bosses = get_tree().get_nodes_in_group("bosses")
	var container = $Control.get_node_or_null("BossBarsContainer")
	var pointer = $Control.get_node_or_null("BossPointer")
	
	if container:
		# Update or create bars for each boss
		var existing_bars = container.get_children()
		
		# Hide all first, then show active ones
		for child in existing_bars:
			child.visible = false
			
		for i in range(bosses.size()):
			var boss_node_ref = bosses[i]
			if not is_instance_valid(boss_node_ref) or ("is_dying" in boss_node_ref and boss_node_ref.is_dying):
				continue
				
			var bar_name = "BossBar_" + str(boss_node_ref.get_instance_id())
			var bar_node = container.get_node_or_null(bar_name)
			
			if not bar_node:
				# Create a new bar for this boss
				var boss_ui = VBoxContainer.new()
				boss_ui.name = bar_name
				boss_ui.alignment = BoxContainer.ALIGNMENT_CENTER
				container.add_child(boss_ui)
				
				var new_label = Label.new()
				new_label.name = "Label"
				new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				new_label.add_theme_font_size_override("font_size", 20)
				new_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
				new_label.add_theme_constant_override("outline_size", 6)
				boss_ui.add_child(new_label)
				
				var new_bar = ProgressBar.new()
				new_bar.name = "Bar"
				new_bar.show_percentage = false
				new_bar.custom_minimum_size = Vector2(640, 16)
				boss_ui.add_child(new_bar)
				
				# Style based on boss type
				var color = Color.RED
				if "heart_color" in boss_node_ref:
					color = boss_node_ref.heart_color
				style_neon_bar(new_bar, color)
				new_bar.get_theme_stylebox("fill").shadow_size = 0
				
				bar_node = boss_ui
			
			bar_node.visible = true
			var active_bar = bar_node.get_node("Bar")
			var active_label = bar_node.get_node("Label")
			
			if "health" in boss_node_ref and "max_health" in boss_node_ref:
				active_bar.max_value = boss_node_ref.max_health
				active_bar.value = boss_node_ref.health
				
				var boss_display_name = "CORRUPTED PROTOCOL"
				if boss_node_ref.get_script().resource_path.contains("boss_fortress"):
					boss_display_name = "FORTRESS PROTOCOL"
				elif boss_node_ref.get_script().resource_path.contains("boss_pulsar"):
					boss_display_name = "PULSAR PROTOCOL"
				elif boss_node_ref.get_script().resource_path.contains("boss_singularity"):
					boss_display_name = "SINGULARITY PROTOCOL"
				
				active_label.text = boss_display_name
		
		# Cleanup bars for bosses that are gone
		for child in existing_bars:
			var boss_id = child.name.replace("BossBar_", "")
			var found = false
			for b in bosses:
				if str(b.get_instance_id()) == boss_id:
					found = true
					break
			if not found:
				child.queue_free()

	if bosses.size() > 0:
		var boss = bosses[0] # Point to the first boss for simplicity
		if pointer and is_instance_valid(boss):
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

func _on_player_health_changed(current_health: int, max_health: int):
	if not vitals:
		return
	if alert and vitals.hearts > current_health and vitals.max_hearts > 0:
		alert.flash_hit()
	vitals.set_hearts(current_health, max_health)
	if alert:
		alert.low_hp = current_health <= 1 and max_health > 0
	AudioManager.set_low_health(current_health <= 1 and max_health > 0)

func setup_combo_ui():
	# Bottom-right, clear of the vitals plate and the player's field of view.
	var box := VBoxContainer.new()
	box.name = "ComboBox"
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -60
	box.offset_bottom = -44
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 4)
	$Control.add_child(box)
	
	var combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = ""
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override("font_size", 34)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.pivot_offset = Vector2(160, 20)
	box.add_child(combo_label)
	
	var combo_bar = ProgressBar.new()
	combo_bar.name = "ComboBar"
	combo_bar.show_percentage = false
	combo_bar.custom_minimum_size = Vector2(190, 6)
	combo_bar.visible = false
	style_neon_bar(combo_bar, Color(1, 0.3, 0.5))
	combo_bar.get_theme_stylebox("fill").shadow_size = 0
	box.add_child(combo_bar)

func style_neon_bar(bar: ProgressBar, color: Color):
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.08, 0.75) # Dark background
	bg.set_border_width_all(2)
	bg.border_color = color.lerp(Color.BLACK, 0.45)
	bg.set_corner_radius_all(1) # Sharp, technical edges
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = color.lerp(Color.WHITE, 0.15)
	fg.set_border_width_all(1)
	fg.border_color = color.lerp(Color.WHITE, 0.8)
	fg.set_corner_radius_all(1)
	fg.shadow_color = Color(color.r, color.g, color.b, 0.55)
	fg.shadow_size = 4
	
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
	combo_label_node.text = "x%d COMBO" % combo
	
	# Only pop when the number actually changes
	if combo_label_node.text != old_text:
		AudioManager.play_sfx("combo_tick", 0.0, 1.0 + minf(combo, 40) * 0.015)
		combo_label_node.scale = Vector2(1.5, 1.5)
		combo_label_node.modulate = Color(2, 2, 2, 1) # Bright flash
		var tween = create_tween().set_parallel(true)
		tween.tween_property(combo_label_node, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_property(combo_label_node, "modulate", Color.WHITE, 0.2)
		
		# Escalating colour tiers, applied as font colour + glow outline so the pop flash still reads
		var tier := Color(0.85, 0.95, 1.0)
		if combo > 50: tier = Color(1.0, 0.45, 0.1) # Orange
		elif combo > 20: tier = Color(1.0, 0.9, 0.2) # Yellow
		elif combo > 10: tier = Color(0.2, 1.0, 1.0) # Cyan
		combo_label_node.add_theme_color_override("font_color", tier)
		combo_label_node.add_theme_font_size_override("font_size", 30 + mini(combo / 10, 10))

func _on_player_xp_changed(current_xp: float, max_xp: float):
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp
	
	# Update level label if it exists
	var player = get_tree().get_first_node_in_group("player")
	if player and level_label:
		level_label.text = "LEVEL " + str(player.level)

func _on_player_energy_changed(current: float, max_energy: float):
	if vitals:
		vitals.set_energy(current, max_energy)
