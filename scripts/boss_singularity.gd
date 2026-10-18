extends CharacterBody2D
## Boss 3 - SINGULARITY PROTOCOL. A violet void that blinks around the arena.
## Phase 1 SPIRAL:   rotating bullet spirals + telegraphed blinks.
## Phase 2 GRAVITY:  pulls the player in, gapped bullet rings, orbiting turrets.
## Phase 3 COLLAPSE: reversing dual spirals, stronger pull, detonating void pulses.
## Hearts (boss_pillar) deal the big damage, same as the other bosses.

@export var health: float = 45000.0
@export var max_health: float = 45000.0
@export var xp_value: int = 3000
@export var shard_reward: int = 500

const COLOR := Color(0.72, 0.3, 1.0)
const HOT := Color(1.0, 0.35, 0.85)
const PULSE_RADIUS := 480.0

var player: Node2D = null
var is_dying: bool = false
var phase: int = 1
var transitioning: bool = false
var heart_color: Color = COLOR
var border_radius: float = 1450.0
var arena_center: Vector2
var arena_barrier: StaticBody2D = null

var spiral_angle: float = 0.0
var spiral_dir: float = 1.0
var spiral_timer: float = 1.0
var ring_timer: float = 3.0
var turret_timer: float = 2.0
var blink_timer: float = 5.0
var pulse_timer: float = 6.0
var flip_timer: float = 3.0
var pillar_spawn_timer: float = 4.0
var spawn_timer: float = 3.0
var pulsing: bool = false
var blinking: bool = false
var pull_strength: float = 0.0

var chaser_scene = load("res://scenes/enemy.tscn")
var kamikaze_scene = load("res://scenes/enemy_kamikaze.tscn")
var shooter_scene = load("res://scenes/enemy_shooter.tscn")
var bullet_scene = load("res://scenes/bullet.tscn")

var satellites: Array[Polygon2D] = []
var gravity_ring: Line2D = null

@onready var poly = $Polygon2D
@onready var satellite_container = $Shields

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	arena_center = global_position
	if player:
		player.dash_nerf_active = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_dash_nerf_warning()
	setup_visuals()
	setup_arena_border()
	spawn_variety_enemies(6)

# ---------------------------------------------------------------- visuals

func _ring_points(radius: float, count: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		pts.append(Vector2(radius, 0).rotated(TAU / count * i))
	return pts

func setup_visuals():
	# Triangular void core
	var pts := PackedVector2Array()
	for i in range(3):
		pts.append(Vector2(95, 0).rotated(TAU / 3.0 * i - PI / 2.0))
	poly.polygon = pts
	poly.color = COLOR
	poly.modulate = Color.WHITE
	Neon.apply(poly, COLOR, 0.08, 7.0)
	Neon.add_glow(self, COLOR, 500.0, 0.1)

	# Inner singularity: bright dot with a ring
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

	# Orbiting turret satellites
	for i in range(3):
		var sat := Polygon2D.new()
		sat.polygon = PackedVector2Array([Vector2(22, 0), Vector2(0, 14), Vector2(-14, 0), Vector2(0, -14)])
		sat.position = Vector2(170, 0).rotated(TAU / 3.0 * i)
		sat.rotation = TAU / 3.0 * i
		satellite_container.add_child(sat)
		Neon.apply(sat, HOT, 0.3, 3.5)
		satellites.append(sat)

	# Gravity ring (visible once the pull starts)
	gravity_ring = Line2D.new()
	gravity_ring.points = _ring_points(700.0, 72)
	gravity_ring.closed = true
	gravity_ring.width = 3.0
	gravity_ring.default_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.0)
	gravity_ring.material = Neon.additive_material()
	add_child(gravity_ring)

	VFX.shockwave(global_position, 2.0, COLOR, 560.0)

