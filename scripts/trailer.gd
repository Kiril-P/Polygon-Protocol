extends Node
## Scripted trailer: runs the real game with a bot at the controls and walks through the
## highlights (title, early waves, upgrades and synergy, the new enemy types, a boss) then
## an end card. Meant for Godot's movie maker, see tools/trailer/README.md.
##
## Options after `--`:  --length=46  --cta="Play free on itch.io"  --seed=7

const GAME_SCENE := "res://scenes/game.tscn"

var length := 46.0
var cta := ""
var game: Node
var player: Node2D
var spawner: Node
var bot_on := true
var _dash_hold := 0.0
var _orbit := 1.0
var _orbit_flip := 0.0
var _clock := 0.0
var _boss_started := false

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--length="):
			length = float(a.get_slice("=", 1))
		elif a.begins_with("--cta="):
			cta = a.get_slice("=", 1)
		elif a.begins_with("--seed="):
			seed(int(a.get_slice("=", 1)))
	# Scripted footage must never touch the player's save, settings or leaderboard
	var gd = GlobalData
	gd.saving_disabled = true
	gd.online_submit_enabled = false
	gd.show_tutorial = false
	gd.is_first_run = false
	gd.title_seen = true
	gd.use_mouse_controls = false
	gd.difficulty_level = 2
	gd.set_run("standard", [])
	await get_tree().process_frame
	game = load(GAME_SCENE).instantiate()
	add_child(game)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	spawner = get_tree().get_first_node_in_group("spawner")
	spawner.tutorial_finished = true
	var title := TitleSequence.new()
	add_child(title)
	_start_level_up_guard()
	_run_timeline()

## A natural level-up during a take must never leave the footage frozen: pick a card after a beat.
func _start_level_up_guard():
	var t := Timer.new()
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.wait_time = 1.6
	t.autostart = true
	t.timeout.connect(func():
		if get_tree().paused:
			_pick_middle_card())
	add_child(t)

func _pick_middle_card():
	var ui := get_tree().get_first_node_in_group("upgrade_ui")
	if ui:
		var buttons := ui.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
		if buttons.size() > 0:
			buttons[buttons.size() / 2].pressed.emit()

func _wait(sec: float):
	await get_tree().create_timer(sec).timeout

func _run_timeline():
	# 0-4.5 title over the first waves
	await _wait(4.5)
	# Early game: the upgrade screen, then the first synergy
	await _wait(3.5)
	await _real_upgrade_pick()
	await _wait(1.5)
	_grant("split")
	await _wait(2.0)
	_grant("chain")
	await _wait(3.5)
	# New threats
	spawner.time_passed = 140.0
	_spawn_group()
	await _wait(5.0)
	_grant("explosive")
	_grant("deflector")
	await _wait(6.0)
	_spawn_group()
	await _wait(3.0)
	# Boss
	_boss_started = true
	spawner.spawn_major_boss(80)
	await _wait(maxf(length - _clock - 6.5, 4.0))
	await _end_card()
	get_tree().quit()

func _grant(id: String):
	var um = UpgradeManager
	for u in um.upgrade_pool:
		if u["id"] == id:
			um.upgrade_counts[id] = um.upgrade_counts.get(id, 0) + 1
			player.apply_upgrade(id, u["value"])
			um._check_synergies(player)
			return

## Opens the real level-up screen and picks the middle card after a beat.
func _real_upgrade_pick():
	var um = UpgradeManager
	um.level_up_pending = 1
	um.show_next_upgrade()
	await _wait(2.0)
	_pick_middle_card()


func _spawn_group():
	var p: Vector2 = player.global_position
	for spec in [[7, Vector2(420, -120)], [8, Vector2(-380, 180)], [9, Vector2(60, -560)], [10, Vector2(520, 260)], [0, Vector2(-300, -240)], [0, Vector2(300, 300)]]:
		spawner._spawn_enemy_at(spec[0], p + spec[1])

func _end_card():
	var layer := CanvasLayer.new()
	layer.layer = 190
	add_child(layer)
	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.01, 0.03, 1.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.modulate.a = 0.0
	layer.add_child(veil)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.modulate.a = 0.0
	layer.add_child(box)
	var a := Label.new()
	a.text = "POLYGON"
	var b := Label.new()
	b.text = "PROTOCOL"
	NeonUI.style_title(a, Color(0.0, 0.9, 1.0), 150)
	NeonUI.style_title(b, Color(1.0, 0.15, 0.65), 150)
	for l in [a, b]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var tag := Label.new()
	tag.text = cta if cta != "" else "SURVIVE THE CORRUPTION"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 40)
	tag.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(tag)
	var t := create_tween()
	t.tween_property(veil, "modulate:a", 1.0, 0.7)
	t.tween_property(box, "modulate:a", 1.0, 0.5)
	t.tween_interval(2.6)
	await t.finished

func _process(delta: float):
	_clock += delta
	if is_instance_valid(player) and player.current_hearts <= 1 and not get_tree().paused:
		player.heal(2) # Footage should survive; hits elsewhere still sell the danger

func _physics_process(delta: float):
	if not bot_on or not is_instance_valid(player) or get_tree().paused:
		return
	var pos := player.global_position
	var steer := Vector2.ZERO
	var near := 0
	var closest := INF
	var closest_pos := pos
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dying") == true:
			continue
		var d := pos.distance_to(e.global_position)
		if d < closest:
			closest = d
			closest_pos = e.global_position
		if d < 460.0:
			steer += (pos - e.global_position).normalized() * (460.0 - d) / 460.0 * 1.6
		if d < 170.0:
			near += 1
	# Orbit the nearest threat so the spinning gun covers it; flip direction now and then
	_orbit_flip -= delta
	if _orbit_flip <= 0.0:
		_orbit = -_orbit
		_orbit_flip = randf_range(2.5, 5.0)
	var to_closest := closest_pos - pos
	if closest < INF:
		steer += to_closest.normalized().orthogonal() * _orbit * 0.9
		if closest > 520.0:
			steer += to_closest.normalized() * 0.8
	var danger_bullet := false
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(b):
			continue
		var rel: Vector2 = pos - b.global_position
		var dir: Vector2 = b.direction
		var ahead := rel.dot(dir)
		if ahead > 0.0 and ahead < 380.0:
			var side := rel - dir * ahead
			if side.length() < 90.0:
				steer += (side.normalized() if side.length() > 1.0 else dir.orthogonal()) * 2.4
				danger_bullet = true
	if steer.length() < 0.05:
		steer = Vector2.RIGHT.rotated(_clock * 0.7)
	steer = steer.normalized()
	for pair in [["move_left", -steer.x], ["move_right", steer.x], ["move_up", -steer.y], ["move_down", steer.y]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])
	_dash_hold = maxf(_dash_hold - delta, 0.0)
	if (near >= 3 or (danger_bullet and randf() < 0.3)) and player.current_energy > 55.0 and _dash_hold <= 0.0:
		_dash_hold = 0.4
	if _dash_hold > 0.0:
		Input.action_press("dash")
	else:
		Input.action_release("dash")
