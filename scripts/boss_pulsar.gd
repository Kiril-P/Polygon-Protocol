extends BossBase
## Boss 2 - PULSAR PROTOCOL. A cyan eye with rotating lasers and two moving shelter platforms.
## Phase 1: 2 counter-rotating lasers.  Phase 2: 3 lasers, one shelter breaks.
## Phase 3: 5 lasers, last shelter breaks. Lasers flash for 2s whenever they are rebuilt.
## Standing on a platform shields you from lasers and refuels your dash.

var laser_rotation: float = 0.0
var laser_speed: float = 1.0
var laser_nodes: Array[Line2D] = []
var warning_tweens: Array[Tween] = []
var platform_nodes: Array[Area2D] = []
var platform_angle: float = 0.0
@export var platform_speed: float = 0.3
var lasers_charging: bool = false

func _configure() -> void:
	boss_id = "pulsar"
	max_health = 30000.0
	xp_value = 1500
	shard_reward = 300
	heart_color = Color(0.0, 1.0, 1.0)
	bullet_color = Color(0.4, 1.0, 1.0)
	death_color = Color(0.0, 0.9, 1.0)
	phase_names = ["", "", "PHASE 2: CROSSFIRE", "PHASE 3: OVERLOAD"]
	heart_first_delay = 0.0
	heart_respawn_delay = 0.0
	heart_range = Vector2(0.3, 0.7)
	heart_range_duo = Vector2(0.3, 0.55)
	transition_time = 0.0 # The rebuilt lasers already telegraph for 2s
	minion_pool = [
		{"scene": load("res://scenes/enemy_fairy.tscn"), "weight": 0.5},
		{"scene": load("res://scenes/enemy_shooter.tscn"), "weight": 0.5},
	]
	minion_cap = [10, 5, 5]
	minion_burst = [3, 4, 4]
	minion_interval = Vector2(3.0, 5.0)
	death_flashes = 16
	score_mult = 30

func _build_visuals() -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(Vector2(100, 0).rotated((TAU / 32.0) * i))
	poly.polygon = pts
	poly.color = Color(0.0, 0.9, 1.0)
	poly.modulate = Color.WHITE
	Neon.apply(poly, Color(0.0, 0.9, 1.0), 0.08, 7.0)
	Neon.add_glow(self, Color(0.0, 0.9, 1.0), 500.0, 0.1)
	VFX.shockwave(global_position, 2.0, Color(0.0, 0.9, 1.0), 560.0)
	var inner := Polygon2D.new()
	var in_pts := PackedVector2Array()
	for i in 16:
		in_pts.append(Vector2(40, 0).rotated((TAU / 16.0) * i))
	inner.polygon = in_pts
	inner.color = Color(0.7, 1.0, 1.0)
	poly.add_child(inner)
	Neon.apply(inner, Color(0.7, 1.0, 1.0), 0.9, 3.0)
	setup_lasers()
	setup_platforms()

func setup_lasers() -> void:
	for l in laser_nodes:
		l.queue_free()
	laser_nodes.clear()
	for t in warning_tweens:
		if t:
			t.kill()
	warning_tweens.clear()

	var count := 2 if phase == 1 else (3 if phase == 2 else 5)
	lasers_charging = true
	for i in count:
		var laser := Line2D.new()
		laser.width = 4.0
		laser.default_color = Color(0, 1, 1, 0.2)
		laser.material = Neon.additive_material()
		laser.points = PackedVector2Array([Vector2.ZERO, Vector2(border_radius, 0)])
		add_child(laser)
		laser_nodes.append(laser)
		var core := Line2D.new()
		core.name = "Core"
		core.width = 1.0
		core.default_color = Color(1, 1, 1, 0.1)
		core.material = Neon.additive_material()
		core.points = laser.points
		laser.add_child(core)
		var t_warn := create_tween().set_loops().bind_node(laser)
		t_warn.tween_property(laser, "default_color:a", 0.5, 0.15).set_trans(Tween.TRANS_SINE)
		t_warn.tween_property(laser, "default_color:a", 0.1, 0.15).set_trans(Tween.TRANS_SINE)
		warning_tweens.append(t_warn)

	var lasers_now := laser_nodes.duplicate()
	var t_activate := create_tween().bind_node(self)
	t_activate.tween_interval(2.0)
	t_activate.tween_callback(func():
		if is_dying:
			return
		lasers_charging = false
		for t in warning_tweens:
			if t:
				t.kill()
		warning_tweens.clear()
		for laser in lasers_now:
			if not is_instance_valid(laser):
				continue
			laser.width = 12.0
			laser.default_color = Color(0, 0.8, 1.0, 1.0)
			laser.modulate = Color(2.5, 3.5, 4.0, 1.0)
			var core = laser.get_node_or_null("Core")
			if core:
				core.width = 4.0
				core.default_color = Color(1, 1, 1, 1.0)
				core.modulate = Color(2, 2, 2, 1)
			var pulse := create_tween().set_loops().bind_node(laser)
			pulse.tween_property(laser, "width", 18.0, 0.08).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(laser, "width", 12.0, 0.08).set_trans(Tween.TRANS_SINE)
		AudioManager.play_sfx("glitch", 5.0, 1.2, 1.5))

