extends CanvasLayer

@onready var control = $Control
@onready var bg = $Control/BG
@onready var menu_ui = $Control/VBoxContainer
@onready var stats_label = $Control/VBoxContainer/StatsLabel
@onready var total_shards_label = $Control/VBoxContainer/TotalShardsLabel
@onready var restart_btn = $Control/VBoxContainer/RestartButton
@onready var menu_btn = $Control/VBoxContainer/MenuButton

func _ready():
	visible = false
	control.modulate.a = 0
	
	# Add Leaderboard Button
	var lb_btn = Button.new()
	lb_btn.text = "LEADERBOARD"
	lb_btn.name = "LeaderboardButton"
	
	# Match other button sizes
	lb_btn.custom_minimum_size = Vector2(250, 50)
	lb_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if restart_btn:
		lb_btn.add_theme_font_size_override("font_size", restart_btn.get_theme_font_size("font_size"))
		
	menu_ui.add_child(lb_btn)
	# Move between restart and menu
	menu_ui.move_child(lb_btn, 4)
	lb_btn.pressed.connect(_on_leaderboard_pressed)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_show_death_screen)
	
	style_all_buttons()
	setup_button_animations()
	_decorate()

## Neon red "system failure" look: dim wash, glowing panel, glitch-split title.
func _decorate():
	bg.color = Color(0.06, 0.0, 0.02, 0.84)
	var panel := Panel.new()
	panel.name = "NeonPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", NeonUI.panel_style(NeonUI.RED, 0.78, 2, 22, 6))
	control.add_child(panel)
	control.move_child(panel, 1)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -450
	panel.offset_bottom = 450
	menu_ui.offset_left = -480
	menu_ui.offset_right = 480
	menu_ui.offset_top = -410
	menu_ui.offset_bottom = 410
	menu_ui.add_theme_constant_override("separation", 14)
	
	var title: Label = $Control/VBoxContainer/TitleLabel
	NeonUI.style_title(title, NeonUI.RED, 64)
	# Chromatic split copies behind the title for a glitchy look
	for spec in [[Vector2(-4, 0), Color(0.0, 1.0, 1.0, 0.45)], [Vector2(4, 0), Color(1.0, 0.0, 0.5, 0.45)]]:
		var ghost := Label.new()
		ghost.text = title.text
		ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.add_theme_font_size_override("font_size", 64)
		ghost.add_theme_color_override("font_color", spec[1])
		ghost.material = Neon.additive_material()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.show_behind_parent = true
		title.add_child(ghost)
		ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ghost.position = spec[0]
		var t := ghost.create_tween().set_loops()
		t.tween_interval(randf_range(0.6, 1.4))
		t.tween_property(ghost, "position", spec[0] * 3.0 + Vector2(0, randf_range(-3, 3)), 0.05)
		t.tween_property(ghost, "position", spec[0], 0.07)
	
	stats_label.add_theme_font_size_override("font_size", 26)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stats_label.add_theme_constant_override("line_spacing", 8)
	total_shards_label.add_theme_color_override("font_color", NeonUI.GOLD.lerp(Color.WHITE, 0.4))
	NeonUI.style_title(total_shards_label, NeonUI.GOLD, 20)
	total_shards_label.add_theme_constant_override("outline_size", 3)
	total_shards_label.add_theme_constant_override("shadow_outline_size", 8)

func style_all_buttons():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn: buttons.append(lb_btn)
	
	for btn in buttons:
		if not btn: continue
		style_menu_button(btn)
	if restart_btn:
		NeonUI.style_button(restart_btn, NeonUI.GREEN)

func style_menu_button(btn: Button):
	NeonUI.style_button(btn)

func setup_button_animations():
	var buttons = [restart_btn, menu_btn]
	var lb_btn = menu_ui.get_node_or_null("LeaderboardButton")
	if lb_btn:
		buttons.append(lb_btn)
		
	for btn in buttons:
		btn.pivot_offset = btn.custom_minimum_size / 2
		btn.focus_mode = Control.FOCUS_NONE # Remove selection border
		
		btn.mouse_entered.connect(func():
			AudioManager.play_sfx("hover")
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "modulate", Color(1.5, 1.5, 2.0), 0.2)
		)
		btn.mouse_exited.connect(func():
			var t = create_tween().set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
			t.tween_property(btn, "modulate", Color.WHITE, 0.2)
		)
		
		btn.button_down.connect(func():
			AudioManager.play_sfx("click")
			btn.scale = Vector2(0.95, 0.95)
		)
		
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)

var _summary: VBoxContainer
var _daily_label: Label

