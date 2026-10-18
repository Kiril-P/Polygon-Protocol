extends Node
## Global visual effects: shockwaves (ring + background grid ripple), shard bursts
## and hit-stop. Autoload name: VFX.

const MAX_WAVES := 12
const WAVE_LIFETIME := 2.2
const ShardBurst = preload("res://scripts/shard_burst.gd")
const RingFX = preload("res://scripts/ring_fx.gd")

var _waves: Array = [] # {pos: Vector2 (world), age: float, strength: float}
var _hit_stop_token: int = 0

func _process(delta: float):
	# Ages use unscaled time so ripples keep moving during hit-stop
	var real_delta := delta / maxf(Engine.time_scale, 0.05)
	for w in _waves:
		w["age"] += real_delta
	_waves = _waves.filter(func(w): return w["age"] < WAVE_LIFETIME)

## Shockwave: ripples the background grid and draws an expanding ring.
func shockwave(world_pos: Vector2, strength: float = 1.0, color: Color = Color(0.3, 0.9, 1.0), radius: float = 200.0):
	if _waves.size() >= MAX_WAVES:
		_waves.pop_front()
	_waves.append({"pos": world_pos, "age": 0.0, "strength": strength})
	var ring := RingFX.new()
	ring.color = color
	ring.max_radius = radius
	ring.duration = 0.35 + 0.12 * strength
	ring.thickness = 3.0 + 3.0 * strength
	_add(ring, world_pos)

## Burst of glowing shards, e.g. when an enemy dies.
func death_burst(world_pos: Vector2, color: Color, size: float = 1.0):
	var burst := ShardBurst.new()
	burst.color = color
	burst.shard_count = clampi(int(10 * size) + 4, 6, 30)
	burst.speed = 260.0 + 140.0 * size
	burst.shard_size = 6.0 + 4.0 * size
	_add(burst, world_pos)

## Freeze-frame for impact. Uses real time so it always ends.
func hit_stop(duration: float = 0.05):
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	_hit_stop_token += 1
	var token := _hit_stop_token
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		if token == _hit_stop_token:
			Engine.time_scale = 1.0)

## Packs live waves for the grid shader (canvas pixel coordinates).
func wave_uniform(canvas_xform: Transform2D) -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(MAX_WAVES)
	for i in _waves.size():
		var w: Dictionary = _waves[i]
		var px: Vector2 = canvas_xform * w["pos"]
		out[i] = Vector4(px.x, px.y, w["age"], w["strength"])
	return out

func _add(node: Node2D, world_pos: Vector2):
	var scene := get_tree().current_scene
	if not scene:
		node.queue_free()
		return
	scene.add_child(node)
	node.global_position = world_pos
