extends Control
## The shape tree: spend shards to unlock starting shapes (see PlayerShapes). Unlocked shapes
## can be equipped here or on the deploy screen. Reached from the Evolution Vault.

const CARD := Vector2(310, 205)
const AREA := Vector2(1200, 870)
## Card centres inside the tree area
const POS := {
	"circle": Vector2(600, 105),
	"spark": Vector2(600, 320),
	"bastion": Vector2(250, 535),
	"comet": Vector2(950, 535),
	"hive": Vector2(600, 750),
}

var _shard_label: Label
var _area: Control
var _links: Control
var _cards: Dictionary = {}
var _note: Label

func _ready():
	NeonUI.living_background(self)
	_build()
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

func _sfx(n: String):
	AudioManager.play_sfx(n)

func _build():
	var title := Label.new()
	title.text = "SHAPE TREE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(title, NeonUI.CYAN, 56)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 36
	add_child(title)
	NeonUI.pulse(title, 0.15, 2.4)

	_shard_label = Label.new()
	_shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonUI.style_title(_shard_label, NeonUI.GOLD, 28)
	_shard_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_shard_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shard_label.offset_top = 110
	add_child(_shard_label)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 18)
	_note.add_theme_color_override("font_color", Color(0.6, 0.78, 0.95))
	_note.text = "A starting shape skips the unarmed opening, with a trade-off for the whole run. The Daily Protocol always starts as a circle."
	_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note.offset_top = 154
	add_child(_note)

	_area = Control.new()
	_area.custom_minimum_size = AREA
	_area.size = AREA
	_area.set_anchors_preset(Control.PRESET_CENTER)
	_area.offset_left = -AREA.x / 2.0
	_area.offset_right = AREA.x / 2.0
	_area.offset_top = -AREA.y / 2.0 + 80.0
	_area.offset_bottom = AREA.y / 2.0 + 80.0
	add_child(_area)
	_links = Control.new()
	_links.set_anchors_preset(Control.PRESET_FULL_RECT)
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.draw.connect(_draw_links)
	_area.add_child(_links)
	for s in PlayerShapes.LIST:
		var card := _make_card(s)
		card.position = POS[s["id"]] - CARD / 2.0
		_area.add_child(card)
		_cards[s["id"]] = card

	var back := Button.new()
	back.text = "RETURN"
	back.custom_minimum_size = Vector2(190, 56)
	back.add_theme_font_size_override("font_size", 22)
	NeonUI.style_button(back)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 40
	back.offset_top = 40
	back.offset_right = 230
	back.offset_bottom = 96
	back.pressed.connect(_on_back)
	back.mouse_entered.connect(func(): _sfx("hover"))
	add_child(back)

func _make_card(def: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	card.size = CARD
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var glyph := ShapeGlyph.new()
	glyph.name = "Glyph"
	glyph.sides = int(def["sides"])
	glyph.custom_minimum_size = Vector2(70, 70)
	top.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(texts)
	var name_l := Label.new()
	name_l.name = "Name"
	name_l.text = def["name"]
	name_l.add_theme_font_size_override("font_size", 26)
	texts.add_child(name_l)
	var req := Label.new()
	req.name = "Req"
	req.add_theme_font_size_override("font_size", 14)
	texts.add_child(req)
	var desc := Label.new()
	desc.name = "Desc"
	desc.text = def["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD.x - 32, 56)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.88, 0.98))
	v.add_child(desc)
	var btn := Button.new()
	btn.name = "Action"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 18)
	btn.mouse_entered.connect(func(): _sfx("hover"))
	btn.pressed.connect(func(): _on_action(def["id"]))
	v.add_child(btn)
	return card

func _on_action(id: String):
	var gd = GlobalData
	_sfx("click")
	if gd.has_shape(id):
		gd.select_shape(id)
	elif gd.buy_shape(id):
		gd.select_shape(id)
		_sfx("level_up")
		VFX.shockwave(_card_world_center(id), 1.2, NeonUI.GOLD, 280.0)
	_refresh()

func _card_world_center(id: String) -> Vector2:
	var screen: Vector2 = _area.global_position + POS[id]
	return get_viewport().get_canvas_transform().affine_inverse() * screen

func _refresh():
	var gd = GlobalData
	_shard_label.text = "QUANTUM SHARDS: %d" % gd.total_shards
	for s in PlayerShapes.LIST:
		var id: String = s["id"]
		var card: PanelContainer = _cards[id]
		var owned: bool = gd.has_shape(id)
		var reqs_ok := true
		var missing: Array = []
		for r in s["requires"]:
			if not gd.has_shape(r):
				reqs_ok = false
				missing.append(PlayerShapes.get_def(r)["name"])
		var can_afford: bool = gd.total_shards >= int(s["cost"])
		var color := NeonUI.CYAN
		if owned:
			color = NeonUI.GREEN if gd.selected_shape == id else NeonUI.CYAN
		elif reqs_ok and can_afford:
			color = NeonUI.GOLD
		elif not reqs_ok:
			color = Color(0.4, 0.45, 0.55)
		card.add_theme_stylebox_override("panel", NeonUI.panel_style(color, 0.82, 3 if gd.selected_shape == id and owned else 2, 14, 6))
		var glyph: ShapeGlyph = card.find_child("Glyph", true, false)
		glyph.color = color
		glyph.locked = not owned and not reqs_ok
		var name_l: Label = card.find_child("Name", true, false)
		NeonUI.style_title(name_l, color, 26)
		var req: Label = card.find_child("Req", true, false)
		if owned:
			req.text = "UNLOCKED"
			req.add_theme_color_override("font_color", NeonUI.GREEN.lerp(Color.WHITE, 0.3))
		elif not reqs_ok:
			req.text = "NEEDS " + " + ".join(missing)
			req.add_theme_color_override("font_color", Color(0.75, 0.6, 0.6))
		else:
			req.text = "%d SHARDS" % int(s["cost"])
			req.add_theme_color_override("font_color", NeonUI.GOLD.lerp(Color.WHITE, 0.3))
		var btn: Button = card.find_child("Action", true, false)
		NeonUI.style_button(btn, color)
		btn.disabled = false
		if owned:
			if gd.selected_shape == id:
				btn.text = "EQUIPPED"
				btn.disabled = true
			else:
				btn.text = "EQUIP"
		elif not reqs_ok:
			btn.text = "LOCKED"
			btn.disabled = true
		else:
			btn.text = "UNLOCK  %d" % int(s["cost"])
			btn.disabled = not can_afford
	_links.queue_redraw()

func _draw_links():
	var gd = GlobalData
	for s in PlayerShapes.LIST:
		for r in s["requires"]:
			var a: Vector2 = POS[r] + Vector2(0, CARD.y / 2.0)
			var b: Vector2 = POS[s["id"]] - Vector2(0, CARD.y / 2.0)
			var lit: bool = gd.has_shape(r)
			var col := NeonUI.CYAN if lit else Color(0.3, 0.36, 0.48)
			var mid_y := (a.y + b.y) / 2.0
			var pts := PackedVector2Array([a, Vector2(a.x, mid_y), Vector2(b.x, mid_y), b])
			_links.draw_polyline(pts, Color(col.r, col.g, col.b, 0.25), 8.0, true)
			_links.draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 if lit else 0.6), 2.5, true)

func _on_back():
	_sfx("click")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		GlobalData.next_scene_path = "res://scenes/evolution_vault.tscn"
		Transition.go("res://scenes/loading_screen.tscn"))
