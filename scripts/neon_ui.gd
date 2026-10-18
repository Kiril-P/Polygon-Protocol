class_name NeonUI
extends RefCounted
## Shared neon styling for menus, cards, buttons and titles so every screen
## reads as part of the same glowing-vector world.

const CYAN := Color(0.0, 0.85, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.6)
const GOLD := Color(1.0, 0.8, 0.1)
const GREEN := Color(0.1, 1.0, 0.55)
const RED := Color(1.0, 0.15, 0.25)

## Dark translucent panel with a hot border and soft outer glow.
static func panel_style(color: Color, fill_alpha: float = 0.72, border: int = 2, glow: int = 10, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.08, color.g * 0.08, color.b * 0.12 + 0.02, fill_alpha)
	s.set_border_width_all(border)
	s.border_color = color.lerp(Color.WHITE, 0.2)
	s.set_corner_radius_all(radius)
	s.corner_radius_bottom_right = radius * 3
	s.shadow_color = Color(color.r, color.g, color.b, 0.18)
	s.shadow_size = glow
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

## Styles a Button with neon normal/hover/pressed/disabled states.
static func style_button(btn: Button, color: Color = CYAN) -> void:
	var normal := panel_style(color, 0.62, 2, 4, 3)
	normal.border_color = Color(color.r, color.g, color.b, 0.75)
	normal.content_margin_left = 20
	var hover := panel_style(color, 0.8, 2, 18, 3)
	hover.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.85)
	hover.border_color = color.lerp(Color.WHITE, 0.5)
	hover.content_margin_left = 20
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(MAGENTA.r * 0.3, MAGENTA.g * 0.3, MAGENTA.b * 0.3, 0.9)
	pressed.border_color = MAGENTA.lerp(Color.WHITE, 0.3)
	pressed.shadow_color = Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(0.3, 0.35, 0.45, 0.5)
	disabled.bg_color = Color(0.03, 0.04, 0.07, 0.5)
	disabled.shadow_size = 0
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.75))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.6))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))

## Glowing title text: bright core, coloured halo via outline + shadow.
static func style_title(label: Label, color: Color = CYAN, size: int = -1) -> void:
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.6))
	label.add_theme_color_override("font_outline_color", Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.28))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 12)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)

## Soft additive glow behind a Control (added as the first child).
static func add_halo(parent: Control, color: Color, alpha: float = 0.25, margin: float = 60.0) -> TextureRect:
	var halo := TextureRect.new()
	halo.name = "NeonHalo"
	halo.texture = Neon.glow_texture()
	halo.material = Neon.additive_material()
	halo.modulate = Color(color.r, color.g, color.b, alpha)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.show_behind_parent = true
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.offset_left = -margin
	halo.offset_top = -margin
	halo.offset_right = margin
	halo.offset_bottom = margin
	parent.add_child(halo)
	parent.move_child(halo, 0)
	return halo

## Slow breathing pulse on a node's modulate; returns the tween.
static func pulse(node: CanvasItem, strength: float = 0.25, period: float = 1.4) -> Tween:
	var t := node.create_tween().set_loops()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(node, "modulate", Color(1.0 + strength, 1.0 + strength, 1.0 + strength * 1.5, node.modulate.a), period * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "modulate", Color(1, 1, 1, node.modulate.a), period * 0.5).set_trans(Tween.TRANS_SINE)
	return t

## Dims the screen with a dark vignette-ish wash tinted toward `tint`.
static func wash(tint: Color, alpha: float = 0.82) -> ColorRect:
	var r := ColorRect.new()
	r.name = "NeonWash"
	r.color = Color(tint.r * 0.04, tint.g * 0.04, tint.b * 0.06, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

## Swaps a screen's flat backdrop for the living neon grid used in-game, with
## occasional ripples. Returns the background CanvasLayer.
static func living_background(host: Node, old_backdrop: CanvasItem = null) -> Node:
	if old_backdrop:
		old_backdrop.visible = false
	var bg: Node = load("res://scenes/background.tscn").instantiate()
	host.add_child(bg)
	var grid := bg.get_node("Grid")
	grid.auto_scroll = Vector2(22, 12)
	var timer := Timer.new()
	timer.wait_time = 2.8
	timer.autostart = true
	timer.timeout.connect(func():
		var vp := host.get_viewport()
		var xform := vp.get_canvas_transform().affine_inverse()
		var size := vp.get_visible_rect().size
		var v: Node = Engine.get_main_loop().root.get_node("VFX")
		v.shockwave(xform * Vector2(randf() * size.x, randf() * size.y), 1.1, Color(0.3, 0.8, 1.0), 260.0))
	host.add_child(timer)
	return bg

## Glowing technical progress bar (same look as the HUD bars).
static func style_bar(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.08, 0.75)
	bg.set_border_width_all(2)
	bg.border_color = color.lerp(Color.BLACK, 0.45)
	bg.set_corner_radius_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color.lerp(Color.WHITE, 0.15)
	fg.set_border_width_all(1)
	fg.border_color = color.lerp(Color.WHITE, 0.8)
	fg.set_corner_radius_all(1)
	fg.shadow_color = Color(color.r, color.g, color.b, 0.55)
	fg.shadow_size = 12
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

## Cyan-filled slider with a glowing track.
static func style_slider(slider: HSlider, color: Color = CYAN) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.05, 0.12, 0.9)
	track.set_border_width_all(1)
	track.border_color = color.lerp(Color.BLACK, 0.5)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = color.lerp(Color.WHITE, 0.1)
	fill.shadow_color = Color(color.r, color.g, color.b, 0.5)
	fill.shadow_size = 8
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
