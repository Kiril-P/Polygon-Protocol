class_name TitleSequence
extends CanvasLayer
## Opening title: a polygon evolves side by side from a triangle to a circle, then the
## title slams in. Plays once per launch over the main menu. Any key or click skips it.

signal finished

const STEP_TIMES := [0.45, 0.72, 0.99, 1.26, 1.53, 1.8]
const SLAM_TIME := 2.1
const HOLD_UNTIL := 3.9
const END_TIME := 4.5
const SIDES := [3, 4, 5, 6, 8, 40]

var _t := 0.0
var _step := -1
var _slammed := false
var _done := false
var _skipping := false
var _canvas: Control
var _title_a: Label
var _title_b: Label
var _tag: Label
var _veil: ColorRect
var _flash: ColorRect
var _rings: Array = [] # {r, a}
var _sides := 3.0
var _radius := 0.0
var _rot := 0.0
var _gs: Node

func _ready():
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gs = get_node("/root/GameSettings")
	_veil = ColorRect.new()
	_veil.color = Color(0.008, 0.01, 0.03, 1.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_shape)
	add_child(_canvas)
	_title_a = _make_title("POLYGON", Color(0.0, 0.9, 1.0))
	_title_b = _make_title("PROTOCOL", Color(1.0, 0.15, 0.65))
	_tag = Label.new()
	_tag.text = "SURVIVE THE CORRUPTION"
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override("font_size", 28)
	_tag.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_tag.add_theme_constant_override("outline_size", 6)
	_tag.modulate.a = 0.0
	add_child(_tag)
	_flash = ColorRect.new()
	_flash.color = _gs.screen_flash_color()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)
	_layout()
	get_viewport().size_changed.connect(_layout)

func _make_title(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 132)
	NeonUI.style_title(l, color, 132)
	l.modulate.a = 0.0
	add_child(l)
	return l

func _layout():
	var vp := get_viewport().get_visible_rect().size
	for l in [_title_a, _title_b]:
		l.size = Vector2(vp.x, 160)
		l.pivot_offset = l.size / 2.0
	_title_a.position = Vector2(0, vp.y * 0.5 - 175)
	_title_b.position = Vector2(0, vp.y * 0.5 - 15)
	_tag.size = Vector2(vp.x, 40)
	_tag.position = Vector2(0, vp.y * 0.5 + 170)

func _unhandled_input(event: InputEvent):
	if _done or _skipping:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		_skip()

func _skip():
	_skipping = true
	if not _slammed:
		_t = HOLD_UNTIL - 0.2
		_slam(true)
	else:
		_t = maxf(_t, HOLD_UNTIL)

func _process(delta: float):
	if _done:
		return
	_t += delta
	_rot += delta * (0.6 + float(maxi(_step, 0)) * 0.5)
	while _step + 1 < STEP_TIMES.size() and _t >= STEP_TIMES[_step + 1] and not _skipping:
		_step += 1
		_next_step()
	_radius = lerpf(_radius, 150.0 + 14.0 * _step, clampf(delta * 8.0, 0.0, 1.0)) if _step >= 0 else 0.0
	for r in _rings:
		r["r"] += delta * 900.0
		r["a"] = maxf(r["a"] - delta * 1.8, 0.0)
	_rings = _rings.filter(func(r): return r["a"] > 0.0)
	if not _slammed and _t >= SLAM_TIME:
		_slam(false)
	if _slammed:
		_radius = lerpf(_radius, 0.0, clampf(delta * 5.0, 0.0, 1.0)) # Shape collapses into the title
	_tag.modulate.a = clampf((_t - (SLAM_TIME + 0.55)) / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - HOLD_UNTIL) / 0.4, 0.0, 1.0))
	_flash.modulate.a = maxf(_flash.modulate.a - delta * 3.0, 0.0)
	if _t >= HOLD_UNTIL:
		var k := clampf((_t - HOLD_UNTIL) / (END_TIME - HOLD_UNTIL), 0.0, 1.0)
		_veil.modulate.a = 1.0 - k
		_title_a.modulate.a = 1.0 - k
		_title_b.modulate.a = 1.0 - k
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if k >= 1.0:
			_finish()
	_canvas.queue_redraw()

func _next_step():
	var i := _step
	_sides = float(SIDES[i])
	_rings.append({"r": 40.0, "a": 0.9})
	var pitch := 1.0 + 0.1 * i
	get_node("/root/AudioManager").play_sfx("combo_tick", 4.0, pitch, pitch)
	if i == SIDES.size() - 1:
		get_node("/root/AudioManager").play_sfx("dash_ready", 0.0, 1.0, 1.0)

func _slam(quiet: bool):
	_slammed = true
	_rings.append({"r": 60.0, "a": 1.0})
	if not quiet:
		_flash.modulate.a = 0.9
		get_node("/root/AudioManager").play_sfx("level_up", 2.0, 0.85, 0.85)
		get_node("/root/AudioManager").play_sfx("boss_spawn", -6.0, 1.0, 1.0)
	var vp := get_viewport().get_visible_rect().size
	for pair in [[_title_a, -vp.x * 0.35], [_title_b, vp.x * 0.35]]:
		var l: Label = pair[0]
		l.modulate.a = 1.0
		l.scale = Vector2(1.45, 1.45)
		var home := l.position
		l.position = home + Vector2(pair[1], 0)
		var t := l.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(l, "position", home, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shake := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var amp: float = 16.0 * _gs.shake
	for i in 6:
		shake.tween_property(_canvas, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.03)
		amp *= 0.6
	shake.tween_property(_canvas, "position", Vector2.ZERO, 0.04)

func _draw_shape():
	var c := _canvas.size / 2.0
	var col := Color(0.0, 0.9, 1.0)
	if _slammed:
		col = col.lerp(Color(1.0, 0.15, 0.65), 0.6)
	for r in _rings:
		_canvas.draw_arc(c, r["r"], 0.0, TAU, 64, Color(col.r, col.g, col.b, r["a"] * 0.8), 3.0, true)
	if _radius > 2.0:
		var n := int(_sides)
		var pts := PackedVector2Array()
		for i in n:
			pts.append(c + Vector2(_radius, 0).rotated(_rot + TAU / n * i))
		pts.append(pts[0])
		var glow: float = _gs.glow
		_canvas.draw_polyline(pts, Color(col.r, col.g, col.b, 0.10 * glow), 26.0, true)
		_canvas.draw_polyline(pts, Color(col.r, col.g, col.b, 0.22 * glow), 12.0, true)
		_canvas.draw_polyline(pts, col.lerp(Color.WHITE, 0.45), 4.0, true)

func _finish():
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
