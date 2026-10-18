class_name HudAlert
extends Control
## Screen-edge red pulse while the player is on their last heart, plus a
## brief flash when a heart is lost. Edges only, so the centre stays clear.

var low_hp := false
var _hit := 0.0
var _time := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func flash_hit():
	_hit = 0.5 if get_node("/root/GameSettings").reduced_flash else 1.0

func _process(delta: float):
	_time += delta
	_hit = maxf(_hit - delta * 2.5, 0.0)
	queue_redraw()

func _draw():
	var strength := _hit * 0.6
	if low_hp:
		strength = maxf(strength, 0.09 + 0.07 * sin(_time * 6.0))
	if strength <= 0.01:
		return
	var s := size
	var depth := 150.0
	var base := HudVitals.pc("alert")
	var c0 := Color(base.r, base.g, base.b, strength)
	var c1 := Color(base.r, base.g, base.b, 0.0)
	for e in 4:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		match e:
			0: pts = [Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, depth), Vector2(0, depth)]; cols = [c0, c0, c1, c1]
			1: pts = [Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, s.y - depth), Vector2(0, s.y - depth)]; cols = [c0, c0, c1, c1]
			2: pts = [Vector2(0, 0), Vector2(0, s.y), Vector2(depth, s.y), Vector2(depth, 0)]; cols = [c0, c0, c1, c1]
			3: pts = [Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - depth, s.y), Vector2(s.x - depth, 0)]; cols = [c0, c0, c1, c1]
		draw_polygon(pts, cols)
