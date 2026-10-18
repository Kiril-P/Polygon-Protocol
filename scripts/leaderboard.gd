extends Control

@onready var leaderboard_container = $UI/ScrollContainer/LeaderboardList
@onready var name_input = $UI/NameEntry/LineEdit
@onready var save_button = $UI/NameEntry/SaveButton
@onready var back_button = $UI/TopBar/BackButton
@onready var stats_panel = $UI/StatsPanel

var is_loading = false
var show_daily := false
var board_button: Button

func _ready():
	var gd = GlobalData
	name_input.text = gd.player_name
	refresh_leaderboard()

	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	board_button = Button.new()
	board_button.custom_minimum_size = Vector2(300, 50)
	board_button.add_theme_font_size_override("font_size", 22)
	board_button.pressed.connect(_on_board_pressed)
	$UI/TopBar.add_child(board_button)
	board_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	board_button.offset_left = -340
	board_button.offset_right = -40
	board_button.offset_top = 45
	board_button.offset_bottom = 100
	_update_board_button()
	
	style_all_buttons()
	setup_animations()
	_decorate()

func _decorate():
	NeonUI.living_background(self, $Background)
	NeonUI.style_title($UI/Title, NeonUI.CYAN)
	NeonUI.pulse($UI/Title, 0.12, 2.6)
	stats_panel.add_theme_stylebox_override("panel", NeonUI.panel_style(NeonUI.GOLD, 0.7, 2, 14, 6))
	var edit := $UI/NameEntry/LineEdit as LineEdit
	var field := NeonUI.panel_style(NeonUI.CYAN, 0.8, 2, 4, 3)
	edit.add_theme_stylebox_override("normal", field)
	edit.add_theme_stylebox_override("focus", NeonUI.panel_style(NeonUI.CYAN, 0.9, 2, 14, 3))
	edit.add_theme_color_override("font_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", NeonUI.CYAN)
	NeonUI.style_title($UI/NameEntry/Label, NeonUI.CYAN, -1)
	$UI/NameEntry/Label.add_theme_constant_override("outline_size", 3)
	$UI/NameEntry/Label.add_theme_constant_override("shadow_outline_size", 8)

func style_all_buttons():
	for btn in [back_button, save_button, board_button]:
		style_menu_button(btn)

func style_menu_button(btn: Button):
	NeonUI.style_button(btn)

func setup_animations():
	for btn in [back_button, save_button]:
		btn.pivot_offset = btn.size / 2
		btn.focus_mode = Control.FOCUS_NONE
		
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

func _update_board_button():
	board_button.text = "VIEW: ALL-TIME" if not show_daily else "VIEW: DAILY " + Protocols.daily_key().substr(5)

func _on_board_pressed():
	if is_loading:
		return
	show_daily = not show_daily
	_update_board_button()
	refresh_leaderboard()

func refresh_leaderboard():
	if is_loading: return
	is_loading = true
	
	# Clear existing
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	var gd = GlobalData
	
	# Update Stats Panel (Personal Best)
	if stats_panel:
		for child in stats_panel.get_children(): child.queue_free()
		var stats_vbox = VBoxContainer.new()
		stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_panel.add_child(stats_vbox)
		
		var stats_title = Label.new()
		stats_title.text = "PERSONAL BEST MISSION DATA"
		stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_title.add_theme_font_size_override("font_size", 20)
		stats_title.modulate = Color(0, 1, 1, 0.8)
		stats_vbox.add_child(stats_title)
		
		var stats_label = Label.new()
		var t = gd.high_score
		var time_str = "%d:%02d" % [int(t / 60), int(t) % 60]
		stats_label.text = "SCORE: %d  |  KILLS: %d  |  LEVEL: %d  |  TIME: %s" % [gd.high_score_points, gd.best_kills, gd.best_level, time_str]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 28)
		stats_label.modulate = Color(1.5, 1.5, 1.0) # Gold-ish glow
		stats_vbox.add_child(stats_label)

	# Headers
	create_entry("RANK", "NAME", "SCORE", "KILLS", "LEVEL", "TIME", true)
	
	# Loading indicator for the list
	var load_label = Label.new()
	load_label.text = "RETRIEVING GLOBAL DATA..."
	load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_label.modulate = Color(0.5, 0.5, 1.0)
	leaderboard_container.add_child(load_label)

	# Fetch from SilentWolf
	if has_node("/root/SilentWolf"):
		var board := "daily_" + Protocols.daily_key() if show_daily else "main"
		var sw_result = await get_node("/root/SilentWolf").Scores.get_scores(10, board).sw_get_scores_complete
		load_label.queue_free()
		
		if sw_result.success:
			var scores = sw_result.scores
			if scores.size() == 0:
				var empty_label = Label.new()
				empty_label.text = "NO GLOBAL DATA FOUND"
				empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				leaderboard_container.add_child(empty_label)
			else:
				var rank = 1
				for score_entry in scores:
					var meta = score_entry.get("metadata", {})
					var e_kills = str(int(float(meta.get("kills", 0))))
					var e_level = str(int(float(meta.get("level", 0))))
					var e_time_raw = float(meta.get("time", 0.0))
					var e_time_str = "%d:%02d" % [int(e_time_raw / 60), int(e_time_raw) % 60]
					
					var is_local = false
					var p_name = score_entry.get("player_name", "UNKNOWN")
					if gd.player_id != "" and p_name == gd.player_name:
						is_local = true
					
					create_entry(str(rank), p_name, str(int(score_entry.get("score", 0))), e_kills, e_level, e_time_str, false, is_local)
					rank += 1
		else:
			# Request failed (e.g. no connection)
			var error_label = Label.new()
			error_label.text = "COULD NOT CONNECT TO ONLINE SERVICES - SHOWING LOCAL DATA"
			error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			error_label.modulate = Color(1.0, 0.5, 0.5)
			leaderboard_container.add_child(error_label)
			
			# Fallback to local
			show_local_leaderboard(gd)
	else:
		load_label.text = "ONLINE SERVICES UNAVAILABLE - SHOWING LOCAL DATA"
		# Fallback to local
		show_local_leaderboard(gd)

	is_loading = false

