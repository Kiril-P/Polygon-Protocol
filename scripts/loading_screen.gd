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

func _ready():
	# Check if a target scene is set globally
	if has_node("/root/GlobalData"):
		target_scene_path = get_node("/root/GlobalData").next_scene_path
	
	# Pick a random tip
	tip_label.text = tips[randi() % tips.size()]
	
	# Start loading
	ResourceLoader.load_threaded_request(target_scene_path)
	progress_bar.value = 0
	
	# Initial fade in
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

func _process(_delta):
	scene_load_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	# Update bar
	var progress_value = progress[0] * 100
	progress_bar.value = lerp(progress_bar.value, float(progress_value), 0.1)
	
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		# Finished loading!
		status_label.text = "CORE STABILIZED. READY."
		progress_bar.value = 100
		
		# Small delay for satisfaction
		set_process(false)
		await get_tree().create_timer(0.5).timeout
		
		# Fade out and switch
		var t = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(func():
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(target_scene_path))
		)
	elif scene_load_status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "ERROR: CORE INITIALIZATION FAILED"
		set_process(false)
