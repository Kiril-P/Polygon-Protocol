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
var hits_remaining: int
var time_alive: float = 0.0
var nearest_enemy: Node2D = null
var fired_by_enemy: bool = false # NEW: Track who fired

@onready var sprite: Polygon2D = $BulletSprite
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

func _ready():
	hits_remaining = pierce + 1  # Pierce 0 = hit 1 enemy, pierce 1 = hit 2 enemies
	body_entered.connect(_on_body_entered)
	setup_bullet_shape()
	
	# Connect to screen notifier for auto-cleanup
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float):
	time_alive += delta
	
	# Auto-destroy after lifetime
	if time_alive >= lifetime:
		queue_free()
		return
	
	# Homing behavior
	if homing_strength > 0.0:
		find_nearest_enemy()
		if nearest_enemy:
			var desired_direction = (nearest_enemy.global_position - global_position).normalized()
			direction = direction.lerp(desired_direction, homing_strength * delta * 5.0).normalized()
	
	# Move bullet
	global_position += direction * speed * delta
	
	# Rotate sprite to face direction
	rotation = direction.angle()

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
		if not fired_by_enemy: # Only player bullets hit enemies
			hit_enemy(body)
	elif body.is_in_group("player"):
		if fired_by_enemy: # Only enemy bullets hit player
			hit_player(body)

func hit_player(player_node: Node):
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
		# Bullets always disappear on contact with player
		queue_free()

func hit_enemy(enemy: Node):
	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	
	# Special effects
	if explodes_on_hit:
		create_explosion()
	
	if chain_lightning:
		chain_to_nearby_enemies(enemy)
	
	if splits_on_hit:
		split_bullet()
	
	# Handle pierce/destruction
	hits_remaining -= 1
	if hits_remaining <= 0:
		queue_free()

func create_explosion():
	# Find all enemies in radius and damage them
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.5)  # Explosion does 50% damage
	
	# TODO: Spawn explosion particle effect
	spawn_explosion_visual()

func spawn_explosion_visual():
	# Create simple explosion circle visual
	var explosion = Polygon2D.new()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	explosion.color = Color(1, 0.5, 0, 0.7)
	
	# Circle shape
	var points = PackedVector2Array()
	for i in range(16):
		var angle = (TAU / 16) * i
		points.append(Vector2(explosion_radius, 0).rotated(angle))
	explosion.polygon = points
	
	# Fade out and delete
	var tween = create_tween()
	tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)

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
