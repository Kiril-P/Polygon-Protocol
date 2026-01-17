extends CharacterBody2D

@export var speed: float = 120.0
@export var health: float = 15.0
@export var damage: float = 5.0
@export var xp_value: int = 8

var player: Node2D = null
var drift_direction: Vector2 = Vector2.ZERO
var drift_timer: float = 0.0
var is_dying: bool = false

@export var xp_gem_scene: PackedScene

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# Small triangle
	scale = Vector2(1.0, 1.0)
	setup_visuals()
	
	# Collision setup
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)
	
	# Start with a random direction
	change_direction()

func setup_visuals():
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Palette Neon Pink
		poly.polygon = PackedVector2Array([
			Vector2(15, 0),
			Vector2(-10, 10),
			Vector2(-10, -10)
		])

func _physics_process(delta: float):
	if is_dying: return
	
	rotation += 3.0 * delta
	
	drift_timer -= delta
	if drift_timer <= 0:
		change_direction()
	
	# Move in drift direction, but slightly lean towards player
	var to_player = Vector2.ZERO
	if player and is_instance_valid(player):
		to_player = (player.global_position - global_position).normalized()
	
	velocity = (drift_direction * 0.7 + to_player * 0.3).normalized() * speed
	move_and_slide()

func change_direction():
	drift_direction = Vector2.RIGHT.rotated(randf() * TAU)
	drift_timer = randf_range(1.0, 3.0)

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	flash_white()
	if health <= 0: die()

func flash_white():
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)

func die():
	if is_dying: return
	is_dying = true
	spawn_death_particles()
	if player and player.has_method("add_shake"): player.add_shake(3.0)
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
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 250.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.1, 0.4)
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
