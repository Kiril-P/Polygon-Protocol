extends Label

@export var glow_speed: float = 2.0
@export var glitch_chance: float = 0.01

var time: float = 0.0
var base_pos: Vector2
var base_scale: Vector2

func _ready():
	base_pos = position
	base_scale = scale
	pivot_offset = size / 2
	
	# Set a very sharp neon outline - Palette: Neon Cyan
	add_theme_color_override("font_outline_color", Color(0.0, 0.8, 1.0, 0.5))
	add_theme_constant_override("outline_size", 12)

func _process(delta: float):
	time += delta
	
	# 1. High-Quality Digital Glow Pulse
	# Using an exponential sine for a "sharper" pulse feel
	var pulse = pow(sin(time * glow_speed), 2.0)
	var glow_color = Color(0.0, 0.8, 1.0) # Sharp Neon Cyan
	
	# Interpolate between a normal state and a super-bright "overdriven" state
	modulate = Color.WHITE.lerp(glow_color * 2.5, pulse * 0.6)
	
	# 2. Subtle "Digital Jitter" instead of goofy floating
	# Very small, very fast offsets to give it a "hardware" feel
	if randf() < glitch_chance:
		position = base_pos + Vector2(randf_range(-2, 2), randf_range(-1, 1))
		scale = base_scale * Vector2(randf_range(0.98, 1.02), randf_range(0.98, 1.02))
	else:
		position = position.lerp(base_pos, 20.0 * delta)
		scale = scale.lerp(base_scale, 20.0 * delta)
	
	# 3. Horizontal "Scanline" offset
	# Just a tiny bit of horizontal swaying to make it feel less static, but keep it tight
	position.x = base_pos.x + sin(time * 0.5) * 5.0
