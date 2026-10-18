class_name UpgradeIcon
extends Control
## Vector icons for upgrades, drawn in the game's neon style (no textures).
## Shapes live in a -1..1 box and are scaled to the control size.

var icon_id: String = "speed"
var color: Color = Color(0.0, 0.85, 1.0)

var _strokes: Array = [] # {pts, closed, fill, alpha, width}

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)

func set_icon(id: String, col: Color) -> UpgradeIcon:
	icon_id = id
	color = col
	_strokes = _build(id)
	queue_redraw()
	return self

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

# ------------------------------------------------------------------ drawing

func _draw():
	var half := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	# Plate: dark hexagon with a faint rim so every icon sits on the same base
	var plate := PackedVector2Array()
	for i in 6:
		plate.append(c + Vector2(half * 0.98, 0).rotated(TAU / 6.0 * i + PI / 6.0))
	draw_colored_polygon(plate, Color(color.r * 0.07, color.g * 0.07, color.b * 0.1, 0.85))
	var rim := plate.duplicate()
	rim.append(plate[0])
	draw_polyline(rim, Color(color.r, color.g, color.b, 0.35), maxf(1.5, half * 0.025), true)

	var scale_px := half * 0.66
	var core_w := maxf(2.0, half * 0.055)
	var hot := color.lerp(Color.WHITE, 0.3)
	for s in _strokes:
		var pts := PackedVector2Array()
		for p in s["pts"]:
			pts.append(c + p * scale_px)
		var closed: bool = s["closed"]
		var a: float = s["alpha"]
		var w: float = core_w * float(s["width"])
		if closed and float(s["fill"]) > 0.0 and pts.size() >= 3:
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, float(s["fill"])))
		var line := pts.duplicate()
		if closed:
			line.append(pts[0])
		draw_polyline(line, Color(color.r, color.g, color.b, 0.12 * a), w * 2.8, true) # soft halo
		draw_polyline(line, Color(hot.r, hot.g, hot.b, a), w, true)

# ------------------------------------------------------------------ shape helpers

static func _s(pts: Array, closed: bool = false, fill: float = 0.0, alpha: float = 1.0, width: float = 1.0) -> Dictionary:
	return {"pts": PackedVector2Array(pts), "closed": closed, "fill": fill, "alpha": alpha, "width": width}

static func _arc_pts(center: Vector2, r: float, a0: float, a1: float, n: int = 20) -> Array:
	var out := []
	for i in n + 1:
		out.append(center + Vector2(r, 0).rotated(lerpf(a0, a1, float(i) / n)))
	return out

static func _circle(center: Vector2, r: float, fill: float = 0.0, alpha: float = 1.0, width: float = 1.0, n: int = 28) -> Dictionary:
	var pts := _arc_pts(center, r, 0.0, TAU, n)
	pts.pop_back()
	return _s(pts, true, fill, alpha, width)

static func _head(tip: Vector2, dir: Vector2, size: float = 0.28) -> Dictionary:
	var d := dir.normalized()
	var n := d.orthogonal()
	return _s([tip - d * size + n * size * 0.7, tip, tip - d * size - n * size * 0.7], false, 0.0, 1.0, 1.0)

static func _heart_pts() -> Array:
	var out := []
	for i in 40:
		var t := TAU / 40.0 * i
		out.append(Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) / 17.0)
	return out

static func _shield_pts(k: float = 1.0) -> Array:
	return [Vector2(0, -0.92), Vector2(0.78, -0.56), Vector2(0.68, 0.24), Vector2(0, 0.95), Vector2(-0.68, 0.24), Vector2(-0.78, -0.56)].map(func(p): return p * k)

static func _bolt() -> Array:
	return [Vector2(0.18, -0.95), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 0.95), Vector2(0.58, -0.22), Vector2(0.05, -0.22)]

static func _star(points: int, r_out: float, r_in: float, rot: float = 0.0) -> Array:
	var out := []
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		out.append(Vector2(r, 0).rotated(PI / points * i + rot))
	return out

