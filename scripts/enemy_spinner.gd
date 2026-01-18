extends CharacterBody2D

@export var speed: float = 120.0
@export var health: float = 40.0
@export var damage: float = 10.0
@export var xp_value: int = 25
@export var fire_rate: float = 0.25
@export var bullet_scene: PackedScene

var player: Node2D = null
var fire_timer: float = 0.0
var spiral_angle: float = 0.0
var is_dying: bool = false

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# Make it bigger
	scale = Vector2(1.4, 1.4)
	
	# Collision setup
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)
	
	setup_visuals()

func setup_visuals():
	# Make it look like a Pentagon
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.1, 0.4) # Neon Pink
		poly.modulate = Color(1.8, 1.2, 1.5, 1.0) # Strong Pink Glow
		var points = PackedVector2Array()
		for i in range(5):
			var angle = (TAU / 5) * i
			points.append(Vector2(25, 0).rotated(angle))
		poly.polygon = points

func _physics_process(delta: float):
	# Spin the body
	rotation += 4.0 * delta
	
	if not player or not is_instance_valid(player):
		return
		
	# Movement: Slow steady approach
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	# Shooting: Spiral pattern
	fire_timer -= delta
	if fire_timer <= 0:
		fire_spiral()
		fire_timer = fire_rate

func fire_spiral():
	if not bullet_scene: return
	
	# Rotate the firing direction over time
	spiral_angle += 0.4
	var dir = Vector2.RIGHT.rotated(spiral_angle)
	
	# Fire 2 bullets in opposite directions
	spawn_bullet(dir)
	spawn_bullet(-dir)

func spawn_bullet(dir: Vector2):
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * 40.0 # Further out
	get_parent().add_child(bullet)
	
	bullet.fired_by_enemy = true # Safety flag
	bullet.direction = dir
	bullet.speed = 350.0 
	bullet.damage = damage
	bullet.add_to_group("enemy_bullets")
	
	# ONLY collide with player (Layer 2)
	bullet.collision_mask = 0
	bullet.set_collision_mask_value(2, true)
	
	# Make it larger
	bullet.scale = Vector2(2.0, 2.0)
	
	if bullet.has_node("BulletSprite"):
		bullet.get_node("BulletSprite").color = Color(0.8, 0.4, 1.0)

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	
	flash_white()
	
	if health <= 0:
		die()

func flash_white():
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)

func die():
	if is_dying: return
	is_dying = true
	
	# Play SFX
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3)
	
	spawn_death_particles()
	
	if player and player.has_method("add_shake"):
		player.add_shake(6.0)
	
	# Give XP directly to player
	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
		
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.total_kills += 1
		gd.run_kills += 1
		gd.add_score(xp_value * 10, player.combo_count if player else 0)
		
	queue_free()

func spawn_death_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.amount = 45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.color = Color(1.0, 0.1, 0.4)
	particles.emitting = true
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)
