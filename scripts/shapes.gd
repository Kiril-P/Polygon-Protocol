class_name PlayerShapes
extends RefCounted
## Starting shapes. The circle is free; the rest are bought with shards in a small tree
## (a shape needs every shape in `requires`). A shape skips the unarmed opening: the run
## starts already evolved to `sides`, in exchange for a permanent trade-off for that run.
##
## Everything balance-related lives in LIST so it can be tuned in one place.
## hearts is added to the starting heart count, the rest are multipliers.

const LIST := [
	{"id": "circle", "name": "CIRCLE", "sides": 0, "cost": 0, "requires": [],
		"desc": "The original. Unarmed until you evolve.",
		"hearts": 0, "speed": 1.0, "damage": 1.0, "fire_interval": 1.0, "energy_recovery": 1.0},
	{"id": "spark", "name": "SPARK", "sides": 3, "cost": 200, "requires": ["circle"],
		"desc": "Starts as a triangle, armed from the first second. Light hull: -1 heart. +10% speed.",
		"hearts": -1, "speed": 1.10, "damage": 1.0, "fire_interval": 1.0, "energy_recovery": 1.0},
	{"id": "bastion", "name": "BASTION", "sides": 4, "cost": 450, "requires": ["spark"],
		"desc": "Starts as a square. Hits 20% harder but moves 15% slower.",
		"hearts": 0, "speed": 0.85, "damage": 1.20, "fire_interval": 1.0, "energy_recovery": 1.0},
	{"id": "comet", "name": "COMET", "sides": 5, "cost": 450, "requires": ["spark"],
		"desc": "Starts as a pentagon. Glass cannon: -2 hearts, +20% speed, dash recharges 25% faster.",
		"hearts": -2, "speed": 1.20, "damage": 1.0, "fire_interval": 1.0, "energy_recovery": 1.25},
	{"id": "hive", "name": "HIVE", "sides": 6, "cost": 1100, "requires": ["bastion", "comet"],
		"desc": "Starts as a hexagon: six streams, but each bullet deals 25% less and fires 25% slower.",
		"hearts": -1, "speed": 1.0, "damage": 0.75, "fire_interval": 1.25, "energy_recovery": 1.0},
]

static func get_def(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id:
			return s
	return {}

static func ids() -> Array:
	var out: Array = []
	for s in LIST:
		out.append(s["id"])
	return out

## Level at which the default progression reaches `sides` (circle -> triangle at 4, then each
## step costs one more level than the side count it adds: 4, 8, 13, 19, 26...).
static func level_for_sides(sides: int) -> int:
	if sides <= 0:
		return 1
	var lvl := 4
	for s in range(3, sides):
		lvl += s + 1
	return lvl

## Level of the next evolution for a run that starts as `sides`, keeping the same schedule
## the default run would have had from that shape onwards.
static func next_evolution_level(sides: int) -> int:
	return level_for_sides(sides) + sides + 1
