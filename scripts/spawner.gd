class_name Spawner
extends Node2D

@export var enemy_types: Array[PackedScene] = []
@export var spawn_rate: float = 2.0
@export var spawn_radius: float = 700.0 # Distance from player to spawn

var spawn_timer: float = 0.0
var time_passed: float = 0.0
var player: Node2D = null
var spawn_delay: float = 3.0 # 3 second safety window at start
var tutorial_finished: bool = false
var hazard_timer: float = 0.0
const HAZARD_INTERVAL: float = 12.0

var boss_active: bool = false
var corruption_warning_shown: bool = false
var choice_active: bool = false
var choice_made: bool = false # The player answered the current encounter's choice
var bosses_done: bool = false # Declined the 6:00 fight: endless mode, no more bosses
var encounter_index: int = 0 # Next entry of the boss schedule (see _encounter)
var warned_index: int = -1 # Encounter whose 10-second warning was already shown
## Real run clock: ticks through boss fights too. `time_passed` is the "wave clock"
## (it pauses during bosses, so enemy mix, events and boss times are measured in fighting time).
var elapsed: float = 0.0

# Index of each enemy in the `enemy_types` array (matches scenes/game.tscn)
const ENEMY_INDEX := {"chaser": 0, "fairy": 1, "shooter": 2, "spinner": 3, "tank": 4, "zigzagger": 5, "kamikaze": 6, "aegis": 7, "splitter": 8, "sniper": 9, "healer": 10}
## Boss schedule in wave-clock seconds. `choice` offers the player a way out (endless mode).
const BOSS_LADDER := [
	{"at": 80, "bosses": ["fortress"]},
	{"at": 180, "bosses": ["pulsar"]},
	{"at": 360, "bosses": ["fortress", "pulsar"], "choice": true},
	{"at": 600, "bosses": ["singularity"]},
	{"at": 900, "bosses": ["prism"]},
]
## After the ladder a pair of bosses arrives every BOSS_LOOP_EVERY seconds, tougher each lap.
const BOSS_LOOP_EVERY := 360.0
const BOSS_LOOP := [["pulsar", "singularity"], ["fortress", "prism"], ["singularity", "prism"]]
const ENDLESS_BONUS := 1.25

var director := SpawnDirector.new()

func _ready():
	add_to_group("spawner")
	director.load_data()
	director.apply_run(GlobalData.run_mode, GlobalData.run_protocols, Protocols.daily_seed(GlobalData.run_daily_key))
	player = get_tree().get_first_node_in_group("player")
	
	# Check if tutorial is disabled to start spawning immediately
	if not GlobalData.show_tutorial:
		tutorial_finished = true

func _process(delta: float):
	if not tutorial_finished:
		return
	elapsed += delta

	boss_active = get_tree().get_nodes_in_group("bosses").size() > 0 or choice_active
	if not boss_active:
		time_passed += delta
		_check_boss_schedule()
		boss_active = get_tree().get_nodes_in_group("bosses").size() > 0 or choice_active

	# Reduced safety window after tutorial/start
	var current_delay = spawn_delay
	if GlobalData.is_first_run:
		current_delay = 0.5 # Start almost immediately
	elif tutorial_finished:
		current_delay = 0.2 # Start spawning almost immediately after tutorial/start
	
	if time_passed < current_delay:
		return

	# Spawn rate ramps up quickly until 4:00, then stays flat: from there the enemy cap is the
	# limit, so late difficulty comes from enemy stats, the mix and the cap (see below).
	var t_rate := minf(time_passed, 240.0)
	var time_factor = (t_rate - spawn_delay) / 60.0
	var scaling = 1.0 + (time_factor * 0.5)
	if t_rate > 60.0:
		scaling += pow((t_rate - 60.0) / 60.0, 1.4) * 1.2

	var multipliers = [0.0, 0.7, 1.0, 1.5, 2.0, 3.0]
	var difficulty_mult: float = multipliers[GlobalData.difficulty_level]

	var base_spawn_rate = spawn_rate * difficulty_mult * scaling
	var hearts_ratio = 1.0
	if player and is_instance_valid(player):
		hearts_ratio = float(player.current_hearts) / maxf(1.0, float(player.max_hearts))
	if not boss_active:
		# The director reads kill rate against a rate the cap can actually sustain
		director.update(delta, time_passed, hearts_ratio, GlobalData.run_kills, minf(base_spawn_rate, 6.0))
	var current_spawn_rate = base_spawn_rate * director.rate_multiplier()
	if GlobalData.protocol_active("swarm"):
		current_spawn_rate *= 1.4

	if not boss_active:
		spawn_timer += delta
		if spawn_timer >= 1.0 / current_spawn_rate:
			spawn_timer = 0.0
			if director.spawn_allowed(get_tree().get_nodes_in_group("enemies").size(), time_passed):
				spawn_enemy()

		if not _near_boss_milestone():
			for ev in director.due_events(time_passed):
				_spawn_event(ev)

	if not boss_active:
		# Hazard Spawning
		hazard_timer += delta
		if hazard_timer >= HAZARD_INTERVAL:
			spawn_hazard()
			hazard_timer = 0.0

