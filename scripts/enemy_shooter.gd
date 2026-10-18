extends EnemyBase
## Keeps its distance, orbits, and fires 3-way bursts.

@export var shooting_range: float = 400.0
@export var keep_distance: float = 300.0
@export var fire_rate: float = 2.5
@export var burst_count: int = 3
@export var burst_delay: float = 0.15

var fire_timer: float = 0.0

func _init():
	speed = 150.0
	health = 20.0
	damage = 10.0
	xp_value = 15
	death_particle_amount = 35
	death_particle_velocity = Vector2(150.0, 300.0)
	death_particle_size = Vector2(4.0, 7.0)
	death_shake = 5.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.3, 1.3)
	setup_visuals()

func setup_visuals():
	# Diamond with "wings"
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
	if not player or not is_instance_valid(player):
		return
	
	# Rotate to "face" the player slowly
	var target_angle = (player.global_position - global_position).angle()
	rotation = lerp_angle(rotation, target_angle, 5.0 * delta)
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	
	# Movement: orbit / keep distance
	if distance_to_player > shooting_range:
		velocity = direction * speed
	elif distance_to_player < keep_distance:
		velocity = -direction * speed
	else:
		velocity = direction.rotated(PI / 2) * (speed * 0.5)
	
	move_and_slide()
	
	fire_timer -= delta
	if fire_timer <= 0 and distance_to_player <= shooting_range:
		fire_burst()
		fire_timer = fire_rate

func fire_burst():
	var base_dir = (player.global_position - global_position).normalized()
	for angle in [-0.3, 0.0, 0.3]: # ~17 degree spread
		fire_bullet(base_dir.rotated(angle), 400.0, damage, Color(1, 0.8, 0.2), 2.5, 20.0)
