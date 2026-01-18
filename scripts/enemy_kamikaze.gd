extends CharacterBody2D

@export var speed: float = 250.0
@export var health: float = 12.0 # Squishy but dangerous
@export var damage: float = 1.0 # 1 Heart (direct damage in take_damage)
@export var xp_value: int = 25
@export var charge_speed_mult: float = 2.5
@export var detect_range: float = 300.0

var player: Node2D = null
var is_dying: bool = false
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO

@onready var sprite = $Polygon2D

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# Small and fast
	scale = Vector2(0.8, 0.8)
	
	if has_node("Polygon2D"):
		sprite.color = Color(1.0, 0.8, 0.0) # Yellow initially
		sprite.modulate = Color(2.0, 1.5, 0.0, 1.0) # Bright glow
	
	# Difficulty scaling
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		var level = gd.difficulty_level
		var speed_mults = [0.0, 0.8, 1.0, 1.1, 1.2, 1.4]
		speed *= speed_mults[level]
		health *= [0.0, 0.7, 1.0, 1.3, 1.6, 2.0][level]

func _physics_process(delta: float):
	if is_dying: return
	
	if not player or not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)
	
	if not is_charging and dist < detect_range:
		start_charge()
	
	if is_charging:
		# Very fast movement in fixed direction
		velocity = charge_direction * speed * charge_speed_mult
		rotation += 15.0 * delta # Spin wildly
		
		# Pulsate red
		var pulse = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
		sprite.color = Color(1.0, 0.8, 0.0).lerp(Color(1.0, 0.0, 0.0), pulse)
		sprite.modulate = Color(2.0, 1.0, 1.0).lerp(Color(5.0, 1.0, 1.0), pulse)
	else:
		# Normal chase
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
		rotation += 5.0 * delta
		
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			explode()
		elif is_charging:
			# If charging and hits anything else, explode too
			explode()

func start_charge():
	is_charging = true
	charge_direction = (player.global_position - global_position).normalized()
	
	# Visual/Sound cue for charging
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	t.tween_property(self, "scale", Vector2(0.8, 0.8), 0.1)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("boss_spawn", -10.0, 1.5, 2.0)

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_hit")
	
	# Flash
	var t = create_tween()
	sprite.modulate = Color(10, 10, 10, 1)
	t.tween_property(sprite, "modulate", Color(2.0, 1.5, 0.0, 1.0), 0.1)
	
	if health <= 0:
		die()

func explode():
	if is_dying: return
	is_dying = true
	
	# Damage player if close
	if player and global_position.distance_to(player.global_position) < 80.0:
		if player.has_method("take_damage"):
			player.take_damage(1) # 1 Heart
	
	# Visual/Sound
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("bullet_explosion", -5.0)
	
	spawn_explosion_particles()
	
	if player and player.has_method("add_shake"):
		player.add_shake(20.0)
		
	queue_free()

func spawn_explosion_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color = Color(1.0, 0.4, 0.0) # Orange explosion
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func die():
	if is_dying: return
	is_dying = true
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3)
	
	spawn_explosion_particles()
	
	if player and player.has_method("add_xp"):
		player.add_xp(xp_value)
		
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		gd.total_kills += 1
		gd.run_kills += 1
		
	queue_free()

func set_xp_value(v): xp_value = v