func setup_arena_border():
	if get_tree().get_nodes_in_group("boss_arena").size() > 0:
		return
	# The border is a sibling (not a child) because this boss moves around inside it
	var border := Line2D.new()
	border.name = "ArenaBorder"
	border.add_to_group("boss_arena")
	var pts := _ring_points(border_radius, 64)
	pts.append(pts[0])
	border.points = pts
	border.width = 14.0
	border.default_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.7)
	border.material = Neon.additive_material()
	var rim := Line2D.new()
	rim.points = pts
	rim.width = 3.0
	rim.default_color = COLOR.lerp(Color.WHITE, 0.7)
	rim.material = Neon.additive_material()
	border.add_child(rim)
	get_parent().add_child.call_deferred(border)
	border.set_deferred("global_position", arena_center)

	var static_body := StaticBody2D.new()
	static_body.name = "Barrier"
	static_body.collision_layer = 1
	get_parent().add_child.call_deferred(static_body)
	static_body.set_deferred("global_position", arena_center)
	arena_barrier = static_body
	var segment_count := 16
	for i in range(segment_count):
		var coll := CollisionShape2D.new()
		var segment := SegmentShape2D.new()
		segment.a = Vector2(border_radius, 0).rotated(TAU / segment_count * i)
		segment.b = Vector2(border_radius, 0).rotated(TAU / segment_count * (i + 1))
		coll.shape = segment
		static_body.add_child(coll)

	var t_glow := create_tween().set_loops().bind_node(border)
	t_glow.tween_property(border, "default_color:a", 1.0, 0.6)
	t_glow.tween_property(border, "default_color:a", 0.45, 0.6)

# ---------------------------------------------------------------- main loop

func _physics_process(delta: float):
	if is_dying:
		return
	poly.rotation += (0.8 + phase * 0.5) * delta
	satellite_container.rotation -= (1.0 + phase * 0.6) * delta
	if not player or not is_instance_valid(player) or transitioning:
		return

	_apply_pull(delta)

	match phase:
		1: _phase_spiral(delta)
		2: _phase_gravity(delta)
		3: _phase_collapse(delta)

	# Blink around the arena (never mid-pulse)
	if not pulsing and not blinking:
		blink_timer -= delta
		if blink_timer <= 0.0:
			blink_timer = [6.0, 8.0, 4.5][phase - 1]
			blink()

	_hearts_and_minions(delta)

func _phase_spiral(delta: float):
	spiral_timer -= delta
	if spiral_timer <= 0.0:
		spiral_timer = 0.2
		_fire_spiral(3, 270.0)

func _phase_gravity(delta: float):
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

func _phase_collapse(delta: float):
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

func _apply_pull(_delta: float):
	pull_strength = [0.0, 120.0, 175.0][phase - 1] if phase > 1 else 0.0
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

# ---------------------------------------------------------------- attacks

func _fire_spiral(arms: int, speed: float):
	spiral_angle += 0.23 * spiral_dir
	for k in range(arms):
		spawn_boss_bullet(Vector2.RIGHT.rotated(spiral_angle + TAU / arms * k), speed)

func _fire_gapped_ring(count: int, speed: float):
	var aim := (player.global_position - global_position).angle()
	for i in range(count):
		var a := TAU / count * i
		if absf(angle_difference(a, aim)) < 0.42:
			continue # Safe lane toward the player
		spawn_boss_bullet(Vector2.RIGHT.rotated(a), speed, HOT)

func _fire_turrets():
	for sat in satellites:
		var origin := sat.global_position
		var dir := (player.global_position - origin).normalized()
		spawn_boss_bullet(dir, 430.0, HOT, origin, 2.0)
		var flash := Neon.add_glow(sat, HOT, 120.0, 0.8)
		var t := flash.create_tween()
		t.tween_property(flash, "modulate:a", 0.0, 0.25)
		t.tween_callback(flash.queue_free)

