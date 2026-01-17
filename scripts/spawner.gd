extends Node2D

@export var enemy_types: Array[PackedScene] = []
@export var spawn_rate: float = 1.0 # Reduced from 2.0 to 1.0
@export var spawn_radius: float = 700.0 # Distance from player to spawn

var spawn_timer: float = 0.0
var time_passed: float = 0.0
var player: Node2D = null
var spawn_delay: float = 3.0 # 3 second safety window at start

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float):
	time_passed += delta
	
	if time_passed < spawn_delay:
		return

	# Gradually increase spawn rate (10% every minute instead of 15%)
	var current_spawn_rate = spawn_rate * (1.0 + ((time_passed - spawn_delay) / 60.0) * 0.10)
	
	spawn_timer += delta
	if spawn_timer >= 1.0 / current_spawn_rate:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	if enemy_types.is_empty():
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	# Pickup random enemy based on time
	var index = 0
	var rand = randf()
	
	# 0: Chaser, 1: Drifter (Easy), 2: Shooter (Hard), 3: Spinner, 4: Tank
	if time_passed < 45: # Very early: 100% Chaser
		index = 0
	elif time_passed < 90: # Early: Introduce Drifter
		index = 0 if rand < 0.6 else 1
	elif time_passed < 180: # Mid: More Drifters, still no shooters
		index = 0 if rand < 0.4 else 1
	elif time_passed < 300: # Late Mid: Shooters finally appear
		if rand < 0.3: index = 0
		elif rand < 0.6: index = 1
		else: index = 2
	else: # End Game: All types including Spinner and Tank
		if rand < 0.2: index = 0
		elif rand < 0.4: index = 1
		elif rand < 0.6: index = 2
		elif rand < 0.8: index = 3
		else: index = 4
	
	# Safety check for array size
	index = clamp(index, 0, enemy_types.size() - 1)
	
	var enemy_scene = enemy_types[index]
	if not enemy_scene: return

	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(spawn_radius, 0).rotated(angle)
	
	var enemy = enemy_scene.instantiate()
	# SET POSITION BEFORE ADD_CHILD
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)