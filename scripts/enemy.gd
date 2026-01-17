extends CharacterBody2D

@export var speed: float = 200.0
@export var health: float = 20.0
@export var damage: float = 10.0
@export var xp_value: int = 10

var player: Node2D = null
var is_dying: bool = false

func _ready():
	add_to_group("enemies")
	# Find the player in the group we just set up
	player = get_tree().get_first_node_in_group("player")
	
	# Make enemies slightly bigger
	scale = Vector2(1.5, 1.5)
	
	if has_node("Polygon2D"):
		$Polygon2D.color = Color(1.0, 0.1, 0.4) # Neon Red/Pink
	# But keep collision with world (Layer 1)
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)

func _physics_process(delta: float):
	# Rotate for visual interest
	rotation += 2.0 * delta
	
	if player and is_instance_valid(player):
		# Calculate direction to player
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func spawn_death_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	
	particles.amount = 40
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = $Polygon2D.color if has_node("Polygon2D") else Color.RED
	
	particles.emitting = true
	
	# Auto-delete particles
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)

func take_damage(amount: float):
	if is_dying:
		return
	health -= amount
	
	# Hit flash
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
