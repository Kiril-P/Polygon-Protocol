extends CharacterBody2D

@export var speed: float = 80.0
@export var health: float = 120.0
@export var damage: float = 20.0 # High contact damage
@export var xp_value: int = 50
@export var fire_rate: float = 3.0
@export var bullet_scene: PackedScene
@export var xp_gem_scene: PackedScene

var player: Node2D = null
var fire_timer: float = 0.0
var is_dying: bool = false

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# Make it bigger
	scale = Vector2(1.2, 1.2)
	
	# Collision setup
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)
	
	setup_visuals()

func setup_visuals():
	# Large Square
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Neon Pink
		var points = PackedVector2Array([
			Vector2(40, 40),
			Vector2(-40, 40),
			Vector2(-40, -40),
			Vector2(40, -40)
		])
		poly.polygon = points

func _physics_process(delta: float):
	# Slow heavy rotation
	rotation += 0.5 * delta
	
	if not player or not is_instance_valid(player):
		return
		
	# Movement: Direct relentless chase
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	# Shooting: Heavy Shotgun Wall
	fire_timer -= delta
	if fire_timer <= 0:
		fire_wall()
		fire_timer = fire_rate

func fire_wall():
	if not bullet_scene: return
	
	var base_dir = (player.global_position - global_position).normalized()
	
	# Fire 5 bullets in a wide spread
	for i in range(-2, 3):
		var angle = i * 0.2
		var dir = base_dir.rotated(angle)
		spawn_bullet(dir)

func spawn_bullet(dir: Vector2):
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * 60.0 # Further out
	get_parent().add_child(bullet)
	
	bullet.fired_by_enemy = true # Safety flag
	bullet.direction = dir
	bullet.speed = 300.0 
	bullet.damage = 10.0
	bullet.add_to_group("enemy_bullets")
	
	# ONLY collide with player (Layer 2)
	bullet.collision_mask = 0
	bullet.set_collision_mask_value(2, true)
	
	# Make it very large
	bullet.scale = Vector2(4.0, 4.0)
	
	if bullet.has_node("BulletSprite"):
		bullet.get_node("BulletSprite").color = Color(0.4, 1.0, 0.4) # Bright Green

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	
	# Visual feedback: Flash white
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)
	
	if health <= 0:
		die()

func die():
	if is_dying: return
	is_dying = true
	spawn_death_particles()
	
	if player and player.has_method("add_shake"):
		player.add_shake(8.0) # More shake for tank
	
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = global_position
		gem.xp_value = xp_value
		get_tree().current_scene.call_deferred("add_child", gem)
	queue_free()

func spawn_death_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.amount = 80 # LOTS of particles for tank
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 450.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 12.0
	particles.color = Color(1.0, 0.1, 0.4)
	particles.emitting = true
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(particles.queue_free)
