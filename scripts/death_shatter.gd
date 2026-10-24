class_name DeathShatter
extends Node2D
## The player's death: the polygon splits along its edges into glowing shards that tumble
## outward, trailed by sparks, with a white flash and two rings. Keeps running while the
## tree is paused (the run-end screen pauses the game) and frees itself.

const DURATION := 2.2

var polygon: PackedVector2Array = PackedVector2Array()
var color: Color = Color(0.0, 0.8, 1.0)
var spin_base: float = 0.0

var _age := 0.0
var _shards: Array = [] # {pts: PackedVector2Array (local to centre), pos, vel, rot, spin}
var _sparks: Array = [] # {pos, vel, life}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	material = Neon.additive_material()
	z_index = 8
	var n := polygon.size()
	if n < 3:
		polygon = PackedVector2Array([Vector2(25, 0), Vector2(-12, 21), Vector2(-12, -21)])
		n = 3
	var centre := Vector2.ZERO
	for p in polygon:
		centre += p
	centre /= float(n)
	# One triangular shard per edge (centre + edge). A circle has 32 edges: pair them up.
	var step := 2 if n > 12 else 1
	var i := 0
	while i < n:
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + step) % n]
		var mid := (a + b) * 0.5
		var out := (mid - centre).normalized()
		_shards.append({
			"pts": PackedVector2Array([a - mid, b - mid, (centre - mid) * 0.6]),
			"pos": mid,
			"vel": out * randf_range(260.0, 520.0) + Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			"rot": 0.0,
			"spin": randf_range(-9.0, 9.0) + spin_base,
		})
		i += step
	for k in 46:
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(160.0, 780.0),
			"life": randf_range(0.5, 1.3),
		})
	# Two rings, the second one late
	VFX.shockwave(global_position, 2.4, color, 520.0)
	get_tree().create_timer(0.18, true, false, true).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			VFX.shockwave(global_position, 1.4, Color.WHITE, 340.0))

func _process(delta: float):
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	var drag := exp(-2.6 * delta)
	for s in _shards:
		s["pos"] += s["vel"] * delta
		s["vel"] *= drag
		s["rot"] += s["spin"] * delta
		s["spin"] *= exp(-1.2 * delta)
	for sp in _sparks:
		sp["pos"] += sp["vel"] * delta
		sp["vel"] *= exp(-3.0 * delta)
	queue_redraw()

func _draw():
	var t := _age / DURATION
	var fade := clampf(1.0 - t * t, 0.0, 1.0)
	# Opening flash
	var flash := maxf(0.0, 1.0 - _age / 0.22)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 90.0 + 220.0 * (1.0 - flash), Color(color.r, color.g, color.b, flash * 0.3))
		draw_circle(Vector2.ZERO, 50.0 + 90.0 * (1.0 - flash), Color(1, 1, 1, flash * 0.7))
	for s in _shards:
		var pts: PackedVector2Array = s["pts"]
		var xf := Transform2D(s["rot"], s["pos"])
		var world := xf * pts
		draw_colored_polygon(world, Color(color.r, color.g, color.b, 0.35 * fade))
		var edge := Color(0.75 + 0.25 * color.r, 0.85, 1.0, fade)
		draw_polyline(PackedVector2Array([world[0], world[1], world[2], world[0]]), edge, 2.5 * (1.0 - t * 0.6), true)
	for sp in _sparks:
		var life: float = sp["life"]
		if _age >= life:
			continue
		var k := 1.0 - _age / life
		var v: Vector2 = sp["vel"]
		draw_line(sp["pos"], sp["pos"] - v * 0.05, Color(color.r, color.g, color.b, k), 2.0 * k + 0.5)
