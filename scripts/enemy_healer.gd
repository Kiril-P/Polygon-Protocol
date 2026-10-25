extends EnemyBase
## Support unit: hangs back behind its allies and pulses healing into everything nearby.
## Kill it first. Counters: Corrupt Rounds (disrupt healing), arcs, seekers, burst damage.

const PULSE_INTERVAL := 2.4
const PULSE_WINDUP := 0.45
const PULSE_RADIUS := 260.0
const PULSE_HEAL_FRACTION := 0.3
const SAFE_DISTANCE := 300.0

var _pulse_timer: float = 1.5
var _winding_up: float = 0.0
var _pulse_color := Color(0.3, 1.0, 0.65)

func _init():
	enemy_id = "healer"
	speed = 125.0
	health = 34.0
	damage = 10.0
	xp_value = 30
	death_particle_amount = 40
	death_particle_velocity = Vector2(150.0, 330.0)
	death_particle_size = Vector2(4.0, 8.0)
	death_shake = 5.0
	play_hit_sfx = false

func _ready():
	super()
	scale = Vector2(1.2, 1.2)
	setup_visuals()
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.3], [0.0, 0.7, 1.0, 1.3, 1.7, 2.2])

func setup_visuals():
	if has_node("Polygon2D"):
		var poly: Polygon2D = $Polygon2D
		poly.color = _pulse_color
		# Plus sign
		var a := 8.0
		var b := 22.0
		poly.polygon = PackedVector2Array([
			Vector2(a, -b), Vector2(a, -a), Vector2(b, -a), Vector2(b, a), Vector2(a, a), Vector2(a, b),
			Vector2(-a, b), Vector2(-a, a), Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a), Vector2(-a, -b)])

func _allies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or e.is_in_group("bosses") or e.get("is_dying"):
			continue
		if "enemy_id" in e and e.enemy_id == "healer":
			continue
		if global_position.distance_to(e.global_position) <= 700.0:
			out.append(e)
	return out

func _physics_process(delta: float):
	if not player or not is_instance_valid(player):
		return
	rotation += 1.0 * delta
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var allies := _allies()
	var goal := global_position
	if allies.is_empty():
		# Nobody to heal: drift away from the player
		goal = global_position - to_player.normalized() * 200.0
	else:
		var centre := Vector2.ZERO
		for e in allies:
			centre += e.global_position
		centre /= allies.size()
		# Stand on the far side of the group from the player
		goal = centre + (centre - player.global_position).normalized() * 70.0
	var move_dir := (goal - global_position)
	if dist < SAFE_DISTANCE:
		move_dir = -to_player.normalized() * 2.0 + move_dir.normalized()
	velocity = move_dir.normalized() * speed if move_dir.length() > 20.0 else Vector2.ZERO
	move_and_slide()

	if _winding_up > 0.0:
		_winding_up -= delta
		if _winding_up <= 0.0:
			_pulse()
	else:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_winding_up = PULSE_WINDUP
			_pulse_timer = PULSE_INTERVAL
	var charge := 0.0 if _winding_up <= 0.0 else 1.0 - _winding_up / PULSE_WINDUP
	if is_instance_valid(neon_outline):
		var base := Color(0.85, 0.3, 1.0) if heal_block > 0.0 else _pulse_color
		neon_outline.default_color = base.lerp(Color.WHITE, charge * 0.8)
		neon_outline.width = 3.5 + 4.0 * charge

func _pulse():
	if is_dying:
		return
	if heal_block > 0.0:
		VFX.shockwave(global_position, 0.1, Color(0.85, 0.3, 1.0), 70.0) # Fizzle
		return
	var healed := 0
	for e in _allies():
		if global_position.distance_to(e.global_position) > PULSE_RADIUS:
			continue
		if e.has_method("heal") and e.heal(e.max_health * PULSE_HEAL_FRACTION) > 0.0:
			healed += 1
			_beam_to(e)
	VFX.shockwave(global_position, 0.15, _pulse_color, PULSE_RADIUS)
	if healed > 0:
		AudioManager.play_sfx("heal", -4.0, 1.0, 1.1)

func _beam_to(target: Node2D):
	var beam := Line2D.new()
	beam.top_level = true
	beam.width = 3.0
	beam.default_color = Color(_pulse_color.r, _pulse_color.g, _pulse_color.b, 0.8)
	beam.material = Neon.additive_material()
	beam.add_point(global_position)
	beam.add_point(target.global_position)
	get_parent().add_child(beam)
	var t := beam.create_tween()
	t.tween_property(beam, "modulate:a", 0.0, 0.3)
	t.tween_callback(beam.queue_free)
