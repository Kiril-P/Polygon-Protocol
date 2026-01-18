extends ColorRect

@export var parallax_factor: float = 0.5
@export var auto_scroll: Vector2 = Vector2.ZERO
var current_offset: Vector2 = Vector2.ZERO

var base_grid_color: Color = Color(0.0, 0.5, 1.0, 0.05) # Starting Cyan
var chaos_grid_color: Color = Color(1.0, 0.1, 0.1, 0.2) # Ending Red (more visible)

func _process(delta: float):
	current_offset += auto_scroll * delta
	
	# Handle Dynamic Difficulty Tinting
	update_difficulty_tint()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Subtle parallax: follow the player at a fraction of their position
		var player_offset = player.global_position * parallax_factor
		if material is ShaderMaterial:
			material.set_shader_parameter("offset", current_offset + player_offset)
	else:
		if material is ShaderMaterial:
			material.set_shader_parameter("offset", current_offset)

func update_difficulty_tint():
	var spawner = get_tree().get_first_node_in_group("spawner")
	if not spawner or not material is ShaderMaterial:
		return
		
	var time = spawner.time_passed
	# Ramp up over 3 minutes (180s)
	var factor = clamp(time / 180.0, 0.0, 1.0)
	
	# Apply exponential curve so it stays cyan longer then turns red fast
	var curve_factor = pow(factor, 2.0)
	
	var current_color = base_grid_color.lerp(chaos_grid_color, curve_factor)
	material.set_shader_parameter("line_color", current_color)
