class_name HudVitals
extends Control
## The one panel the player needs mid-fight: hearts and dash stamina, drawn
## large, flat and high-contrast on a dark plate (no glow to wash it out).
## Colour carries state: red hearts / cyan dash when healthy, amber when
## low, red while the dash is depleted and recharging.

const PANEL_SIZE := Vector2(560, 124)
const HEX_R := 21.0
const BAR_W := 340.0
const BAR_H := 22.0

const PLATE := Color(0.02, 0.03, 0.07, 0.9)

var hearts: int = 0
var max_hearts: int = 0
var energy: float = 100.0
var max_energy: float = 100.0

var _shown_energy: float = 100.0
var _depleted: bool = false      # true from reaching 0 until the bar is back above the threshold
var _ready_flash: float = 0.0    # 1 -> 0 after the bar recovers from empty
var _hit_flash: float = 0.0      # 1 -> 0 after losing a heart
var _heal_flash: float = 0.0
var _lost_index: int = -1
var _time: float = 0.0
var _font: Font
var ui_scale: float = 1.0   # HUD size setting
var _pop: float = 1.0       # transient hit pop

static func pc(key: String) -> Color:
	return Engine.get_main_loop().root.get_node("GameSettings").pal()[key]

func _init():
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	_font = get_theme_default_font()
	pivot_offset = Vector2(PANEL_SIZE.x / 2.0, PANEL_SIZE.y)   # grow upward from the bottom centre
	get_node("/root/GameSettings").changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings():
	ui_scale = get_node("/root/GameSettings").hud_scale()
	scale = Vector2.ONE * ui_scale * _pop
	queue_redraw()

func set_hearts(current: int, maximum: int):
	if hearts > current and max_hearts > 0:
		_hit_flash = 1.0
		_lost_index = current
		_pop = 1.06
	elif current > hearts and max_hearts > 0:
		_heal_flash = 1.0
	hearts = current
	max_hearts = maximum
	queue_redraw()

func set_energy(current: float, maximum: float):
	energy = current
	max_energy = maximum
	var frac := current / maxf(maximum, 1.0)
	if current <= 0.0:
		_depleted = true
	elif _depleted and frac >= 0.3:
		_depleted = false
		_ready_flash = 1.0
		get_node("/root/AudioManager").play_sfx("dash_ready")
	queue_redraw()

