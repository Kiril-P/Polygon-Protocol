class_name BossBase
extends CharacterBody2D
## Everything the bosses have in common: arena, dash nerf, hearts, minions, phases, bullets,
## chip-damage rules, death sequence and rewards. A boss script only describes what is
## unique to it: `_configure()` (numbers), `_build_visuals()`, `_boss_process(delta)` (attacks)
## and the optional hooks `_on_phase(n)`, `_after_transition()`, `_on_death_start()`.
##
## Damage model: hearts (boss_pillar.gd) do the real damage, nine of them kill any boss.
## Everything else (bullets, dashes, beams) is "chip": each hit is capped and chip alone can
## never take the boss below half a heart, so the last blow is always a heart.

const HEARTS_TO_KILL := 9
const CHIP_CAP := 0.0015 # Largest share of max HP a single non-heart hit can take
const BULLET_SCENE := preload("res://scenes/bullet.tscn")

@export var health: float = 10000.0
@export var max_health: float = 10000.0
@export var xp_value: int = 500
@export var shard_reward: int = 100

# Set in _configure()
var boss_id: String = ""
var boss_title: String = "CORRUPTED PROTOCOL"
var heart_color: Color = Color(1.0, 0.2, 0.4)
var bullet_color: Color = Color(1.0, 0.2, 0.2)
var phase_thresholds: Array = [0.67, 0.34] # Health fraction that starts phase 2, 3, ...
var phase_names: Array = ["", "", "PHASE 2", "PHASE 3"]
var transition_time: float = 1.2 # Invulnerable beat on a phase change (0 = none)
var heart_first_delay: float = 5.0
var heart_respawn_delay: float = 2.0
var heart_range: Vector2 = Vector2(0.5, 0.85) # Heart distance from the arena centre (fraction of the radius)
var heart_range_duo: Vector2 = Vector2(0.6, 0.85)
var minion_pool: Array = [] # [{scene, weight, min_phase}]
var minion_cap: Array = [10, 5, 5]
var minion_burst: Array = [3, 2, 2]
var minion_interval: Vector2 = Vector2(3.5, 5.5)
var minion_first_burst: int = 10
var death_flashes: int = 12
var death_color: Color = Color(1.0, 0.2, 0.35)
var score_mult: int = 20

var player: Node2D = null
var arena: BossArena = null
var arena_center: Vector2
var border_radius: float = BossArena.RING_RADIUS
var is_dying: bool = false
var transitioning: bool = false
var phase: int = 1
var hearts_popped: int = 0

var _heart_timer: float = 0.0
var _minion_timer: float = 2.0
var _loop: int = 0

@onready var poly: Polygon2D = $Polygon2D
@onready var shield_container: Node2D = $Shields

# ------------------------------------------------------------------ overridable hooks
func _configure() -> void: pass
func _build_visuals() -> void: pass
func _boss_process(_delta: float) -> void: pass
func _on_phase(_new_phase: int) -> void: pass
func _after_transition() -> void: pass
func _on_death_start() -> void: pass
func _idle_motion(_delta: float) -> void: pass

# ------------------------------------------------------------------ lifecycle
func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	_configure()
	var def := BossTable.get_def(boss_id)
	boss_title = def.get("title", boss_title)

	# Later fights of the endless boss loop hit harder and pay more
	_loop = int(get_meta("loop", 0))
	if _loop > 0:
		max_health *= 1.0 + 0.35 * _loop
		shard_reward = int(shard_reward * (1.0 + 0.5 * _loop))
		xp_value = int(xp_value * (1.0 + 0.5 * _loop))
	health = max_health

	arena = get_tree().get_first_node_in_group("boss_arena_node") as BossArena
	if arena == null:
		# The spawner normally builds the arena first; this is the fallback
		BossArena.ensure(get_parent(), global_position, def.get("arena", "ring"), def.get("color", heart_color))
	arena_center = arena.global_position if arena else global_position
	border_radius = arena.radius if arena else BossArena.RING_RADIUS

	if player:
		if not player.dash_nerf_active:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud:
				hud.show_dash_nerf_warning()
		player.dash_nerf_active = true

	_build_visuals()
	_heart_timer = heart_first_delay
	_minion_timer = randf_range(minion_interval.x, minion_interval.y)
	AudioManager.set_boss_music_mode(true, 1, boss_id)
	var n := _duo_factor()
	spawn_minions(maxi(int(minion_first_burst * n), 1) if minion_first_burst > 0 else 0)

