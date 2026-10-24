extends Node
## Headless checks for the first run, shapes, telemetry, death report, combo tiers, juice, bosses and waves.
##   Godot --headless --path . res://tests/run_tests.tscn
## Never writes the real save, settings or telemetry log, and never posts online.
## (Run as a scene, not with -s: scripts that name autoloads only compile once those exist.)

var root: Window

var failures := 0
var checks := 0

func check(cond: bool, what: String):
	checks += 1
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)

func _ready():
	root = get_tree().root
	await get_tree().process_frame
	var gd = root.get_node("GlobalData")
	gd.saving_disabled = true
	gd.online_submit_enabled = false
	root.get_node("Telemetry").post_enabled = false
	root.get_node("GameSettings").hit_stop = true
	for k in gd.permanent_upgrades:
		gd.permanent_upgrades[k] = 0 # The real save's meta upgrades must not skew hearts or shields
	gd.deactivated_upgrades = []

	test_shapes(gd)
	test_death_report()
	test_combo_tiers()
	test_shape_purchase(gd)
	await test_start_shapes(gd)
	await test_first_run(gd)
	await test_death_and_telemetry(gd)
	await test_juice(gd)
	await test_layout(gd)
	test_boss_table()
	await test_bosses(gd)
	await test_boss_schedule(gd)
	test_waves(gd)

	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ units
func test_shapes(_gd):
	print("shapes")
	check(PlayerShapes.level_for_sides(3) == 4, "triangle level is 4")
	check(PlayerShapes.level_for_sides(4) == 8, "square level is 8")
	check(PlayerShapes.level_for_sides(5) == 13, "pentagon level is 13")
	check(PlayerShapes.level_for_sides(6) == 19, "hexagon level is 19")
	check(PlayerShapes.next_evolution_level(3) == 8, "triangle start evolves again at 8 (default schedule)")
	check(PlayerShapes.next_evolution_level(6) == 26, "hexagon start evolves again at 26")
	for s in PlayerShapes.LIST:
		for r in s["requires"]:
			check(not PlayerShapes.get_def(r).is_empty(), "%s requires an existing shape (%s)" % [s["id"], r])

func test_death_report():
	print("death report")
	var r := DeathReport.build({"killer": "SNIPER", "kind": "shot", "hits": [[10.0, "SHOOTER"], [14.0, "SNIPER"], [19.0, "SNIPER"]], "run_time": 120.0, "dash_empty": false})
	check(r["headline"] == "SHOT BY  SNIPER", "headline uses the damage kind: " + r["headline"])
	check("Lost 3 hearts" in r["detail"], "burst of three hits is called out")
	check("flashes white" in r["detail"], "sniper tip is included")
	var e := DeathReport.build({"killer": "CHASER", "kind": "contact", "hits": [[5.0, "CHASER"]], "run_time": 30.0, "dash_empty": true})
	check("dash was empty" in e["detail"], "empty dash is mentioned")
	check(not ("Early death" in e["detail"]), "empty-dash message replaces the early-death one")
	var unknown := DeathReport.build({"killer": "", "hits": [], "run_time": 200.0})
	check(unknown["headline"] == "SYSTEM FAILURE" and unknown["detail"] != "", "unknown killer still gives a line and a tip")
	for k in DeathReport.TIPS:
		check(DeathReport.TIPS[k] != "", "tip for " + k)

func test_combo_tiers():
	print("combo tiers")
	check(ComboTiers.tier_for(0) == -1 and ComboTiers.tier_for(4) == -1, "no tier below 5")
	check(ComboTiers.tier_for(5) == 0 and ComboTiers.tier_for(9) == 0, "chain at 5")
	check(ComboTiers.tier_for(10) == 1, "surge at 10")
	check(ComboTiers.tier_for(20) == 2, "frenzy at 20")
	check(ComboTiers.tier_for(35) == 3, "overload at 35")
	check(ComboTiers.tier_for(500) == 4, "top tier caps")
	check(ComboTiers.next_min(4) == -1 and ComboTiers.next_min(0) == 10, "next_min")

