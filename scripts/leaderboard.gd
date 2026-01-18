extends Control

@onready var leaderboard_container = $UI/ScrollContainer/LeaderboardList
@onready var name_input = $UI/NameEntry/LineEdit
@onready var save_button = $UI/NameEntry/SaveButton
@onready var back_button = $UI/TopBar/BackButton
@onready var stats_panel = $UI/StatsPanel

var is_loading = false

func _ready():
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		name_input.text = gd.player_name
		refresh_leaderboard()
	
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	style_all_buttons()
	setup_animations()

func style_all_buttons():
	for btn in [back_button, save_button]:
		style_menu_button(btn)

func style_menu_button(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	normal.border_width_left = 4
	normal.border_color = Color(0.0, 0.8, 1.0, 0.6)
	normal.corner_radius_top_left = 2
	normal.corner_radius_bottom_right = 15
	normal.content_margin_left = 20
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.4, 0.8)
	hover.border_color = Color(0.0, 1.0, 1.0, 1.0)
	hover.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
	hover.shadow_size = 10
	
	var pressed = hover.duplicate()
	pressed.bg_color = Color(0.3, 0.1, 0.4, 0.9)
	pressed.border_color = Color(1.0, 0.0, 1.0, 1.0)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

func setup_animations():
	for btn in [back_button, save_button]:
		btn.pivot_offset = btn.size / 2
		btn.focus_mode = Control.FOCUS_NONE
		
		btn.mouse_entered.connect(func():
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("hover")
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
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
			btn.scale = Vector2(0.95, 0.95)
		)
		
		btn.button_up.connect(func():
			btn.scale = Vector2(1.1, 1.1)
		)

func refresh_leaderboard():
	if is_loading: return
	is_loading = true
	
	# Clear existing
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		
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
			var sw_result = await get_node("/root/SilentWolf").Scores.get_scores(10).sw_get_scores_complete
			load_label.queue_free()
			
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
					var e_kills = str(meta.get("kills", "0"))
					var e_level = str(meta.get("level", "0"))
					var e_time_raw = float(meta.get("time", 0.0))
					var e_time_str = "%d:%02d" % [int(e_time_raw / 60), int(e_time_raw) % 60]
					
					var is_local = false
					var p_name = score_entry.get("player_name", "UNKNOWN")
					if gd.player_id != "" and p_name == gd.player_name:
						is_local = true
					
					create_entry(str(rank), p_name, str(int(score_entry.get("score", 0))), e_kills, e_level, e_time_str, false, is_local)
					rank += 1
		else:
			load_label.text = "ONLINE SERVICES UNAVAILABLE - SHOWING LOCAL DATA"
			# Fallback to local
			var entries = gd.leaderboard.duplicate()
			entries.sort_custom(func(a, b): return a["score"] > b["score"])
			var rank = 1
			for entry in entries:
				var e_time = entry.get("time", 0.0)
				var e_time_str = "%d:%02d" % [int(e_time / 60), int(e_time) % 60]
				create_entry(str(rank), entry["name"], str(entry["score"]), str(entry["kills"]), str(entry["level"]), e_time_str, false, entry.get("id") == gd.player_id)
				rank += 1
	
	is_loading = false

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
	
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
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
			await get_node("/root/SilentWolf").Scores.save_score(name_text, gd.high_score_points, "main", metadata).sw_save_score_complete
		
		save_button.disabled = false
		save_button.text = "SAVE SCORE"
		
		# Refresh UI
		refresh_leaderboard()
		
		# Feedback animation
		var t = create_tween()
		t.tween_property(save_button, "modulate", Color(0, 5, 0), 0.1)
		t.tween_property(save_button, "modulate", Color.WHITE, 0.2)

func _on_back_pressed():
	if has_node("/root/GlobalData"):
		get_node("/root/GlobalData").next_scene_path = "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
