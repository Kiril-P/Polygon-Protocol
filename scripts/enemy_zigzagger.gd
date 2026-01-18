extends CharacterBody2D

@export var speed: float = 140.0
@export var health: float = 12.0
@export var damage: float = 5.0
@export var xp_value: int = 10
@export var bullet_scene: PackedScene
@export var amplitude: float = 150.0
@export var frequency: float = 3.0

var player: Node2D = null
var time: float = 0.0
var is_dying: bool = false
var fire_timer: float = 1.5

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	scale = Vector2(1.1, 1.1)
	setup_visuals()
	set_collision_mask_value(2, false)
	set_collision_layer_value(3, true)

func setup_visuals():
	if has_node("Polygon2D"):
		var poly = $Polygon2D
		poly.color = Color(0.8, 1.0, 0.4) # Lime Green
		poly.modulate = Color(1.3, 1.8, 1.2, 1.0) # Glow
		poly.polygon = PackedVector2Array([
			Vector2(15, 0),
			Vector2(-5, 10),
			Vector2(-10, 0),
			Vector2(-5, -10)
		])

func _physics_process(delta: float):
	if is_dying or not player or not is_instance_valid(player): return
	
	time += delta
	var to_player = (player.global_position - global_position).normalized()
	var side_vector = to_player.rotated(PI/2)
	
	# Zigzag movement: forward + sine wave sideways
	var wave = sin(time * frequency) * amplitude
	velocity = (to_player * speed) + (side_vector * wave)
	
	move_and_slide()
	rotation = velocity.angle()
	
	fire_timer -= delta
	if fire_timer <= 0:
		fire_aimed_shot()
		fire_timer = 2.5

func fire_aimed_shot():
	if not bullet_scene or not player: return
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	get_parent().add_child(b)
	b.fired_by_enemy = true
	b.direction = (player.global_position - global_position).normalized()
	b.speed = 300.0
	b.damage = damage
	b.add_to_group("enemy_bullets")
	b.set_collision_mask_value(2, true)
	if b.has_node("BulletSprite"):
		b.get_node("BulletSprite").color = Color(0.8, 1.0, 0.4)

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

func die():
	if is_dying: return
	is_dying = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("enemy_death", 0.0, 0.9, 1.1, 0.3)
	spawn_death_particles()
	if player and player.has_method("add_xp"): player.add_xp(xp_value)
	queue_free()

func spawn_death_particles():
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.8, 1.0, 0.4)
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
