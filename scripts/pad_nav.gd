extends Node
## Controller support. Tracks whether the player is on a gamepad (for hints and rumble) and,
## while they are, keeps focus on a sensible control in whichever menu is open so the stick,
## D-pad and A button work everywhere without touching each menu script. Autoload: PadNav.

signal using_pad_changed(on: bool)

const AXIS_THRESHOLD := 0.55
const POLL_INTERVAL := 0.12

var using_pad := false
var _poll := 0.0
var _touched: Array = [] # Controls whose focus_mode we raised while on a pad

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent):
	if event is InputEventJoypadButton and event.pressed:
		_set_pad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > AXIS_THRESHOLD:
		_set_pad(true)
	elif using_pad and (event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 3.0)):
		_set_pad(false)

func _set_pad(on: bool):
	if on == using_pad:
		return
	using_pad = on
	if on:
		_poll = POLL_INTERVAL # focus straight away
	else:
		_release_focus()
	using_pad_changed.emit(on)

func _release_focus():
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()
	for c in _touched:
		if is_instance_valid(c):
			c.focus_mode = Control.FOCUS_NONE
	_touched.clear()

func _process(delta: float):
	if not using_pad:
		return
	_poll += delta
	if _poll < POLL_INTERVAL:
		return
	_poll = 0.0
	_ensure_focus()

## Menus hide the default focus box; borrow the hover look (or a cyan ring on sliders) so the
## controller always shows where it is.
func _style_focus(c: Control):
	if c is BaseButton:
		if c.get_theme_stylebox("focus") is StyleBoxEmpty:
			var look := c.get_theme_stylebox("hover").duplicate() as StyleBox
			if look is StyleBoxFlat:
				look.set_border_width_all(3)
				look.border_color = Color(0.85, 1.0, 1.0)
			c.add_theme_stylebox_override("focus", look)
	elif c is Slider:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_border_width_all(2)
		ring.border_color = Color(0.85, 1.0, 1.0, 0.9)
		ring.set_corner_radius_all(4)
		ring.set_expand_margin_all(4)
		c.add_theme_stylebox_override("focus", ring)

func _layer_of(c: Node) -> int:
	var n := c.get_parent()
	while n:
		if n is CanvasLayer:
			return n.layer
		n = n.get_parent()
	return 0

func _candidates() -> Array:
	var out: Array = []
	var root := get_tree().root
	for kind in ["BaseButton", "Slider"]:
		for c in root.find_children("*", kind, true, false):
			var ctl := c as Control
			if ctl == null or not ctl.is_visible_in_tree() or ctl.has_meta("no_pad") or ctl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			if ctl is BaseButton and ctl.disabled:
				continue
			if ctl is Slider and not ctl.editable:
				continue
			if _faded_out(ctl):
				continue
			out.append(ctl)
	return out

## True while the control sits inside something that is still fading in (e.g. under the title card).
func _faded_out(c: Node) -> bool:
	var n := c
	while n:
		if n is CanvasItem and n.modulate.a < 0.05:
			return true
		n = n.get_parent()
	return false

func _ensure_focus():
	var cands := _candidates()
	if cands.is_empty():
		return
	# The topmost layer wins, so an overlay always takes the controller from the screen below
	var top := -99999
	for c in cands:
		top = maxi(top, _layer_of(c))
	cands = cands.filter(func(c): return _layer_of(c) == top)
	for c in cands:
		if c.focus_mode == Control.FOCUS_NONE:
			c.focus_mode = Control.FOCUS_ALL
			_touched.append(c)
			_style_focus(c)
	var cur := get_viewport().gui_get_focus_owner()
	if cur != null and cur in cands:
		return
	cands.sort_custom(func(a, b):
		var pa: Vector2 = a.global_position
		var pb: Vector2 = b.global_position
		return pa.y < pb.y - 4.0 or (absf(pa.y - pb.y) <= 4.0 and pa.x < pb.x))
	var pick: Control = cands[0]
	for c in cands:
		if c.has_meta("pad_default"):
			pick = c
			break
	pick.grab_focus()

## Vibrates the active pad (no-op off a pad or when rumble is switched off).
func rumble(weak: float, strong: float, seconds: float):
	if not using_pad or not get_node("/root/GameSettings").rumble:
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	Input.start_joy_vibration(pads[0], weak, strong, seconds)
