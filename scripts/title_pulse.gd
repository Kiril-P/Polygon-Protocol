extends Label

@export var glow_speed: float = 2.0
@export var glitch_chance: float = 0.02

var time: float = 0.0
var base_pos: Vector2
var base_scale: Vector2

func _ready():
	base_pos = position
	base_scale = scale
	pivot_offset = size / 2
	
	# Initial appearance animation
	modulate.a = 0
	scale = base_scale * 1.5
	var intro = create_tween().set_parallel(true)
	intro.tween_property(self, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUINT)
	intro.tween_property(self, "scale", base_scale, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Neon styling
	add_theme_color_override("font_outline_color", Color(0.0, 1.0, 1.0, 0.8))
	add_theme_constant_override("outline_size", 16)
	add_theme_color_override("font_shadow_color", Color(0.5, 0, 1, 0.5))
	add_theme_constant_override("shadow_offset_x", 4)
	add_theme_constant_override("shadow_offset_y", 4)

func _process(delta: float):
	time += delta
	
	# 1. Cyber Glow Pulse
	var pulse = (sin(time * glow_speed) + 1.0) / 2.0
	var cyan = Color(0.0, 1.0, 1.0)
	var magenta = Color(1.0, 0.0, 1.0)
	
	# Cycle between Cyan and a bit of Magenta for that Retrowave feel
	var target_color = cyan.lerp(magenta, 0.2 * pulse)
	add_theme_color_override("font_outline_color", target_color.lerp(Color.WHITE, 0.3 * pulse))
	
	# 2. Glitch Effect
	if randf() < glitch_chance:
		# Random position "jumps"
		position = base_pos + Vector2(randf_range(-15, 15), randf_range(-5, 5))
		# Random text corruption feel (using scale)
		scale.x = base_scale.x * randf_range(0.8, 1.4)
		modulate = Color(2, 2, 2, 1) # Flash white
		
		# Occasional "split" feel
		if randf() < 0.5:
			text = "P0lygon Pr0t0col"
		else:
			text = "P_LYGON PROTOC_L"
	else:
		position = position.lerp(base_pos, 15.0 * delta)
		scale = scale.lerp(base_scale, 15.0 * delta)
		modulate = modulate.lerp(Color.WHITE, 10.0 * delta)
		text = "Polygon Protocol"
	
	# 3. Floating Motion
	position.y = base_pos.y + sin(time * 1.5) * 8.0
	rotation = sin(time * 0.8) * 0.02
	
	# 4. Multi-layered glow (dynamic shadows)
	var glow_offset = Vector2(sin(time * 3.0), cos(time * 3.0)) * 6.0
	add_theme_constant_override("shadow_offset_x", int(glow_offset.x))
	add_theme_constant_override("shadow_offset_y", int(glow_offset.y))
	add_theme_color_override("font_shadow_color", magenta.lerp(cyan, pulse).lerp(Color.TRANSPARENT, 0.4))