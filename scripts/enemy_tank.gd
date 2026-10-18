extends EnemyBase
## Heavy square that chases relentlessly and fires a 5-bullet shotgun wall.

@export var fire_rate: float = 3.0

var fire_timer: float = 0.0

func _init():
	speed = 80.0
	health = 120.0
	damage = 20.0 # High contact damage
	xp_value = 50
	death_particle_amount = 80
	death_particle_velocity = Vector2(150.0, 450.0)
	death_particle_size = Vector2(5.0, 12.0)
	death_particle_color = Color(1.0, 0.1, 0.4)
	death_particle_lifetime = 1.5
	death_shake = 8.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.2, 1.2)
	setup_visuals()

func setup_visuals():
	# Large square
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Neon Pink
		poly.modulate = Color(1.8, 1.2, 1.5, 1.0) # Glow
		poly.polygon = PackedVector2Array([
			Vector2(40, 40),
			Vector2(-40, 40),
			Vector2(-40, -40),
			Vector2(40, -40)
		])

func _physics_process(delta: float):
	rotation += 0.5 * delta # Slow heavy rotation
	if not player or not is_instance_valid(player):
		return
	
	velocity = (player.global_position - global_position).normalized() * speed
	move_and_slide()
	
	fire_timer -= delta
	if fire_timer <= 0:
		fire_wall()
		fire_timer = fire_rate

func fire_wall():
	var base_dir = (player.global_position - global_position).normalized()
	for i in range(-2, 3):
		fire_bullet(base_dir.rotated(i * 0.2), 300.0, 10.0, Color(0.4, 1.0, 0.4), 4.0, 45.0)
