extends CanvasLayer
## Full-screen post-processing (bloom, chromatic aberration, vignette, danger pulse).
## Autoload name: PostFX. Draws below the HUD, which lives on layer 1 and is added later.

var _rect: ColorRect
var _mat: ShaderMaterial
var _kick: float = 0.0
var _danger: float = 0.0

const BASE_ABERRATION := 0.0012

func _ready():
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)

## Adds a short-lived burst of chromatic aberration.
func kick(amount: float):
	_kick = minf(_kick + amount, 0.012)

func _process(delta: float):
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-9.0 * delta))
	var player = get_tree().get_first_node_in_group("player")
	var danger_target := 0.0
	var dash_boost := 0.0
	if player and is_instance_valid(player):
		if player.current_hearts <= 1 and not player.is_dead:
			danger_target = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
		if player.is_dashing:
			dash_boost = 0.0025
	_danger = lerpf(_danger, danger_target, 1.0 - exp(-8.0 * delta))
	_mat.set_shader_parameter("aberration", BASE_ABERRATION + _kick + dash_boost)
	_mat.set_shader_parameter("danger", _danger)
	_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
