extends EnemyBase
## Armoured hexagon with a rotating front shield. Bullets that hit the shield arc are
## absorbed, so you have to flank it, dash through it, or use area damage.
## Counters: Breaker Rounds (crack the shield), explosions, arcs, plasma, beams, dash.

const SHIELD_HALF_ARC := deg_to_rad(62.0)
const SHIELD_RADIUS := 34.0
const TURN_RATE := 1.35 # radians/s, slow enough to be outflanked

var shield_angle: float = 0.0
var _shield: Line2D
var _shield_glow: Line2D
var _flash: float = 0.0

func _init():
	enemy_id = "aegis"
	speed = 95.0
	health = 70.0
	damage = 10.0
	xp_value = 30
	death_particle_amount = 55
	death_particle_velocity = Vector2(150.0, 380.0)
	death_particle_size = Vector2(4.0, 9.0)
	death_shake = 6.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.25, 1.25)
	setup_visuals()
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.3], [0.0, 0.7, 1.0, 1.3, 1.7, 2.2])
	if player and is_instance_valid(player):
		shield_angle = (player.global_position - global_position).angle()
	_build_shield()

func setup_visuals():
	if has_node("Polygon2D"):
		var poly: Polygon2D = $Polygon2D
		poly.color = Color(0.2, 0.75, 1.0)
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(Vector2(22, 0).rotated(TAU / 6.0 * i))
		poly.polygon = pts

func _build_shield():
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(Vector2(SHIELD_RADIUS, 0).rotated(lerpf(-SHIELD_HALF_ARC, SHIELD_HALF_ARC, i / 16.0)))
	_shield_glow = Line2D.new()
	_shield_glow.top_level = false
	_shield_glow.points = pts
	_shield_glow.width = 13.0
	_shield_glow.default_color = Color(0.3, 0.85, 1.0, 0.22)
	_shield_glow.material = Neon.additive_material()
	_shield_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_shield_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_shield_glow)
	_shield = Line2D.new()
	_shield.points = pts
	_shield.width = 5.0
	_shield.default_color = Color(0.75, 0.97, 1.0, 0.95)
	_shield.material = Neon.additive_material()
	_shield.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_shield.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_shield)

func _physics_process(delta: float):
	if not player or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	shield_angle = rotate_toward(shield_angle, to_player.angle(), TURN_RATE * delta)
	# The body keeps its own rotation (cosmetic); the shield arcs are drawn in world orientation
	rotation = shield_angle
	velocity = to_player.normalized() * speed
	move_and_slide()
	_flash = maxf(_flash - delta * 5.0, 0.0)
	var a := 0.95 if _flash <= 0.0 else 1.0
	_shield.width = 5.0 + 5.0 * _flash
	_shield.default_color = Color(0.75, 0.97, 1.0).lerp(Color.WHITE, _flash)
	_shield.default_color.a = a

## True when a hit coming from world position `from` lands on the shield arc.
func shield_blocks(from: Vector2) -> bool:
	if is_dying:
		return false
	var to_hit := (from - global_position).angle()
	return absf(angle_difference(to_hit, shield_angle)) <= SHIELD_HALF_ARC

func hit_by_bullet(amount: float, bullet: Node) -> bool:
	if not shield_blocks(bullet.global_position):
		take_damage(amount)
		return false
	_flash = 1.0
	AudioManager.play_sfx("bullet_bounce", -4.0, 1.4, 1.8)
	var ring_pos: Vector2 = global_position + Vector2(SHIELD_RADIUS * scale.x, 0).rotated(shield_angle)
	VFX.shockwave(ring_pos, 0.1, Color(0.6, 0.95, 1.0), 40.0)
	if bullet.get("breaker"):
		var siege: bool = bullet.synergies.has("siege_breaker")
		take_damage(amount * (1.0 if siege else 0.6))
		return not siege # Siege Breaker rounds punch straight through
	return true
