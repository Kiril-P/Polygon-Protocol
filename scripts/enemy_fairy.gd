extends EnemyBase
## Approaches to the edge of the screen, fires a few shots, then leaves.

@export var stop_distance: float = 650.0 # Keeps them at the edge

enum State { APPROACH, SHOOT, LEAVE }
var current_state: State = State.APPROACH

var shots_fired: int = 0
var max_shots: int = 3
var fire_timer: float = 1.0
var leave_direction: Vector2 = Vector2.ZERO

func _init():
	speed = 200.0
	health = 10.0
	damage = 5.0
	xp_value = 5
	death_particle_amount = 15
	death_particle_velocity = Vector2(80.0, 150.0)
	death_particle_size = Vector2(2.0, 4.0)
	death_particle_color = Color(0.4, 0.8, 1.0)

func _ready():
	super()
	scale = Vector2(0.9, 0.9)
	setup_visuals()

func setup_visuals():
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.9, 0.0) # Neon Yellow (distinct from player cyan)
		poly.modulate = Color(2.0, 1.8, 1.0, 1.0) # Strong glow
		poly.polygon = PackedVector2Array([
			Vector2(15, 0),
			Vector2(-5, 10),
			Vector2(-10, 0),
			Vector2(-5, -10)
		])

func _physics_process(delta: float):
	if is_dying or not player or not is_instance_valid(player): return
	
	match current_state:
		State.APPROACH:
			var to_player = player.global_position - global_position
			if to_player.length() <= stop_distance:
				current_state = State.SHOOT
				velocity = Vector2.ZERO
			else:
				velocity = to_player.normalized() * speed
			rotation = velocity.angle() if velocity.length() > 0 else to_player.angle()
			
		State.SHOOT:
			rotation = (player.global_position - global_position).angle()
			fire_timer -= delta
			if fire_timer <= 0:
				fire_shot()
				shots_fired += 1
				if shots_fired >= max_shots:
					current_state = State.LEAVE
					leave_direction = (global_position - player.global_position).normalized()
					if leave_direction == Vector2.ZERO: leave_direction = Vector2.UP.rotated(randf() * TAU)
				else:
					fire_timer = 1.2 # Delay between burst shots
			
		State.LEAVE:
			velocity = leave_direction * speed
			rotation = velocity.angle()
			if global_position.distance_to(player.global_position) > 1000:
				queue_free()

	move_and_slide()

func fire_shot():
	if not player: return
	fire_bullet((player.global_position - global_position).normalized(), 300.0, damage, Color(1.0, 0.9, 0.0))
