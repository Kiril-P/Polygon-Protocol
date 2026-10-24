extends Control

@onready var shard_label = $UI/TopBar/ShardLabel
@onready var grid = $UI/ScrollContainer/UpgradeGrid
@onready var background = $Background

var vault_upgrades = [
	{"id": "blast_cleaning", "name": "BLAST CLEANING", "desc": "Level-up shockwave vaporizes enemy bullets.", "cost": 50, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_001.png"},
	{"id": "energy_shield", "name": "ENERGY SHIELD", "desc": "Start with a protective barrier that absorbs 1 hit.", "cost": 100, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_003.png"},
	{"id": "shield_regen", "name": "SHIELD REGEN", "desc": "Shield restores itself after 15 seconds.", "cost": 250, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_005.png"},
	{"id": "starting_hearts", "name": "REINFORCED HULL", "desc": "Permanently increases starting Heart slots.", "cost": 150, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_007.png"},
	{"id": "sharp_edges", "name": "SHARP EDGES", "desc": "Increases base damage of all weapons.", "cost": 200, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_009.png"},
	{"id": "dash_mastery", "name": "DASH MASTERY", "desc": "Reduces Dash energy consumption.", "cost": 200, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_011.png"},
	{"id": "emergency_overdrive", "name": "EMERGENCY OVERDRIVE", "desc": "At 1 heart, gain 5s of extreme speed and fire rate. (Once per run)", "cost": 300, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_013.png"},
	{"id": "shard_multiplier", "name": "RECURSIVE HARVEST", "desc": "Earn 50% more Quantum Shards on every run.", "cost": 400, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_017.png"},
	{"id": "repulsive_armor", "name": "REPULSIVE ARMOR", "desc": "Taking damage releases a shockwave that pushes back nearby enemies.", "cost": 500, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_018.png"},
	{"id": "dash_resistance", "name": "PROTOCOL OVERRIDE", "desc": "Maintains 50% Dash efficiency even when crippled by bosses.", "cost": 750, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_020.png"}
]

func _ready():
	setup_background()
	update_ui()
	create_upgrade_cards()
	
	# Entry Animation
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	style_back_button()
	style_header()
	_add_shapes_button()

## Opens the shape tree (starting shapes bought with shards).
func _add_shapes_button():
	var back_btn = $UI/TopBar/BackButton
	var btn := Button.new()
	btn.text = "SHAPE TREE"
	btn.custom_minimum_size = Vector2(190, 0)
	btn.add_theme_font_size_override("font_size", 20)
	back_btn.get_parent().add_child(btn)
	back_btn.get_parent().move_child(btn, back_btn.get_index())
	NeonUI.style_button(btn, NeonUI.GOLD)
	setup_button_animations(btn)
	btn.pressed.connect(func():
		var t = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(func():
			GlobalData.next_scene_path = "res://scenes/shape_tree.tscn"
			Transition.go("res://scenes/loading_screen.tscn")))

func style_header():
	NeonUI.style_title($UI/TitleLabel, NeonUI.CYAN)
	NeonUI.style_title(shard_label, NeonUI.GOLD, -1)
	shard_label.add_theme_constant_override("shadow_outline_size", 12)
	NeonUI.pulse($UI/TitleLabel, 0.15, 2.4)

func style_back_button():
	var back_btn = $UI/TopBar/BackButton # Assuming this is the path
	if not back_btn: return
	style_menu_button(back_btn)
	setup_button_animations(back_btn)

func style_menu_button(btn: Button):
	NeonUI.style_button(btn)

func setup_button_animations(btn: Button):
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

func setup_background():
	NeonUI.living_background(self, background)

func update_ui():
	var total = GlobalData.total_shards
	shard_label.text = "QUANTUM SHARDS: " + str(total)

func create_upgrade_cards():
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	
	var gd = GlobalData
	
	for upg in vault_upgrades:
		var card = create_card(upg, gd)
		grid.add_child(card)

func create_card(data, gd):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 300)
	
	# Style the card: colour reflects state (owned/active, disabled, affordable, too expensive)
	var owned_now: bool = gd.has_upgrade(data["id"])
	var card_color := NeonUI.CYAN
	if owned_now:
		card_color = NeonUI.GREEN if gd.is_upgrade_active(data["id"]) else NeonUI.RED
	elif gd.total_shards >= data["cost"]:
		card_color = NeonUI.GOLD
	var style := NeonUI.panel_style(card_color, 0.78, 2, 12, 6)
	panel.add_theme_stylebox_override("panel", style)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 15)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	
	# Icon (vector, tinted by card state)
	var icon := UpgradeIcon.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	icon.set_icon(data["id"], card_color)
	
	# Title
	var title = Label.new()
	title.text = data["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	NeonUI.style_title(title, card_color)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_constant_override("shadow_outline_size", 0)
	v.add_child(title)
	
	# Desc
	var desc = Label.new()
	desc.text = data["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.8, 0.8, 0.8)
	v.add_child(desc)
	
	# Purchase Button
	var btn = Button.new()
	var owned = gd.has_upgrade(data["id"])
	var active = gd.is_upgrade_active(data["id"])
	var can_afford = gd.total_shards >= data["cost"]
	
	if owned:
		if active:
			btn.text = "ACTIVE"
		else:
			btn.text = "DISABLED"
			panel.modulate.a = 0.7
	elif data["id"] == "shield_regen" and not gd.has_upgrade("energy_shield"):
		btn.text = "LOCKED"
		btn.disabled = true
		panel.modulate.a = 0.5
	else:
		btn.text = str(data["cost"]) + " SHARDS"
		btn.disabled = not can_afford
	
	NeonUI.style_button(btn, card_color)
	setup_button_animations(btn)
	
	btn.pressed.connect(func():
		if owned:
			gd.toggle_upgrade(data["id"])
			AudioManager.play_sfx("click")
			create_upgrade_cards() # Refresh UI
		elif gd.total_shards >= data["cost"]:
			AudioManager.play_sfx("click")
			gd.total_shards -= data["cost"]
			gd.permanent_upgrades[data["id"]] = 1
			gd.save_game()
			# Visual feedback
			var t = create_tween()
			t.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.1)
			t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)
			t.tween_callback(func():
				update_ui()
				create_upgrade_cards()
			)
	)
	v.add_child(btn)
	
	# Hover animation
	panel.mouse_entered.connect(func():
		AudioManager.play_sfx("hover")
		var t = create_tween().set_parallel(true)
		t.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.2)
		t.tween_property(panel, "modulate", Color(1.2, 1.2, 1.5), 0.2)
	)
	panel.mouse_exited.connect(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2)
		t.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	)
	
	return panel

func _on_back_pressed():
	AudioManager.play_sfx("click")

	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		GlobalData.next_scene_path = "res://scenes/main_menu.tscn"
		Transition.go("res://scenes/loading_screen.tscn")
	)
