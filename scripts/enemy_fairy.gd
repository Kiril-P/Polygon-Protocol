extends CharacterBody2D

@export var speed: float = 200.0
@export var health: float = 10.0
@export var damage: float = 5.0
@export var xp_value: int = 5
@export var bullet_scene: PackedScene
@export var stop_distance: float = 650.0 # Increased to keep them at the edge

enum State { APPROACH, SHOOT, LEAVE }
var current_state: State = State.APPROACH

var player: Node2D = null
var is_dying: bool = false
var shots_fired: int = 0
var max_shots: int = 3
var fire_timer: float = 1.0
var leave_direction: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	scale = Vector2(0.9, 0.9)
	setup_visuals()
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)

func setup_visuals():
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(1.0, 0.9, 0.0) # Neon Yellow (Distinct from player Cyan)
		poly.modulate = Color(2.0, 1.8, 1.0, 1.0) # Strong Glow
		poly.polygon = PackedVector2Array([
			Vector2(15, 0),
			Vector2(-5, 10),
			Vector2(-10, 0),
			Vector2(-5, -10)
		])

func _physics_process(delta: float):
	if is_dying or not player or not is_instance_valid(player): return
	
	match current_state:
		State.APPROACH:
			var to_player = player.global_position - global_position
			var dist = to_player.length()
			if dist <= stop_distance:
				current_state = State.SHOOT
				velocity = Vector2.ZERO
			else:
				velocity = to_player.normalized() * speed
			rotation = velocity.angle() if velocity.length() > 0 else (player.global_position - global_position).angle()
			
		State.SHOOT:
			# Look at player
			rotation = (player.global_position - global_position).angle()
			fire_timer -= delta
			if fire_timer <= 0:
				fire_shot()
				shots_fired += 1
				if shots_fired >= max_shots:
					current_state = State.LEAVE
					leave_direction = (global_position - player.global_position).normalized()
					if leave_direction == Vector2.ZERO: leave_direction = Vector2.UP.rotated(randf() * TAU)
				else:
					fire_timer = 1.2 # Delay between burst shots (Increased for bigger interval)
			
		State.LEAVE:
			velocity = leave_direction * speed
			rotation = velocity.angle()
			# Despawn when far enough
			if global_position.distance_to(player.global_position) > 1000:
				queue_free()

	move_and_slide()

func fire_shot():
	if not bullet_scene or not player: return
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	get_parent().add_child(b)
	b.fired_by_enemy = true
	b.direction = (player.global_position - global_position).normalized()
	b.speed = 300.0
	b.damage = damage
	b.add_to_group("enemy_bullets")
	b.set_collision_mask_value(1, true)
	b.set_collision_mask_value(2, true)
	if b.has_node("BulletSprite"):
		b.get_node("BulletSprite").color = Color(1.0, 0.9, 0.0) # Match Fairy Yellow

func take_damage(amount: float):
	if is_dying: return
	health -= amount
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_hit")
	flash_white()
	if health <= 0: die()

func flash_white():
	var tween = create_tween()
	tween.tween_property($Polygon2D, "modulate", Color(5, 5, 5, 1), 0.05)
	tween.tween_property($Polygon2D, "modulate", Color(1, 1, 1, 1), 0.05)

func set_xp_value(v):
	xp_value = v

func die():
	if is_dying: return
	is_dying = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3)
	spawn_death_particles()
	if player and player.has_method("add_xp"): player.add_xp(xp_value)
	
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
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.4, 0.8, 1.0)
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
