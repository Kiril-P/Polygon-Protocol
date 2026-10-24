class_name FirstRun
extends Node
## The scripted first run: about two minutes of guided play for a player who has never
## finished it, built from five short lessons with hand-placed, slow enemies. Each lesson
## ends when its goal is met or its time-out passes, so nobody gets stuck.
##
##   MOVE   walk around
##   DASH   dash through three chasers (dashing kills, and makes you untouchable)
##   LEVEL  kill chasers until the level-up, pick an upgrade (the first pick evolves you)
##   SHOOT  the shape now auto-fires: kill a shooter and dodge its bullets
##   COMBO  kill a cluster quickly to chain a combo
##
## While it runs the normal spawner is held back (spawner.tutorial_finished = false); on
## hand-over the real run starts from 0:00. It is added by the player when
## GlobalData.first_run_done is false and removes itself when finished or skipped.

const STEPS := ["move", "dash", "level", "shoot", "combo"]
const TIMEOUT := {"move": 12.0, "dash": 30.0, "level": 40.0, "shoot": 25.0, "combo": 18.0}
const SPAWN_RADIUS := 430.0
const SLOW := 0.6 # Training enemies move at this fraction of their normal speed
const MOVE_GOAL := 380.0
const DASH_KILLS := 3
const COMBO_GOAL := 5

var player: Node2D
var spawner: Node
var _i := -1
var _t := 0.0
var _moved := 0.0
var _last_pos := Vector2.ZERO
var _kills0 := 0
var _spawn_t := 0.0
var _spawned := 0
var _shooter: Node = null
var _done := false
var _low_energy_hint := false
var _layer: CanvasLayer
var _head: Label
var _body: Label
var _hint: Label
var _pips: Label
var _skip: Button

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE # The player runs always; lesson timers must stop for the upgrade menu
	_begin.call_deferred()

func _begin():
	player = get_parent() as Node2D
	spawner = get_tree().get_first_node_in_group("spawner")
	if player == null or spawner == null:
		_finish(false)
		return
	spawner.tutorial_finished = false
	_last_pos = player.global_position
	_build_ui()
	_enter(0)

# ------------------------------------------------------------------ steps
func _enter(i: int):
	_i = i
	_t = 0.0
	_spawn_t = 0.0
	_spawned = 0
	_kills0 = GlobalData.run_kills
	_low_energy_hint = false
	_shooter = null
	_hint.text = ""
	if _i >= STEPS.size():
		_finish(false)
		return
	_set_text(STEPS[_i])
	AudioManager.play_sfx("level_up", -10.0, 1.2, 1.3)
	match STEPS[_i]:
		"dash":
			var base := randf() * TAU
			for k in DASH_KILLS:
				_spawn("chaser", base + TAU * k / DASH_KILLS, {"health_mult": 0.5})
		"shoot":
			_shooter = _spawn("shooter", randf() * TAU, {"health_mult": 0.5}, 1.25)
		"combo":
			var a := randf() * TAU
			for k in 8:
				_spawn("chaser", a + (k - 3.5) * 0.09, {"health_mult": 0.5}, 0.97 + 0.03 * (k % 2))

func _process(delta: float):
	if _done or _i < 0:
		return
	_t += delta
	var id: String = STEPS[_i]
	match id:
		"move":
			var step := player.global_position.distance_to(_last_pos)
			_moved += minf(step, 60.0) # A respawn or teleport must not count as walking
			_last_pos = player.global_position
			if _moved >= MOVE_GOAL:
				_complete()
		"dash":
			if GlobalData.run_kills - _kills0 >= DASH_KILLS:
				_complete()
			elif not _low_energy_hint and player.current_energy < 25.0:
				_low_energy_hint = true
				_hint.text = "OUT OF ENERGY? LET GO OF DASH. IT REFILLS WHEN YOU DON'T USE IT."
		"level":
			_spawn_t -= delta
			if _spawn_t <= 0.0 and _spawned < 16 and _live_trainees() < 5:
				_spawn_t = 1.8
				_spawned += 1
				_spawn("chaser", randf() * TAU, {"xp_mult": 2.2, "health_mult": 0.6}, 1.0, 0.75)
			if player.level >= 2 and not UpgradeManager.is_ui_active:
				_hint.text = "UPGRADES STACK. MATCHING ONES UNLOCK NAMED SYNERGIES."
				_complete(1.6)
		"shoot":
			if not is_instance_valid(_shooter):
				_complete()
			elif _t > 10.0:
				_hint.text = "YOUR SHAPE FIRES BY ITSELF. TURN TO LINE UP AN EDGE WITH THE SHOOTER."
		"combo":
			if player.highest_combo_run >= COMBO_GOAL or player.combo_count >= COMBO_GOAL:
				_complete()
	if _i >= 0 and _i < STEPS.size() and not _done and _t >= float(TIMEOUT[STEPS[_i]]):
		_complete()

var _advancing := false

func _complete(delay: float = 0.6):
	if _advancing or _done:
		return
	_advancing = true
	_pips_update(_i + 1)
	AudioManager.play_sfx("combo_tick", -4.0, 1.4, 1.5)
	var next := _i + 1
	await get_tree().create_timer(delay).timeout
	_advancing = false
	if _done:
		return
	_enter(next)