func _show_death_screen(stats: Dictionary):
	# Wait a tiny bit for the player death explosion to finish
	await get_tree().create_timer(1.0).timeout
	
	visible = true
	stats_label.visible = false
	_build_summary(stats)
	total_shards_label.text = "TOTAL SHARDS: " + str(GlobalData.total_shards)

	# Stylish Fade In
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	# Title "glitch" pop
	var title = $Control/VBoxContainer/TitleLabel
	var t2 = create_tween()
	t2.tween_property(title, "scale", Vector2(1.2, 1.2), 0.1)
	t2.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	
	add_vault_splash()
	VFX.shockwave(_screen_center(), 2.0, NeonUI.RED, 500.0)
	
	# New-best moment once the numbers have counted up
	var prev: Dictionary = stats.get("prev", {})
	if "score" in stats.get("broken", []) and int(prev.get("score", 0)) > 0:
		await get_tree().create_timer(1.5).timeout
		_new_best_moment()

func _screen_center() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size / 2.0)

func _label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l

## Counts a label up from 0 to `target`. `fmt` turns the number into text.
func _count_up(label: Label, target: float, fmt: Callable, duration: float = 0.9, delay: float = 0.3):
	label.text = fmt.call(0.0)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float): label.text = fmt.call(v), 0.0, target, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _fmt_time(v: float) -> String:
	return "%d:%02d" % [int(v / 60.0), int(v) % 60]

func _build_summary(stats: Dictionary):
	if is_instance_valid(_summary):
		_summary.queue_free()
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override("separation", 10)
	_summary.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_ui.add_child(_summary)
	menu_ui.move_child(_summary, stats_label.get_index())
	var broken: Array = stats.get("broken", [])
	var prev: Dictionary = stats.get("prev", {})
	var has_history := int(prev.get("score", 0)) > 0
	var gold := NeonUI.GOLD
	
	var killer: String = stats.get("killed_by", "")
	if killer != "":
		_summary.add_child(_label("TERMINATED BY  " + killer, 22, Color(1.0, 0.45, 0.5)))
	
	# Score, big
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 18)
	_summary.add_child(score_row)
	score_row.add_child(_label("SCORE", 26, Color(0.6, 0.8, 1.0)))
	var score_val := _label("0", 72, Color.WHITE)
	NeonUI.style_title(score_val, NeonUI.CYAN, 72)
	score_row.add_child(score_val)
	_count_up(score_val, float(stats.get("score", 0)), func(v): return str(int(v)))
	if stats.get("multiplier", 1.0) > 1.001:
		score_row.add_child(_label("x%.2f PROTOCOLS" % stats["multiplier"], 20, gold))
	if has_history and "score" in broken:
		var tag := _label("NEW BEST", 30, gold)
		score_row.add_child(tag)
		var pulse := tag.create_tween().set_loops()
		pulse.tween_property(tag, "modulate", Color(1.6, 1.4, 0.6), 0.5)
		pulse.tween_property(tag, "modulate", Color.WHITE, 0.5)
	elif has_history:
		_summary.add_child(_label("BEST  %d" % int(prev.get("score", 0)), 20, Color(0.6, 0.75, 0.9)))
	
	# Stat tiles
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 56)
	_summary.add_child(grid)
	var tiles := [
		["TIME", "time", float(stats.get("time", 0.0)), _fmt_time],
		["LEVEL", "level", float(stats.get("level", 1)), func(v): return str(int(v))],
		["KILLS", "kills", float(stats.get("kills", 0)), func(v): return str(int(v))],
		["COMBO", "combo", float(stats.get("highest_combo", 0)), func(v): return "x" + str(int(v))],
	]
	for tile in tiles:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		grid.add_child(box)
		box.add_child(_label(tile[0], 18, Color(0.6, 0.8, 1.0)))
		var val := _label("0", 40, Color.WHITE)
		box.add_child(val)
		_count_up(val, tile[2], tile[3], 0.9, 0.45)
		var is_best: bool = has_history and tile[1] in broken
		box.add_child(_label("NEW BEST" if is_best else " ", 16, gold))
	
	# Build: upgrade icons with counts, synergies on a gold line
	var counts: Dictionary = UpgradeManager.upgrade_counts
	if not counts.is_empty():
		var ids: Array = counts.keys()
		ids.sort_custom(func(a, b): return counts[a] > counts[b])
		var build := HBoxContainer.new()
		build.alignment = BoxContainer.ALIGNMENT_CENTER
		build.add_theme_constant_override("separation", 10)
		_summary.add_child(build)
		for id in ids.slice(0, 14):
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(58, 58)
			build.add_child(holder)
			var icon := UpgradeIcon.new()
			icon.custom_minimum_size = Vector2(58, 58)
			icon.size = Vector2(58, 58)
			holder.add_child(icon)
			icon.set_icon(str(id), gold if _is_special(str(id)) else NeonUI.CYAN)
			if counts[id] > 1:
				var n := _label("x%d" % counts[id], 15, Color.WHITE)
				n.position = Vector2(30, 36)
				holder.add_child(n)
	var syn_names := []
	for sid in UpgradeManager.active_synergies:
		for syn in UpgradeManager.SYNERGIES:
			if syn["id"] == sid:
				syn_names.append(syn["name"])
	if not syn_names.is_empty():
		_summary.add_child(_label(" + ".join(syn_names), 18, NeonUI.MAGENTA.lerp(Color.WHITE, 0.4)))
	
	# Protocols and daily
	var protos: Array = stats.get("protocols", [])
	var gd = GlobalData
	if stats.get("mode", "standard") == "daily":
		_daily_label = _label("", 20, NeonUI.GREEN.lerp(Color.WHITE, 0.4))
		_summary.add_child(_daily_label)
		_update_daily(stats)
		if gd.daily_submit_state == "pending":
			gd.daily_submit_finished.connect(func(_ok): _update_daily(stats), CONNECT_ONE_SHOT)
	elif not protos.is_empty():
		_summary.add_child(_label(Protocols.names(protos), 18, gold.lerp(Color.WHITE, 0.3)))
	
	_summary.add_child(_label("+%d SHARDS" % int(stats.get("shards", 0)), 28, gold))

