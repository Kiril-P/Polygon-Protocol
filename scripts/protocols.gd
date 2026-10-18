class_name Protocols
extends RefCounted
## Pre-run risk/reward modifiers ("protocols"). Each one makes the run harder and adds to a
## score and shard multiplier. The Daily Protocol picks two of them from the UTC date so
## everyone plays the same run that day.

const LIST := [
	{"id": "swarm", "name": "SWARM", "desc": "40% more enemies, but they have 25% less health.", "bonus": 0.25},
	{"id": "hunters", "name": "HUNTERS", "desc": "Every enemy moves 25% faster.", "bonus": 0.25},
	{"id": "glass", "name": "GLASS CORE", "desc": "Start with 2 hearts and no meta hearts, but deal 50% more damage.", "bonus": 0.5},
	{"id": "low_power", "name": "LOW POWER", "desc": "Dash energy capacity is 40% smaller.", "bonus": 0.2},
	{"id": "vanguard", "name": "VANGUARD", "desc": "New enemy types arrive a full minute sooner.", "bonus": 0.4},
	{"id": "no_repairs", "name": "NO REPAIRS", "desc": "Repair Nanites never show up as an upgrade.", "bonus": 0.2},
	{"id": "elite_tide", "name": "ELITE TIDE", "desc": "Giant elites arrive twice as often.", "bonus": 0.3},
]
const DAILY_COUNT := 2

static func get_def(id: String) -> Dictionary:
	for p in LIST:
		if p["id"] == id:
			return p
	return {}

## Score and shard multiplier for a set of protocol ids (1.0 when empty).
static func multiplier(ids: Array) -> float:
	var m := 1.0
	for id in ids:
		m += float(get_def(id).get("bonus", 0.0))
	return m

static func names(ids: Array) -> String:
	var out := []
	for id in ids:
		out.append(str(get_def(id).get("name", id)))
	return " + ".join(out)

## UTC calendar date, e.g. "2026-10-18". Everyone on Earth shares the same daily run.
static func daily_key(unix_time: float = -1.0) -> String:
	var t := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var d := Time.get_date_dict_from_unix_time(int(t))
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

## Stable seed derived from the date key (String.hash() is stable across platforms).
static func daily_seed(key: String) -> int:
	return absi(("polygon-protocol-" + key).hash())

## The two protocols of the day. Depends only on the date key.
static func daily_ids(key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = daily_seed(key)
	var pool: Array = []
	for p in LIST:
		pool.append(p["id"])
	var out: Array = []
	for i in DAILY_COUNT:
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx])
		pool.remove_at(idx)
	return out