func test_shape_purchase(gd):
	print("shape purchase")
	gd.unlocked_shapes = ["circle"]
	gd.selected_shape = "circle"
	gd.total_shards = 0
	check(not gd.buy_shape("spark"), "cannot buy without shards")
	gd.total_shards = 1000
	check(not gd.buy_shape("bastion"), "cannot skip the tree (needs spark)")
	check(gd.buy_shape("spark") and gd.total_shards == 800, "buy spark for 200")
	check(not gd.buy_shape("spark"), "cannot buy twice")
	gd.total_shards = 5000
	check(not gd.buy_shape("hive"), "hive is locked until both branches are owned")
	check(gd.buy_shape("bastion") and gd.buy_shape("comet"), "both branches open after spark")
	check(not gd.buy_shape("hive") or gd.total_shards == 5000 - 450 - 450 - 1100, "hive costs 1100")
	gd.total_shards = 5000
	check(gd.has_shape("hive") or gd.buy_shape("hive"), "hive unlocks with both branches")
	gd.select_shape("hive")
	check(gd.run_shape() == "hive", "run uses the selected shape")
	gd.set_run("daily", [])
	check(gd.run_shape() == "circle", "daily always starts as the circle")
	gd.set_run("standard", [])
	gd.selected_shape = "not_owned"
	check(gd.run_shape() == "circle", "unowned selection falls back to the circle")

# ------------------------------------------------------------------ integration
func _spawn_game() -> Node:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	get_tree().current_scene = game # Effects are parented to the current scene
	await get_tree().process_frame
	await get_tree().process_frame
	return game

func _free_game(game: Node):
	Engine.time_scale = 1.0
	get_tree().paused = false
	game.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	await get_tree().process_frame

func test_start_shapes(gd):
	print("start shapes")
	gd.unlocked_shapes = ["circle", "spark", "bastion", "comet", "hive"]
	gd.first_run_done = true
	var expect := {
		"circle": {"shape": 0, "hearts": 5},
		"spark": {"shape": 3, "hearts": 4},
		"bastion": {"shape": 4, "hearts": 5},
		"comet": {"shape": 5, "hearts": 3},
		"hive": {"shape": 6, "hearts": 4},
	}
	for id in expect:
		gd.selected_shape = id
		gd.set_run("standard", [])
		var game := await _spawn_game()
		var p = get_tree().get_first_node_in_group("player")
		check(p != null and p.current_shape == expect[id]["shape"], "%s starts with %d sides (got %s)" % [id, expect[id]["shape"], str(p.current_shape if p else "?")])
		check(p.max_hearts == expect[id]["hearts"] and p.current_hearts == p.max_hearts, "%s has %d hearts (got %d)" % [id, expect[id]["hearts"], p.max_hearts])
		if id != "circle":
			check(p.next_evolution_level == PlayerShapes.next_evolution_level(expect[id]["shape"]), "%s evolution schedule" % id)
		check(p.first_run_script == null, "no first run when finished")
		await _free_game(game)
	# Glass Core sets hearts absolutely, whatever the shape
	gd.selected_shape = "comet"
	gd.set_run("standard", ["glass"])
	var g2 := await _spawn_game()
	var p2 = get_tree().get_first_node_in_group("player")
	check(p2.max_hearts == 2, "glass core wins over the shape's hearts")
	await _free_game(g2)
	gd.selected_shape = "circle"

