extends CharacterBody2D

@export var speed: float = 150.0
@export var health: float = 20.0
@export var damage: float = 10.0
@export var xp_value: int = 15
@export var shooting_range: float = 400.0
@export var keep_distance: float = 300.0
@export var fire_rate: float = 2.5
@export var burst_count: int = 3
@export var burst_delay: float = 0.15
@export var bullet_scene: PackedScene

var player: Node2D = null
var fire_timer: float = 0.0
var is_dying: bool = false

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# Make it bigger
	scale = Vector2(1.3, 1.3)
	
	# Collision setup
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)
	
	setup_shooter_visuals()

func setup_shooter_visuals():
	# Make it look like a diamond with "wings"
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Neon Pink
		poly.modulate = Color(1.8, 1.2, 1.5, 1.0) # Glow
		poly.polygon = PackedVector2Array([
			Vector2(20, 0),   # Front
			Vector2(0, 15),   # Left wing
			Vector2(-15, 0),  # Back
			Vector2(0, -15)   # Right wing
		])

func _physics_process(delta: float):
	# Rotate to "face" the player slowly
	if player and is_instance_valid(player):
		var target_angle = (player.global_position - global_position).angle()
		rotation = lerp_angle(rotation, target_angle, 5.0 * delta)
	
	if not player or not is_instance_valid(player):
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	
	# Movement logic: Orbit/Keep distance
	if distance_to_player > shooting_range:
		velocity = direction * speed
	elif distance_to_player < keep_distance:
		velocity = -direction * speed
	else:
		# Orbit slowly
		var orbit_dir = direction.rotated(PI/2)
		velocity = orbit_dir * (speed * 0.5)
	
	move_and_slide()
	
	# Shooting logic: Burst pattern
	fire_timer -= delta
	if fire_timer <= 0 and distance_to_player <= shooting_range:
		fire_burst()
		fire_timer = fire_rate

func fire_burst():
	# 3-way spread pattern
	var angles = [-0.3, 0, 0.3] # Radians (~17 degrees)
	var base_dir = (player.global_position - global_position).normalized()
	
	for angle in angles:
		var dir = base_dir.rotated(angle)
		spawn_bullet(dir)

func spawn_bullet(dir: Vector2):
	if not bullet_scene: return
	var bullet = bullet_scene.instantiate()
	# SET POSITION BEFORE ADD_CHILD
	bullet.global_position = global_position + dir * 40.0 # Further out
	get_parent().add_child(bullet)
	
	bullet.fired_by_enemy = true # Safety flag
	bullet.direction = dir
	bullet.speed = 400.0 
	bullet.damage = damage
	bullet.add_to_group("enemy_bullets")
	
	# ONLY collide with player (Layer 2)
	bullet.collision_mask = 0
	bullet.set_collision_mask_value(2, true)
	
	# Make it larger
	bullet.scale = Vector2(2.5, 2.5)
	
	if bullet.has_node("BulletSprite"):
		bullet.get_node("BulletSprite").color = Color(1, 0.8, 0.2) # Gold/Yellow

func take_damage(amount: float):
	if is_dying:
		return
	health -= amount
	
	flash_white()
	
	if health <= 0:
		die()

func flash_white():
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)

func die():
	if is_dying:
		return
	is_dying = true
	
	spawn_death_particles()
	
	if player and player.has_method("add_shake"):
		player.add_shake(5.0)
	
	# Give XP directly to player
	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
		
	queue_free()

func spawn_death_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	
	particles.amount = 35
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.color = $Polygon2D.color if has_node("Polygon2D") else Color.ORANGE
	
	particles.emitting = true
	
	# Auto-delete particles
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)
