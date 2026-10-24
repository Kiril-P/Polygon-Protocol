extends BossBase
## Boss 3 - SINGULARITY PROTOCOL. A violet void that blinks around the arena.
## Phase 1 SPIRAL:   rotating bullet spirals + telegraphed blinks.
## Phase 2 GRAVITY:  pulls the player in, gapped bullet rings, orbiting turrets.
## Phase 3 COLLAPSE: reversing dual spirals, stronger pull, detonating void pulses.

const COLOR := Color(0.72, 0.3, 1.0)
const HOT := Color(1.0, 0.35, 0.85)
const PULSE_RADIUS := 480.0

var spiral_angle: float = 0.0
var spiral_dir: float = 1.0
var spiral_timer: float = 1.0
var ring_timer: float = 3.0
var turret_timer: float = 2.0
var blink_timer: float = 5.0
var pulse_timer: float = 6.0
var flip_timer: float = 3.0
var pulsing: bool = false
var blinking: bool = false
var pull_strength: float = 0.0

var satellites: Array[Polygon2D] = []
var gravity_ring: Line2D = null

func _configure() -> void:
	boss_id = "singularity"
	max_health = 45000.0
	xp_value = 3000
	shard_reward = 500
	heart_color = COLOR
	bullet_color = COLOR
	death_color = COLOR
	phase_names = ["", "", "PHASE 2: GRAVITY", "PHASE 3: COLLAPSE"]
	transition_time = 2.0
	heart_first_delay = 4.0
	heart_respawn_delay = 2.5
	heart_range = Vector2(0.35, 0.95)
	heart_range_duo = Vector2(0.35, 0.95)
	minion_pool = [
		{"scene": load("res://scenes/enemy.tscn"), "weight": 0.55},
		{"scene": load("res://scenes/enemy_shooter.tscn"), "weight": 0.2},
		{"scene": load("res://scenes/enemy_kamikaze.tscn"), "weight": 0.25, "min_phase": 2},
	]
	minion_cap = [8, 6, 5]
	minion_burst = [2, 2, 3]
	minion_interval = Vector2(4.0, 6.0)
	minion_first_burst = 6
	death_flashes = 14

func _ring_points(radius: float, count: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		pts.append(Vector2(radius, 0).rotated(TAU / count * i))
	return pts

func _build_visuals() -> void:
	var pts := PackedVector2Array()
	for i in 3:
		pts.append(Vector2(95, 0).rotated(TAU / 3.0 * i - PI / 2.0))
	poly.polygon = pts
	poly.color = COLOR
	poly.modulate = Color.WHITE
	Neon.apply(poly, COLOR, 0.08, 7.0)
	Neon.add_glow(self, COLOR, 500.0, 0.1)

	var inner := Polygon2D.new()
	inner.polygon = _ring_points(26, 20)
	inner.color = Color(1, 1, 1)
	poly.add_child(inner)
	Neon.apply(inner, HOT, 0.9, 3.0)
	var halo := Line2D.new()
	halo.points = _ring_points(48, 32)
	halo.closed = true
	halo.width = 2.5
	halo.default_color = HOT
	halo.material = Neon.additive_material()
	poly.add_child(halo)

	for i in 3:
		var sat := Polygon2D.new()
		sat.polygon = PackedVector2Array([Vector2(22, 0), Vector2(0, 14), Vector2(-14, 0), Vector2(0, -14)])
		sat.position = Vector2(170, 0).rotated(TAU / 3.0 * i)
		sat.rotation = TAU / 3.0 * i
		shield_container.add_child(sat)
		Neon.apply(sat, HOT, 0.3, 3.5)
		satellites.append(sat)

	gravity_ring = Line2D.new()
	gravity_ring.points = _ring_points(700.0, 72)
	gravity_ring.closed = true
	gravity_ring.width = 3.0
	gravity_ring.default_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.0)
	gravity_ring.material = Neon.additive_material()
	add_child(gravity_ring)
	VFX.shockwave(global_position, 2.0, COLOR, 560.0)

func _idle_motion(delta: float) -> void:
	poly.rotation += (0.8 + phase * 0.5) * delta
	shield_container.rotation -= (1.0 + phase * 0.6) * delta

func _boss_process(delta: float) -> void:
	_apply_pull()
	match phase:
		1: _phase_spiral(delta)
		2: _phase_gravity(delta)
		3: _phase_collapse(delta)
	if not pulsing and not blinking:
		blink_timer -= delta
		if blink_timer <= 0.0:
			blink_timer = [6.0, 8.0, 4.5][phase - 1]
			blink()

func _phase_spiral(delta: float) -> void:
	spiral_timer -= delta
	if spiral_timer <= 0.0:
		spiral_timer = 0.2
		_fire_spiral(3, 270.0)

func _phase_gravity(delta: float) -> void:
	spiral_timer -= delta
	if spiral_timer <= 0.0:
		spiral_timer = 0.28
		_fire_spiral(2, 250.0)
	ring_timer -= delta
	if ring_timer <= 0.0:
		ring_timer = 2.2
		_fire_gapped_ring(24, 320.0)
	turret_timer -= delta
	if turret_timer <= 0.0:
		turret_timer = 1.5
		_fire_turrets()