func _is_special(id: String) -> bool:
	for u in UpgradeManager.upgrade_pool:
		if u["id"] == id:
			return u.get("is_special", false)
	return false

func _update_daily(stats: Dictionary):
	if not is_instance_valid(_daily_label):
		return
	var d: Dictionary = stats.get("daily", {})
	var state: String = GlobalData.daily_submit_state
	var board := "UPLOADING..." if state == "pending" else ("POSTED TO TODAY'S BOARD" if state == "ok" else "OFFLINE - SAVED LOCALLY")
	var best := "NEW DAILY BEST   " if d.get("daily_best", false) else ""
	_daily_label.text = "DAILY %s   %s%s   STREAK %d" % [GlobalData.run_daily_key.substr(5), best, board, int(d.get("streak", 1))]

## Gold flash, shockwave and confetti when the run beat the personal best score.
func _new_best_moment():
	AudioManager.play_sfx("level_up")
	var gold := NeonUI.GOLD
	VFX.shockwave(_screen_center(), 2.0, gold, 700.0)
	var flash := ColorRect.new()
	flash.color = GameSettings.flash(Color(gold.r, gold.g, gold.b, 0.35))
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)
	
	var banner := _label("NEW PERSONAL BEST", 54, gold)
	NeonUI.style_title(banner, gold, 54)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.position.y = 12
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(2.2, 2.2)
	banner.modulate.a = 0.0
	control.add_child(banner)
	var bt := banner.create_tween().set_parallel(true)
	bt.tween_property(banner, "modulate:a", 1.0, 0.12)
	bt.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var confetti := CPUParticles2D.new()
	confetti.amount = 70
	confetti.one_shot = true
	confetti.explosiveness = 1.0
	confetti.lifetime = 1.6
	confetti.direction = Vector2(0, -1)
	confetti.spread = 80.0
	confetti.gravity = Vector2(0, 520)
	confetti.initial_velocity_min = 380.0
	confetti.initial_velocity_max = 820.0
	confetti.scale_amount_min = 4.0
	confetti.scale_amount_max = 9.0
	confetti.color = gold
	confetti.position = get_viewport().get_visible_rect().size / 2.0 + Vector2(0, 80)
	confetti.emitting = true
	control.add_child(confetti)
	get_tree().create_timer(2.2, true, false, true).timeout.connect(func():
		if is_instance_valid(confetti): confetti.queue_free())

func add_vault_splash():
	var splash = Label.new()
	splash.text = "SPEND SHARDS IN EVOLUTION VAULT"
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.add_theme_font_size_override("font_size", 22)
	NeonUI.style_title(splash, NeonUI.GOLD, 22)
	splash.add_theme_constant_override("outline_size", 4)
	
	control.add_child(splash)
	splash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Center it horizontally using grow direction
	splash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	splash.position.y -= 120 # Above buttons
	
	# Entry animation
	splash.scale = Vector2.ZERO
	splash.pivot_offset = splash.size / 2
	var t = create_tween()
	t.tween_interval(0.5)
	t.tween_property(splash, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	t.tween_property(splash, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Pulsing
	var t2 = create_tween().set_loops()
	t2.tween_property(splash, "modulate", Color(1.5, 1.5, 2.0), 0.8)
	t2.tween_property(splash, "modulate", Color.WHITE, 0.8)

func _on_restart_pressed():
	get_tree().paused = false
	Transition.reload()

func _on_leaderboard_pressed():
	get_tree().paused = false
	GlobalData.next_scene_path = "res://scenes/leaderboard.tscn"
	Transition.go("res://scenes/loading_screen.tscn")

func _on_main_menu_pressed():
	get_tree().paused = false
	Transition.go("res://scenes/main_menu.tscn")
