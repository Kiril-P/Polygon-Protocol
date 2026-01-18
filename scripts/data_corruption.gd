extends Area2D

var lifetime: float = 8.0
var damage_interval: float = 0.5
var damage_timer: float = 0.0
var size: float = 0.0
var max_size: float = 150.0
var rotation_speed: float = 0.0

@onready var poly: Polygon2D = $Polygon2D
@onready var collision: CollisionShape2D = $CollisionShape2D
var particles: CPUParticles2D

func _ready():
	# Randomized glitchy shape
	var points = PackedVector2Array()
	var sides = 6 # Hexagon as requested
	for i in range(sides):
		var angle = (TAU / sides) * i
		var r = 1.0 + randf_range(-0.3, 0.3)
		points.append(Vector2(r, 0).rotated(angle))
	poly.polygon = points
	poly.color = Color(1.0, 0.0, 0.2, 0.0) # Transparent red
	poly.scale = Vector2.ZERO
	
	# Setup Particles
	particles = CPUParticles2D.new()
	add_child(particles)
	particles.amount = 30
	particles.lifetime = 1.5
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	if "emission_sphere_radius" in particles:
		particles.emission_sphere_radius = 1.0 
	elif "emission_radius" in particles:
		particles.set("emission_radius", 1.0)
	particles.gravity = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.1, 0.3, 0.6) # Neon Red
	particles.emitting = true
	
	# Entry animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(poly, "scale", Vector2(max_size, max_size), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(collision, "scale", Vector2(max_size, max_size), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(particles, "scale", Vector2(max_size, max_size), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(poly, "color:a", 0.4, 1.0)
	
	# Pulsing
	var pulse = create_tween().set_loops(9999)
	pulse.tween_property(poly, "modulate", Color(1.5, 1.2, 1.2, 1.0), 0.5)
	pulse.tween_property(poly, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	
	# Connect bullet blocking signal
	area_entered.connect(_on_area_entered)
	
	# Random rotation speed
	rotation_speed = randf_range(-2.0, 2.0)

func _process(delta: float):
	rotation += rotation_speed * delta
	lifetime -= delta
	if lifetime <= 0:
		die()
		return
		
	# Glitch the shape slightly every frame
	var points = poly.polygon
	for i in range(points.size()):
		points[i] = points[i].move_toward(points[i].normalized() * (1.0 + randf_range(-0.1, 0.1)), 0.1)
	poly.polygon = points
	
	# Damage logic
	damage_timer -= delta
	if damage_timer <= 0:
		deal_damage()
		damage_timer = damage_interval

func deal_damage():
	# Visual glitch on damage
	var t = create_tween()
	t.tween_property(poly, "scale", poly.scale * 1.1, 0.05)
	t.tween_property(poly, "scale", Vector2(max_size, max_size), 0.05)
	
	# Damage Player and Enemies
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)
		elif body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(10.0) # Decent damage to enemies

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemy_bullets") or area.is_in_group("player_bullets"):
		# Destroy the bullet
		area.queue_free()
		# Spawn a tiny spark
		spawn_block_particle(area.global_position)

func spawn_block_particle(pos: Vector2):
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = pos
	p.amount = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.3
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.2, 0.4)
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)

func die():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(poly, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(collision, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(particles, "modulate:a", 0.0, 0.5)
	tween.tween_property(poly, "color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