func _phase_collapse(delta: float) -> void:
	spiral_timer -= delta
	if spiral_timer <= 0.0:
		spiral_timer = 0.17
		_fire_spiral(4, 280.0)
	flip_timer -= delta
	if flip_timer <= 0.0:
		flip_timer = 3.0
		spiral_dir = -spiral_dir
	ring_timer -= delta
	if ring_timer <= 0.0:
		ring_timer = 1.7
		_fire_gapped_ring(28, 350.0)
	turret_timer -= delta
	if turret_timer <= 0.0:
		turret_timer = 1.1
		_fire_turrets()
	if not pulsing:
		pulse_timer -= delta
		if pulse_timer <= 0.0:
			pulse_timer = 6.5
			singularity_pulse()

func _apply_pull() -> void:
	pull_strength = [0.0, 120.0, 175.0][phase - 1]
	if pull_strength <= 0.0 or not "external_pull" in player:
		return
	var to := global_position - player.global_position
	var dist := to.length()
	if dist < 120.0 or dist > 1300.0:
		return
	var strength := pull_strength * clampf(1.25 - dist / 1300.0, 0.3, 1.0)
	if player.is_dashing:
		strength *= 0.3
	player.external_pull = to.normalized() * strength

func _fire_spiral(arms: int, speed: float) -> void:
	spiral_angle += 0.23 * spiral_dir
	for k in arms:
		spawn_boss_bullet(Vector2.RIGHT.rotated(spiral_angle + TAU / arms * k), speed, COLOR, Vector2.INF, 2.6)

func _fire_gapped_ring(count: int, speed: float) -> void:
	var aim := (player.global_position - global_position).angle()
	for i in count:
		var a := TAU / count * i
		if absf(angle_difference(a, aim)) < 0.42:
			continue # Safe lane toward the player
		spawn_boss_bullet(Vector2.RIGHT.rotated(a), speed, HOT, Vector2.INF, 2.6)

func _fire_turrets() -> void:
	for sat in satellites:
		var origin := sat.global_position
		var dir := (player.global_position - origin).normalized()
		spawn_boss_bullet(dir, 430.0, HOT, origin, 2.0)
		var flash := Neon.add_glow(sat, HOT, 120.0, 0.8)
		var t := flash.create_tween()
		t.tween_property(flash, "modulate:a", 0.0, 0.25)
		t.tween_callback(flash.queue_free)

func blink() -> void:
	blinking = true
	var dest := _pick_blink_destination()
	VFX.shockwave(dest, 1.2, HOT, 220.0)
	AudioManager.play_sfx("glitch", 0.0, 1.0, 1.4)
	var t := create_tween().bind_node(self)
	t.tween_property(self, "modulate:a", 0.15, 0.55)
	t.tween_callback(func():
		global_position = dest
		VFX.shockwave(dest, 2.0, COLOR, 420.0)
		if player:
			player.add_shake(6.0))
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_callback(func(): blinking = false)

func _pick_blink_destination() -> Vector2:
	var away: Vector2 = player.global_position if player else Vector2.INF
	return arena.random_point(away, 500.0, 350.0, 0.0) if arena else arena_center

func singularity_pulse() -> void:
	pulsing = true
	AudioManager.play_sfx("boss_phase", 0.0, 0.8, 0.85)
	var zone := Polygon2D.new()
	zone.polygon = _ring_points(PULSE_RADIUS, 40)
	zone.color = Color(HOT.r, HOT.g, HOT.b, 0.0)
	add_child(zone)
	var rim := Line2D.new()
	rim.points = zone.polygon
	rim.closed = true
	rim.width = 5.0
	rim.default_color = Color(HOT.r, HOT.g, HOT.b, 0.9)
	rim.material = Neon.additive_material()
	zone.add_child(rim)
	zone.scale = Vector2(0.2, 0.2)
	var t := create_tween().bind_node(self)
	t.tween_property(zone, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(zone, "color:a", 0.35, 1.2)
	t.tween_callback(func():
		if is_instance_valid(player) and player.global_position.distance_to(global_position) < PULSE_RADIUS:
			player.take_damage(1, "SINGULARITY")
		VFX.shockwave(global_position, 3.0, HOT, PULSE_RADIUS * 2.2)
		VFX.death_burst(global_position, HOT, 1.5)
		PostFX.kick(0.008)
		if player:
			player.add_shake(14.0)
		zone.queue_free()
		pulsing = false)

func _on_phase(new_phase: int) -> void:
	pulsing = false
	var col: Color = [COLOR, HOT, Color(1.0, 0.15, 0.3)][new_phase - 1]
	Neon.apply(poly, col, 0.1, 7.0)
	if gravity_ring:
		create_tween().tween_property(gravity_ring, "default_color:a", 0.55, 1.0)

func _after_transition() -> void:
	spiral_timer = 0.5
	ring_timer = 2.0
	turret_timer = 2.5
	pulse_timer = 5.0
	blink_timer = 3.0

func _on_death_start() -> void:
	if gravity_ring:
		gravity_ring.queue_free()
