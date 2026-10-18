extends Node2D
## One-shot burst of glowing shards plus a core flash, drawn from a single node.

var color: Color = Color.WHITE
var shard_count: int = 14
var speed: float = 380.0
var shard_size: float = 9.0
var lifetime: float = 0.75

var _age: float = 0.0
var _pos: PackedVector2Array
var _vel: PackedVector2Array
var _rot: PackedFloat32Array
var _spin: PackedFloat32Array
var _scale: PackedFloat32Array

func _ready():
	material = Neon.additive_material()
	z_index = 5
	for i in shard_count:
		var a := randf() * TAU
		_pos.append(Vector2.ZERO)
		_vel.append(Vector2.from_angle(a) * speed * randf_range(0.3, 1.0))
		_rot.append(randf() * TAU)
		_spin.append(randf_range(-12.0, 12.0))
		_scale.append(randf_range(0.5, 1.4))

func _process(delta: float):
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var drag := exp(-3.2 * delta)
	for i in shard_count:
		_pos[i] += _vel[i] * delta
		_vel[i] *= drag
		_rot[i] += _spin[i] * delta
	queue_redraw()

func _draw():
	var t := _age / lifetime
	var fade := 1.0 - t
	# Core flash
	var flash := maxf(0.0, 1.0 - _age / 0.12)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, shard_size * 3.0 * (1.0 + (1.0 - flash)), Color(1, 1, 1, flash * 0.5))
	var hot := color.lerp(Color.WHITE, 0.25 * fade)
	for i in shard_count:
		var s := shard_size * _scale[i] * (0.4 + 0.6 * fade)
		var pts := PackedVector2Array([
			Vector2(s, 0).rotated(_rot[i]),
			Vector2(-s * 0.6, s * 0.5).rotated(_rot[i]),
			Vector2(-s * 0.6, -s * 0.5).rotated(_rot[i]),
		])
		for k in 3:
			pts[k] += _pos[i]
		draw_colored_polygon(pts, Color(hot.r, hot.g, hot.b, fade * 0.9))