func _physics_process(delta: float):
	if is_dying:
		return
	_idle_motion(delta)
	if not player or not is_instance_valid(player) or transitioning:
		return
	_boss_process(delta)
	_hearts_and_minions(delta)

func is_duo() -> bool:
	return get_tree().get_nodes_in_group("bosses").size() > 1

## 0.5 when two bosses share the arena, so a duo fight is not twice the minions.
func _duo_factor() -> float:
	return 0.5 if is_duo() else 1.0

# ------------------------------------------------------------------ hearts & minions
func _own_hearts() -> Array:
	var out: Array = []
	for h in get_tree().get_nodes_in_group("boss_hearts"):
		if is_instance_valid(h) and h.get("boss") == self and not h.get("is_dying"):
			out.append(h)
	return out

func _hearts_and_minions(delta: float):
	if _own_hearts().is_empty():
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			spawn_hearts()
			_heart_timer = heart_respawn_delay
	_minion_timer -= delta
	if _minion_timer <= 0.0:
		var i := clampi(phase - 1, 0, minion_cap.size() - 1)
		var cap := maxi(int(minion_cap[i] * _duo_factor()), 1)
		if get_tree().get_nodes_in_group("boss_minions").size() < cap:
			spawn_minions(maxi(int(minion_burst[clampi(phase - 1, 0, minion_burst.size() - 1)] * _duo_factor() + 0.5), 1))
		_minion_timer = randf_range(minion_interval.x, minion_interval.y)

func spawn_minions(count: int):
	if minion_pool.is_empty() or count <= 0:
		return
	var total := 0.0
	for m in minion_pool:
		if phase >= int(m.get("min_phase", 1)):
			total += float(m["weight"])
	for i in count:
		var pos: Vector2 = _minion_point()
		var roll := randf() * total
		var scene: PackedScene = minion_pool[0]["scene"]
		for m in minion_pool:
			if phase < int(m.get("min_phase", 1)):
				continue
			roll -= float(m["weight"])
			if roll <= 0.0:
				scene = m["scene"]
				break
		var enemy = scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = pos
		enemy.add_to_group("boss_minions")
		if enemy.has_method("set_xp_value"):
			enemy.set_xp_value(1) # Keeps boss fights from farming level-ups

func _minion_point() -> Vector2:
	var away: Vector2 = player.global_position if player else Vector2.INF
	if arena:
		return arena.random_point(away, 420.0, 170.0, 0.28)
	return global_position + Vector2(randf_range(400.0, border_radius - 170.0), 0).rotated(randf() * TAU)

## Three hearts, 120 degrees apart. Dash into one to hurt the boss.
func spawn_hearts():
	var rng := heart_range_duo if is_duo() else heart_range
	var inner: float = arena.inner_radius() if arena else border_radius
	var start_angle := randf() * TAU
	for i in 3:
		var angle := start_angle + (TAU / 3.0) * i + randf_range(-0.25, 0.25)
		var dist := randf_range(inner * rng.x, minf(inner * rng.y, inner - 150.0))
		var heart := Area2D.new()
		heart.set_script(load("res://scripts/boss_pillar.gd"))
		heart.set("boss", self)
		heart.set("heart_color", heart_color)
		get_parent().add_child(heart)
		heart.global_position = arena_center + Vector2(dist, 0).rotated(angle)
		VFX.shockwave(heart.global_position, 0.6, heart_color, 140.0)

func clear_own_hearts():
	for h in _own_hearts():
		h.queue_free()

# ------------------------------------------------------------------ bullets
func spawn_boss_bullet(dir: Vector2, b_speed: float, color: Color = Color(0, 0, 0, 0), origin: Vector2 = Vector2.INF, bullet_scale: float = 3.0):
	var b = BULLET_SCENE.instantiate()
	b.fired_by_enemy = true
	b.direction = dir
	b.speed = b_speed
	b.damage = 10.0
	b.global_position = (global_position + dir * 80.0) if origin == Vector2.INF else origin
	b.set_meta("source", boss_id.to_upper())
	get_parent().add_child(b)
	b.scale = Vector2(bullet_scale, bullet_scale)
	b.add_to_group("enemy_bullets")
	if b.has_node("BulletSprite"):
		b.get_node("BulletSprite").color = bullet_color if color.a == 0.0 else color

