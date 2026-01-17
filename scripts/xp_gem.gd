extends Area2D

@export var xp_value: float = 10.0
@export var magnet_speed: float = 600.0

var player: Node2D = null
var being_pulled: bool = false
var is_collected: bool = false # NEW: Safety flag

func _ready():
	# Ensure the gem can see the player (Layer 2)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	
	setup_trail()

func setup_trail():
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.amount = 8
	particles.lifetime = 0.3
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.1, 1.0, 0.5, 0.6) # Palette Green
	particles.emitting = true

func _process(delta: float):
	if is_collected: return # Stop moving if already picked up
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	if not being_pulled and distance < player.xp_magnet_range:
		being_pulled = true
	
	if being_pulled:
		var direction = (player.global_position - global_position).normalized()
		var current_speed = magnet_speed * (1.0 + (100.0 / max(1.0, distance)))
		global_position += direction * current_speed * delta

func _on_body_entered(body: Node):
	if is_collected: return
	
	if body.is_in_group("player"):
		is_collected = true
		# Disable everything immediately
		set_deferred("monitoring", false)
		visible = false 
		
		if body.has_method("add_xp"):
			body.add_xp(xp_value)
			print("XP GAINED: ", xp_value) # Debug check
			
		queue_free()