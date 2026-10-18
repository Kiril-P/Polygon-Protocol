class_name AccessibilityMenu
extends CanvasLayer
## Accessibility & controls overlay: glow / shake sliders, reduced flash,
## colour palette, HUD size and key rebinding. Opens over the main menu or the
## pause menu (works while the tree is paused). Changes apply live.

var on_close: Callable
var gs: Node = Engine.get_main_loop().root.get_node("GameSettings")
var _preview: HudVitals
var _preview_home: Vector2
var _glow_label: Label
var _shake_label: Label
var _flash_btn: Button
var _palette_btn: Button
var _size_btn: Button
var _rumble_btn: Button
var _touch_btn: Button
var _key_buttons: Dictionary = {}
var _status: Label
var _capturing: String = ""
var _closing := false

func _sfx(sfx_name: String):
	get_node("/root/AudioManager").play_sfx(sfx_name)

static func open(host: Node, close_callback: Callable = Callable()) -> AccessibilityMenu:
	var m := AccessibilityMenu.new()
	m.on_close = close_callback
	host.add_child(m)
	return m

func _ready():
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	gs.modal_open += 1
	_build()
	_refresh()

func _build():
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", NeonUI.panel_style(NeonUI.CYAN, 0.92, 2, 12, 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "ACCESSIBILITY & CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(title, NeonUI.CYAN, 40)
	root.add_child(title)

	# Live preview of the HUD plate (reflects palette, size and shake)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(880, 210)
	root.add_child(holder)
	_preview = HudVitals.new()
	_preview.set_hearts(3, 5)
	_preview.set_energy(62.0, 100.0)
	_preview_home = Vector2((880.0 - HudVitals.PANEL_SIZE.x) / 2.0, 210.0 - HudVitals.PANEL_SIZE.y - 4.0)
	_preview.position = _preview_home
	holder.add_child(_preview)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	root.add_child(cols)

	# ---- Display column
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	left.add_child(_section_label("DISPLAY"))
	_glow_label = _slider_row(left, "GLOW", gs.glow, func(v):
		gs.set_glow(v)
		_refresh())
	_shake_label = _slider_row(left, "SCREEN SHAKE", gs.shake, func(v):
		gs.set_shake(v)
		_jitter()
		_refresh())
	_flash_btn = _button("", func():
		gs.set_reduced_flash(not gs.reduced_flash)
		_refresh())
	left.add_child(_flash_btn)
	_palette_btn = _button("", func():
		gs.set_palette(gs.palette + 1)
		_refresh())
	left.add_child(_palette_btn)
	_size_btn = _button("", func():
		gs.set_hud_size(gs.hud_size + 1)
		_refresh())
	left.add_child(_size_btn)
	_rumble_btn = _button("", func():
		gs.set_rumble(not gs.rumble)
		if gs.rumble:
			get_node("/root/PadNav").rumble(0.7, 0.7, 0.25)
		_refresh())
	left.add_child(_rumble_btn)
	_touch_btn = _button("", func():
		gs.cycle_touch_pref()
		_refresh())
	left.add_child(_touch_btn)

	# ---- Controls column
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(_section_label("KEY BINDINGS"))
	for action in gs.REBIND_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = gs.REBIND_ACTIONS[action]
		lbl.custom_minimum_size = Vector2(170, 0)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		row.add_child(lbl)
		var btn := _button("", func(): _begin_capture(action))
		btn.custom_minimum_size = Vector2(190, 40)
		row.add_child(btn)
		right.add_child(row)
		_key_buttons[action] = btn
	_status = Label.new()
	_status.text = "Click a key, then press the new one. ESC cancels. Controller: stick / D-pad + A, B to close."
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380, 40)
	right.add_child(_status)
	var reset_keys := _button("RESET KEYS", func():
		gs.reset_bindings()
		_status.text = "Keys reset to W A S D + SPACE."
		_refresh())
	right.add_child(reset_keys)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	root.add_child(footer)
	var reset_display := _button("RESET DISPLAY", func():
		gs.reset_display()
		_sync_sliders()
		_refresh())
	reset_display.custom_minimum_size = Vector2(240, 54)
	footer.add_child(reset_display)
	var close := _button("CLOSE", close_menu)
	close.custom_minimum_size = Vector2(240, 54)
	footer.add_child(close)

