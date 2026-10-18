class_name DashRing
extends Node2D
## Stamina arc around the ship so the player can read their dash without
## looking away from the action. Only visible while the dash is in use or
## recovering; fades out when full.

const RADIUS := 40.0

var _energy: float = 100.0
var _max: float = 100.0
var _depleted := false
var _alpha := 0.0
var _flash := 0.0
var _target: Node2D

func _ready():
	top_level = true
	z_index = 5
	_target = get_parent()
	if _target.has_signal("energy_changed"):
		_target.energy_changed.connect(_on_energy)
	global_position = _target.global_position

func _on_energy(current: float, maximum: float):
	if current <= 0.0:
		_depleted = true
	elif _depleted and current / maxf(maximum, 1.0) >= 0.3:
		_depleted = false
		_flash = 1.0
	_energy = current
	_max = maximum

func _process(delta: float):
	if is_instance_valid(_target):
		global_position = _target.global_position
	var full := _energy >= _max - 0.5
	var want := 0.0 if (full and _flash <= 0.0) else 0.9
	_alpha = move_toward(_alpha, want, delta * (6.0 if want > _alpha else 2.5))
	_flash = maxf(_flash - delta * 2.0, 0.0)
	visible = _alpha > 0.01
	if visible:
		queue_redraw()

func _draw():
	var frac := clampf(_energy / maxf(_max, 1.0), 0.0, 1.0)
	var col := HudVitals.DASH
	if _depleted:
		col = HudVitals.DASH_EMPTY
	elif frac < 0.3:
		col = HudVitals.DASH_LOW
	var a := _alpha
	# Track
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(0, 0, 0, 0.45 * a), 7.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.18 * a), 4.0, true)
	if frac > 0.0:
		var start := -PI / 2.0
		draw_arc(Vector2.ZERO, RADIUS, start, start + TAU * frac, 64, Color(col.r, col.g, col.b, a), 4.5, true)
	if _flash > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 64, Color(0.7, 1.0, 1.0, _flash), 3.0, true)