func spawn_hazard():
	if not player: return
	
	# Show warning on first hazard if tutorial is on
	if not corruption_warning_shown:
		if GlobalData.show_tutorial:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_corruption_warning"):
				hud.show_corruption_warning()
		corruption_warning_shown = true

	AudioManager.play_sfx("glitch", 5.0, 0.5, 0.8) # Increased volume from -5.0 to 5.0

	# Spawn hazard somewhere nearby but not right on top of player
	var angle = randf() * TAU
	var dist = randf_range(200, 500)
	var pos = player.global_position + Vector2(dist, 0).rotated(angle)
	
	var hazard = Area2D.new()
	hazard.script = load("res://scripts/data_corruption.gd")
	
	# Add components needed by script BEFORE add_child so _ready works
	var poly = Polygon2D.new()
	poly.name = "Polygon2D"
	hazard.add_child(poly)
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 1.0 
	collision.shape = shape
	hazard.add_child(collision)
	
	hazard.global_position = pos
	get_parent().add_child(hazard)
	
	# Set collision mask to detect player, enemies, AND bullets
	hazard.collision_layer = 0
	hazard.collision_mask = 0
	hazard.set_collision_mask_value(2, true) # Player
	hazard.set_collision_mask_value(3, true) # Enemies
	hazard.monitorable = true
	hazard.monitoring = true

## True shortly before the next boss, so formations never stack on the boss warning.
func _near_boss_milestone() -> bool:
	if bosses_done:
		return false
	var buffer := float(director.cfg.get("event_boss_buffer_seconds", 12.0))
	return time_passed >= float(_encounter(encounter_index)["at"]) - buffer

## Boss schedule entry `i`: {at, bosses, choice, loop}. Past the ladder it repeats BOSS_LOOP.
func _encounter(i: int) -> Dictionary:
	if i < BOSS_LADDER.size():
		var e: Dictionary = BOSS_LADDER[i].duplicate()
		e["loop"] = 0
		return e
	var j := i - BOSS_LADDER.size()
	return {
		"at": float(BOSS_LADDER[BOSS_LADDER.size() - 1]["at"]) + BOSS_LOOP_EVERY * (j + 1),
		"bosses": BOSS_LOOP[j % BOSS_LOOP.size()],
		"loop": j / BOSS_LOOP.size() + 1,
	}

func _check_boss_schedule():
	if bosses_done or not player or not is_instance_valid(player):
		return
	var enc := _encounter(encounter_index)
	var at := float(enc["at"])
	if warned_index != encounter_index and time_passed >= at - 10.0:
		warned_index = encounter_index
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_boss_warning"):
			hud.show_boss_warning(10, BossTable.get_def(enc["bosses"][0]).get("title", ""))
			AudioManager.play_sfx("boss_warning")
	if time_passed < at:
		return
	if enc.get("choice", false) and not choice_made:
		if not choice_active:
			spawn_6min_choice(enc["bosses"])
		return
	spawn_encounter(enc["bosses"], int(enc["loop"]))
	encounter_index += 1
	choice_made = false

