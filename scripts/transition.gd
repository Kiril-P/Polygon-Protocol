extends CanvasLayer
## Scene transitions: a neon scan-line wipe that covers the screen, swaps the scene, then
## uncovers it. Blocks input while active so a stale click can't hit the next scene.
## Autoload name: Transition.

const WIPE_SHADER := """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float reveal = 0.0; // 0 = covering, 1 = uncovering
uniform vec4 tint : source_color = vec4(0.0, 0.85, 1.0, 1.0);
void fragment() {
	float band = floor(UV.y * 16.0);
	float jitter = fract(sin(band * 91.7) * 437.5) * 0.14;
	float front = UV.x * 0.9 + UV.y * 0.25 + jitter;
	float p = progress * 1.45 - 0.05;
	float covered = reveal < 0.5 ? step(front, p) : step(p, front);
	float edge = 1.0 - smoothstep(0.0, 0.03, abs(front - p));
	vec3 base = vec3(0.012, 0.016, 0.04);
	vec3 col = mix(base, tint.rgb, edge);
	COLOR = vec4(col, max(covered, edge * 0.9));
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false

func _ready():
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = WIPE_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)

func is_busy() -> bool:
	return _busy

## Wipes to `path` (a scene file). Ignored while another transition is running.
func go(path: String, speed: float = 1.0):
	await _swap(func(): get_tree().change_scene_to_file(path), speed)

## Wipes and reloads the current scene (retry after death).
func reload(speed: float = 1.0):
	await _swap(func(): get_tree().reload_current_scene(), speed)

func _swap(do_swap: Callable, speed: float):
	if _busy:
		return
	_busy = true
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_mat.set_shader_parameter("tint", Color(0.0, 0.85, 1.0, 1.0))
	_mat.set_shader_parameter("reveal", 0.0)
	_mat.set_shader_parameter("progress", 0.0)
	AudioManager.play_sfx("glitch", -10.0, 0.9, 1.1)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_method(func(v): _mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.32 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	do_swap.call()
	await get_tree().process_frame
	await get_tree().process_frame
	_mat.set_shader_parameter("reveal", 1.0)
	_mat.set_shader_parameter("progress", 0.0)
	var t2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t2.tween_method(func(v): _mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.4 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t2.finished
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
