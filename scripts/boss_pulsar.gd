extends CharacterBody2D

@export var health: float = 12000.0
@export var max_health: float = 12000.0
@export var xp_value: int = 1500

var player: Node2D = null
var is_dying: bool = false
var phase: int = 1
var laser_rotation: float = 0.0
var laser_speed: float = 1.0
var laser_nodes: Array[Line2D] = []
var lasers_active: bool = true

var arena_barrier: StaticBody2D = null
var border_radius: float = 1450.0

@onready var poly = $Polygon2D

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.dash_nerf_active = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_dash_nerf_warning()
	
	setup_visuals()
	setup_arena_border()
	setup_lasers()

func setup_visuals():
	# Massive Eye Core
	var pts = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32.0) * i
		pts.append(Vector2(100, 0).rotated(angle))
	poly.polygon = pts
	poly.color = Color(0.05, 0.05, 0.1) # Dark Void
	poly.modulate = Color(0, 1.5, 2.0) # Neon Cyan Glow
	
	# Pupils/Inner Core
	var inner = Polygon2D.new()
	var in_pts = PackedVector2Array()
	for i in range(16):
		in_pts.append(Vector2(40, 0).rotated((TAU / 16.0) * i))
	inner.polygon = in_pts
	inner.color = Color(1, 1, 1)
	poly.add_child(inner)

func setup_arena_border():
	var border = Line2D.new()
	border.name = "ArenaBorder"
	var pts = PackedVector2Array()
	for i in range(65):
		pts.append(Vector2(border_radius, 0).rotated((TAU / 64.0) * i))
	border.points = pts
	border.width = 15.0
	border.default_color = Color(0, 1, 1, 0.6)
	add_child(border)
	
	var static_body = StaticBody2D.new()
	static_body.name = "Barrier"
	static_body.collision_layer = 1
	get_parent().add_child.call_deferred(static_body)
	static_body.global_position = global_position
	arena_barrier = static_body
	
	var segment_count = 16
	for i in range(segment_count):
		var p1 = Vector2(border_radius, 0).rotated((TAU / segment_count) * i)
		var p2 = Vector2(border_radius, 0).rotated((TAU / segment_count) * (i + 1))
		var coll = CollisionShape2D.new()
		var segment = SegmentShape2D.new()
		segment.a = p1
		segment.b = p2
		coll.shape = segment
		static_body.add_child(coll)

func setup_lasers():
	# Clear existing
	for l in laser_nodes:
		l.queue_free()
	laser_nodes.clear()
	
	var count = 2
	if phase == 2: count = 3
	elif phase == 3: count = 5
	
	var angle_step = TAU / float(count)
	for i in range(count):
		var laser = Line2D.new()
		laser.width = 12.0
		laser.default_color = Color(0, 1, 1, 0.8)
		laser.points = PackedVector2Array([Vector2.ZERO, Vector2(border_radius, 0)])
		add_child(laser)
		laser_nodes.append(laser)
		
		# Glow
		var t = create_tween().set_loops()
		t.tween_property(laser, "width", 18.0, 0.1)
		t.tween_property(laser, "width", 12.0, 0.1)

func _physics_process(delta: float):
	if is_dying: return
	
	# Laser Rotation (Never stops)
	laser_rotation += laser_speed * delta
	var count = laser_nodes.size()
	var angle_step = TAU / float(count)
	
	for i in range(count):
		var dir = 1.0
		# In Phase 1 (2 lasers), make them rotate in opposite directions
		if count == 2 and i == 1:
			dir = -1.0
			
		var angle = (laser_rotation * dir) + (angle_step * i)
		laser_nodes[i].rotation = angle
		check_laser_collision(laser_nodes[i])
			
	# Heart Spawning logic
	var active_hearts = get_tree().get_nodes_in_group("boss_hearts")
	var has_own_heart = false
	for h in active_hearts:
		if h.get("boss") == self:
			has_own_heart = true
			break
			
	if not has_own_heart and not is_dying:
		spawn_three_hearts()

func spawn_three_hearts():
	var start_angle = randf() * TAU
	for i in range(3):
		var angle = start_angle + (TAU / 3.0) * i
		var pos = Vector2(border_radius - 150.0, 0).rotated(angle)
		
		var heart_script = load("res://scripts/boss_pillar.gd")
		var heart = Area2D.new()
		heart.set_script(heart_script)
		heart.set("boss", self)
		get_parent().add_child(heart)
		heart.global_position = global_position + pos
		heart.add_to_group("boss_hearts")

func check_laser_collision(laser: Line2D):
	if not player or not is_instance_valid(player): return
	
	var to_player = player.global_position - global_position
	var laser_dir = Vector2.RIGHT.rotated(laser.rotation)
	
	var projection = to_player.dot(laser_dir)
	if projection > 0 and projection < border_radius:
		var closest_point = laser_dir * projection
		if player.global_position.distance_to(global_position + closest_point) < 35.0:
			if player.has_method("take_damage"):
				player.take_damage(1)

func take_damage(amount: float):
	if is_dying: return
	
	health -= amount
	
	# Visual Flash
	var t = create_tween()
	poly.modulate = Color(5, 5, 5, 1)
	var target_col = Color(0, 1.5, 2.0, 1.0) if phase < 3 else Color(2.0, 0.0, 5.0, 1.0)
	t.tween_property(poly, "modulate", target_col, 0.1)
	
	# Phase Transitions based on health (each set of 3 hearts is 1/3 of max health)
	# User wants 3/9 per heart, so 3 hearts = 9/9 = 100%? 
	# Wait, 3/9 damage per heart means 3 hearts = 9/9 damage.
	# So destroying 3 hearts KILLS the boss if we don't have phases.
	# I'll interpret "3/9 damage" as each heart set representing a phase.
	
	var health_percent = health / max_health
	
	if health_percent < 0.67 and phase == 1:
		phase = 2
		laser_speed *= 1.2
		setup_lasers()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn", 1.2)
			
	elif health_percent < 0.34 and phase == 2:
		phase = 3
		laser_speed *= 1.2
		poly.color = Color(0.1, 0.0, 0.2) # Deep Purple Void
		setup_lasers()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("boss_spawn", 1.5)
	
	if health <= 0:
		die()

func die():
	if is_dying: return
	is_dying = true
	
	if player:
		player.dash_nerf_active = false
	
	if is_instance_valid(arena_barrier):
		arena_barrier.queue_free()
		
	var hearts = get_tree().get_nodes_in_group("boss_hearts")
	for h in hearts:
		if h.get("boss") == self:
			h.queue_free()
			
	queue_free()
