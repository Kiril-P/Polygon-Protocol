extends BossBase
## Boss 1 - FORTRESS PROTOCOL. A stationary octagon wrapped in orbiting shields.
## Phase 1: slow radial rings.  Phase 2: faster, double rings (the core turns magenta).
## Hearts spawn mid-to-outer arena, so you have to cross the bullet field to reach them.

var fire_timer: float = 0.0

func _configure() -> void:
	boss_id = "fortress"
	max_health = 12000.0
	xp_value = 500
	shard_reward = 150
	heart_color = Color(1.0, 0.2, 0.4)
	bullet_color = Color(1.0, 0.2, 0.2)
	death_color = Color(1.0, 0.2, 0.35)
	phase_thresholds = [0.67]
	phase_names = ["", "", "PHASE 2: OVERDRIVE"]
	heart_range = Vector2(0.5, 0.9)
	heart_range_duo = Vector2(0.6, 0.9)
	minion_pool = [
		{"scene": load("res://scenes/enemy.tscn"), "weight": 0.6},
		{"scene": load("res://scenes/enemy_shooter.tscn"), "weight": 0.4},
	]
	death_flashes = 12

func _build_visuals() -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2(60, 0).rotated(TAU / 8 * i))
	poly.polygon = pts
	poly.color = Color(1.0, 0.15, 0.25)
	poly.modulate = Color.WHITE
	Neon.apply(poly, Color(1.0, 0.15, 0.25), 0.12, 6.0)
	Neon.add_glow(self, Color(1.0, 0.2, 0.3), 420.0, 0.1)
	VFX.shockwave(global_position, 2.0, Color(1.0, 0.2, 0.3), 520.0)
	for i in 6:
		var shield := Polygon2D.new()
		shield.polygon = PackedVector2Array([Vector2(20, -30), Vector2(40, 0), Vector2(20, 30), Vector2(10, 0)])
		shield.position = Vector2(120, 0).rotated(TAU / 6 * i)
		shield.rotation = TAU / 6 * i
		shield.color = Color(1.0, 0.1, 0.4)
		Neon.apply(shield, Color(1.0, 0.1, 0.4), 0.3, 4.0)
		shield_container.add_child(shield)

func _idle_motion(delta: float) -> void:
	shield_container.rotation += 1.5 * delta
	poly.rotation -= 1.5 * delta
	rotation += 0.2 * delta

func _boss_process(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	if phase == 1:
		spawn_ring(12, 300.0)
		fire_timer = 2.0
	else:
		spawn_ring(16, 400.0)
		var t := create_tween().bind_node(self)
		t.tween_interval(0.2)
		t.tween_callback(func(): spawn_ring(12, 350.0, 0.2))
		fire_timer = 0.8

func _on_phase(_n: int) -> void:
	poly.modulate = Color.WHITE
	Neon.apply(poly, Color(1.0, 0.1, 0.9), 0.12, 6.0) # Magenta rage
	VFX.shockwave(global_position, 2.6, Color(1.0, 0.1, 0.9), 650.0)

func _after_transition() -> void:
	fire_timer = 0.6