## Debug helper: moves both clocks and re-points the schedule at the next boss.
func jump_to(seconds: float):
	time_passed = seconds
	elapsed = maxf(elapsed, seconds)
	choice_active = false
	choice_made = false
	bosses_done = false
	encounter_index = 0
	while float(_encounter(encounter_index)["at"]) <= seconds:
		encounter_index += 1
	warned_index = -1

func reset_clock():
	time_passed = 0.0
	elapsed = 0.0

## Distance from the player at which enemies appear (just off-screen, camera-zoom aware).
func _current_spawn_radius() -> float:
	if player and player.has_node("Camera2D"):
		var zoom = player.get_node("Camera2D").zoom.x
		# Zoom 1.0 -> 700; zoomed out to 0.5 -> 1400. Small buffer keeps them off-screen.
		return (spawn_radius / zoom) + 100.0
	return spawn_radius

func spawn_enemy():
	if enemy_types.is_empty():
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	var lookahead := 60.0 if GlobalData.protocol_active("vanguard") else 0.0
	var index: int = ENEMY_INDEX.get(director.pick_enemy(time_passed + lookahead), 0)
	var angle = randf() * TAU
	
	# ANTI-KITING: 30% chance to spawn specifically in front of the player's movement
	if player.velocity.length() > 10.0 and randf() < 0.3:
		# Cone of 90 degrees in front
		angle = player.velocity.normalized().angle() + randf_range(-PI/4, PI/4)
	
	_spawn_enemy_at(index, player.global_position + Vector2(_current_spawn_radius(), 0).rotated(angle))

## Instantiates enemy `index` at `pos`. `mods` may hold health_mult, xp_mult, scale_mult.
func _spawn_enemy_at(index: int, pos: Vector2, mods: Dictionary = {}) -> Node:
	index = clamp(index, 0, enemy_types.size() - 1)
	var enemy_scene = enemy_types[index]
	if not enemy_scene:
		return null
	
	var enemy = enemy_scene.instantiate()
	# SET POSITION BEFORE ADD_CHILD
	enemy.global_position = pos
	
	# Scale XP based on time passed
	var base_xp = enemy.xp_value if "xp_value" in enemy else 10
	var scaled_xp = base_xp * (1.0 + (time_passed / 60.0)) * mods.get("xp_mult", 1.0)
	if enemy.has_method("set_xp_value"):
		enemy.set_xp_value(int(scaled_xp))
	if "health" in enemy:
		enemy.health *= mods.get("health_mult", 1.0) * health_scale()
		if GlobalData.protocol_active("swarm"):
			enemy.health *= 0.75
	
	get_parent().add_child(enemy)
	if "speed" in enemy:
		enemy.speed *= speed_scale()
		if GlobalData.protocol_active("hunters"):
			enemy.speed *= 1.25
	# Enemy scripts set their own scale in _ready(), so apply size changes afterwards
	if mods.has("scale_mult"):
		enemy.scale *= mods["scale_mult"]
	return enemy

## Late-run toughness: the spawn rate stops growing at 4:00, so enemies get tougher instead.
func health_scale() -> float:
	return 1.0 + maxf(0.0, time_passed - 240.0) / 900.0 # 2x at 19:00

func speed_scale() -> float:
	return 1.0 + clampf((time_passed - 300.0) / 1200.0, 0.0, 0.3)

