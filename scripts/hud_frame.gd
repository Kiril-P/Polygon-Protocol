extends Control
## Decorative corner brackets that frame the playfield.

const MARGIN := 22.0
const ARM := 56.0
const COLOR := Color(0.0, 0.85, 1.0, 0.38)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw():
	var s := size
	var m := MARGIN
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var origin := Vector2(m + (s.x - 2.0 * m) * corner.x, m + (s.y - 2.0 * m) * corner.y)
		var dx := Vector2(ARM * (1.0 - 2.0 * corner.x), 0)
		var dy := Vector2(0, ARM * (1.0 - 2.0 * corner.y))
		draw_polyline(PackedVector2Array([origin + dy, origin, origin + dx]), COLOR, 3.0, true)
		draw_polyline(PackedVector2Array([origin + dy * 0.35 + dx * 0.0 + Vector2(10 * (1.0 - 2.0 * corner.x), 0), origin + Vector2(10 * (1.0 - 2.0 * corner.x), 10 * (1.0 - 2.0 * corner.y)), origin + dx * 0.35 + Vector2(0, 10 * (1.0 - 2.0 * corner.y))]), Color(COLOR, 0.18), 2.0, true)
