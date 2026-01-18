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
	{"id": "repulsive_armor", "name": "REPULSIVE ARMOR", "desc": "Taking damage releases a shockwave that pushes back nearby enemies.", "cost": 500, "icon": "res://assets/kenney_rune-pack/PNG/Blue/Tile (outline)/runeBlue_tileOutline_018.png"}
]

func _ready():
	setup_background()
	update_ui()
	create_upgrade_cards()
	
	# Entry Animation
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

func setup_background():
	# Create a techy/grid background
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.05, 0.05, 0.1) # Deep space blue
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(bg_rect)
	
	# Add some "floating" particles for vibe
	var particles = CPUParticles2D.new()
	background.add_child(particles)
	particles.position = Vector2(576, 324)
	particles.amount = 50
	particles.lifetime = 10.0
	particles.preprocess = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(600, 400)
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 15.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.0, 0.8, 1.0, 0.2) # Dim Cyan dots

func update_ui():
	var total = get_node("/root/GlobalData").total_shards
	shard_label.text = "QUANTUM SHARDS: " + str(total)

func create_upgrade_cards():
	# Clear grid
	for child in grid.get_children():
		child.queue_free()
	
	var gd = get_node("/root/GlobalData")
	
	for upg in vault_upgrades:
		var card = create_card(upg, gd)
		grid.add_child(card)

func create_card(data, gd):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 300)
	
	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 1.0, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 15)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	
	# Icon
	var icon = TextureRect.new()
	icon.texture = load(data["icon"])
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(0.0, 0.8, 1.0)
	v.add_child(icon)
	
	# Title
	var title = Label.new()
	title.text = data["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
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
			style.border_color = Color(0.0, 1.0, 0.5, 0.8) # Green glow for active
		else:
			btn.text = "DISABLED"
			style.border_color = Color(1.0, 0.2, 0.2, 0.8) # Red glow for disabled
			panel.modulate.a = 0.7
	elif data["id"] == "shield_regen" and not gd.has_upgrade("energy_shield"):
		btn.text = "LOCKED"
		btn.disabled = true
		panel.modulate.a = 0.5
	else:
		btn.text = str(data["cost"]) + " SHARDS"
		btn.disabled = not can_afford
	
	btn.pressed.connect(func():
		if owned:
			gd.toggle_upgrade(data["id"])
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
			create_upgrade_cards() # Refresh UI
		elif gd.total_shards >= data["cost"]:
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
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
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("hover")
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
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