# ------------------------------------------------------------------ icon library

static func _build(id: String) -> Array:
	var o: Array = []
	match id:
		"speed":
			for k in [-1, 0, 1]:
				var x: float = k * 0.46
				o.append(_s([Vector2(x - 0.4, -0.62), Vector2(x + 0.08, 0), Vector2(x - 0.4, 0.62)], false, 0.0, 1.0 - 0.0 * absf(k)))
		"damage", "sharp_edges":
			o.append(_s(_star(4, 0.98, 0.26), true, 0.22))
			o.append(_circle(Vector2.ZERO, 0.16, 0.5))
		"dash_charge":
			o.append(_s([Vector2(-0.75, -0.42), Vector2(0.4, -0.42), Vector2(0.4, 0.42), Vector2(-0.75, 0.42)], true, 0.1))
			o.append(_s([Vector2(0.4, -0.18), Vector2(0.7, -0.18), Vector2(0.7, 0.18), Vector2(0.4, 0.18)]))
			for i in 3:
				var x: float = -0.6 + i * 0.3
				o.append(_s([Vector2(x, -0.22), Vector2(x + 0.18, -0.22), Vector2(x + 0.18, 0.22), Vector2(x, 0.22)], true, 0.7))
		"dash_cooldown", "dash_mastery":
			o.append(_circle(Vector2(0, 0.12), 0.7))
			o.append(_s([Vector2(0, 0.12), Vector2(0, -0.4)]))
			o.append(_s([Vector2(0, 0.12), Vector2(0.3, 0.3)]))
			o.append(_s([Vector2(-0.14, -0.8), Vector2(0.14, -0.8)]))
			o.append(_s([Vector2(0, -0.8), Vector2(0, -0.58)]))
			if id == "dash_mastery":
				o.append(_s([Vector2(0.62, -0.62), Vector2(0.92, -0.62), Vector2(0.78, -0.36)], false))
		"fire_rate":
			for y in [-0.58, 0.0, 0.58]:
				o.append(_s([Vector2(-0.9, y), Vector2(-0.05, y)], false, 0.0, 0.55))
				o.append(_s([Vector2(-0.05, y - 0.17), Vector2(0.55, y - 0.17), Vector2(0.9, y), Vector2(0.55, y + 0.17), Vector2(-0.05, y + 0.17)], true, 0.35))
		"bounce":
			o.append(_s([Vector2(-0.85, 0.65), Vector2(-0.35, -0.55), Vector2(0.15, 0.65), Vector2(0.62, -0.2)]))
			o.append(_head(Vector2(0.62, -0.2), Vector2(0.45, -0.85)))
			o.append(_s([Vector2(-0.95, 0.8), Vector2(0.4, 0.8)], false, 0.0, 0.4))
		"max_hearts", "starting_hearts", "heal":
			var hp := _heart_pts().map(func(p): return p * 0.92)
			o.append(_s(hp, true, 0.18))
			if id == "heal":
				o.append(_s([Vector2(0, -0.28), Vector2(0, 0.38)]))
				o.append(_s([Vector2(-0.33, 0.05), Vector2(0.33, 0.05)]))
			elif id == "max_hearts":
				o.append(_s([Vector2(0.66, -0.9), Vector2(0.66, -0.4)], false, 0.0, 1.0, 0.9))
				o.append(_s([Vector2(0.41, -0.65), Vector2(0.91, -0.65)], false, 0.0, 1.0, 0.9))
			else:
				o.append(_s([Vector2(0, -0.2), Vector2(0, 0.35)]))
				o.append(_s([Vector2(-0.28, 0.08), Vector2(0.28, 0.08)]))
		"bullet_speed":
			o.append(_s([Vector2(-0.2, 0), Vector2(0.85, 0)]))
			o.append(_head(Vector2(0.9, 0), Vector2.RIGHT, 0.4))
			for y in [-0.5, 0.5]:
				o.append(_s([Vector2(-0.85, y), Vector2(-0.1, y)], false, 0.0, 0.6))
			o.append(_s([Vector2(-0.95, 0), Vector2(-0.45, 0)], false, 0.0, 0.5))
		"rotation_speed":
			o.append(_s(_arc_pts(Vector2.ZERO, 0.7, -2.4, 0.5)))
			o.append(_s(_arc_pts(Vector2.ZERO, 0.7, 0.74, 3.64)))
			o.append(_head(Vector2(0.7, 0).rotated(0.5), Vector2(0, 1).rotated(0.5), 0.3))
			o.append(_head(Vector2(0.7, 0).rotated(3.64), Vector2(0, 1).rotated(3.64), 0.3))
			o.append(_circle(Vector2.ZERO, 0.14, 0.6))
		"dash_lifesteal":
			var drop: Array = [Vector2(0, -0.95)]
			for i in 19:
				var a := deg_to_rad(-48.0 + 276.0 * float(i) / 18.0)
				drop.append(Vector2(cos(a), sin(a)) * 0.62 + Vector2(0, 0.25))
			o.append(_s(drop, true, 0.22))
			o.append(_s([Vector2(-0.18, 0.1), Vector2(0.0, 0.3), Vector2(0.22, -0.02)], false, 0.0, 0.8))
		"gravity_well":
			var sp: Array = []
			for i in 48:
				var t := float(i) / 47.0
				sp.append(Vector2(0.1 + 0.85 * t, 0).rotated(t * TAU * 2.6))
			o.append(_s(sp))
			o.append(_circle(Vector2.ZERO, 0.1, 0.9))
		"prismatic_beam":
			o.append(_s([Vector2(0.0, -0.62), Vector2(0.62, 0.5), Vector2(-0.62, 0.5)], true, 0.14))
			o.append(_s([Vector2(-0.95, 0.05), Vector2(-0.22, 0.05)], false, 0.0, 0.9))
			for y in [-0.55, -0.05, 0.45]:
				o.append(_s([Vector2(0.35, 0.18), Vector2(0.95, y)], false, 0.0, 0.7))
		"explosive":
			o.append(_circle(Vector2.ZERO, 0.3, 0.3))
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU / 8.0 * i)
				var r_out := 0.95 if i % 2 == 0 else 0.7
				o.append(_s([d * 0.5, d * r_out]))
		"pierce":
			for x in [-0.15, 0.3]:
				o.append(_s([Vector2(x, -0.62), Vector2(x, 0.62)], false, 0.0, 0.5))
			o.append(_s([Vector2(-0.95, 0), Vector2(0.75, 0)]))
			o.append(_head(Vector2(0.95, 0), Vector2.RIGHT, 0.4))
		"homing":
			o.append(_circle(Vector2.ZERO, 0.58, 0.0, 1.0))
			o.append(_circle(Vector2.ZERO, 0.12, 0.8))
			for i in 4:
				var d := Vector2.RIGHT.rotated(TAU / 4.0 * i)
				o.append(_s([d * 0.38, d * 0.95]))
		"dash_trail":
			o.append(_s([Vector2(0.2, -0.55), Vector2(0.78, 0), Vector2(0.2, 0.55)], false, 0.0, 1.0, 1.2))
			for i in 3:
				var x: float = -0.1 - i * 0.38
				o.append(_s([Vector2(x - 0.2, -0.3 + i * 0.07), Vector2(x, 0)], false, 0.0, 0.7 - i * 0.18))
				o.append(_s([Vector2(x - 0.2, 0.3 - i * 0.07), Vector2(x, 0)], false, 0.0, 0.7 - i * 0.18))
		"split":
			o.append(_s([Vector2(-0.95, 0), Vector2(-0.2, 0)]))
			o.append(_s([Vector2(-0.2, 0), Vector2(0.15, -0.55), Vector2(0.75, -0.55)]))
			o.append(_s([Vector2(-0.2, 0), Vector2(0.15, 0.55), Vector2(0.75, 0.55)]))
			o.append(_head(Vector2(0.95, -0.55), Vector2.RIGHT, 0.3))
			o.append(_head(Vector2(0.95, 0.55), Vector2.RIGHT, 0.3))
		"chain":
			o.append(_circle(Vector2(-0.62, 0.55), 0.2, 0.5))
			o.append(_circle(Vector2(0.62, -0.55), 0.2, 0.5))
			o.append(_s([Vector2(-0.5, 0.38), Vector2(-0.12, 0.05), Vector2(-0.22, -0.12), Vector2(0.18, -0.1), Vector2(0.05, -0.28), Vector2(0.5, -0.4)]))
		"blast_cleaning":
			for k in 3:
				o.append(_circle(Vector2.ZERO, 0.28 + k * 0.3, 0.0, 1.0 - k * 0.27))
			o.append(_circle(Vector2.ZERO, 0.08, 0.9))
		"energy_shield":
			o.append(_s(_shield_pts(), true, 0.16))
			o.append(_s(_shield_pts(0.55), true, 0.0, 0.5))
		"shield_regen":
			o.append(_s(_shield_pts(0.62), true, 0.16))
			o.append(_s(_arc_pts(Vector2.ZERO, 0.92, 0.5, 2.6), false, 0.0, 0.9))
			o.append(_s(_arc_pts(Vector2.ZERO, 0.92, 3.64, 5.74), false, 0.0, 0.9))
			o.append(_head(Vector2(0.92, 0).rotated(2.6), Vector2(0, 1).rotated(2.6), 0.24))
			o.append(_head(Vector2(0.92, 0).rotated(5.74), Vector2(0, 1).rotated(5.74), 0.24))
		"emergency_overdrive":
			o.append(_s(_bolt(), true, 0.25, 1.0, 1.1))
		"shard_multiplier":
			var gem: Array = [Vector2(-0.52, -0.38), Vector2(0, -0.85), Vector2(0.52, -0.38), Vector2(0.52, 0.1), Vector2(0, 0.88), Vector2(-0.52, 0.1)]
			o.append(_s(gem, true, 0.18))
			o.append(_s([Vector2(-0.52, -0.38), Vector2(0.52, -0.38)], false, 0.0, 0.6))
			o.append(_s([Vector2(-0.52, 0.1), Vector2(0, -0.38), Vector2(0.52, 0.1)], false, 0.0, 0.6))
			o.append(_s([Vector2(0, -0.38), Vector2(0, 0.88)], false, 0.0, 0.4))
		"repulsive_armor":
			o.append(_circle(Vector2.ZERO, 0.34, 0.2))
			for i in 4:
				var d := Vector2.RIGHT.rotated(TAU / 4.0 * i + PI / 4.0)
				o.append(_s([d * 0.55, d * 0.9]))
				o.append(_head(d * 0.98, d, 0.2))
		"dash_resistance":
			o.append(_s([Vector2(-0.48, -0.48), Vector2(0.48, -0.48), Vector2(0.48, 0.48), Vector2(-0.48, 0.48)], true, 0.14))
			for i in 3:
				var t: float = -0.28 + i * 0.28
				o.append(_s([Vector2(t, -0.48), Vector2(t, -0.82)], false, 0.0, 0.7))
				o.append(_s([Vector2(t, 0.48), Vector2(t, 0.82)], false, 0.0, 0.7))
				o.append(_s([Vector2(-0.48, t), Vector2(-0.82, t)], false, 0.0, 0.7))
				o.append(_s([Vector2(0.48, t), Vector2(0.82, t)], false, 0.0, 0.7))
			o.append(_s([Vector2(-0.16, -0.22), Vector2(0.14, 0), Vector2(-0.16, 0.22)], false, 0.0, 1.0, 1.1))
		_:
			# Unknown id: a hexagon so a missing icon is visible but never breaks the card
			o.append(_s(_star(6, 0.7, 0.7), true, 0.15))
	return o