func test_first_run(gd):
	print("first run")
	gd.unlocked_shapes = ["circle"]
	gd.selected_shape = "circle"
	gd.first_run_done = false
	gd.is_first_run = true
	gd.set_run("standard", [])
	var game := await _spawn_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var p = get_tree().get_first_node_in_group("player")
	var sp = get_tree().get_first_node_in_group("spawner")
	check(p.first_run_script != null, "first run script is attached")
	check(sp.tutorial_finished == false, "normal spawner is held back during training")
	var fr: FirstRun = p.first_run_script
	check(fr._i == 0, "starts on MOVE")

	# MOVE: walk 400px
	for i in 12:
		p.global_position += Vector2(40, 0)
		await get_tree().process_frame
	check(fr._advancing or fr._i >= 1, "moving completes MOVE")
	await get_tree().create_timer(1.0, true, false, true).timeout
	check(fr._i == 1, "advanced to DASH")
	check(_trainees() == 3, "three training chasers spawned (got %d)" % _trainees())
	# Training enemies are slowed
	var slow_ok := true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("trainee") and e.speed > 150.0:
			slow_ok = false
	check(slow_ok, "training enemies are slowed")

	# DASH: kill three
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("trainee"):
			e.take_damage(9999.0)
	await get_tree().process_frame
	await get_tree().create_timer(1.0, true, false, true).timeout
	check(fr._i == 2, "three kills advance to LEVEL (step %d)" % fr._i)

	# LEVEL: force a level-up and pick the first upgrade
	p.add_xp(p.xp_to_next_level)
	await get_tree().process_frame
	await get_tree().process_frame
	check(root.get_node("UpgradeManager").is_ui_active, "level-up menu opened")
	var tp := fr._t
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(is_equal_approx(fr._t, tp), "lesson timer pauses with the upgrade menu")
	var um = root.get_node("UpgradeManager")
	um.apply_upgrade(um.upgrade_pool[0].duplicate())
	await get_tree().create_timer(2.5, true, false, true).timeout
	check(p.current_shape == 3, "first upgrade evolves to a triangle")
	check(fr._i == 3, "advanced to SHOOT (step %d)" % fr._i)
	check(is_instance_valid(fr._shooter), "shooter spawned")

	# SHOOT: kill it
	fr._shooter.take_damage(9999.0)
	await get_tree().process_frame
	await get_tree().create_timer(1.0, true, false, true).timeout
	check(fr._i == 4, "killing the shooter advances to COMBO (step %d)" % fr._i)

	# COMBO: chain five kills
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("trainee"):
			e.take_damage(9999.0)
			await get_tree().process_frame
	await get_tree().create_timer(1.5, true, false, true).timeout
	check(fr._done, "training finished")
	check(gd.first_run_done, "first_run_done is set")
	check(sp.tutorial_finished and is_equal_approx(sp.time_passed, 0.0), "spawner handed over at 0:00")
	await _free_game(game)

	# Skipping
	gd.first_run_done = false
	var g2 := await _spawn_game()
	var p2 = get_tree().get_first_node_in_group("player")
	var fr2: FirstRun = p2.first_run_script
	fr2._finish(true)
	check(gd.first_run_done and fr2._done, "skipping finishes training")
	await _free_game(g2)

	# Veteran saves skip it
	gd.first_run_done = true
	var g3 := await _spawn_game()
	check(get_tree().get_first_node_in_group("player").first_run_script == null, "finished players get no training")
	await _free_game(g3)

func _trainees() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("trainee"):
			n += 1
	return n

