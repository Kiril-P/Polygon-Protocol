class_name SpawnDirector
extends RefCounted
## Data-driven spawn logic: which enemy to spawn when, scheduled formation
## events, and an intensity multiplier that eases off when the player is
## struggling and ramps up when they are clearing the screen.
## Data lives in res://data/spawn_waves.json so waves can be tuned without code.

const DATA_PATH := "res://data/spawn_waves.json"

var spawns: Array = []
var events: Array = []
var cfg: Dictionary = {}

var intensity: float = 1.0
var _next_event_time: Dictionary = {} # event id -> next trigger time
var _kill_times: Array[float] = []
var _last_kills: int = 0
var _breather_left: float = 0.0

func load_data(path: String = DATA_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SpawnDirector: cannot open " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SpawnDirector: invalid JSON in " + path)
		return false
	spawns = parsed.get("spawns", [])
	events = parsed.get("events", [])
	cfg = parsed.get("director", {})
	_next_event_time.clear()
	for ev in events:
		_next_event_time[ev["id"]] = float(ev.get("first", 0.0))
	return not spawns.is_empty()

## Weighted random enemy name for run time `t`.
func pick_enemy(t: float) -> String:
	var total := 0.0
	for s in spawns:
		if _active(s, t):
			total += float(s["weight"])
	if total <= 0.0:
		return "chaser"
	var roll := randf() * total
	for s in spawns:
		if not _active(s, t):
			continue
		roll -= float(s["weight"])
		if roll <= 0.0:
			return s["enemy"]
	return "chaser"

func _active(entry: Dictionary, t: float) -> bool:
	return t >= float(entry.get("from", 0.0)) and t < float(entry.get("until", INF))

## Events whose trigger time has been reached; each is rescheduled by its `every`.
func due_events(t: float) -> Array:
	var due: Array = []
	for ev in events:
		var id: String = ev["id"]
		if t >= _next_event_time[id]:
			due.append(ev)
			var every := float(ev.get("every", 0.0))
			_next_event_time[id] = t + every if every > 0.0 else INF
	return due

## Enemies in a formation event at run time `t`.
func event_count(ev: Dictionary, t: float) -> int:
	return int(ev.get("count", 1)) + int(float(ev.get("count_per_minute", 0)) * t / 60.0)

func start_breather():
	_breather_left = float(cfg.get("breather_seconds", 0.0))

func spawn_allowed(alive_enemies: int) -> bool:
	return alive_enemies < int(cfg.get("enemy_cap", 9999))

## Multiplier applied on top of the base spawn rate.
func rate_multiplier() -> float:
	var breather := float(cfg.get("breather_rate_mult", 1.0)) if _breather_left > 0.0 else 1.0
	return intensity * breather

## Call every frame. `total_kills` is the monotonically increasing run kill count.
func update(delta: float, t: float, hearts_ratio: float, total_kills: int, current_spawn_rate: float):
	_breather_left = maxf(0.0, _breather_left - delta)
	for i in range(maxi(0, total_kills - _last_kills)):
		_kill_times.append(t)
	_last_kills = total_kills
	var window := float(cfg.get("kill_window_seconds", 10.0))
	while not _kill_times.is_empty() and _kill_times[0] < t - window:
		_kill_times.pop_front()
	
	var target := 1.0
	var kill_rate := float(_kill_times.size()) / window
	if hearts_ratio <= float(cfg.get("struggling_hearts_ratio", 0.0)):
		target = float(cfg.get("struggling_intensity", 1.0))
	elif hearts_ratio >= float(cfg.get("dominating_hearts_ratio", 2.0)) \
			and kill_rate >= float(cfg.get("dominating_kill_ratio", 99.0)) * current_spawn_rate:
		target = float(cfg.get("dominating_intensity", 1.0))
	intensity = move_toward(intensity, target, float(cfg.get("adjust_per_second", 0.05)) * delta)
	intensity = clampf(intensity, float(cfg.get("intensity_min", 0.5)), float(cfg.get("intensity_max", 1.5)))