## Runs a scheduled event from spawn_waves.json (elite / ring / wall / pincer).
func _spawn_event(ev: Dictionary):
	if not player or not is_instance_valid(player) or enemy_types.is_empty():
		return
	var index: int = ENEMY_INDEX.get(ev.get("enemy", "chaser"), 0)
	var count: int = director.event_count(ev, time_passed)
	var radius = _current_spawn_radius()
	var origin = player.global_position
	var base_angle = randf() * TAU
	if player.velocity.length() > 10.0:
		base_angle = player.velocity.angle() # Cut the player off
	
	match ev.get("type", ""):
		"elite":
			AudioManager.play_sfx("elite_spawn")
			_spawn_enemy_at(index, origin + Vector2(radius, 0).rotated(base_angle), {
				"scale_mult": ev.get("scale_mult", 1.0),
				"health_mult": ev.get("health_mult", 1.0),
				"xp_mult": ev.get("xp_mult", 1.0),
			})
		"ring":
			AudioManager.play_sfx("glitch", -3.0, 0.9, 1.1)
			for i in count:
				_spawn_enemy_at(index, origin + Vector2(radius, 0).rotated(base_angle + TAU * i / count))
		"wall":
			AudioManager.play_sfx("glitch", -3.0, 0.9, 1.1)
			var spacing: float = ev.get("spacing", 90.0)
			var center = origin + Vector2(radius, 0).rotated(base_angle)
			var along = Vector2.RIGHT.rotated(base_angle + PI / 2.0)
			for i in count:
				_spawn_enemy_at(index, center + along * spacing * (i - (count - 1) / 2.0))
		"squad":
			# A Mender with an escort fanned out around it
			AudioManager.play_sfx("glitch", -3.0, 0.9, 1.1)
			var escort: int = ENEMY_INDEX.get(ev.get("escort", "chaser"), 0)
			var centre = origin + Vector2(radius, 0).rotated(base_angle)
			_spawn_enemy_at(index, centre)
			for i in count:
				_spawn_enemy_at(escort, centre + Vector2(90.0, 0).rotated(TAU * i / maxi(count, 1)))
		"pincer":
			AudioManager.play_sfx("glitch", -3.0, 0.9, 1.1)
			for side in [0.0, PI]:
				for i in count:
					var a = base_angle + side + (i - (count - 1) / 2.0) * 0.18
					_spawn_enemy_at(index, origin + Vector2(radius, 0).rotated(a))

## Starts a boss fight: one shared arena, then every boss of the encounter at the same spot.
func spawn_encounter(ids: Array, loop: int = 0):
	var center: Vector2 = player.global_position + Vector2(spawn_radius * 1.2, 0).rotated(randf() * TAU)
	var arena_def := BossTable.get_def(ids[0])
	for id in ids:
		if BossTable.get_def(id).get("arena", "") == "prism":
			arena_def = BossTable.get_def(id) # The Prism's walls need the hexagon
	BossArena.ensure(get_parent(), center, arena_def["arena"], arena_def["color"])
	for id in ids:
		spawn_major_boss(id, center, loop)

func spawn_major_boss(id: String, forced_pos: Vector2 = Vector2.ZERO, loop: int = 0):
	var def := BossTable.get_def(id)
	if def.is_empty():
		push_error("Unknown boss id: " + id)
		return
	var boss = CharacterBody2D.new()
	boss.add_to_group("bosses") # Add to group immediately
	boss.add_to_group("enemies") # ...so it is ignored by the clear below
	boss.set_meta("loop", loop)

	# Everything else on screen is wiped (staggered, quiet) when a boss arrives
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() > 5:
		AudioManager.play_sfx("glitch", -5.0, 0.8, 1.2)
	for enemy in existing_enemies:
		if is_instance_valid(enemy) and enemy != boss and not enemy.is_in_group("bosses"):
			var t_kill = enemy.create_tween().bind_node(enemy)
			t_kill.tween_interval(randf_range(0.0, 0.5))
			t_kill.tween_callback(func():
				if is_instance_valid(enemy):
					if enemy.has_method("spawn_death_particles"):
						enemy.spawn_death_particles()
					enemy.queue_free())

	boss.tree_exited.connect(_on_boss_tree_exited)
	boss.set_script(load(def["script"]))

	var poly = Polygon2D.new()
	poly.name = "Polygon2D"
	boss.add_child(poly)
	var shields = Node2D.new()
	shields.name = "Shields"
	boss.add_child(shields)
	var coll = CollisionShape2D.new()
	coll.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 80.0 # LARGE hit box for multi-directional shooting
	coll.shape = shape
	boss.add_child(coll)

	var pos: Vector2 = forced_pos
	if forced_pos == Vector2.ZERO:
		pos = player.global_position + Vector2(spawn_radius * 1.2, 0).rotated(randf() * TAU)
	boss.global_position = pos
	boss.set_collision_layer_value(3, true) # Enemy layer
	boss.set_collision_mask_value(1, true) # World
	boss.set_collision_mask_value(2, true) # Player

	# The arena of this fight (spawn_encounter already built it; a lone debug spawn builds its own)
	BossArena.ensure(get_parent(), pos, def["arena"], def["color"])

	AudioManager.play_sfx("boss_spawn")
	get_parent().add_child(boss)
	clear_enemy_bullets()

