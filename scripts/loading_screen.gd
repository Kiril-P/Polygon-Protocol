extends Control

@export var target_scene_path: String = "res://scenes/game.tscn"

@onready var progress_bar = %ProgressBar
@onready var status_label = %StatusLabel
@onready var tip_label = %TipLabel

var progress = []
var scene_load_status = 0

var tips = [
	"TIP: DASH INTO ENEMIES TO GENERATE XP SHARDS",
	"TIP: EVERY EVOLUTION INCREASES YOUR FIREPOWER",
	"TIP: BULLETS BOUNCE OFF THE ARENA BOUNDARIES",
	"TIP: WATCH FOR KAMIKAZE ENEMIES - THEY SPIN BEFORE CHARGING",
	"TIP: THE VOLATILE SINGULARITY UPGRADE IS EXTREMELY RARE",
	"TIP: KEEP MOVING TO AVOID GETTING SURROUNDED"
]

var glitch_timer: float = 0.0
var is_first_load: bool = true

func _ready():
	# Initial background color
	var bg = ColorRect.new()
	bg.name = "CyberBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.01, 0.02, 1.0) # Very dark blue
	add_child(bg)
	move_child(bg, 0)

	# Decide where to go
	if has_node("/root/GlobalData"):
		var gd = get_node("/root/GlobalData")
		# If this is the VERY first time (never even finished a run or changed this flag)
		# we go straight to the game. Otherwise, we go to main menu.
		if not gd.is_quick_start and (gd.next_scene_path == "" or gd.next_scene_path == null):
			target_scene_path = "res://scenes/game.tscn"
			# Mark that we've done the quick start once
			gd.is_quick_start = true
			gd.save_game()
		elif gd.next_scene_path != "" and gd.next_scene_path != null:
			target_scene_path = gd.next_scene_path
		else:
			target_scene_path = "res://scenes/main_menu.tscn"
	else:
		target_scene_path = "res://scenes/main_menu.tscn"
	
	# Cyberpunk Styling
	status_label.add_theme_color_override("font_color", Color(0, 1, 1)) # Cyan
	tip_label.add_theme_color_override("font_color", Color(1, 0, 1)) # Magenta
	
	# Pick a random tip
	tip_label.text = tips[randi() % tips.size()]
	
	# Start background loading
	ResourceLoader.load_threaded_request(target_scene_path)
	progress_bar.value = 0
	
	# Initial fade in
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

func setup_cyber_effects():
	# (Moved content into _ready to avoid redundant calls)
	pass

func _process(delta):
	scene_load_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	# Update bar
	var progress_value = progress[0] * 100
	progress_bar.value = lerp(progress_bar.value, float(progress_value), 0.1)
	
	# Text Glitch Effect
	glitch_timer += delta
	if glitch_timer > 0.1:
		glitch_timer = 0
		if randf() < 0.05: # 5% chance to glitch
			status_label.position += Vector2(randf_range(-5, 5), randf_range(-2, 2))
			status_label.modulate = Color(2, 2, 2) # Flash white
			await get_tree().create_timer(0.05).timeout
			status_label.position = Vector2.ZERO # Note: this might need adjustment if using containers
			status_label.modulate = Color.WHITE
	
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		# Finished loading!
		if progress_bar.value > 95: # Ensure bar looks full
			status_label.text = "CORE STABILIZED. READY."
			progress_bar.value = 100
			
			# Small delay for satisfaction
			set_process(false)
			await get_tree().create_timer(1.0).timeout # Longer delay for first splash
			
			# Final Cyber Transition
			trigger_glitch_out()
	elif scene_load_status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "ERROR: CORE INITIALIZATION FAILED"
		set_process(false)

func trigger_glitch_out():
	var t = create_tween()
	# Shake screen
	for i in range(10):
		t.tween_property(self, "position", Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.03)
	
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		if has_node("/root/GlobalData"):
			get_node("/root/GlobalData").next_scene_path = ""
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(target_scene_path))
	)
