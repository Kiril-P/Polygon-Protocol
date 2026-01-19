extends Area2D

signal chosen

var label_text: String = ""
var is_boss_choice: bool = true
var player: Node2D = null
var visual_container: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	visual_container = Node2D.new()
	add_child(visual_container)
	
	# Initial state
	scale = Vector2.ZERO
	modulate.a = 0
	
	var color = Color(1.0, 0.2, 0.4) if is_boss_choice else Color(0.2, 1.0, 0.4)
	
	# Layered Polygon Design (Neon look)
	_create_neon_polygon(70, color, 1.0) 
	_create_neon_polygon(85, color, 0.4) 
	_create_neon_polygon(105, color, 0.15) 
	
	# Add Neon Particles
	_add_neon_particles(color)
	
	# Label Styling (Doesn't rotate)
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.position = Vector2(-200, -160) 
	label.size = Vector2(400, 50)
	add_child(label)
	
	# Dash Requirement Label
	var dash_label = Label.new()
	dash_label.text = "[DASH TO SELECT]"
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label.add_theme_font_size_override("font_size", 20)
	dash_label.modulate = color
	dash_label.modulate.a = 0.9
	dash_label.position = Vector2(-100, 130)
	dash_label.size = Vector2(200, 30)
	add_child(dash_label)
	
	# Collision (Much larger)
	var coll = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 110.0
	coll.shape = shape
	add_child(coll)
	
	# Set collision mask to detect player (Layer 2)
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)
	
	# Entrance Animation
	var entrance = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(self, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(self, "modulate:a", 1.0, 0.6)
	
	# Persistent Idle Animation (Pulse)
	var idle = create_tween().set_loops().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	idle.tween_property(visual_container, "scale", Vector2(1.15, 1.15), 1.5).set_trans(Tween.TRANS_SINE)
	idle.chain().tween_property(visual_container, "scale", Vector2(0.9, 0.9), 1.5).set_trans(Tween.TRANS_SINE)
	
	# Rotation for the neon polygons only
	var rotate_tween = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	rotate_tween.tween_property(visual_container, "rotation", TAU, 6.0).as_relative()
	
	body_entered.connect(_on_body_entered)

func _create_neon_polygon(radius: float, color: Color, alpha: float):
	var poly = Polygon2D.new()
	var points = PackedVector2Array()
	var sides = 6 if is_boss_choice else 8
	
	for i in range(sides):
		var angle = (TAU / sides) * i
		points.append(Vector2(radius, 0).rotated(angle))
	
	poly.polygon = points
	poly.color = color
	poly.color.a = alpha
	
	var line = Line2D.new()
	var line_points = points.duplicate()
	line_points.append(points[0]) 
	line.points = line_points
	line.width = 6.0
	line.default_color = color
	line.default_color.a = alpha * 1.5
	poly.add_child(line)
	
	visual_container.add_child(poly)

func _add_neon_particles(color: Color):
	var p = CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 2.0
	p.preprocess = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 90.0
	p.gravity = Vector2.ZERO
	p.radial_accel_min = -30.0
	p.radial_accel_max = 30.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.color.a = 0.5
	p.draw_order = CPUParticles2D.DRAW_ORDER_LIFETIME
	add_child(p)
	p.emitting = true

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.get("is_dashing"):
			chosen.emit()
			# Visual pop on selection
			var pop = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			pop.tween_property(self, "scale", Vector2(2.5, 2.5), 0.3).set_trans(Tween.TRANS_EXPO)
			pop.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
			pop.tween_callback(queue_free)
