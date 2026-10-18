extends CanvasLayer

@onready var control = $Control
@onready var container = $Control/HBoxContainer
@onready var title = $Control/Title
@onready var upgrade_button_scene = preload("res://scenes/upgrade_button.tscn")

func _ready():
	add_to_group("upgrade_ui")
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	NeonUI.style_title(title, NeonUI.CYAN, 56)
	NeonUI.pulse(title, 0.08, 2.2)
	$Control/BG.color = Color(0.0, 0.01, 0.04, 0.82)
	
	var manager = UpgradeManager
	if manager:
		manager.request_upgrade_ui.connect(_show_upgrade_options)

var _session: int = 0 # Bumped every time options are shown; stale fade-outs check it
var _selecting: bool = false
var _tweens: Array[Tween] = []

func _kill_tweens():
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()

func _show_upgrade_options(options: Array):
	_session += 1
	_selecting = false
	_kill_tweens()
	
	# Clear previous (remove immediately so old cards can never be clicked)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	# Initial UI state for animation
	visible = true
	control.modulate.a = 0
	container.scale = Vector2(0.8, 0.8)
	title.position.y = -50
	
	# Create buttons
	for i in range(options.size()):
		var upgrade_data = options[i]
		var btn = upgrade_button_scene.instantiate()
		container.add_child(btn)
		btn.setup(upgrade_data)
		btn.pressed.connect(_on_upgrade_selected.bind(upgrade_data, _session))
		# Short input lock so a click meant for the previous card can't pick from the next round
		btn.disabled = true
		
		# Individual button animation (pop in sequence)
		btn.modulate.a = 0
		btn.scale = Vector2(0.5, 0.5)
		var btn_tween = create_tween()
		_tweens.append(btn_tween)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(0.1 * i)
		btn_tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.1 * i)
	
	var unlock := create_tween()
	_tweens.append(unlock)
	unlock.tween_interval(0.45)
	unlock.tween_callback(func():
		for b in container.get_children():
			if b is Button and not _selecting:
				b.disabled = false)
	
	# Overall UI fade/slide in
	var main_tween = create_tween().set_parallel(true)
	_tweens.append(main_tween)
	main_tween.tween_property(control, "modulate:a", 1.0, 0.4)
	main_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_QUINT)
	main_tween.tween_property(title, "position:y", 50, 0.5).set_trans(Tween.TRANS_BACK)

func _on_upgrade_selected(upgrade_data: Dictionary, session: int = -1):
	if _selecting or (session != -1 and session != _session):
		return # Double-clicks must not apply two upgrades
	_selecting = true
	AudioManager.play_sfx("click")
	for btn in container.get_children():
		if btn is Button:
			btn.disabled = true
	
	var manager = UpgradeManager
	if manager:
		# May synchronously show the NEXT queued level-up (bumps _session)
		manager.apply_upgrade(upgrade_data)
		if manager.is_ui_active:
			return # Another level-up is already showing: keep the UI up
	
	# No more level-ups pending: fade out, unless something re-opened the UI meanwhile
	var my_session := _session
	_kill_tweens()
	var tween = create_tween()
	_tweens.append(tween)
	tween.tween_property(control, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		if my_session == _session:
			visible = false)
