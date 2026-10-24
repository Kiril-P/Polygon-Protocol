class_name ShapeGlyph
extends Control
## A regular polygon (or a circle for sides == 0) drawn as a glowing outline. Used by the
## shape tree and the deploy screen. Set `sides` and `color`, it redraws itself.

var sides: int = 0:
	set(v):
		sides = v
		queue_redraw()
var color: Color = Color(0.0, 0.85, 1.0):
	set(v):
		color = v
		queue_redraw()
var locked: bool = false:
	set(v):
		locked = v
		queue_redraw()

func _draw():
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.4
	var pts := PackedVector2Array()
	var n := 40 if sides <= 0 else sides
	for i in n:
		pts.append(c + Vector2(r, 0).rotated(TAU * i / n - PI / 2.0))
	var col := Color(0.35, 0.4, 0.5) if locked else color
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.14))
	pts.append(pts[0])
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.25), 9.0, true)
	draw_polyline(pts, col.lerp(Color.WHITE, 0.35), 3.0, true)
	if locked:
		var lock_c := c + Vector2(0, 2)
		draw_rect(Rect2(lock_c + Vector2(-9, -2), Vector2(18, 14)), Color(0.55, 0.6, 0.7), false, 2.0)
		draw_arc(lock_c + Vector2(0, -2), 6.0, PI, TAU, 12, Color(0.55, 0.6, 0.7), 2.0)
