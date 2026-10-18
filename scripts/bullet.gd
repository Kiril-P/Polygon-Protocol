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
var trail: Line2D = null
const TRAIL_POINTS: int = 12
var hit_enemies: Array[RID] = [] # NEW: Avoid hitting same enemy multiple times
var hits_remaining: int = -1 # Lazily initialised on first hit: pierce is assigned after add_child()
var time_alive: float = 0.0
var nearest_enemy: Node2D = null
var retarget_timer: float = 0.0
const RETARGET_INTERVAL: float = 0.1
var fired_by_enemy: bool = false 
var synergies: Dictionary = {} # Active upgrade synergies, set by the player
var generation: int = 0 # 0 = fired by player, 1+ = split children
var breaker: bool = false # Cracks Aegis shields instead of being absorbed
var corrupts: bool = false # Hits disrupt enemy healing

@onready var sprite: Polygon2D = $BulletSprite
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

func _ready():
	body_entered.connect(_on_body_entered)
	setup_bullet_shape()
	
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
		
	# Check for initial overlap (if spawned inside a platform)
	# Immediate check is better using a call_deferred or similar
	call_deferred("_check_initial_collision")

func _check_initial_collision():
	if is_instance_valid(self):
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.collision_layer & 1: # Hits Layer 1
				_on_body_entered(body)
				break

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
		retarget_timer -= delta
		if retarget_timer <= 0.0 or not is_instance_valid(nearest_enemy):
			find_nearest_enemy()
			retarget_timer = RETARGET_INTERVAL
		if nearest_enemy:
			var desired_direction = (nearest_enemy.global_position - global_position).normalized()
			direction = direction.lerp(desired_direction, homing_strength * delta * 5.0).normalized()
	
	global_position += direction * speed * delta
	rotation = direction.angle()
	
	_update_trail()

## Comet trail: one Line2D per bullet instead of a ghost polygon every 50ms.
func _update_trail():
	if not trail:
		_setup_glow()
	trail.add_point(global_position)
	while trail.get_point_count() > TRAIL_POINTS:
		trail.remove_point(0)

func _setup_glow():
	var color: Color = sprite.color
	Neon.add_glow(self, color, 30.0 if not fired_by_enemy else 40.0, 0.2)
	sprite.color = color.lerp(Color.WHITE, 0.2)
	trail = Line2D.new()
	trail.top_level = true # Points are world-space; outlives the bullet for a fade-out
	trail.material = Neon.additive_material()
	trail.width = 4.5 * scale.x
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = curve
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r * 1.1, color.g * 1.1, color.b * 1.1, 0.5)])
	trail.gradient = grad
	trail.z_index = -1
	get_parent().add_child(trail)

func _exit_tree():
	if is_instance_valid(trail) and trail.is_inside_tree():
		var t := trail.create_tween()
		t.tween_property(trail, "modulate:a", 0.0, 0.2)
		t.tween_callback(trail.queue_free)

func handle_screen_bounce():
	var camera = get_viewport().get_camera_2d()
	var pos = global_position
	var bounced = false
	
	if not camera:
		# Fallback to simple viewport if no camera
		var screen_rect = get_viewport_rect()
		var margin = 10.0
		if pos.x < margin and direction.x < 0: direction.x *= -1; bounced = true
		elif pos.x > screen_rect.size.x - margin and direction.x > 0: direction.x *= -1; bounced = true
		if pos.y < margin and direction.y < 0: direction.y *= -1; bounced = true
		elif pos.y > screen_rect.size.y - margin and direction.y > 0: direction.y *= -1; bounced = true
		if bounced: _on_bounced()
		return

	var viewport_size = get_viewport_rect().size
	var camera_center = camera.get_screen_center_position()
	var zoom = camera.zoom
	var visible_size = viewport_size / zoom
	var visible_rect = Rect2(camera_center - visible_size / 2, visible_size)
	
	var margin_v = 15.0
	
	if pos.x < visible_rect.position.x + margin_v and direction.x < 0:
		direction.x *= -1
		bounced = true
	elif pos.x > visible_rect.end.x - margin_v and direction.x > 0:
		direction.x *= -1
		bounced = true
		
	if pos.y < visible_rect.position.y + margin_v and direction.y < 0:
		direction.y *= -1
		bounced = true
	elif pos.y > visible_rect.end.y - margin_v and direction.y > 0:
		direction.y *= -1
		bounced = true
	
	if bounced:
		_on_bounced()

func _on_bounced():
	bounces -= 1
	rotation = direction.angle()
	AudioManager.play_sfx("bullet_bounce", -5.0)

	var tween = create_tween()
	sprite.modulate = GameSettings.flash(Color(5, 5, 5, 1))
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

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
	
	# Make sure Area2D can detect bodies (Enemies are CharacterBody2D)
	collision_layer = 0
	set_collision_mask_value(1, true) # Layer 1 is World/Platforms
	set_collision_mask_value(2, true) # Layer 2 is Player
	set_collision_mask_value(3, true) # Layer 3 is Enemies

func find_nearest_enemy():
	nearest_enemy = null
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_distance = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if synergies.has("hunter_killer") and enemy.get_rid() in hit_enemies:
			continue # Hunter-Killer: retarget after each pierce
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearest_enemy = enemy

func _on_body_entered(body: Node):
	if body.is_in_group("enemies"):
		if not fired_by_enemy:
			hit_enemy(body)
	elif body.is_in_group("player"):
		if fired_by_enemy:
			hit_player(body)
	elif body.collision_layer & 1: # Hits Layer 1 (World/Platforms)
		# No more bouncing off platforms - just die to keep screen clear
		AudioManager.play_sfx("bullet_bounce", -15.0)
		queue_free()

func hit_player(player_node: Node):
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
		queue_free()

