extends EnemyBase
## Basic chaser: runs straight at the player.

func _init():
	speed = 200.0
	health = 20.0
	damage = 10.0
	xp_value = 10
	death_particle_amount = 40
	death_particle_velocity = Vector2(150.0, 350.0)
	death_particle_size = Vector2(4.0, 8.0)
	death_shake = 5.0

func _ready():
	super()
	scale = Vector2(1.5, 1.5)
	if has_node("Polygon2D"):
		$Polygon2D.color = Color(1.0, 0.1, 0.4) # Neon Red/Pink
		$Polygon2D.modulate = Color(1.5, 1.2, 1.2, 1.0) # Glow
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.3], [0.0, 0.7, 1.0, 1.3, 1.7, 2.2])

func _physics_process(delta: float):
	# Rotate for visual interest
	rotation += 2.0 * delta
	if player and is_instance_valid(player):
		velocity = (player.global_position - global_position).normalized() * speed
		move_and_slide()