func test_death_and_telemetry(gd):
	print("death and telemetry")
	gd.first_run_done = true
	gd.set_run("standard", ["swarm", "hunters"])
	gd.selected_shape = "circle"
	var game := await _spawn_game()
	var p = get_tree().get_first_node_in_group("player")
	var got := []
	p.game_over.connect(func(stats): got.append(stats))
	p.iframe_timer = 0.0
	root.get_node("UpgradeManager").apply_upgrade({"id": "speed", "value": 0.25, "name": "Swiftness"})
	root.get_node("UpgradeManager").apply_upgrade({"id": "damage", "value": 0.25, "name": "Sharp Edges"})
	for i in 5:
		p.iframe_timer = 0.0
		p.take_damage(1, "SNIPER", "shot")
		await get_tree().process_frame
	check(p.is_dead, "player died after five hits")
	check(got.size() == 1, "game_over emitted once")
	var stats: Dictionary = got[0]
	check(stats["how"]["headline"] == "SHOT BY  SNIPER", "stats carry the how-you-died headline")
	check("Lost" in stats["how"]["detail"], "burst of hits is reported")
	check(stats["shape"] == "circle", "stats carry the shape")
	var rec: Dictionary = root.get_node("Telemetry").build_record(stats)
	check(rec["protocols"] == ["swarm", "hunters"], "record has the protocols")
	check(rec["killed_by"] == "SNIPER", "record has the cause of death")
	check(rec["picks"].size() == 2 and rec["picks"][0][1] == "speed" and rec["picks"][1][1] == "damage", "record has the upgrade picks in order")
	check(rec["hearts_lost"] == 5, "record counts hearts lost")
	check(not rec.has("player_id") and not rec.has("name") and not rec.has("id"), "record has no identifying fields")
	var json := JSON.stringify(rec)
	check(not (gd.player_id != "" and gd.player_id in json), "player id is nowhere in the record")
	check(JSON.parse_string(json) != null, "record serialises to JSON")
	check(json.length() < 1500, "record is small (%d bytes)" % json.length())
	# The death effects were created and keep running under the pause
	var shatter: DeathShatter = null
	for c in game.get_children():
		if c is DeathShatter:
			shatter = c
	if shatter == null:
		for c in game.get_children():
			print("    child: ", c.name, " ", c.get_class(), " ", c.get_script().resource_path if c.get_script() else "")
	check(shatter != null, "death shatter spawned")
	check(shatter != null and shatter.process_mode == Node.PROCESS_MODE_ALWAYS, "shatter runs while paused")
	check(not p.visible, "player body hidden after the shatter")
	await get_tree().create_timer(1.8, true, false, true).timeout
	var ds = get_tree().get_first_node_in_group("death_screen")
	var screen: CanvasLayer = null
	for c in game.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("death_screen.gd"):
			screen = c
	check(screen != null and screen.visible, "death screen is visible")
	if screen:
		check(screen.find_child("HowDetail", true, false) != null, "death screen shows the how-you-died line")
	await _free_game(game)

func test_juice(gd):
	print("juice")
	gd.first_run_done = true
	gd.set_run("standard", [])
	var game := await _spawn_game()
	var p = get_tree().get_first_node_in_group("player")
	var vfx = root.get_node("VFX")
	# Hit stop
	vfx.hit_stop(0.05, 0.05, 0.0)
	check(Engine.time_scale < 1.0, "hit stop slows time")
	await get_tree().create_timer(0.2, true, false, true).timeout
	check(Engine.time_scale == 1.0, "hit stop restores time")
	root.get_node("GameSettings").hit_stop = false
	vfx.hit_stop(0.05)
	check(Engine.time_scale == 1.0, "hit stop obeys the setting")
	root.get_node("GameSettings").hit_stop = true
	# Min gap
	vfx.hit_stop(0.02, 0.05, 0.0)
	await get_tree().create_timer(0.1, true, false, true).timeout
	vfx.hit_stop(0.02, 0.05, 5.0)
	check(Engine.time_scale == 1.0, "min gap blocks back-to-back stops")
	# Camera punch decays and is bounded
	p.add_punch(Vector2.RIGHT, 30.0)
	var peak := 0.0
	for i in 40:
		p._step_punch(1.0 / 60.0)
		peak = maxf(peak, p.punch_offset.length())
	check(peak > 8.0 and peak <= 46.0 + 10.0, "punch moves the camera (peak %.1f px)" % peak)
	for i in 240:
		p._step_punch(1.0 / 60.0)
	check(p.punch_offset == Vector2.ZERO, "punch settles back to zero")
	root.get_node("GameSettings").shake = 0.0
	p.add_punch(Vector2.RIGHT, 30.0)
	check(p.punch_vel == Vector2.ZERO, "shake slider at 0 disables the punch")
	root.get_node("GameSettings").shake = 1.0
	# Combo tiers fire signals
	var tiers := []
	p.combo_tier_changed.connect(func(t, prev): tiers.append([t, prev]))
	for i in 12:
		p.add_xp(1.0)
	check(tiers.size() >= 2 and tiers[0] == [0, -1] and tiers[1] == [1, 0], "tier signals climb: %s" % str(tiers))
	p.reset_combo()
	check(p.combo_tier == -1, "tier resets with the combo")
	# Combo meter
	var hud = get_tree().get_first_node_in_group("hud")
	check(hud != null, "hud exists")
	if hud:
		hud._on_player_combo_changed(25, 1.0)
		var tl: Label = hud.find_child("ComboTierLabel", true, false)
		var ml: Label = hud.find_child("ComboMultLabel", true, false)
		check(tl.text == "FRENZY", "meter shows tier name (%s)" % tl.text)
		check(ml.text == "SCORE x3.5", "meter shows score multiplier (%s)" % ml.text)
		hud._on_player_combo_changed(0, 0.0)
		check(tl.text == "", "meter clears when the combo ends")
	# Enemy kills create bursts
	var before := game.get_child_count()
	var e = load("res://scenes/enemy.tscn").instantiate()
	game.add_child(e)
	e.global_position = p.global_position + Vector2(300, 0)
	await get_tree().process_frame
	e.take_damage(9999.0)
	await get_tree().process_frame
	var bursts := 0
	for c in game.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("shard_burst.gd"):
			bursts += 1
	check(bursts >= 1, "enemy death spawns a shard burst")
	await _free_game(game)