func clear_enemy_bullets():
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	for bullet in bullets:
		if is_instance_valid(bullet):
			# Visual pop for bullet deletion
			var t = bullet.create_tween()
			t.tween_property(bullet, "scale", Vector2.ZERO, 0.2)
			t.tween_callback(bullet.queue_free)

func spawn_6min_choice(boss_ids: Array = []):
	choice_active = true
	clear_all_enemies()
	get_tree().paused = true # The choice nodes keep running (process_mode ALWAYS)
	AudioManager.play_sfx("boss_phase")
	AudioManager.set_muffled(true)

	var names: Array = []
	for id in boss_ids:
		names.append(str(BossTable.get_def(id).get("title", id)).replace(" PROTOCOL", ""))
	var choice_boss = _create_choice_node("BOSS FIGHT", true, " + ".join(names) + "\nBig shard rewards, then harder bosses")
	choice_boss.global_position = player.global_position + Vector2(-300, 0)
	choice_boss.chosen.connect(_on_choice_boss_selected)

	var choice_endless = _create_choice_node("ENDLESS", false, "No more bosses\n+%d%% score and shards" % int((ENDLESS_BONUS - 1.0) * 100.0))
	choice_endless.global_position = player.global_position + Vector2(300, 0)
	choice_endless.chosen.connect(_on_choice_endless_selected)

func _create_choice_node(text: String, is_boss: bool, sub_text: String = ""):
	var node = Area2D.new()
	node.script = load("res://scripts/boss_choice_node.gd")
	node.label_text = text
	node.sub_text = sub_text
	node.is_boss_choice = is_boss
	node.add_to_group("choice_nodes")
	get_parent().add_child(node)
	return node

func _on_choice_boss_selected():
	get_tree().paused = false
	choice_active = false
	choice_made = true # _check_boss_schedule spawns the fight on the next frame
	AudioManager.set_muffled(false)
	_cleanup_choices()

func _on_choice_endless_selected():
	get_tree().paused = false
	choice_active = false
	choice_made = true
	bosses_done = true
	GlobalData.run_endless_bonus = ENDLESS_BONUS
	AudioManager.set_muffled(false)
	_cleanup_choices()
	AudioManager.play_sfx("level_up")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_phase"):
		hud.show_boss_phase("ENDLESS: +%d%% SCORE AND SHARDS" % int((ENDLESS_BONUS - 1.0) * 100.0), Color(0.2, 1.0, 0.4))

func _cleanup_choices():
	for node in get_tree().get_nodes_in_group("choice_nodes"):
		node.queue_free()

func clear_all_enemies():
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		if is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			if enemy.has_method("spawn_death_particles"):
				enemy.spawn_death_particles()
			enemy.queue_free()
	
	clear_enemy_bullets()

func _on_boss_tree_exited():
	# SAFETY: Ensure spawner is still alive and in tree
	if not is_inside_tree():
		return
	await get_tree().process_frame # The group is updated a frame later
	if not is_inside_tree():
		return
	if get_tree().get_nodes_in_group("bosses").size() == 0:
		boss_active = false
		director.sync_kills(GlobalData.run_kills) # Boss kills must not look like a killing spree
		director.start_breather()
		if player:
			player.dash_nerf_active = false
		AudioManager.set_boss_music_mode(false, 1)
