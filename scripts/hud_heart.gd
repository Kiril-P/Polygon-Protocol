class_name HudHeart
extends Control
## A single neon hexagon heart slot. Filled = alive, hollow = lost.

const RADIUS := 15.0

var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()

func _init():
	custom_minimum_size = Vector2(38, 38)
	pivot_offset = Vector2(19, 19)

func _draw():
	var center := size / 2.0
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(center + Vector2(RADIUS, 0).rotated(TAU / 6.0 * i + PI / 6.0))
	var outline := pts.duplicate()
	outline.append(pts[0])
	if filled:
		draw_circle(center, RADIUS * 1.7, Color(1.0, 0.1, 0.25, 0.14))
		draw_circle(center, RADIUS * 1.25, Color(1.0, 0.1, 0.25, 0.12))
		draw_colored_polygon(pts, Color(0.55, 0.03, 0.12, 0.9))
		draw_polyline(outline, Color(1.0, 0.45, 0.55), 3.0, true)
		# Bright inner core
		var core := PackedVector2Array()
		for p in pts:
			core.append(center + (p - center) * 0.45)
		draw_colored_polygon(core, Color(1.0, 0.35, 0.45, 0.95))
	else:
		draw_polyline(outline, Color(0.6, 0.15, 0.25, 0.45), 2.0, true)
