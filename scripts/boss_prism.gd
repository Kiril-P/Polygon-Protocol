extends BossBase
## Boss 4 - PRISM PROTOCOL. A golden hexagon in a hexagonal arena whose walls overload.
## A wall flashes amber for 1.4s, then turns live for 2.5s and hurts anything near it.
## Phase 1 REFRACT: aimed fans + one wall at a time (usually the one nearest you).
## Phase 2 SPECTRUM: rotating six-arm spiral, two opposite walls at once.
## Phase 3 OVERLOAD: every other wall at once, the safe set flips, faster fans.
## Hearts sit close to the walls, so reaching one means timing the overloads.

const COLOR := Color(1.0, 0.75, 0.2)
const HOT := Color(1.0, 0.95, 0.6)
const SPECTRUM := [Color(1.0, 0.3, 0.3), Color(1.0, 0.75, 0.2), Color(0.5, 1.0, 0.4), Color(0.3, 0.9, 1.0), Color(0.6, 0.4, 1.0), Color(1.0, 0.4, 0.9)]

var fan_timer: float = 2.0
var spiral_timer: float = 1.0
var spiral_angle: float = 0.0
var wall_timer: float = 4.0
var volley_timer: float = 3.0
var flip: int = 0

func _configure() -> void:
	boss_id = "prism"
	max_health = 60000.0
	xp_value = 5000
	shard_reward = 800
	heart_color = COLOR
	bullet_color = COLOR
	death_color = COLOR
	phase_names = ["", "", "PHASE 2: SPECTRUM", "PHASE 3: OVERLOAD"]
	transition_time = 1.5
	heart_first_delay = 4.0
	heart_respawn_delay = 2.5
	heart_range = Vector2(0.45, 0.95)
	heart_range_duo = Vector2(0.45, 0.95)
	minion_pool = [
		{"scene": load("res://scenes/enemy.tscn"), "weight": 0.4},
		{"scene": load("res://scenes/enemy_fairy.tscn"), "weight": 0.3},
		{"scene": load("res://scenes/enemy_aegis.tscn"), "weight": 0.2, "min_phase": 2},
		{"scene": load("res://scenes/enemy_sniper.tscn"), "weight": 0.1, "min_phase": 2},
	]
	minion_cap = [8, 6, 5]
	minion_burst = [2, 2, 2]
	minion_interval = Vector2(4.5, 6.5)
	minion_first_burst = 6
	death_flashes = 16

func _hex(radius: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2(radius, 0).rotated(TAU / 6.0 * i + rot))
	return pts

func _build_visuals() -> void:
	poly.polygon = _hex(90.0, PI / 6.0)
	poly.color = COLOR
	poly.modulate = Color.WHITE
	Neon.apply(poly, COLOR, 0.08, 7.0)
	Neon.add_glow(self, COLOR, 500.0, 0.1)
	var inner := Polygon2D.new()
	inner.polygon = _hex(34.0)
	inner.color = HOT
	poly.add_child(inner)
	Neon.apply(inner, HOT, 0.9, 3.0)
	# Six prism shards orbit the core, one per spectrum colour
	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(26, 0), Vector2(0, 12), Vector2(-12, 0), Vector2(0, -12)])
		shard.position = Vector2(165, 0).rotated(TAU / 6.0 * i)
		shard.rotation = TAU / 6.0 * i
		shield_container.add_child(shard)
		Neon.apply(shard, SPECTRUM[i], 0.35, 3.5)
	VFX.shockwave(global_position, 2.0, COLOR, 560.0)

func _idle_motion(delta: float) -> void:
	poly.rotation += (0.4 + phase * 0.25) * delta
	shield_container.rotation -= (0.9 + phase * 0.3) * delta

func _boss_process(delta: float) -> void:
	_fans(delta)
	if phase >= 2:
		spiral_timer -= delta
		if spiral_timer <= 0.0:
			spiral_timer = 0.55 if phase == 2 else 0.4
			_fire_spiral()
	volley_timer -= delta
	if volley_timer <= 0.0:
		volley_timer = [3.4, 3.0, 2.4][phase - 1]
		_fire_volley()
	wall_timer -= delta
	if wall_timer <= 0.0:
		wall_timer = [5.0, 5.5, 6.0][phase - 1]
		_overload_walls()

## Three-bullet fan aimed at the player.
func _fans(delta: float) -> void:
	fan_timer -= delta
	if fan_timer > 0.0:
		return
	fan_timer = [1.5, 1.3, 1.0][phase - 1]
	var dir := (player.global_position - global_position).normalized()
	for k in [-1, 0, 1]:
		spawn_boss_bullet(dir.rotated(k * 0.24), 380.0, HOT, Vector2.INF, 2.6)

func _fire_spiral() -> void:
	spiral_angle += 0.21
	for k in 6:
		spawn_boss_bullet(Vector2.RIGHT.rotated(spiral_angle + TAU / 6.0 * k), 240.0, SPECTRUM[k], Vector2.INF, 2.4)

## Six coloured bullets aimed where the player is now, fanned slightly so you must move.
func _fire_volley() -> void:
	var aim := (player.global_position - global_position).angle()
	for k in 6:
		spawn_boss_bullet(Vector2.RIGHT.rotated(aim + (k - 2.5) * 0.17), 330.0 + k * 12.0, SPECTRUM[k], Vector2.INF, 2.8)

func _overload_walls() -> void:
	if arena == null or arena.wall_count() == 0:
		return
	var n := arena.wall_count()
	var pick: Array = []
	match phase:
		1:
			pick = [_nearest_wall_to_player() if randf() < 0.6 else randi() % n]
		2:
			var a := _nearest_wall_to_player() if randf() < 0.6 else randi() % n
			pick = [a, a + n / 2]
		3:
			flip = 1 - flip
			pick = [flip, flip + 2, flip + 4]
	arena.overload_walls(pick, 1.4, 2.5)
	AudioManager.play_sfx("glitch", -2.0, 0.7, 0.9)

func _nearest_wall_to_player() -> int:
	var best := 0
	var best_d := INF
	var rel: Vector2 = player.global_position - arena.global_position
	for i in arena.wall_count():
		var d := rel.distance_to(arena.wall_mid(i))
		if d < best_d:
			best_d = d
			best = i
	return best

func _on_phase(new_phase: int) -> void:
	Neon.apply(poly, [COLOR, Color(1.0, 0.5, 0.15), Color(1.0, 0.2, 0.3)][new_phase - 1], 0.1, 7.0)

func _after_transition() -> void:
	fan_timer = 1.0
	spiral_timer = 1.0
	volley_timer = 2.5
	wall_timer = 3.0