func spawn_ring(count: int, b_speed: float, angle_offset: float = 0.0, color: Color = Color(0, 0, 0, 0)):
	for i in count:
		spawn_boss_bullet(Vector2.RIGHT.rotated(TAU / count * i + angle_offset), b_speed, color)

# ------------------------------------------------------------------ damage & phases
## Chip damage (bullets, dashes, beams): capped per hit, and it can never finish the boss.
func take_damage(amount: float):
	if is_dying or transitioning:
		return
	var floor_hp := max_health / HEARTS_TO_KILL * 0.5
	var dealt := minf(amount, max_health * CHIP_CAP)
	health = maxf(health - dealt, minf(health, floor_hp))
	_after_damage()

## Called by boss_pillar.gd when the player dashes through a heart.
func heart_hit():
	if is_dying or transitioning:
		return
	hearts_popped += 1
	health -= max_health / HEARTS_TO_KILL
	if hearts_popped >= HEARTS_TO_KILL or health <= max_health * 0.001:
		health = 0.0
	_after_damage()

func _after_damage():
	var t := create_tween()
	poly.modulate = GameSettings.flash(Color(5, 5, 5, 1))
	t.tween_property(poly, "modulate", Color.WHITE, 0.1)
	if health <= 0.0:
		start_death_sequence()
	elif phase <= phase_thresholds.size() and health < max_health * float(phase_thresholds[phase - 1]):
		_enter_phase(phase + 1)

func _enter_phase(new_phase: int):
	phase = new_phase
	clear_own_hearts()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b):
			b.queue_free()
	var col: Color = death_color.lerp(heart_color, 0.5)
	VFX.shockwave(global_position, 3.0, col, 850.0)
	VFX.hit_stop(0.1)
	PostFX.kick(0.012)
	if player:
		player.add_shake(16.0)
	AudioManager.play_sfx("boss_phase")
	AudioManager.set_boss_music_mode(true, new_phase, boss_id)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_phase") and new_phase < phase_names.size():
		hud.show_boss_phase(str(phase_names[new_phase]), heart_color)
	_on_phase(new_phase)
	_heart_timer = 1.0
	if transition_time > 0.0:
		transitioning = true
		var t := create_tween().bind_node(self)
		t.tween_interval(transition_time)
		t.tween_callback(func():
			transitioning = false
			_after_transition())
	else:
		_after_transition()

# ------------------------------------------------------------------ death
func start_death_sequence():
	if is_dying:
		return
	is_dying = true
	_on_death_start()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and not e.is_in_group("bosses"):
			if e.has_method("spawn_death_particles"):
				e.spawn_death_particles()
			e.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b):
			b.queue_free()
	clear_own_hearts()
	AudioManager.set_muffled(true)
	AudioManager.play_sfx("boss_death")
	AudioManager.duck_music(10.0, 3.0, 1.5)

	var t := create_tween()
	for i in death_flashes:
		var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
		t.tween_callback(func():
			VFX.death_burst(global_position + offset, death_color if randf() < 0.5 else heart_color, 1.2)
			VFX.shockwave(global_position + offset, 0.8, heart_color, 200.0)
			if player:
				player.add_shake(8.0)
			poly.modulate = GameSettings.flash(Color(10, 10, 10, 1)))
		t.tween_interval(0.1)
		t.tween_property(poly, "modulate", Color.WHITE, 0.05)
	t.tween_callback(die)

func die():
	AudioManager.set_muffled(false)
	AudioManager.play_sfx("enemy_death_big", 0.0, 0.5, 0.6)
	if player and player.has_method("add_shake"):
		player.add_shake(30.0)
	VFX.death_burst(global_position, death_color, 3.2)
	VFX.shockwave(global_position, 3.2, heart_color, 1000.0)
	VFX.hit_stop(0.14)
	PostFX.kick(0.014)

	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
	var gd = GlobalData
	gd.total_kills += 1
	gd.run_kills += 1
	gd.bosses_killed += 1
	gd.add_score(xp_value * score_mult, player.combo_count if player else 0)
	gd.add_boss_shards(shard_reward)

	# The dash nerf stays on while another boss of this fight is still alive
	var others := 0
	for b in get_tree().get_nodes_in_group("bosses"):
		if b != self and is_instance_valid(b) and not b.get("is_dying"):
			others += 1
	if others == 0 and player:
		player.dash_nerf_active = false
	clear_own_hearts()
	queue_free()
