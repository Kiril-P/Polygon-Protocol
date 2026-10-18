extends Node
## Player-facing display / accessibility / control settings. Autoload: GameSettings.
## Stored in user://settings.cfg (separate from the save file so it survives save resets).
## Defaults reproduce the game exactly as shipped before these options existed.

signal changed

const PATH := "user://settings.cfg"

const PALETTES := [
	{"name": "DEFAULT", "heart": Color(1.0, 0.22, 0.34), "heart_dark": Color(0.28, 0.05, 0.1), "dash": Color(0.1, 0.9, 1.0),
		"dash_low": Color(1.0, 0.72, 0.15), "dash_empty": Color(1.0, 0.25, 0.3), "alert": Color(1.0, 0.1, 0.2)},
	# Blue / orange: separable for red-green colour blindness (protan / deutan)
	{"name": "BLUE / ORANGE", "heart": Color(1.0, 0.66, 0.0), "heart_dark": Color(0.28, 0.17, 0.0), "dash": Color(0.25, 0.6, 1.0),
		"dash_low": Color(1.0, 1.0, 1.0), "dash_empty": Color(0.8, 0.4, 0.0), "alert": Color(1.0, 0.6, 0.0)},
	# Maximum luminance contrast: white hearts, yellow dash
	{"name": "HIGH CONTRAST", "heart": Color(1.0, 1.0, 1.0), "heart_dark": Color(0.18, 0.18, 0.2), "dash": Color(1.0, 0.95, 0.2),
		"dash_low": Color(1.0, 0.5, 0.0), "dash_empty": Color(0.65, 0.65, 0.7), "alert": Color(1.0, 1.0, 1.0)},
]

const HUD_SIZES := [
	{"name": "NORMAL", "scale": 1.0},
	{"name": "LARGE", "scale": 1.25},
	{"name": "EXTRA LARGE", "scale": 1.5},
]

## action -> label (primary key is rebindable; alternates such as the arrow keys stay)
const REBIND_ACTIONS := {
	"move_up": "MOVE UP", "move_down": "MOVE DOWN", "move_left": "MOVE LEFT",
	"move_right": "MOVE RIGHT", "dash": "DASH",
}
const RESERVED_KEYS := [KEY_ESCAPE]

var glow: float = 1.0           # 0..1.5, multiplier on bloom and glow sprites
var shake: float = 1.0          # 0..1.5, multiplier on screen shake
var reduced_flash: bool = false
var palette: int = 0
var hud_size: int = 0
var bindings: Dictionary = {}   # action -> physical keycode (only overrides)

var modal_open: int = 0         # >0 while a settings overlay is up (blocks the pause toggle)

var _default_primary: Dictionary = {}
var _default_alts: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in REBIND_ACTIONS:
		var events := InputMap.action_get_events(action)
		_default_alts[action] = []
		for i in events.size():
			if events[i] is InputEventKey:
				if i == 0:
					_default_primary[action] = events[i].physical_keycode
				else:
					_default_alts[action].append(events[i].physical_keycode)
	load_settings()
	apply_bindings()
	call_deferred("apply_glow")

# ------------------------------------------------------------------ accessors
func pal() -> Dictionary:
	return PALETTES[clampi(palette, 0, PALETTES.size() - 1)]

func hud_scale() -> float:
	return HUD_SIZES[clampi(hud_size, 0, HUD_SIZES.size() - 1)]["scale"]

## Tames a flash colour (modulate overshoot) when "reduced flash" is on.
func flash(c: Color) -> Color:
	if not reduced_flash:
		return c
	return Color(minf(c.r, 1.3), minf(c.g, 1.3), minf(c.b, 1.3), c.a)

## Colour for full-screen impact / transition flashes: white, or a dark fade when reduced.
func screen_flash_color() -> Color:
	return Color(0.03, 0.04, 0.08) if reduced_flash else Color.WHITE

func scaled_shake(intensity: float) -> float:
	return intensity * shake