var _sliders: Array[HSlider] = []

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", NeonUI.CYAN)
	return l

func _slider_row(parent: Control, caption: String, value: float, on_change: Callable) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	lbl.set_meta("caption", caption)
	box.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.5
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	NeonUI.style_slider(s)
	s.value_changed.connect(on_change)
	box.add_child(s)
	parent.add_child(box)
	_sliders.append(s)
	return lbl

func _sync_sliders():
	if _sliders.size() >= 2:
		_sliders[0].set_value_no_signal(gs.glow)
		_sliders[1].set_value_no_signal(gs.shake)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	NeonUI.style_button(b)
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	b.mouse_entered.connect(func(): _sfx("hover"))
	return b

func _refresh():
	_glow_label.text = "%s   %d%%" % [_glow_label.get_meta("caption"), roundi(gs.glow * 100.0)]
	_shake_label.text = "%s   %d%%" % [_shake_label.get_meta("caption"), roundi(gs.shake * 100.0)]
	_flash_btn.text = "REDUCED FLASH: " + ("ON" if gs.reduced_flash else "OFF")
	_palette_btn.text = "COLOURS: " + gs.pal()["name"]
	_size_btn.text = "HUD SIZE: " + gs.HUD_SIZES[gs.hud_size]["name"]
	_rumble_btn.text = "VIBRATION: " + ("ON" if gs.rumble else "OFF")
	_touch_btn.text = "TOUCH CONTROLS: " + ["AUTO", "ON", "OFF"][gs.touch_pref]
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = "PRESS A KEY..." if _capturing == action else gs.key_name(action)
		if _capturing == action:
			b.add_theme_color_override("font_color", NeonUI.GOLD)
		else:
			b.remove_theme_color_override("font_color")

## Wiggles the preview by the current shake strength so the slider is felt.
func _jitter():
	if gs.shake <= 0.0:
		return
	var amp: float = 14.0 * gs.shake
	var t := create_tween()
	for i in 4:
		t.tween_property(_preview, "position", _preview_home + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
		amp *= 0.6
	t.tween_property(_preview, "position", _preview_home, 0.05)

func _begin_capture(action: String):
	_capturing = action
	_status.text = "Press a key for %s (ESC to cancel)..." % gs.REBIND_ACTIONS[action]
	_refresh()

func _input(event: InputEvent):
	if _closing:
		return
	if _capturing != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				_capturing = ""
				_status.text = "Cancelled."
			else:
				var action := _capturing
				var other := ""
				for o in gs.REBIND_ACTIONS:
					if o != action and gs.key_for(o) == event.physical_keycode:
						other = gs.REBIND_ACTIONS[o]
				if gs.set_binding(action, event.physical_keycode):
					_status.text = "%s -> %s" % [gs.REBIND_ACTIONS[action], gs.key_name(action)]
					if other != "":
						_status.text += "   (swapped with %s)" % other
				else:
					_status.text = "That key is reserved."
				_capturing = ""
			_refresh()
		elif (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
			_capturing = ""
			_status.text = "Cancelled."
			_refresh()
		return
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START)):
		get_viewport().set_input_as_handled()
		close_menu()

func close_menu():
	if _closing:
		return
	_closing = true
	_sfx("click")
	if on_close.is_valid():
		on_close.call()
	# Keep the pause toggle blocked briefly so the ESC that closed us can't also unpause.
	var settings := gs   # captured locally: the lambda must not depend on this (freed) node
	get_tree().create_timer(0.2, true, false, true).timeout.connect(func():
		settings.modal_open = maxi(settings.modal_open - 1, 0))
	queue_free()
