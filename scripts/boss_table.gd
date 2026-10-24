class_name BossTable
extends RefCounted
## Every boss in one table: which script runs it, how it is introduced and which arena it
## fights in. Adding a boss = one script that extends BossBase + one entry here (+ music
## stems named boss_<id>_<layer>.ogg and an entry in AudioManager.BOSS_MAX_PHASE).
##
## The encounter order (what spawns when) lives in Spawner.BOSS_LADDER.

const LIST := {
	"fortress": {"script": "res://scripts/boss_fortress.gd", "title": "FORTRESS PROTOCOL", "arena": "ring", "color": Color(1.0, 0.2, 0.4)},
	"pulsar": {"script": "res://scripts/boss_pulsar.gd", "title": "PULSAR PROTOCOL", "arena": "ring", "color": Color(0.0, 1.0, 1.0)},
	"singularity": {"script": "res://scripts/boss_singularity.gd", "title": "SINGULARITY PROTOCOL", "arena": "ring", "color": Color(0.72, 0.3, 1.0)},
	"prism": {"script": "res://scripts/boss_prism.gd", "title": "PRISM PROTOCOL", "arena": "prism", "color": Color(1.0, 0.75, 0.2)},
}

static func get_def(id: String) -> Dictionary:
	return LIST.get(id, {})

static func ids() -> Array:
	return LIST.keys()