func spawn_boss_bullet(dir: Vector2, b_speed: float, color: Color = COLOR, origin: Vector2 = Vector2.INF, bullet_scale: float = 2.6):
	if not bullet_scene:
		return
	var b = bullet_scene.instantiate()
	b.fired_by_enemy = true
	b.direction = dir
	b.speed = b_speed
	b.damage = 10.0
	b.global_position = (global_position + dir * 90.0) if origin == Vector2.INF else origin
	get_parent().add_child(b)
	b.scale = Vector2(bullet_scale, bullet_scale)
	b.add_to_group("enemy_bullets")
	if b.has_node("BulletSprite"):
		b.get_node("BulletSprite").color = color

func blink():
	blinking = true
	var dest := _pick_blink_destination()
	# Telegraph: a ring appears where the boss will land
	VFX.shockwave(dest, 1.2, HOT, 220.0)
	AudioManager.play_sfx("glitch", 0.0, 1.0, 1.4)
	var t := create_tween().bind_node(self)
	t.tween_property(self, "modulate:a", 0.15, 0.55)
	t.tween_callback(func():
		global_position = dest
		VFX.shockwave(dest, 2.0, COLOR, 420.0)
		if player: player.add_shake(6.0))
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_callback(func(): blinking = false)

func _pick_blink_destination() -> Vector2:
	var dest := arena_center
	for i in range(12):
		dest = arena_center + Vector2(randf_range(0.0, border_radius - 350.0), 0).rotated(randf() * TAU)
		if not player or dest.distance_to(player.global_position) > 500.0:
			break
	return dest

func singularity_pulse():
	pulsing = true
	AudioManager.play_sfx("boss_spawn", 0.0, 0.7)
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
			player.take_damage(1)
		VFX.shockwave(global_position, 3.0, HOT, PULSE_RADIUS * 2.2)
		VFX.death_burst(global_position, HOT, 1.5)
		PostFX.kick(0.008)
		if player: player.add_shake(14.0)
		zone.queue_free()
		pulsing = false)

# ---------------------------------------------------------------- hearts & minions

func _hearts_and_minions(delta: float):
	var has_own_heart := false
	for h in get_tree().get_nodes_in_group("boss_hearts"):
		if h.get("boss") == self:
			has_own_heart = true
			break
	if not has_own_heart:
		pillar_spawn_timer -= delta
		if pillar_spawn_timer <= 0.0:
			spawn_pillar()
			pillar_spawn_timer = 2.5

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var cap: int = [8, 6, 5][phase - 1]
		if get_tree().get_nodes_in_group("boss_minions").size() < cap:
			spawn_variety_enemies(2 if phase < 3 else 3)
		spawn_timer = randf_range(4.0, 6.0)

func spawn_variety_enemies(count: int):
	for i in range(count):
		var spawn_pos := arena_center
		for attempt in range(10):
			spawn_pos = arena_center + Vector2(randf_range(400.0, border_radius - 150.0), 0).rotated(randf() * TAU)
			if not player or spawn_pos.distance_to(player.global_position) > 400.0:
				break
		var roll := randf()
		var scene = chaser_scene
		if roll > 0.75 and phase >= 2:
			scene = kamikaze_scene
		elif roll > 0.55:
			scene = shooter_scene
		var enemy = scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.add_to_group("boss_minions")
		if enemy.has_method("set_xp_value"):
			enemy.set_xp_value(1)

func spawn_pillar():
	var start_angle := randf() * TAU
	for i in range(3):
		var angle := start_angle + (TAU / 3.0) * i + randf_range(-0.25, 0.25)
		var dist := randf_range(border_radius * 0.35, border_radius - 200.0)
		var heart := Area2D.new()
		heart.set_script(load("res://scripts/boss_pillar.gd"))
		heart.set("boss", self)
		heart.set("heart_color", heart_color)
		get_parent().add_child(heart)
		heart.global_position = arena_center + Vector2(dist, 0).rotated(angle)
		VFX.shockwave(heart.global_position, 0.6, heart_color, 140.0)

# ---------------------------------------------------------------- damage & phases

