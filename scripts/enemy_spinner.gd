extends EnemyBase
## Slow pentagon that sprays a rotating spiral of bullets.

@export var fire_rate: float = 0.25

var fire_timer: float = 0.0
var spiral_angle: float = 0.0

func _init():
	speed = 120.0
	health = 40.0
	damage = 10.0
	xp_value = 25
	death_particle_amount = 45
	death_particle_velocity = Vector2(150.0, 350.0)
	death_particle_size = Vector2(4.0, 9.0)
	death_particle_color = Color(1.0, 0.1, 0.4)
	death_shake = 6.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.4, 1.4)
	setup_visuals()

func setup_visuals():
	# Pentagon
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Neon Pink
		poly.modulate = Color(1.8, 1.2, 1.5, 1.0) # Strong pink glow
		var points = PackedVector2Array()
		for i in range(5):
			points.append(Vector2(25, 0).rotated((TAU / 5) * i))
		poly.polygon = points

func _physics_process(delta: float):
	rotation += 4.0 * delta
	if not player or not is_instance_valid(player):
		return
	velocity = (player.global_position - global_position).normalized() * speed
	move_and_slide()
	
	fire_timer -= delta
	if fire_timer <= 0:
		fire_spiral()
		fire_timer = fire_rate

func fire_spiral():
	spiral_angle += 0.4
	var dir = Vector2.RIGHT.rotated(spiral_angle)
	# Two bullets in opposite directions
	for d in [dir, -dir]:
		fire_bullet(d, 350.0, damage, Color(0.8, 0.4, 1.0), 2.0, 20.0)