func _process(delta: float):
	_time += delta
	_shown_energy = lerpf(_shown_energy, energy, clampf(delta * 18.0, 0.0, 1.0))
	_hit_flash = maxf(_hit_flash - delta * 2.2, 0.0)
	_heal_flash = maxf(_heal_flash - delta * 2.0, 0.0)
	_ready_flash = maxf(_ready_flash - delta * 1.6, 0.0)
	_pop = lerpf(_pop, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	scale = Vector2.ONE * ui_scale * _pop
	queue_redraw()

func _dash_color(frac: float) -> Color:
	if _depleted:
		return pc("dash_empty")
	if frac < 0.3:
		return pc("dash_low")
	return pc("dash")

func _hex(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(center + Vector2(r, 0).rotated(TAU / 6.0 * i + PI / 6.0))
	return pts

func _text_centered(text: String, pos: Vector2, font_size: int, color: Color):
	if not _font:
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(_font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	draw_string(_font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw():
	var low_hp := hearts <= 1 and max_hearts > 0
	var urgent := (0.55 + 0.45 * sin(_time * 8.0)) if low_hp else 0.0

	# Plate
	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(2)
	var HEART := pc("heart")
	var HEART_DARK := pc("heart_dark")
	var border := Color(0.35, 0.5, 0.65, 0.5)
	if low_hp:
		border = HEART.lerp(Color.WHITE, 0.1 * urgent)
		border.a = 0.5 + 0.5 * urgent
	elif _hit_flash > 0.0:
		border = HEART
	plate.border_color = border
	draw_style_box(plate, Rect2(Vector2.ZERO, PANEL_SIZE))

	# --- Hearts row -------------------------------------------------------
	var n := maxi(max_hearts, 1)
	var step := minf(HEX_R * 2.0 + 10.0, (PANEL_SIZE.x - 90.0) / n)
	var r := minf(HEX_R, step / 2.0 - 3.0)
	var row_w := step * (n - 1)
	var cy := 38.0
	var x0 := PANEL_SIZE.x / 2.0 - row_w / 2.0
	for i in n:
		var c := Vector2(x0 + step * i, cy)
		var pts := _hex(c, r)
		var outline := pts.duplicate()
		outline.append(pts[0])
		if i < hearts:
			var beat := 1.0
			if low_hp:
				beat = 1.0 + 0.1 * urgent
			var col := HEART
			if _heal_flash > 0.0:
				col = col.lerp(Color(0.4, 1.0, 0.6), _heal_flash * 0.7)
			draw_colored_polygon(_hex(c, r * beat), col.darkened(0.35))
			draw_colored_polygon(_hex(c, r * 0.62 * beat), col.lerp(Color.WHITE, 0.25))
			draw_polyline(outline, col.lerp(Color.WHITE, 0.55), 2.5, true)
		else:
			draw_colored_polygon(pts, HEART_DARK)
			draw_polyline(outline, Color(0.55, 0.2, 0.28, 0.9), 2.0, true)
			if i == _lost_index and _hit_flash > 0.0:
				draw_colored_polygon(_hex(c, r * (1.0 + 0.9 * _hit_flash)), Color(1, 1, 1, 0.5 * _hit_flash))

	# --- Dash row ---------------------------------------------------------
	var frac := clampf(_shown_energy / maxf(max_energy, 1.0), 0.0, 1.0)
	var col := _dash_color(frac)
	var bx := 84.0
	var by := 82.0
	# Icon: double chevron
	var ic := Vector2(bx - 42.0, by + BAR_H / 2.0)
	for k in 2:
		var o := Vector2(k * 13.0, 0)
		draw_polyline(PackedVector2Array([ic + o + Vector2(-7, -10), ic + o + Vector2(3, 0), ic + o + Vector2(-7, 10)]), col, 3.0, true)
	# Track
	draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.01, 0.02, 0.05, 0.95))
	# Fill
	var fw := BAR_W * frac
	if fw > 0.5:
		draw_rect(Rect2(bx, by, fw, BAR_H), col.darkened(0.15))
		draw_rect(Rect2(bx, by, fw, BAR_H * 0.45), col.lerp(Color.WHITE, 0.35))
	# Depleted: pulsing warning stripes over the track
	if _depleted:
		var a := 0.4 + 0.25 * sin(_time * 8.0)
		var ec := pc("dash_empty")
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(ec.r, ec.g, ec.b, a))
		# Diagonal hatching so "empty" never relies on colour alone
		var x_ := 0.0
		while x_ < BAR_W:
			draw_line(Vector2(bx + x_, by + BAR_H), Vector2(bx + minf(x_ + BAR_H, BAR_W), by + maxf(BAR_H - (BAR_W - x_), 0.0)), Color(1, 1, 1, 0.35), 2.0)
			x_ += 14.0
	# Tick marks (quarters) and unlock threshold
	for q in [0.25, 0.5, 0.75]:
		draw_line(Vector2(bx + BAR_W * q, by), Vector2(bx + BAR_W * q, by + BAR_H), Color(0, 0, 0, 0.55), 2.0)
	draw_rect(Rect2(bx, by, BAR_W, BAR_H), col.lerp(Color.WHITE, 0.35 + 0.4 * _ready_flash), false, 2.0)
	if _ready_flash > 0.0:
		draw_rect(Rect2(bx - 3, by - 3, BAR_W + 6, BAR_H + 6), Color(0.6, 1.0, 1.0, _ready_flash), false, 3.0)
	# Status label to the right of the bar
	var status := "DASH"
	var scol := col
	if _depleted:
		status = "RECHARGE"
	elif frac < 0.3:
		status = "LOW"
	elif _ready_flash > 0.0:
		status = "READY"
		scol = Color(0.7, 1.0, 1.0)
	_text_centered(status, Vector2(bx + BAR_W + 66.0, by + BAR_H - 2.0), 20, scol)
