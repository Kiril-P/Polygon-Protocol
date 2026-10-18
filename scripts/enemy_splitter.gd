extends EnemyBase
## Bloated pentagon that bursts into fast shards when killed. Fine alone, a swarm when
## shot at range. Counters: Shockwave Kills (nova), explosions, arcs, piercing.

const SCENE_PATH := "res://scenes/enemy_splitter.tscn"
const SHARD_COUNT := 3

## 2 = parent, 1 = shard (set before add_child)
var tier: int = 2
var _burst: Vector2 = Vector2.ZERO # Outward kick a fresh shard decays out of
var _wobble: float = 0.0

func _init():
	enemy_id = "splitter"
	speed = 105.0
	health = 55.0
	damage = 10.0
	xp_value = 22
	death_particle_amount = 50
	death_particle_velocity = Vector2(150.0, 350.0)
	death_particle_size = Vector2(4.0, 9.0)
	death_shake = 5.0

func _ready():
	if tier <= 1:
		speed = 235.0
		health = 9.0
		xp_value = 4
		death_particle_amount = 14
		death_shake = 0.0
	super()
	if tier > 1:
		scale = Vector2(1.7, 1.7)
	else:
		scale = Vector2(0.75, 0.75)
	setup_visuals()
	apply_difficulty([0.0, 0.8, 1.0, 1.1, 1.2, 1.3], [0.0, 0.7, 1.0, 1.3, 1.7, 2.2])
	_wobble = randf() * TAU

func setup_visuals():
	if has_node("Polygon2D"):
		var poly: Polygon2D = $Polygon2D
		poly.color = Color(1.0, 0.55, 0.1) if tier > 1 else Color(1.0, 0.8, 0.25)
		var pts := PackedVector2Array()
		for i in 5:
			pts.append(Vector2(18, 0).rotated(TAU / 5.0 * i - PI / 2.0))
		poly.polygon = pts

func _physics_process(delta: float):
	rotation += (1.2 if tier > 1 else 4.0) * delta
	if not player or not is_instance_valid(player):
		return
	_wobble += delta * 3.0
	var dir := (player.global_position - global_position).normalized()
	if tier > 1:
		dir = dir.rotated(sin(_wobble) * 0.35) # Lumbering sway
	velocity = dir * speed + _burst
	_burst = _burst.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

func die():
	if is_dying:
		return
	if tier > 1:
		_spawn_shards.call_deferred(global_position, xp_value)
	super()

func _spawn_shards(origin: Vector2, parent_xp: int):
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var scene: PackedScene = load(SCENE_PATH)
	var base := randf() * TAU
	for i in SHARD_COUNT:
		var shard = scene.instantiate()
		shard.tier = 1
		shard.global_position = origin
		parent.add_child(shard)
		shard.set_xp_value(maxi(2, int(parent_xp / 5.0)))
		shard._burst = Vector2(520.0, 0).rotated(base + TAU / SHARD_COUNT * i)
