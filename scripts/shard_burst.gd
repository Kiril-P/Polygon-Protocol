extends Node2D
## One-shot burst drawn from a single node: tumbling glass shards with speed streaks,
## slow embers that linger and a white-hot core flash. Used for enemy deaths and the
## player's shatter (set `always_process` so it keeps playing under the death pause).

const MAX_LIVE := 16 # Past this many bursts at once, new ones shrink so swarms stay cheap
static var _live := 0

var color: Color = Color.WHITE
var shard_count: int = 14
var speed: float = 380.0
var shard_size: float = 9.0
var lifetime: float = 0.8
var ember_count: int = 6
var always_process: bool = false

var _age: float = 0.0
var _pos: PackedVector2Array
var _vel: PackedVector2Array
var _rot: PackedFloat32Array
var _spin: PackedFloat32Array
var _scale: PackedFloat32Array
var _len: PackedFloat32Array
var _epos: PackedVector2Array
var _evel: PackedVector2Array
var _ephase: PackedFloat32Array

func _ready():
	if always_process:
		process_mode = Node.PROCESS_MODE_ALWAYS
	material = Neon.additive_material()
	z_index = 5
	_live += 1
	if _live > MAX_LIVE:
		shard_count = maxi(shard_count / 2, 4)
		ember_count = 0
	for i in shard_count:
		var a := randf() * TAU
		_pos.append(Vector2.ZERO)
		_vel.append(Vector2.from_angle(a) * speed * randf_range(0.3, 1.0))
		_rot.append(a)
		_spin.append(randf_range(-10.0, 10.0))
		_scale.append(randf_range(0.5, 1.4))
		_len.append(randf_range(1.0, 2.2))
	for i in ember_count:
		_epos.append(Vector2.ZERO)
		_evel.append(Vector2.from_angle(randf() * TAU) * speed * randf_range(0.08, 0.35))
		_ephase.append(randf() * TAU)

func _exit_tree():
	_live = maxi(_live - 1, 0)

func _process(delta: float):
	_age += delta
	if _age >= lifetime * 1.5:
		queue_free()
		return
	var drag := exp(-3.2 * delta)
	for i in shard_count:
		_pos[i] += _vel[i] * delta
		_vel[i] *= drag
		_rot[i] += _spin[i] * delta
	var edrag := exp(-1.6 * delta)
	for i in ember_count:
		_epos[i] += _evel[i] * delta
		_evel[i] *= edrag
	queue_redraw()

func _draw():
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var fade := 1.0 - t
	# Core flash: white-hot, then tinted
	var flash := maxf(0.0, 1.0 - _age / 0.14)
	if flash > 0.0:
		var r := shard_size * 3.2 * (1.0 + (1.0 - flash))
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, flash * 0.35))
		draw_circle(Vector2.ZERO, r * 0.55, Color(1, 1, 1, flash * 0.6))
	var hot := color.lerp(Color.WHITE, 0.3 * fade)
	if t < 1.0:
		for i in shard_count:
			var s := shard_size * _scale[i] * (0.4 + 0.6 * fade)
			var dir := Vector2.from_angle(_rot[i])
			var side := dir.orthogonal() * s * 0.32
			var head := _pos[i] + dir * s * _len[i]
			var tail := _pos[i] - dir * s * 0.5
			draw_colored_polygon(PackedVector2Array([head, _pos[i] + side, tail, _pos[i] - side]), Color(hot.r, hot.g, hot.b, fade * 0.95))
			# Speed streak behind a fast shard
			var v := _vel[i]
			if v.length() > 90.0:
				draw_line(_pos[i], _pos[i] - v * 0.045, Color(color.r, color.g, color.b, fade * 0.5), maxf(s * 0.22, 1.0))
	# Embers outlive the shards and twinkle
	var et := clampf(_age / (lifetime * 1.5), 0.0, 1.0)
	for i in ember_count:
		var tw := 0.55 + 0.45 * sin(_age * 26.0 + _ephase[i])
		var a := (1.0 - et) * tw
		draw_circle(_epos[i], shard_size * 0.22 * (1.0 - et * 0.6) + 0.8, Color(hot.r, hot.g, hot.b, a * 0.9))
