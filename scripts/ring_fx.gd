extends Node2D
## Expanding glowing ring (shockwave).

var color: Color = Color.CYAN
var max_radius: float = 220.0
var duration: float = 0.5
var thickness: float = 6.0

var _age: float = 0.0

func _ready():
	material = Neon.additive_material()
	z_index = 4

func _process(delta: float):
	_age += delta
	if _age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw():
	var t := clampf(_age / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var r := max_radius * eased
	var a := 1.0 - t
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, a * 0.8), thickness * (1.0 - t * 0.7), true)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(color.r, color.g, color.b, a * 0.2), thickness * 2.0 * (1.0 - t), true)