func take_damage(amount: float):
	if is_dying or transitioning:
		return
	health -= amount

	if phase == 1 and health < max_health * 0.67:
		_enter_phase(2)
	elif phase == 2 and health < max_health * 0.34:
		_enter_phase(3)

	var t := create_tween()
	poly.modulate = Color(5, 5, 5, 1)
	t.tween_property(poly, "modulate", Color.WHITE, 0.1)

	if health <= 0.0:
		start_death_sequence()

func _enter_phase(new_phase: int):
	phase = new_phase
	transitioning = true
	pulsing = false
	# Wipe the field so the player gets a breath before the new pattern
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b):
			b.queue_free()
	for h in get_tree().get_nodes_in_group("boss_hearts"):
		if is_instance_valid(h) and h.get("boss") == self:
			h.queue_free()
	var col: Color = [COLOR, HOT, Color(1.0, 0.15, 0.3)][new_phase - 1]
	VFX.shockwave(global_position, 3.2, col, 900.0)
	VFX.hit_stop(0.1)
	PostFX.kick(0.012)
	if player: player.add_shake(18.0)
	AudioManager.play_sfx("boss_spawn", 2.0, 0.6)
	AudioManager.set_boss_music_mode(true, new_phase)
	Neon.apply(poly, col, 0.1, 7.0)
	if gravity_ring:
		create_tween().tween_property(gravity_ring, "default_color:a", 0.55, 1.0)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_phase"):
		hud.show_boss_phase(["", "", "PHASE 2: GRAVITY", "PHASE 3: COLLAPSE"][new_phase])
	# Brief invulnerable beat, then reset the attack timers
	var t := create_tween().bind_node(self)
	t.tween_interval(2.0)
	t.tween_callback(func():
		transitioning = false
		spiral_timer = 0.5
		ring_timer = 2.0
		turret_timer = 2.5
		pulse_timer = 5.0
		blink_timer = 3.0
		pillar_spawn_timer = 1.0)

func start_death_sequence():
	if is_dying:
		return
	is_dying = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and not e.is_in_group("bosses"):
			if e.has_method("spawn_death_particles"):
				e.spawn_death_particles()
			e.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b):
			b.queue_free()
	if gravity_ring:
		gravity_ring.queue_free()
	AudioManager.set_muffled(true)
	AudioManager.play_sfx("boss_spawn", 1.5, 0.5)

	var t := create_tween()
	for i in range(14):
		var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
		t.tween_callback(func():
			VFX.death_burst(global_position + offset, COLOR if randf() < 0.5 else HOT, 1.2)
			VFX.shockwave(global_position + offset, 0.8, HOT, 200.0)
			if player: player.add_shake(8.0)
			poly.modulate = Color(10, 10, 10, 1))
		t.tween_interval(0.1)
		t.tween_property(poly, "modulate", Color.WHITE, 0.05)
	t.tween_callback(die)

func die():
	AudioManager.set_muffled(false)
	AudioManager.play_sfx("enemy_death", 10.0, 0.3, 0.6)
	if player and player.has_method("add_shake"):
		player.add_shake(30.0)
	VFX.death_burst(global_position, COLOR, 3.5)
	VFX.shockwave(global_position, 3.5, HOT, 1100.0)
	VFX.hit_stop(0.14)
	PostFX.kick(0.014)

	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
	var gd = GlobalData
	gd.total_kills += 1
	gd.run_kills += 1
	gd.add_score(xp_value * 20, player.combo_count if player else 0)
	gd.add_shards(shard_reward)
	gd.save_game()

	if get_tree().get_nodes_in_group("bosses").size() <= 1:
		if is_instance_valid(arena_barrier):
			arena_barrier.queue_free()
		for b in get_tree().get_nodes_in_group("boss_arena"):
			b.queue_free()
	if player:
		player.dash_nerf_active = false
	for heart in get_tree().get_nodes_in_group("boss_hearts"):
		if is_instance_valid(heart) and heart.get("boss") == self:
			heart.queue_free()
	queue_free()
