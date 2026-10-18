class_name ProtocolMenu
extends CanvasLayer
## Pre-run screen: pick risk/reward protocols for a standard run, or play today's Daily
## Protocol (fixed modifiers and enemy order for everyone, scored on a daily board).

var on_deploy: Callable
var _mode: String = "standard"
var _picked: Array = []
var _body: VBoxContainer
var _desc: Label
var _mult: Label
var _mode_buttons: Dictionary = {}
var _deploy: Button
var _toggles: Dictionary = {}
var _closing := false

static func open(host: Node, deploy_callback: Callable) -> ProtocolMenu:
	var m := ProtocolMenu.new()
	m.on_deploy = deploy_callback
	host.add_child(m)
	return m

func _sfx(sfx_name: String):
	get_node("/root/AudioManager").play_sfx(sfx_name)

func _ready():
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gd = get_node("/root/GlobalData")
	_picked = gd.last_protocols.duplicate()
	_build()
	_refresh()
	_deploy.grab_focus.call_deferred()

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
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(900, 0)
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "SELECT PROTOCOL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(title, NeonUI.CYAN, 44)
	root.add_child(title)

	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 18)
	root.add_child(modes)
	for m in [["standard", "STANDARD RUN"], ["daily", "DAILY PROTOCOL"]]:
		var b := _button(m[1], func(): _set_mode(m[0]))
		b.custom_minimum_size = Vector2(300, 52)
		modes.add_child(b)
		_mode_buttons[m[0]] = b

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.custom_minimum_size = Vector2(0, 330)
	root.add_child(_body)

	_desc = Label.new()
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 50)
	_desc.add_theme_font_size_override("font_size", 20)
	_desc.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	root.add_child(_desc)
	_mult = Label.new()
	_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(_mult, NeonUI.GOLD, 28)
	root.add_child(_mult)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	root.add_child(footer)
	var back := _button("BACK", close_menu)
	back.custom_minimum_size = Vector2(240, 58)
	footer.add_child(back)
	_deploy = _button("DEPLOY", _on_deploy)
	_deploy.custom_minimum_size = Vector2(320, 58)
	NeonUI.style_button(_deploy, NeonUI.GREEN)
	_focus_style(_deploy, NeonUI.GREEN)
	footer.add_child(_deploy)

func _button(text: String, cb: Callable, color: Color = NeonUI.CYAN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	NeonUI.style_button(b, color)
	_focus_style(b, color)
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	b.mouse_entered.connect(func(): _sfx("hover"))
	return b

## Visible keyboard / gamepad focus ring.
func _focus_style(b: Button, color: Color):
	var f := NeonUI.panel_style(color, 0.85, 3, 16, 3)
	f.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.9)
	f.border_color = color.lerp(Color.WHITE, 0.7)
	f.content_margin_left = 20
	b.add_theme_stylebox_override("focus", f)

func _set_mode(m: String):
	_mode = m
	_refresh()

func _refresh():
	for k in _mode_buttons:
		var b: Button = _mode_buttons[k]
		var sel: bool = k == _mode
		NeonUI.style_button(b, NeonUI.GOLD if sel else NeonUI.CYAN)
		_focus_style(b, NeonUI.GOLD if sel else NeonUI.CYAN)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_toggles.clear()
	if _mode == "standard":
		_build_standard()
	else:
		_build_daily()
	_update_footer()

func _build_standard():
	var hint := Label.new()
	hint.text = "Stack any protocols. Each makes the run harder and raises your score and shard multiplier."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	_body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for p in Protocols.LIST:
		var id: String = p["id"]
		var b := _button("", func():
			if id in _picked:
				_picked.erase(id)
			else:
				_picked.append(id)
			_update_toggle(id)
			_update_footer())
		b.custom_minimum_size = Vector2(430, 56)
		b.mouse_entered.connect(func(): _show_desc(id))
		b.focus_entered.connect(func(): _show_desc(id))
		grid.add_child(b)
		_toggles[id] = b
		_update_toggle(id)

func _update_toggle(id: String):
	var b: Button = _toggles[id]
	var on: bool = id in _picked
	var p := Protocols.get_def(id)
	b.text = "%s %s   +%d%%" % ["[X]" if on else "[  ]", p["name"], roundi(float(p["bonus"]) * 100.0)]
	var col := NeonUI.GOLD if on else NeonUI.CYAN
	NeonUI.style_button(b, col)
	_focus_style(b, col)
	b.add_theme_font_size_override("font_size", 22)

func _show_desc(id: String):
	_desc.text = str(Protocols.get_def(id).get("desc", ""))

func _build_daily():
	var gd = get_node("/root/GlobalData")
	var key := Protocols.daily_key()
	var ids := Protocols.daily_ids(key)
	var date := Label.new()
	date.text = "TODAY  " + key + "  (UTC)"
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(date, NeonUI.GOLD, 30)
	_body.add_child(date)
	for id in ids:
		var p := Protocols.get_def(id)
		var l := Label.new()
		l.text = "%s  +%d%%\n%s" % [p["name"], roundi(float(p["bonus"]) * 100.0), p["desc"]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		_body.add_child(l)
	var best := Label.new()
	var today_best: int = gd.daily_best_score if gd.daily_best_key == key else 0
	best.text = "YOUR BEST TODAY: %s      STREAK: %d day%s" % [str(today_best) if today_best > 0 else "--", gd.daily_streak if gd.daily_last_played == key or gd.daily_last_played == Protocols.daily_key(Time.get_unix_time_from_system() - 86400.0) else 0, "" if gd.daily_streak == 1 else "s"]
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_font_size_override("font_size", 22)
	best.add_theme_color_override("font_color", NeonUI.GREEN.lerp(Color.WHITE, 0.4))
	_body.add_child(best)
	var note := Label.new()
	note.text = "Same protocols and same enemy order for every player today. Your score posts to today's online board when the run ends."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	_body.add_child(note)

func _current_ids() -> Array:
	if _mode == "daily":
		return Protocols.daily_ids(Protocols.daily_key())
	return _picked

func _update_footer():
	var ids := _current_ids()
	_mult.text = "SCORE & SHARDS  x%.2f" % Protocols.multiplier(ids)
	if _mode == "standard":
		if _desc.text == "":
			_desc.text = "Hover or select a protocol to read it."
	else:
		_desc.text = ""
	_deploy.text = "DEPLOY DAILY" if _mode == "daily" else "DEPLOY"

func _on_deploy():
	if _closing:
		return
	_closing = true
	get_node("/root/GlobalData").set_run(_mode, _current_ids())
	queue_free()
	if on_deploy.is_valid():
		on_deploy.call()

func close_menu():
	if _closing:
		return
	_closing = true
	queue_free()

func _input(event: InputEvent):
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
