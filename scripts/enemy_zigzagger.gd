extends EnemyBase
## Weaves toward the player on a sine wave, firing aimed shots.

@export var amplitude: float = 150.0
@export var frequency: float = 3.0

var time: float = 0.0
var fire_timer: float = 1.5

func _init():
	speed = 140.0
	health = 12.0
	damage = 5.0
	xp_value = 10
	death_particle_amount = 20
	death_particle_velocity = Vector2(100.0, 200.0)
	death_particle_color = Color(0.8, 1.0, 0.4)

func _ready():
	super()
	scale = Vector2(1.1, 1.1)
	setup_visuals()

func setup_visuals():
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(0.8, 1.0, 0.4) # Lime green
		poly.modulate = Color(1.3, 1.8, 1.2, 1.0) # Glow
		poly.polygon = PackedVector2Array([
			Vector2(15, 0),
			Vector2(-5, 10),
			Vector2(-10, 0),
			Vector2(-5, -10)
		])

func _physics_process(delta: float):
	if is_dying or not player or not is_instance_valid(player): return
	
	time += delta
	var to_player = (player.global_position - global_position).normalized()
	var side_vector = to_player.rotated(PI / 2)
	
	# Forward + sine wave sideways
	var wave = sin(time * frequency) * amplitude
	velocity = (to_player * speed) + (side_vector * wave)
	
	move_and_slide()
	rotation = velocity.angle()
	
	fire_timer -= delta
	if fire_timer <= 0:
		fire_bullet((player.global_position - global_position).normalized(), 300.0, damage, Color(0.8, 1.0, 0.4))
		fire_timer = 2.5