func _live_trainees() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_meta("trainee") and not e.get("is_dying"):
			n += 1
	return n

## Places a slowed training enemy `kind` on a ring around the player (screen-visible).
func _spawn(kind: String, angle: float, mods: Dictionary = {}, radius_mult: float = 1.0, speed_mult: float = SLOW) -> Node:
	var idx: int = spawner.ENEMY_INDEX.get(kind, 0)
	var pos: Vector2 = player.global_position + Vector2(SPAWN_RADIUS * radius_mult, 0).rotated(angle)
	var e: Node = spawner._spawn_enemy_at(idx, pos, mods)
	if e == null:
		return null
	e.set_meta("trainee", true)
	if "speed" in e:
		e.speed *= speed_mult
	return e

# ------------------------------------------------------------------ text
func _dash_text() -> String:
	if PadNav.using_pad:
		return "HOLD RT"
	if PadNav.touch_on():
		return "HOLD THE DASH BUTTON"
	return "HOLD %s (OR LEFT CLICK)" % GameSettings.key_name("dash")

func _move_text() -> String:
	if PadNav.using_pad:
		return "LEFT STICK TO MOVE"
	if PadNav.touch_on():
		return "DRAG ON THE LEFT TO MOVE"
	if GlobalData.use_mouse_controls:
		return "MOVE THE MOUSE TO MOVE"
	return "%s TO MOVE" % player._move_keys_text()

func _set_text(id: String):
	var head := ""
	var body := ""
	match id:
		"move":
			head = "MOVE"
			body = _move_text()
		"dash":
			head = "DASH"
			body = "%s AND RAM THE RED SHAPES.\nWHILE YOU DASH NOTHING CAN HURT YOU." % _dash_text()
		"level":
			head = "LEVEL UP"
			body = "KEEP KILLING TO FILL THE XP BAR.\nWHEN IT FILLS, PICK AN UPGRADE."
		"shoot":
			head = "NOW YOU SHOOT"
			body = "YOU FIRE FROM EVERY EDGE.\nKILL THE SHOOTER, AND DASH THROUGH ITS BULLETS."
		"combo":
			head = "COMBO"
			body = "KILL FAST TO CHAIN A COMBO.\nEVERY KILL EXTENDS THE TIMER."
	_head.text = head
	_body.text = body
	_pips_update(_i)
	_head.pivot_offset = _head.size / 2.0
	_head.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_head, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pips_update(done: int):
	var s := ""
	for k in STEPS.size():
		s += ("● " if k < done else "○ ")
	_pips.text = "TRAINING  " + s.strip_edges()

# ------------------------------------------------------------------ ui
func _build_ui():
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.name = "FirstRunUI"
	add_child(_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 170
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)
	_pips = _label(18, Color(0.6, 0.8, 1.0))
	box.add_child(_pips)
	_head = _label(52, NeonUI.CYAN)
	NeonUI.style_title(_head, NeonUI.CYAN, 52)
	box.add_child(_head)
	_body = _label(26, Color(0.9, 0.97, 1.0))
	box.add_child(_body)
	_hint = _label(20, NeonUI.GOLD.lerp(Color.WHITE, 0.3))
	box.add_child(_hint)
	_skip = Button.new()
	_skip.text = "SKIP TRAINING  [%s]" % ("Y" if PadNav.using_pad else "ENTER")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 16)
	NeonUI.style_button(_skip, Color(0.5, 0.6, 0.75))
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_skip.offset_left = 40
	_skip.offset_top = -80
	_skip.offset_bottom = -30
	_skip.offset_right = 300
	_skip.pressed.connect(func(): _finish(true))
	_layer.add_child(_skip)

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _unhandled_input(event: InputEvent):
	if _done:
		return
	if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		get_viewport().set_input_as_handled()
		_finish(true)

# ------------------------------------------------------------------ end
## Hands the run over to the normal spawner. `skipped` only changes the banner.
func _finish(skipped: bool):
	if _done:
		return
	_done = true
	var gd = GlobalData
	gd.first_run_done = true
	gd.save_game()
	if is_instance_valid(spawner):
		spawner.reset_clock()
		spawner.spawn_timer = 10.0 # First wave right away, as after the old tutorial
		spawner.tutorial_finished = true
	if is_instance_valid(_layer):
		for c in _layer.get_children():
			c.queue_free()
		if not skipped:
			_banner("TRAINING COMPLETE", "SURVIVE.")
		else:
			get_tree().create_timer(0.1).timeout.connect(_layer.queue_free)

func _banner(title: String, sub: String):
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 200
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)
	var t := _label(60, NeonUI.GREEN)
	NeonUI.style_title(t, NeonUI.GREEN, 60)
	t.text = title
	box.add_child(t)
	var s := _label(30, Color(0.9, 1.0, 0.95))
	s.text = sub
	box.add_child(s)
	AudioManager.play_sfx("level_up")
	var tw := box.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_layer.queue_free)

## Called by the player on death. Dying late in training counts as finished; an early death retries it.
func on_player_died():
	if _done:
		return
	_done = true
	if _i >= 2:
		GlobalData.first_run_done = true
		GlobalData.save_game()
	if is_instance_valid(_layer):
		_layer.queue_free()