func show_local_leaderboard(gd):
	if show_daily:
		if gd.daily_best_key == Protocols.daily_key() and gd.daily_best_score > 0:
			create_entry("-", gd.player_name, str(gd.daily_best_score), "-", "-", "-", false, true)
		return
	var entries = gd.leaderboard.duplicate()
	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	var rank = 1
	for entry in entries:
		var e_time = entry.get("time", 0.0)
		var e_time_str = "%d:%02d" % [int(e_time / 60), int(e_time) % 60]
		create_entry(str(rank), entry["name"], str(entry["score"]), str(entry["kills"]), str(entry["level"]), e_time_str, false, entry.get("id") == gd.player_id)
		rank += 1

func create_entry(rank, p_name, score, kills, level, time_val, is_header = false, is_local = false):
	var h_box = HBoxContainer.new()
	h_box.custom_minimum_size = Vector2(0, 45)
	leaderboard_container.add_child(h_box)
	
	var labels = [rank, p_name, score, kills, level, time_val]
	for i in range(labels.size()):
		var label = Label.new()
		label.text = labels[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_header:
			label.add_theme_font_size_override("font_size", 22)
			label.modulate = Color(0, 2, 2) # Cyan Glow
		else:
			label.add_theme_font_size_override("font_size", 18)
			if is_local:
				label.modulate = Color(2, 2, 0) # Yellow Glow
		h_box.add_child(label)

func _on_save_pressed():
	if is_loading: return
	
	var gd = GlobalData
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		name_text = "UNKNOWN"
	
	# Update local copy
	gd.update_leaderboard(name_text, gd.high_score_points, gd.best_kills, gd.best_level, gd.high_score)
	
	# Disable button during upload
	save_button.disabled = true
	save_button.text = "UPLOADING..."
	
	# Upload to SilentWolf
	if has_node("/root/SilentWolf"):
		var metadata = {
			"kills": gd.best_kills,
			"level": gd.best_level,
			"time": gd.high_score,
			"player_id": gd.player_id # Help identify unique users
		}
		# Note: SilentWolf uses 'main' leaderboard by default
		var sw_result = await get_node("/root/SilentWolf").Scores.save_score(name_text, gd.high_score_points, "main", metadata).sw_save_score_complete
		if not sw_result.success:
			save_button.text = "UPLOAD FAILED - RETRY?"
			save_button.disabled = false
			return
	
	save_button.disabled = false
	save_button.text = "SAVE SCORE"
	
	# Refresh UI
	refresh_leaderboard()
	
	# Feedback animation
	var t = create_tween()
	t.tween_property(save_button, "modulate", Color(0, 5, 0), 0.1)
	t.tween_property(save_button, "modulate", Color.WHITE, 0.2)

func _on_back_pressed():
	GlobalData.next_scene_path = "res://scenes/main_menu.tscn"
	Transition.go("res://scenes/loading_screen.tscn")
