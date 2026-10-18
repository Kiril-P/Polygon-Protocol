extends EnemyBase
## Charges in a straight line once the player is in range, then explodes.

@export var charge_speed_mult: float = 2.5
@export var detect_range: float = 300.0

var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO

@onready var sprite = $Polygon2D

func _init():
	speed = 250.0
	health = 12.0 # Squishy but dangerous
	damage = 1.0 # 1 heart (direct damage in explode)
	xp_value = 25
	death_particle_amount = 30
	death_particle_velocity = Vector2(200.0, 400.0)
	death_particle_size = Vector2(5.0, 10.0)
	death_particle_color = Color(1.0, 0.4, 0.0)
	play_hit_sfx = true

func _ready():
	super()
	scale = Vector2(0.8, 0.8)
	sprite.color = Color(1.0, 0.4, 0.0) # Vibrant orange (restyled to neon by EnemyBase)
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.4], [0.0, 0.7, 1.0, 1.3, 1.6, 2.0])

func _physics_process(delta: float):
	if is_dying or not player or not is_instance_valid(player):
		return

	if not is_charging and global_position.distance_to(player.global_position) < detect_range:
		start_charge()
	
	if is_charging:
		velocity = charge_direction * speed * charge_speed_mult
		rotation += 15.0 * delta # Spin wildly
		var pulse = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
		if neon_outline:
			neon_outline.default_color = Color(1.0, 0.7, 0.2).lerp(Color(1.0, 0.1, 0.1), pulse) * Color(1.6, 1.6, 1.6, 1.0)
		sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.5, 0.8, 0.8), pulse)
	else:
		velocity = (player.global_position - global_position).normalized() * speed
		rotation += 5.0 * delta
		
	var collision = move_and_collide(velocity * delta)
	if collision:
		# Hitting the player, or anything else while charging, detonates
		if collision.get_collider().is_in_group("player") or is_charging:
			explode()

func start_charge():
	is_charging = true
	charge_direction = (player.global_position - global_position).normalized()
	
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	t.tween_property(self, "scale", Vector2(0.8, 0.8), 0.1)
	AudioManager.play_sfx("kamikaze_alert")

func flash_white():
	var t = create_tween()
	sprite.modulate = Color(10, 10, 10, 1)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func explode():
	if is_dying: return
	is_dying = true
	
	if player and global_position.distance_to(player.global_position) < 80.0 and player.has_method("take_damage"):
		player.take_damage(1) # 1 heart
	
	AudioManager.play_sfx("bullet_explosion")
	spawn_death_particles()
	VFX.shockwave(global_position, 1.3, Color(1.0, 0.5, 0.1), 160.0)
	if player and player.has_method("add_shake"):
		player.add_shake(20.0)
	queue_free()
