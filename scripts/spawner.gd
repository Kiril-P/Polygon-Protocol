extends Node2D

@export var enemy_types: Array[PackedScene] = []
@export var spawn_rate: float = 2.0
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

	# Gradually increase spawn rate (Increasing scaling hardness)
	var current_spawn_rate = spawn_rate * (1.0 + ((time_passed - spawn_delay) / 60.0) * 0.5)
	
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

	var available_indices = []
	
	# 0: Chaser, 1: Fairy, 2: Shooter, 3: Spinner, 4: Tank, 5: Zigzagger
	if time_passed < 40: # Phase 1: Early Game Stagger (0-40s)
		available_indices.append(0) # Chasers (3s+)
		if time_passed >= 10:
			available_indices.append(1) # Fairies at 10s
		if time_passed >= 25:
			available_indices.append(5) # Zigzaggers at 25s
			
	elif time_passed < 80: # Phase 2: Mid Game Stagger (40-80s)
		# Early enemies still possible but less common
		available_indices.append_array([0, 1, 5])
		
		# Introduce mid/late enemies one by one
		if time_passed >= 42:
			for i in range(3): available_indices.append(3) # Spinners at 42s
		if time_passed >= 55:
			for i in range(3): available_indices.append(4) # Tanks at 55s
		if time_passed >= 65:
			for i in range(4): available_indices.append(2) # Shooters at 65s (Late game threat)
	else: # Phase 3: Total Chaos (80s+)
		# Full weighted mix
		available_indices = [0, 1, 5, 2, 2, 3, 3, 4, 4]

	var index = available_indices[randi() % available_indices.size()]
	
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