func hit_enemy(enemy: Node):
	if hits_remaining < 0:
		hits_remaining = pierce + 1
	hit_enemies.append(enemy.get_rid())
	var blocked := false
	# KINETIC DAMAGE: Bonus damage based on speed (Base speed is ~400)
	var speed_mult = 1.0 + max(0, (speed - 400.0) / 600.0)
	if enemy.has_method("hit_by_bullet"):
		blocked = enemy.hit_by_bullet(damage * speed_mult, self)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damage * speed_mult)
	if corrupts and not blocked and enemy.has_method("corrupt"):
		enemy.corrupt(3.0)
	
	if explodes_on_hit:
		create_explosion()
	
	if chain_lightning:
		chain_to_nearby_enemies(enemy)
	
	if splits_on_hit:
		split_bullet.call_deferred() # Cannot add Area2Ds while physics queries flush
	
	# BOUNCE OFF ENEMIES
	if bounces > 0:
		# Bounce direction away from enemy center
		var bounce_dir = (global_position - enemy.global_position).normalized()
		# Combine with current direction for a more "glancing" bounce
		direction = (direction.bounce(bounce_dir) + bounce_dir * 0.2).normalized()
		_on_bounced()
		# Add a bit of "safe" distance to prevent re-colliding immediately
		global_position += direction * 5.0
		return # Don't process pierce if we bounced
	
	if blocked:
		hits_remaining = 1 # Absorbed by a shield: the bullet is spent whatever its pierce
	hits_remaining -= 1
	if hits_remaining <= 0:
		queue_free()
	else:
		# Visual feedback for piercing (flicker)
		var tween = create_tween()
		sprite.modulate.a = 0.3
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

func create_explosion():
	# Play SFX - Reduced volume as requested
	AudioManager.play_sfx("bullet_explosion", -8.0)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.5)
	
	if synergies.has("chain_reaction"):
		chain_from(global_position, null, 0.5)
	spawn_explosion_visual()

func spawn_explosion_visual():
	# Parent to main scene so it survives if bullet/parent is deleted
	var main = get_tree().current_scene
	
	VFX.shockwave(global_position, 0.7, Color(1.0, 0.55, 0.15), explosion_radius * 2.2)
	
	# 1. THE CORE FLASH (Cyan/White)
	var flash = Polygon2D.new()
	main.add_child(flash)
	flash.global_position = global_position
	flash.color = Color(1, 1, 1, 1)
	var points = PackedVector2Array()
	for i in range(16):
		points.append(Vector2(5, 0).rotated(TAU/16 * i))
	flash.polygon = points
	
	# Use scene tree tween for guaranteed cleanup
	var flash_tween = get_tree().create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(explosion_radius/4.0, explosion_radius/4.0), 0.1)
	flash_tween.tween_property(flash, "modulate", Color(0, 0.8, 1, 0), 0.2).set_delay(0.05)
	flash_tween.set_parallel(false)
	flash_tween.tween_callback(flash.queue_free)
	
	# 2. INNER SPARKS (Orange/Yellow)
	var sparks = CPUParticles2D.new()
	main.add_child(sparks)
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
	
	# 3. OUTER SHOCKWAVE (Purple/Magenta)
	var wave = CPUParticles2D.new()
	main.add_child(wave)
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

	# Guaranteed cleanup
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(sparks): sparks.queue_free()
		if is_instance_valid(wave): wave.queue_free()
	)
	
	# Screen shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_shake"):
		player.add_shake(12.0)

func chain_to_nearby_enemies(source_enemy: Node):
	chain_from(source_enemy.global_position, source_enemy, 0.7)

## Arcs lightning from `origin` to up to 3 nearby enemies (excluding `source`).
func chain_from(origin: Vector2, source: Node, damage_fraction: float):
	var chained = 0
	var max_chains = 3
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if chained >= max_chains:
			break
		if not is_instance_valid(enemy) or enemy == source:
			continue
		if origin.distance_to(enemy.global_position) <= chain_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * damage_fraction)
			if synergies.has("plague_arc") and enemy.has_method("corrupt"):
				enemy.corrupt(3.0)
			spawn_lightning_visual(origin, enemy.global_position)
			chained += 1

func spawn_lightning_visual(from: Vector2, to: Vector2):
	var lightning = Line2D.new()
	get_parent().add_child(lightning)
	lightning.add_point(from)
	lightning.add_point(to)
	lightning.width = 2.0
	lightning.default_color = Color(0.5, 0.5, 1.0, 0.8)
	
	# Delete after brief flash
	# Tween lives on the lightning itself: the bullet is usually freed right after chaining,
	# which would kill a bullet-bound tween and leave the arc on screen forever.
	var tween = lightning.create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.15)
	tween.tween_callback(lightning.queue_free)

func split_bullet():
	# Create 2 bullets at angles
	for i in range(2):
		var new_bullet = load("res://scenes/bullet.tscn").instantiate()
		get_parent().add_child(new_bullet)
		new_bullet.global_position = global_position
		
		# Angle offset
		var angle_offset = PI / 4 if i == 0 else -PI / 4
		new_bullet.direction = direction.rotated(angle_offset)
		new_bullet.speed = speed * 0.8
		new_bullet.damage = damage * 0.6
		new_bullet.pierce = max(0, pierce - 1)
		new_bullet.generation = generation + 1
		new_bullet.homing_strength = homing_strength
		new_bullet.synergies = synergies
		# Storm Front: fractured bullets keep arcing lightning
		if synergies.has("storm_front"):
			new_bullet.chain_lightning = chain_lightning
			new_bullet.chain_range = chain_range
		
		# Don't let split bullets split again (prevent infinite bullets)
		new_bullet.splits_on_hit = false

func _on_screen_exited():
	if bounces <= 0:
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