## UI layout without rendering: control rectangles are computed headless, so overlaps and
## off-screen cards can still be caught.
func test_layout(gd):
	print("layout")
	gd.total_shards = 640
	gd.unlocked_shapes = ["circle", "spark"]
	var tree: Control = load("res://scenes/shape_tree.tscn").instantiate()
	root.add_child(tree)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rects := {}
	for id in tree._cards:
		var c: Control = tree._cards[id]
		rects[id] = c.get_global_rect()
	var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	for id in rects:
		check(screen.encloses(rects[id]), "%s card is on screen %s" % [id, str(rects[id])])
	var ids: Array = rects.keys()
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].intersects(rects[ids[j]]):
				overlap = true
				print("    overlap: ", ids[i], " ", ids[j])
	check(not overlap, "no two cards overlap")
	for id in tree._cards:
		var c: Control = tree._cards[id]
		check(c.size.y <= tree.CARD.y + 40, "%s card height stays near its design size (%.0f)" % [id, c.size.y])
	# Buying through the UI path
	gd.total_shards = 100
	tree._refresh()
	var btn: Button = tree._cards["bastion"].find_child("Action", true, false)
	check(btn.disabled, "bastion is disabled when it costs more than the shards owned")
	gd.total_shards = 2000
	tree._refresh()
	btn = tree._cards["bastion"].find_child("Action", true, false)
	check(not btn.disabled, "bastion can be bought with shards")
	tree._on_action("bastion")
	check(gd.has_shape("bastion") and gd.selected_shape == "bastion", "buying equips the new shape")
	tree.queue_free()

	# Death screen: the summary (with the how-you-died text) must fit inside its panel
	gd.first_run_done = true
	gd.set_run("standard", [])
	var game := await _spawn_game()
	var p = get_tree().get_first_node_in_group("player")
	for i in 5:
		p.iframe_timer = 0.0
		p.take_damage(1, "SPLITTER", "contact")
		await get_tree().process_frame
	await get_tree().create_timer(1.8, true, false, true).timeout
	var screen_node: CanvasLayer = null
	for c in game.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("death_screen.gd"):
			screen_node = c
	var vbox: Control = screen_node.get_node("Control/VBoxContainer")
	var panel: Control = screen_node.get_node("Control/NeonPanel")
	var content_h: float = vbox.get_combined_minimum_size().y
	check(content_h <= panel.size.y - 30.0, "death screen content (%.0f px) fits its panel (%.0f px)" % [content_h, panel.size.y])
	var how: Label = screen_node.find_child("HowDetail", true, false)
	check(how != null and how.get_line_count() <= 4, "how-you-died text wraps to at most 4 lines (%d)" % (how.get_line_count() if how else -1))
	await _free_game(game)

