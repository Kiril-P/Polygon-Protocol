class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (and the web build on them): a floating move stick
## anywhere on the left half of the screen, a hold-to-dash button bottom right and a pause
## button top right. They drive the same input actions as keyboard and pad, so the player
## script needs no special cases. Only shown while touch mode is on.

const STICK_RADIUS := 120.0
const DEADZONE := 0.16
const DASH_RADIUS := 100.0
const PAUSE_RADIUS := 44.0
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var _view: Control
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _dash_finger := -1
var _pad: Node = Engine.get_main_loop().root.get_node("PadNav")

func _ready():
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_controls)
	add_child(_view)
	_pad.touch_changed.connect(func(_on): _sync())
	_sync()

func _exit_tree():
	_release_all()

func _sync():
	visible = _pad.touch_on()
	if not visible:
		_release_all()

func _size() -> Vector2:
	return _view.size

func _dash_center() -> Vector2:
	return Vector2(_size().x - 170.0, _size().y - 190.0)

func _pause_center() -> Vector2:
	return Vector2(_size().x - 70.0, 70.0)

func _process(_delta: float):
	if visible and get_tree().paused and (_stick_finger != -1 or _dash_finger != -1):
		_release_all()
	# Pause, level-up and death screens bring their own tappable UI
	_view.visible = not get_tree().paused
	if visible:
		_view.queue_redraw()

func _input(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed and not visible:
		_pad.note_touch() # the overlay is ahead of PadNav in input order, so tell it ourselves
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.index, event.position)
		else:
			_end(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_move_stick(event.position)

func _begin(index: int, pos: Vector2):
	if pos.distance_to(_pause_center()) <= PAUSE_RADIUS * 1.5:
		_tap_pause()
		return
	if _dash_finger == -1 and pos.distance_to(_dash_center()) <= DASH_RADIUS * 1.3:
		_dash_finger = index
		Input.action_press("dash")
		return
	if _stick_finger == -1 and pos.x < _size().x * 0.55:
		_stick_finger = index
		_stick_origin = pos
		_move_stick(pos)

func _end(index: int):
	if index == _stick_finger:
		_stick_finger = -1
		_stick_vec = Vector2.ZERO
		_apply_move()
	elif index == _dash_finger:
		_dash_finger = -1
		Input.action_release("dash")

func _move_stick(pos: Vector2):
	var d := (pos - _stick_origin) / STICK_RADIUS
	if d.length() > 1.0:
		# Drag the anchor along so reversing direction never needs a long swipe back
		_stick_origin = pos - d.normalized() * STICK_RADIUS
		d = d.normalized()
	_stick_vec = d if d.length() > DEADZONE else Vector2.ZERO
	_apply_move()

func _apply_move():
	var v := _stick_vec
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_up", maxf(-v.y, 0.0))
	_set_axis("move_down", maxf(v.y, 0.0))

func _set_axis(action: String, strength: float):
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_all():
	_stick_finger = -1
	_dash_finger = -1
	_stick_vec = Vector2.ZERO
	for a in MOVE_ACTIONS:
		Input.action_release(a)
	Input.action_release("dash")

func _tap_pause():
	Input.action_press("ui_cancel")
	get_tree().create_timer(0.1, true, false, true).timeout.connect(func():
		Input.action_release("ui_cancel"))

func _draw_controls():
	var cyan := Color(0.0, 0.9, 1.0)
	# Stick: faint hint ring when idle, anchored ring + knob while dragging
	var base := _stick_origin if _stick_finger != -1 else Vector2(210.0, _size().y - 210.0)
	var active := _stick_finger != -1
	_view.draw_circle(base, STICK_RADIUS, Color(0.02, 0.05, 0.1, 0.35 if active else 0.18))
	_view.draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(cyan.r, cyan.g, cyan.b, 0.7 if active else 0.3), 3.0, true)
	var knob := base + _stick_vec * STICK_RADIUS * 0.8
	_view.draw_circle(knob, 46.0, Color(cyan.r, cyan.g, cyan.b, 0.55 if active else 0.22))
	_view.draw_arc(knob, 46.0, 0.0, TAU, 32, Color(0.85, 1.0, 1.0, 0.9 if active else 0.4), 3.0, true)
	# Dash button
	var dc := _dash_center()
	var held := _dash_finger != -1
	_view.draw_circle(dc, DASH_RADIUS, Color(0.0, 0.25, 0.3, 0.6) if held else Color(0.02, 0.05, 0.1, 0.4))
	_view.draw_arc(dc, DASH_RADIUS, 0.0, TAU, 48, Color(cyan.r, cyan.g, cyan.b, 1.0 if held else 0.6), 4.0, true)
	for k in 2:
		var o := Vector2(k * 26.0 - 13.0, 0.0)
		_view.draw_polyline(PackedVector2Array([dc + o + Vector2(-14, -26), dc + o + Vector2(10, 0), dc + o + Vector2(-14, 26)]), Color(0.85, 1.0, 1.0, 0.95 if held else 0.7), 7.0, true)
	# Pause button
	var pc := _pause_center()
	_view.draw_circle(pc, PAUSE_RADIUS, Color(0.02, 0.05, 0.1, 0.45))
	_view.draw_arc(pc, PAUSE_RADIUS, 0.0, TAU, 32, Color(cyan.r, cyan.g, cyan.b, 0.55), 3.0, true)
	for dx in [-9.0, 9.0]:
		_view.draw_rect(Rect2(pc + Vector2(dx - 4.0, -14.0), Vector2(8.0, 28.0)), Color(0.85, 1.0, 1.0, 0.85))
