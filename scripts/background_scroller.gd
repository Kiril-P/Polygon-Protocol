extends ColorRect

@export var parallax_factor: float = 0.5
@export var auto_scroll: Vector2 = Vector2.ZERO
var current_offset: Vector2 = Vector2.ZERO

func _process(delta: float):
	current_offset += auto_scroll * delta
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Subtle parallax: follow the player at a fraction of their position
		var player_offset = player.global_position * parallax_factor
		if material is ShaderMaterial:
			material.set_shader_parameter("offset", current_offset + player_offset)
	else:
		if material is ShaderMaterial:
			material.set_shader_parameter("offset", current_offset)