# ------------------------------------------------------------------ bosses & waves
func _wait(sec: float):
	await get_tree().create_timer(sec, true, false, true).timeout

## A running game with a player that cannot die or level up mid-test, and the spawner released.
func _boss_game(gd) -> Array:
	gd.first_run_done = true
	gd.set_run("standard", [])
	var game := await _spawn_game()
	var p = get_tree().get_first_node_in_group("player")
	p.max_hearts = 999
	p.current_hearts = 999
	p.xp_to_next_level = 1.0e12
	var sp = get_tree().get_first_node_in_group("spawner")
	sp.tutorial_finished = true
	return [game, p, sp]

func _bosses_alive() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			n += 1
	return n

## Pops hearts the way the dash does, skipping the invulnerable beat between phases.
func _pop_hearts(boss, count: int):
	for i in count:
		boss.transitioning = false
		boss.heart_hit()

func test_boss_table():
	print("boss table")
	for id in BossTable.ids():
		var def := BossTable.get_def(id)
		check(ResourceLoader.exists(def["script"]), "%s: script exists" % id)
		check(AudioManager.BOSS_MAX_PHASE.has(id), "%s: has a music entry" % id)
		for layer in AudioManager.BOSS_LAYERS:
			check(ResourceLoader.exists("%sboss_%s_%s.ogg" % [AudioManager.MUSIC_DIR, id, layer]), "%s: %s stem exists" % [id, layer])
	var sp := Spawner.new()
	for i in 8:
		for id in sp._encounter(i)["bosses"]:
			check(BossTable.LIST.has(id), "encounter %d boss '%s' is in the table" % [i, id])
	sp.free()