func setup_platforms() -> void:
	for p in platform_nodes:
		p.queue_free()
	platform_nodes.clear()
	for i in 2:
		var platform := Area2D.new()
		platform.name = "ShelterPlatform"
		platform.collision_layer = 0
		platform.collision_mask = 2
		add_child(platform)
		platform_nodes.append(platform)
		var width := 180.0
		var thickness := 50.0
		var platform_poly := Polygon2D.new()
		platform_poly.polygon = PackedVector2Array([
			Vector2(-width / 2, -thickness / 2), Vector2(width / 2, -thickness / 2),
			Vector2(width / 2, thickness / 2), Vector2(-width / 2, thickness / 2)])
		platform_poly.color = Color(0.0, 1.0, 0.5, 0.4)
		platform.add_child(platform_poly)
		Neon.apply(platform_poly, Color(0.1, 1.0, 0.55), 0.22, 3.0)
		Neon.add_glow(platform, Color(0.1, 1.0, 0.55), 260.0, 0.2)
		var core := Polygon2D.new()
		core.polygon = PackedVector2Array([
			Vector2(-width / 2 + 15, -10), Vector2(width / 2 - 15, -10),
			Vector2(width / 2 - 15, 10), Vector2(-width / 2 + 15, 10)])
		core.color = Color(0.7, 1.0, 0.85, 0.8)
		core.material = Neon.additive_material()
		platform.add_child(core)
		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width, thickness)
		coll.shape = shape
		platform.add_child(coll)
		# Solid too, so it blocks bullets
		var static_body := StaticBody2D.new()
		platform.add_child(static_body)
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		var physical_coll := CollisionShape2D.new()
		physical_coll.shape = shape
		static_body.add_child(physical_coll)

func _boss_process(delta: float) -> void:
	laser_rotation += laser_speed * delta
	var count := laser_nodes.size()
	for i in count:
		var dir := -1.0 if (count == 2 and i == 1) else 1.0
		laser_nodes[i].rotation = laser_rotation * dir + (TAU / count) * i
		check_laser_collision(laser_nodes[i])

	platform_angle += platform_speed * delta
	var on_platform := false
	for i in platform_nodes.size():
		var angle := platform_angle + PI * i
		platform_nodes[i].position = Vector2(border_radius * 0.55, 0).rotated(angle)
		platform_nodes[i].rotation = angle + PI / 2
		if platform_nodes[i].overlaps_body(player):
			on_platform = true
			if "current_energy" in player and "max_energy" in player:
				player.current_energy = minf(player.max_energy, player.current_energy + 70.0 * delta)
				player.energy_changed.emit(player.current_energy, player.max_energy)
				player.modulate = Color(0.8, 2.5, 1.0)
	if not on_platform and "is_dashing" in player and not player.is_dashing:
		player.modulate = Color(1, 1, 1, 1)

func check_laser_collision(laser: Line2D) -> void:
	if lasers_charging:
		return
	var laser_dir := Vector2.RIGHT.rotated(laser.rotation)
	var max_len := border_radius
	var blocked := false
	for platform in platform_nodes:
		var to_platform: Vector2 = platform.global_position - global_position
		if absf(angle_difference(laser.rotation, to_platform.angle())) < 0.15:
			max_len = to_platform.length()
			blocked = true
			break
	laser.points = PackedVector2Array([Vector2.ZERO, Vector2(max_len, 0)])
	var core = laser.get_node_or_null("Core")
	if core:
		core.points = laser.points
	if blocked:
		return
	var to_player: Vector2 = player.global_position - global_position
	var projection := to_player.dot(laser_dir)
	if projection > 0 and projection < max_len:
		if player.global_position.distance_to(global_position + laser_dir * projection) < 35.0:
			player.take_damage(1, "PULSAR")

func _on_phase(new_phase: int) -> void:
	laser_speed *= 1.2
	if new_phase == 3:
		Neon.apply(poly, Color(0.85, 0.2, 1.0), 0.08, 7.0)
		VFX.shockwave(global_position, 2.6, Color(0.85, 0.2, 1.0), 700.0)
	setup_lasers()
	remove_one_platform()

func remove_one_platform() -> void:
	if platform_nodes.is_empty():
		return
	var p: Area2D = platform_nodes.pop_back()
	if not is_instance_valid(p):
		return
	var t := create_tween()
	for v in p.get_children():
		if v is Polygon2D:
			t.parallel().tween_property(v, "color", Color(1, 0, 0, 0.8), 0.5)
			t.parallel().tween_property(v, "modulate", GameSettings.flash(Color(5, 2, 2)), 0.5)
	t.tween_interval(0.5)
	for i in 10:
		t.tween_property(p, "position", p.position + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.05)
	t.parallel().tween_property(p, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)
	AudioManager.play_sfx("glitch", 2.0, 0.8, 1.2)

func _on_death_start() -> void:
	for l in laser_nodes:
		if is_instance_valid(l):
			l.visible = false
	for p in platform_nodes:
		if is_instance_valid(p):
			p.queue_free()
	platform_nodes.clear()
	if is_instance_valid(player):
		player.modulate = Color.WHITE
