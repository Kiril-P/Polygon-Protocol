extends Area2D

var boss: Node2D = null
var heart_color: Color = Color(1.0, 0.9, 0.0) # Default Gold
var is_dying: bool = false

func _ready():
	add_to_group("boss_hearts")
	# Check if boss has a custom heart color
	if boss and boss.get("heart_color"):
		heart_color = boss.get("heart_color")
	setup_visuals()
	body_entered.connect(_on_body_entered)

func setup_visuals():
	# Ensure we can detect the player (Layer 2)
	collision_mask = 0
	set_collision_mask_value(2, true)
	
	var poly = Polygon2D.new()
	# Heart-like shape
	var pts = PackedVector2Array([
		Vector2(0, 15), Vector2(-15, 0), Vector2(-15, -10), 
		Vector2(-7, -15), Vector2(0, -7), Vector2(7, -15), 
		Vector2(15, -10), Vector2(15, 0)
	])
	poly.polygon = pts
	poly.color = heart_color
	# Calculate a glow version of the color
	var glow_color = heart_color * 2.5
	glow_color.a = 1.0
	poly.modulate = glow_color
	add_child(poly)
	
	# Add an outline to make it pop even more
	var outline = Line2D.new()
	outline.points = pts
	outline.add_point(pts[0]) # Close the loop
	outline.width = 2.0
	outline.default_color = Color.BLACK
	poly.add_child(outline)
	
	# Add a collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 25.0
	shape.shape = circle
	add_child(shape)
	
	# Entrance effect
	scale = Vector2.ZERO
	var t_pillar_in = create_tween().bind_node(self)
	t_pillar_in.tween_property(self, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_BACK)
	
	# Constant Pulse animation
	var t_pillar_pulse = create_tween().set_loops().bind_node(poly)
	t_pillar_pulse.tween_property(poly, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_SINE)
	t_pillar_pulse.tween_property(poly, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body):
	if is_dying: return
	
	if body.is_in_group("player") and body.get("is_dashing"):
		die(true)

func die(hit_by_player: bool):
	if is_dying: return
	is_dying = true
	
	if hit_by_player and boss and is_instance_valid(boss):
		# Boss takes significant damage from heart destruction
		var damage_percent = 0.111 # ~11% for Bosses (9 hearts total to kill)
		
		boss.take_damage(boss.max_health * damage_percent) 
		
		# Feedback sound and screen shake
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 1.2, 1.5)
			
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("add_shake"):
			player.add_shake(15.0)
			
		# Visual feedback on boss (redundant with take_damage but for extra impact)
		if boss.has_node("Polygon2D"):
			var t = create_tween()
			boss.get_node("Polygon2D").modulate = Color(10, 10, 10, 1)
			t.tween_property(boss.get_node("Polygon2D"), "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.2)
	
	# Explosion effect
	spawn_particles()
	queue_free()

func spawn_particles():
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
	p.amount = 30
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = heart_color # Match heart color
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