func test_bosses(gd):
	print("bosses")
	var env := await _boss_game(gd)
	var game: Node = env[0]
	var p = env[1]
	var sp = env[2]

	for id in BossTable.ids():
		var def := BossTable.get_def(id)
		sp.spawn_encounter([id])
		await _wait(0.4)
		var boss = get_tree().get_first_node_in_group("bosses")
		check(boss != null and boss.boss_id == id, "%s: spawns with its id" % id)
		check(boss.boss_title == def["title"], "%s: title comes from the table" % id)
		var arenas := get_tree().get_nodes_in_group("boss_arena_node")
		check(arenas.size() == 1 and arenas[0].kind == def["arena"], "%s: one %s arena" % [id, def["arena"]])
		check(p.dash_nerf_active, "%s: dash nerf on" % id)

		# Chip damage can never finish a boss or trigger a phase by itself
		var before: float = boss.health
		boss.take_damage(1.0e9)
		check(before - boss.health <= boss.max_health * BossBase.CHIP_CAP + 0.01, "%s: one chip hit takes at most %.2f%%" % [id, BossBase.CHIP_CAP * 100.0])
		for i in 200:
			boss.take_damage(1.0e9)
		check(not boss.is_dying and boss.health >= boss.max_health / 18.0 - 0.01, "%s: chip alone leaves at least half a heart" % id)
		boss.health = boss.max_health
		boss.phase = 1

		# Three hearts per phase, nine to kill, with no leftover sliver
		_pop_hearts(boss, 3)
		check(boss.phase == 2, "%s: phase 2 after 3 hearts" % id)
		if boss.phase_thresholds.size() >= 2:
			_pop_hearts(boss, 3)
			check(boss.phase == 3, "%s: phase 3 after 6 hearts" % id)
			_pop_hearts(boss, 2)
			check(boss.health > 0.0 and not boss.is_dying, "%s: still alive after 8 hearts" % id)
			_pop_hearts(boss, 1)
		else:
			_pop_hearts(boss, 5)
			check(boss.health > 0.0 and not boss.is_dying, "%s: still alive after 8 hearts" % id)
			_pop_hearts(boss, 1)
		check(boss.is_dying and boss.health == 0.0, "%s: ninth heart kills exactly" % id)
		await _wait(4.0)
		check(_bosses_alive() == 0, "%s: gone after death" % id)
		check(not p.dash_nerf_active, "%s: dash nerf cleared" % id)
		await _wait(1.0)
		check(get_tree().get_nodes_in_group("boss_arena_node").is_empty(), "%s: arena and barrier removed together" % id)
		for n in game.get_children():
			if n is StaticBody2D and n.name == "Barrier":
				check(false, "%s: leaked a barrier" % id)
		check(get_tree().get_nodes_in_group("boss_hearts").is_empty(), "%s: no hearts left behind" % id)

	# Duo fight: one shared arena; the dash nerf survives the first boss dying
	sp.spawn_encounter(["fortress", "pulsar"])
	await _wait(0.4)
	check(_bosses_alive() == 2, "duo: both bosses spawn")
	check(get_tree().get_nodes_in_group("boss_arena_node").size() == 1, "duo: one arena for both")
	var fortress = null
	for b in get_tree().get_nodes_in_group("bosses"):
		if b.boss_id == "fortress":
			fortress = b
	_pop_hearts(fortress, 9)
	await _wait(3.5)
	check(_bosses_alive() == 1, "duo: fortress died, pulsar lives")
	check(p.dash_nerf_active, "duo: dash nerf stays while the other boss lives")
	check(get_tree().get_nodes_in_group("boss_arena_node").size() == 1, "duo: arena stays while the other boss lives")
	var pulsar = get_tree().get_first_node_in_group("bosses")
	_pop_hearts(pulsar, 9)
	await _wait(5.0)
	check(_bosses_alive() == 0 and not p.dash_nerf_active, "duo: all clear after both die")

	# Boss shards: multiplied, banked at once, counted for the summary
	gd.total_shards = 0
	gd.run_boss_shards = 0
	gd.run_endless_bonus = 1.0
	check(gd.add_boss_shards(100) == 100 and gd.total_shards == 100 and gd.run_boss_shards == 100, "boss shards bank immediately and are tracked")
	gd.run_endless_bonus = 1.25
	check(gd.add_boss_shards(100) == 125, "endless bonus applies to boss shards")
	gd.run_endless_bonus = 1.0

	# Prism walls: warn, then hurt, then reset
	sp.spawn_encounter(["prism"])
	await _wait(0.4)
	var prism = get_tree().get_first_node_in_group("bosses")
	var arena: BossArena = get_tree().get_first_node_in_group("boss_arena_node")
	check(arena.kind == "prism" and arena.wall_count() == 6, "prism: hexagon arena with six walls")
	check(arena.inner_radius() < arena.radius, "prism: inscribed radius is smaller than the corner radius")
	arena.overload_walls([0], 0.6, 1.2)
	check(arena.wall_state(0) == "warn", "prism: wall starts in warning")
	p.global_position = arena.global_position + arena.wall_mid(0) * 0.97
	var hearts_before: int = p.current_hearts
	await _wait(0.4)
	check(p.current_hearts == hearts_before, "prism: a warning wall does not hurt")
	await _wait(0.5)
	check(arena.wall_state(0) == "live", "prism: wall goes live")
	await _wait(0.4)
	check(p.current_hearts < hearts_before, "prism: a live wall hurts the player")
	await _wait(1.0)
	check(arena.wall_state(0) == "off", "prism: wall resets")
	prism.start_death_sequence()
	await _wait(5.0)
	await _free_game(game)

