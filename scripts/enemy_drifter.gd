extends EnemyBase
## Wanders in random directions while leaning toward the player.

var drift_direction: Vector2 = Vector2.ZERO
var drift_timer: float = 0.0

func _init():
	speed = 120.0
	health = 15.0
	damage = 5.0
	xp_value = 8
	death_particle_amount = 20
	death_particle_velocity = Vector2(100.0, 250.0)
	death_shake = 3.0
	play_hit_sfx = false

func _ready():
	super()
	setup_visuals()
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
	if is_dying:
		return
	rotation += 3.0 * delta
	drift_timer -= delta
	if drift_timer <= 0:
		change_direction()
	var to_player = Vector2.ZERO
	if player and is_instance_valid(player):
		to_player = (player.global_position - global_position).normalized()
	velocity = (drift_direction * 0.7 + to_player * 0.3).normalized() * speed
	move_and_slide()

func change_direction():
	drift_direction = Vector2.RIGHT.rotated(randf() * TAU)
	drift_timer = randf_range(1.0, 3.0)
