extends Area2D

# Bullet properties
var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: float = 10.0
var pierce: int = 0  # How many enemies it can hit before dying
var lifetime: float = 5.0  # Auto-destroy after 5 seconds

# Upgrade effects
var explodes_on_hit: bool = false
var explosion_radius: float = 50.0
var splits_on_hit: bool = false
var bounces: int = 0
var homing_strength: float = 0.0  # 0 = no homing, 1 = full homing
var chain_lightning: bool = false
var chain_range: float = 100.0

# Internal
var hit_enemies: Array[RID] = [] # NEW: Avoid hitting same enemy multiple times
var hits_remaining: int
var time_alive: float = 0.0
var nearest_enemy: Node2D = null
var fired_by_enemy: bool = false 

@onready var sprite: Polygon2D = $BulletSprite
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

func _ready():
	hits_remaining = pierce + 1
	body_entered.connect(_on_body_entered)
	setup_bullet_shape()

func _physics_process(delta: float):
	time_alive += delta
	
	if time_alive >= lifetime:
		queue_free()
		return
	
	# Bounce logic
	if bounces > 0:
		handle_screen_bounce()
	
	# Homing behavior
	if homing_strength > 0.0:
		find_nearest_enemy()
		if nearest_enemy:
			var desired_direction = (nearest_enemy.global_position - global_position).normalized()
			direction = direction.lerp(desired_direction, homing_strength * delta * 5.0).normalized()
	
	global_position += direction * speed * delta
	rotation = direction.angle()

func handle_screen_bounce():
	var screen_rect = get_viewport_rect()
	var pos = global_position
	
	var margin = 10.0
	if pos.x < margin and direction.x < 0:
		direction.x *= -1
		bounces -= 1
	elif pos.x > screen_rect.size.x - margin and direction.x > 0:
		direction.x *= -1
		bounces -= 1
		
	if pos.y < margin and direction.y < 0:
		direction.y *= -1
		bounces -= 1
	elif pos.y > screen_rect.size.y - margin and direction.y > 0:
		direction.y *= -1
		bounces -= 1

func setup_bullet_shape():
	# Simple diamond/arrow shape - Made 50% bigger
	var points = PackedVector2Array([
		Vector2(12, 0),
		Vector2(3, 4.5),
		Vector2(-6, 0),
		Vector2(3, -4.5)
	])
	sprite.polygon = points
	collision.polygon = points
	
	# Set a bright color
	sprite.color = Color(0.0, 0.9, 1.0) # Neon Cyan

func find_nearest_enemy():
	nearest_enemy = null
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_distance = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearest_enemy = enemy

func _on_body_entered(body: Node):
	if body.is_in_group("enemies"):
		if not fired_by_enemy:
			if not hit_enemies.has(body.get_rid()):
				hit_enemies.append(body.get_rid())
				hit_enemy(body)
	elif body.is_in_group("player"):
		if fired_by_enemy:
			hit_player(body)

func hit_player(player_node: Node):
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
		queue_free()

func hit_enemy(enemy: Node):
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	if explodes_on_hit:
		create_explosion()
	
	if chain_lightning:
		chain_to_nearby_enemies(enemy)
	
	if splits_on_hit:
		split_bullet()
	
	hits_remaining -= 1
	if hits_remaining <= 0:
		queue_free()

func create_explosion():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.5)
	
	spawn_explosion_visual()

func spawn_explosion_visual():
	# Use a list to track all created effects for safety
	var effects = []

	# 1. THE CORE FLASH (Cyan/White)
	var flash = Polygon2D.new()
	get_tree().current_scene.add_child(flash) # Parent to scene, not parent (which might be deleted)
	flash.global_position = global_position
	flash.color = Color(1, 1, 1, 1)
	var points = PackedVector2Array()
	for i in range(16):
		points.append(Vector2(5, 0).rotated(TAU/16 * i))
	flash.polygon = points
	effects.append(flash)
	
	# Use scene tree tween so it survives bullet deletion
	var flash_tween = get_tree().create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(explosion_radius/4.0, explosion_radius/4.0), 0.1)
	flash_tween.tween_property(flash, "modulate", Color(0, 0.8, 1, 0), 0.2).set_delay(0.05)
	flash_tween.set_parallel(false)
	flash_tween.tween_callback(flash.queue_free)
	
	# 2. INNER SPARKS (Orange/Yellow)
	var sparks = CPUParticles2D.new()
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = global_position
	sparks.amount = 25
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 100.0
	sparks.initial_velocity_max = 250.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 5.0
	sparks.color = Color(1.0, 0.5, 0.0) # Bright Orange
	sparks.emitting = true
	effects.append(sparks)
	
	# 3. OUTER SHOCKWAVE (Purple/Magenta)
	var wave = CPUParticles2D.new()
	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position
	wave.amount = 15
	wave.one_shot = true
	wave.explosiveness = 1.0
	wave.spread = 180.0
	wave.gravity = Vector2.ZERO
	wave.initial_velocity_min = 200.0
	wave.initial_velocity_max = 350.0
	wave.scale_amount_min = 3.0
	wave.scale_amount_max = 6.0
	wave.color = Color(0.8, 0.0, 1.0) # Neon Purple
	wave.emitting = true
	effects.append(wave)

	# Safety cleanup for particles
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)
	get_tree().create_timer(1.0).timeout.connect(wave.queue_free)
	
	# Screen shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_shake"):
		player.add_shake(12.0)

func chain_to_nearby_enemies(source_enemy: Node):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var chained = 0
	var max_chains = 3
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == source_enemy:
			continue
		if chained >= max_chains:
			break
		
		var distance = source_enemy.global_position.distance_to(enemy.global_position)
		if distance <= chain_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.7)  # Chain does 70% damage
			spawn_lightning_visual(source_enemy.global_position, enemy.global_position)
			chained += 1

func spawn_lightning_visual(from: Vector2, to: Vector2):
	var lightning = Line2D.new()
	get_parent().add_child(lightning)
	lightning.add_point(from)
	lightning.add_point(to)
	lightning.width = 2.0
	lightning.default_color = Color(0.5, 0.5, 1.0, 0.8)
	
	# Delete after brief flash
	var tween = create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.15)
	tween.tween_callback(lightning.queue_free)

func split_bullet():
	# Create 2 bullets at angles
	var bullet_scene = load("res://scenes/bullet.tscn")
	for i in range(2):
		var new_bullet = bullet_scene.instantiate()
		get_parent().add_child(new_bullet)
		new_bullet.global_position = global_position
		
		# Angle offset
		var angle_offset = PI / 4 if i == 0 else -PI / 4
		new_bullet.direction = direction.rotated(angle_offset)
		new_bullet.speed = speed * 0.8
		new_bullet.damage = damage * 0.6
		new_bullet.pierce = max(0, pierce - 1)
		
		# Don't let split bullets split again (prevent infinite bullets)
		new_bullet.splits_on_hit = false

func _on_screen_exited():
	queue_free()

# Helper function to apply upgrades from player
func apply_upgrade(upgrade_name: String, value):
	match upgrade_name:
		"explode":
			explodes_on_hit = true
			explosion_radius = value
		"split":
			splits_on_hit = true
		"bounce":
			bounces = value
		"homing":
			homing_strength = value
		"chain":
			chain_lightning = true
			chain_range = value