func test_boss_schedule(gd):
	print("boss schedule")
	var env := await _boss_game(gd)
	var game: Node = env[0]
	var sp = env[2]
	check(sp._encounter(0)["at"] == 80 and sp._encounter(0)["bosses"] == ["fortress"], "first boss: Fortress at 1:20")
	check(sp._encounter(2).get("choice", false), "the 6:00 duo offers a choice")
	check(sp._encounter(4)["bosses"] == ["prism"] and sp._encounter(4)["at"] == 900, "Prism arrives at 15:00")
	check(sp._encounter(5)["at"] > sp._encounter(4)["at"] and sp._encounter(5)["loop"] == 1, "the boss loop continues after the ladder")
	check(sp._encounter(5 + BOSS_LOOP_LEN)["loop"] == 2, "loop lap counter grows")
	sp.jump_to(350.0)
	check(sp.encounter_index == 2, "jump_to(350) points at the 6:00 choice")

	# The 10-second warning fires once, the fight spawns once
	sp.jump_to(70.0)
	check(sp.encounter_index == 0, "jump_to(70) points at the first boss")
	sp._check_boss_schedule()
	check(sp.warned_index == 0, "warning shown for encounter 0")
	sp._check_boss_schedule()
	check(sp.encounter_index == 0 and _bosses_alive() == 0, "no boss before its time")
	sp.time_passed = 80.0
	sp._check_boss_schedule()
	await _wait(0.3)
	check(_bosses_alive() == 1 and sp.encounter_index == 1, "boss spawns at 1:20 and the schedule advances")
	sp._check_boss_schedule()
	check(_bosses_alive() == 1, "it does not spawn twice")
	for b in get_tree().get_nodes_in_group("bosses"):
		b.queue_free()
	await _wait(1.0)

	# Declining the 6:00 boss is endless: no more bosses, bonus score
	sp.jump_to(359.0)
	sp.time_passed = 360.0
	sp._check_boss_schedule()
	check(sp.choice_active and get_tree().paused, "6:00 pauses for the choice")
	check(get_tree().get_nodes_in_group("choice_nodes").size() == 2, "two choice nodes")
	sp._on_choice_endless_selected()
	check(not get_tree().paused and sp.bosses_done, "endless unpauses and ends the boss schedule")
	sp.time_passed = 5000.0
	sp._check_boss_schedule()
	check(_bosses_alive() == 0, "no boss spawns after choosing endless")
	check(not sp._near_boss_milestone(), "formations are not held back once bosses are over")
	gd.run_score = 0
	gd.add_score(100, 0)
	check(gd.run_score == int(100 * gd.protocol_multiplier() * 1.25), "endless bonus applies to score (%d)" % gd.run_score)
	gd.run_endless_bonus = 1.0
	await _free_game(game)

const BOSS_LOOP_LEN := 3

func test_waves(gd):
	print("waves")
	var d := SpawnDirector.new()
	d.load_data()
	check(d.current_cap(0.0) == 70, "enemy cap starts at 70")
	check(d.current_cap(600.0) == 110, "enemy cap grows with time, up to cap_max (110)")
	check(d.current_cap(60000.0) == 110, "enemy cap never exceeds cap_max")
	check(d.spawn_allowed(69, 0.0) and not d.spawn_allowed(70, 0.0), "spawn_allowed respects the cap")
	d.rng.seed = 7
	var heavy := ["tank", "sniper", "aegis", "healer", "spinner", "shooter"]
	var early := 0
	var late := 0
	for i in 3000:
		if d.pick_enemy(300.0) in heavy:
			early += 1
		if d.pick_enemy(700.0) in heavy:
			late += 1
	check(late > early, "late waves lean on the dangerous enemies (%d vs %d of 3000)" % [late, early])
	d.sync_kills(40)
	check(d._kill_times.is_empty(), "sync_kills drops the boss kill spree")
	var sp := Spawner.new()
	sp.time_passed = 0.0
	check(is_equal_approx(sp.health_scale(), 1.0) and is_equal_approx(sp.speed_scale(), 1.0), "early enemies have base stats")
	sp.time_passed = 1140.0
	check(is_equal_approx(sp.health_scale(), 2.0), "enemy health doubles by 19:00")
	check(sp.speed_scale() > 1.2 and sp.speed_scale() <= 1.3, "enemy speed saturates at +30%")
	sp.free()