# ------------------------------------------------------------------ setters
func set_glow(v: float):
	glow = clampf(v, 0.0, 1.5)
	apply_glow()
	_changed()

func set_shake(v: float):
	shake = clampf(v, 0.0, 1.5)
	_changed()

func set_reduced_flash(on: bool):
	reduced_flash = on
	apply_glow()
	_changed()

func set_palette(i: int):
	palette = posmod(i, PALETTES.size())
	_changed()

func set_hud_size(i: int):
	hud_size = posmod(i, HUD_SIZES.size())
	_changed()

func reset_display():
	glow = 1.0
	shake = 1.0
	reduced_flash = false
	palette = 0
	hud_size = 0
	apply_glow()
	_changed()

func _changed():
	save_settings()
	changed.emit()

## Pushes glow settings to the post-process shader and to live glow sprites.
func apply_glow():
	var fx := get_node_or_null("/root/PostFX")
	if fx and fx.has_method("set_glow"):
		fx.set_glow(glow, reduced_flash)
	if get_tree():
		for n in get_tree().get_nodes_in_group("neon_glow"):
			if is_instance_valid(n) and n.has_meta("base_alpha"):
				n.modulate.a = float(n.get_meta("base_alpha")) * glow

# ------------------------------------------------------------------ key bindings
func key_for(action: String) -> int:
	return int(bindings.get(action, _default_primary.get(action, 0)))

func key_name(action: String) -> String:
	return keycode_name(key_for(action))

static func keycode_name(physical: int) -> String:
	var label := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
	if label == "":
		label = OS.get_keycode_string(physical)
	return label.to_upper() if label != "" else "?"

## Binds `physical` to `action`. If another action already uses that key the two swap.
## Returns false for reserved keys.
func set_binding(action: String, physical: int) -> bool:
	if physical in RESERVED_KEYS or not REBIND_ACTIONS.has(action):
		return false
	var old := key_for(action)
	for other in REBIND_ACTIONS:
		if other != action and key_for(other) == physical:
			bindings[other] = old
	bindings[action] = physical
	apply_bindings()
	_changed()
	return true

func reset_bindings():
	bindings.clear()
	apply_bindings()
	_changed()

func apply_bindings():
	var primaries := {}
	for action in REBIND_ACTIONS:
		primaries[key_for(action)] = true
	for action in REBIND_ACTIONS:
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key_for(action) as Key
		InputMap.action_add_event(action, ev)
		for alt in _default_alts[action]:
			if not primaries.has(alt):   # an arrow key now bound elsewhere stops being an alias
				var a := InputEventKey.new()
				a.physical_keycode = alt as Key
				InputMap.action_add_event(action, a)

# ------------------------------------------------------------------ persistence
func save_settings():
	var cfg := ConfigFile.new()
	cfg.set_value("display", "glow", glow)
	cfg.set_value("display", "shake", shake)
	cfg.set_value("display", "reduced_flash", reduced_flash)
	cfg.set_value("display", "palette", palette)
	cfg.set_value("display", "hud_size", hud_size)
	for action in bindings:
		cfg.set_value("keys", action, bindings[action])
	cfg.save(PATH)

func load_settings():
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	glow = clampf(float(cfg.get_value("display", "glow", 1.0)), 0.0, 1.5)
	shake = clampf(float(cfg.get_value("display", "shake", 1.0)), 0.0, 1.5)
	reduced_flash = bool(cfg.get_value("display", "reduced_flash", false))
	palette = clampi(int(cfg.get_value("display", "palette", 0)), 0, PALETTES.size() - 1)
	hud_size = clampi(int(cfg.get_value("display", "hud_size", 0)), 0, HUD_SIZES.size() - 1)
	bindings.clear()
	if cfg.has_section("keys"):
		for action in cfg.get_section_keys("keys"):
			if REBIND_ACTIONS.has(action):
				bindings[action] = int(cfg.get_value("keys", action))
