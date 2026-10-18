extends Button
## Level-up card: category tag, vector icon, name, description and a footer for
## the level / synergy. The card builds its own layout so the scene stays trivial.

const CATEGORY_COLORS := {
	"offense": Color(1.0, 0.5, 0.3),
	"defense": Color(0.2, 1.0, 0.55),
	"mobility": Color(0.0, 0.85, 1.0),
	"special": Color(1.0, 0.8, 0.1),
	"counter": Color(0.72, 0.5, 1.0),
}
const CATEGORY_BY_ID := {
	"damage": "offense", "fire_rate": "offense", "bullet_speed": "offense", "rotation_speed": "offense",
	"pierce": "offense", "homing": "offense", "split": "offense", "chain": "offense", "explosive": "offense",
	"prismatic_beam": "offense", "bounce": "offense",
	"max_hearts": "defense", "heal": "defense", "dash_lifesteal": "defense",
	"speed": "mobility", "dash_charge": "mobility", "dash_cooldown": "mobility", "dash_trail": "mobility", "gravity_well": "mobility",
}
const SYNERGY_COLOR := Color(1.0, 0.2, 0.75)

var accent: Color = NeonUI.CYAN
var is_special: bool = false

func setup(upgrade_data: Dictionary):
	is_special = upgrade_data.get("is_special", false)
	var id: String = upgrade_data.get("id", "")
	var counters: String = upgrade_data.get("counters", "")
	var category: String = "special" if is_special else CATEGORY_BY_ID.get(id, "mobility")
	if counters != "":
		category = "counter"
	accent = CATEGORY_COLORS[category]
	
	# Split the manager's decorated strings back into name / level / synergy
	var full_name: String = upgrade_data.get("name", "")
	var level_text := ""
	var m := RegEx.create_from_string("^(.*) \\(Level (\\d+)\\)$").search(full_name)
	if m:
		full_name = m.get_string(1)
		level_text = "LEVEL " + m.get_string(2)
	var desc: String = upgrade_data.get("description", "")
	var synergy_text := ""
	var syn_at := desc.find("\nSYNERGY:")
	if syn_at != -1:
		synergy_text = desc.substr(syn_at + 9).strip_edges()
		desc = desc.substr(0, syn_at)
	var has_synergy: bool = upgrade_data.has("synergy")
	if has_synergy:
		accent = accent.lerp(SYNERGY_COLOR, 0.35)
	
	# Fresh layout
	for c in get_children():
		remove_child(c)
		c.queue_free()
	flat = false
	text = ""
	custom_minimum_size = Vector2(300, 420) if is_special else Vector2(250, 350)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	
	var tag_text := "SPECIAL" if is_special else category.to_upper()
	if counters != "":
		tag_text = "COUNTER · " + String(UpgradeManager.INTEL[counters]["name"])
	var tag := _label(tag_text, 13, Color(accent.r, accent.g, accent.b, 0.85))
	box.add_child(tag)
	
	var icon := UpgradeIcon.new()
	var icon_size := 170.0 if is_special else 130.0
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	icon.set_icon(id, accent)
	
	var title := _label(full_name.to_upper(), 26 if is_special else 22, accent.lerp(Color.WHITE, 0.6))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(accent.r, accent.g, accent.b, 0.45)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	
	var body := _label(desc, 16, Color(0.82, 0.88, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	
	if has_synergy and synergy_text != "":
		var syn := _label("SYNERGY  " + synergy_text.get_slice(" (", 0), 13, SYNERGY_COLOR.lerp(Color.WHITE, 0.4))
		syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(syn)
	elif level_text != "":
		box.add_child(_label(level_text, 13, Color(accent.r, accent.g, accent.b, 0.8)))
	
	style_menu_button(self)
	
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		button_down.connect(_on_button_down)
		button_up.connect(_on_button_up)

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func style_menu_button(btn: Button):
	var normal := NeonUI.panel_style(accent, 0.86, 2, 6, 6)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.8)
	var hover := NeonUI.panel_style(accent, 0.94, 3, 14, 6)
	hover.border_color = accent.lerp(Color.WHITE, 0.45)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.border_color = NeonUI.MAGENTA.lerp(Color.WHITE, 0.3)
	var disabled := normal.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_button_down():
	scale = Vector2(0.96, 0.96)

func _on_button_up():
	scale = Vector2(1.04, 1.04)

func _on_mouse_entered():
	if disabled:
		return
	AudioManager.play_sfx("hover")
	pivot_offset = size / 2
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mouse_exited():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
