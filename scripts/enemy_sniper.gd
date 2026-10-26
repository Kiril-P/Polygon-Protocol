extends EnemyBase
## Needle that keeps its distance, paints a laser, then fires one fast, heavy shot.
## The aim locks a moment before the shot: move (or dash) when the line flashes white.
## Counters: Deflector (reflects the shot back, hard), seekers and piercing to reach it.

const CHARGE_TIME := 1.25
const LOCK_AT := 0.8 # Seconds into the charge when the aim stops tracking
const BULLET_SPEED := 1100.0

@export var preferred_distance: float = 470.0
@export var cooldown: float = 3.6

var _state: int = 0 # 0 reposition, 1 charge
var _timer: float = 2.0
var _aim: Vector2 = Vector2.RIGHT
var _line: Line2D

func _init():
	enemy_id = "sniper"
	speed = 140.0
	health = 16.0
	damage = 10.0
	xp_value = 28
	death_particle_amount = 35
	death_particle_velocity = Vector2(150.0, 320.0)
	death_particle_size = Vector2(3.0, 7.0)
	death_shake = 4.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.3, 1.3)
	setup_visuals()
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.3], [0.0, 0.7, 1.0, 1.3, 1.7, 2.2])
	_timer = randf_range(1.5, 3.0)
	_line = Line2D.new()
	_line.top_level = true # World-space; freed with the sniper so it can never linger
	_line.width = 2.0
	_line.material = Neon.additive_material()
	_line.visible = false
	_line.z_index = 5
	add_child(_line)

func setup_visuals():
	if has_node("Polygon2D"):
		var poly: Polygon2D = $Polygon2D
		poly.color = Color(0.85, 0.3, 1.0)
		poly.polygon = PackedVector2Array([Vector2(26, 0), Vector2(-6, 8), Vector2(-14, 0), Vector2(-6, -8)])

func _physics_process(delta: float):
	if not player or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if _state == 1:
		_charge(delta, to_player)
		return
	rotation = lerp_angle(rotation, to_player.angle(), 6.0 * delta)
	var dir := to_player.normalized()
	if dist < preferred_distance - 70.0:
		velocity = -dir * speed
	elif dist > preferred_distance + 90.0:
		velocity = dir * speed * 0.8
	else:
		velocity = dir.rotated(PI / 2.0) * speed * 0.35
	move_and_slide()
	_timer -= delta
	if _timer <= 0.0 and dist < 900.0:
		_state = 1
		_timer = 0.0
		_aim = dir
		_line.visible = true
		AudioManager.play_sfx("glitch", -8.0, 1.0, 1.2)

func _charge(delta: float, to_player: Vector2):
	velocity = Vector2.ZERO
	_timer += delta
	if _timer < LOCK_AT:
		_aim = _aim.lerp(to_player.normalized(), clampf(delta * 7.0, 0.0, 1.0)).normalized()
	rotation = _aim.angle()
	var locked := _timer >= LOCK_AT
	var t := clampf(_timer / CHARGE_TIME, 0.0, 1.0)
	var col := Color(1.0, 1.0, 1.0, 0.95) if locked else Color(0.85, 0.3, 1.0, 0.35 + 0.4 * t)
	_line.default_color = col
	_line.width = (6.0 if locked else 2.0 + 2.0 * t)
	_line.clear_points()
	_line.add_point(global_position)
	_line.add_point(global_position + _aim * 1500.0)
	if _timer >= CHARGE_TIME:
		fire_bullet(_aim, BULLET_SPEED, damage, Color(1.0, 0.45, 1.0), 1.6, 34.0)
		_mark_last_bullet()
		_line.visible = false
		_state = 0
		_timer = cooldown * randf_range(0.85, 1.2)

## Tags the shot so a Deflector can send it back with interest.
func _mark_last_bullet():
	var bullets := get_tree().get_nodes_in_group("enemy_bullets")
	if not bullets.is_empty():
		bullets[bullets.size() - 1].set_meta("sniper", true)
