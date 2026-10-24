class_name DeathReport
extends RefCounted
## The "how you died" line on the death screen: what hit you, how fast you went down and
## one concrete thing to try next time. Pure functions so tests can call them directly.

## One tip per killer (display names from EnemyBase.display_name and the bosses).
const TIPS := {
	"CHASER": "Chasers run straight at you and gather if you stand still. Keep moving and dash through the pack.",
	"FAIRY": "Fairies fire a few shots and leave. Dodge, don't chase them.",
	"SHOOTER": "Shooters orbit and fire 3-way bursts. Close in with a dash, or keep moving sideways to the burst.",
	"SPINNER": "Spinners spray a rotating spiral. Circle against the spin, or dash through it.",
	"TANK": "Tanks never stop chasing and fire a five-shot wall. Dash through the wall instead of dodging around it.",
	"ZIGZAGGER": "Zigzaggers weave while firing aimed shots. Don't run in a straight line.",
	"KAMIKAZE": "Kamikazes charge in a straight line once you are in range. Sidestep late, or dash into them.",
	"AEGIS": "The Aegis shield absorbs shots from the front. Flank it or dash through it.",
	"SPLITTER": "Splitters burst into fast shards. Kill them away from you and clear the shards with area damage.",
	"SNIPER": "The Sniper's aim locks when its beam flashes white. Move or dash the moment it flashes.",
	"MENDER": "Menders heal everything near them. Kill the Mender first.",
	"FORTRESS": "Boss fights drain your dash. Save it for dodging and hit the glowing hearts for big damage.",
	"PULSAR": "Pulsar's lasers never stop turning. Stand on a green shelter platform to block them and refuel your dash, and dash through the hearts in the gaps.",
	"SINGULARITY": "The Singularity blinks and pulls you in. Keep dash energy to escape the pull and watch for the gaps in its rings.",
	"PRISM": "The Prism fires fans aimed at you. Keep moving sideways and watch the arena walls: a flashing amber wall turns deadly 1.4 seconds later.",
	"ARENA WALL": "Prism walls flash amber before they overload. Stay away from a flashing wall and cut across the middle to reach the hearts.",
	"DATA CORRUPTION": "Glitch zones grow for a few seconds. Leave the area as soon as one appears.",
	"ENEMY FIRE": "Stray bullets add up. Dash through them: dashing makes you untouchable.",
}
const DEFAULT_TIP := "Dash is a shield: while you are dashing nothing can hurt you."

## `info`: {killer, kind ("shot"/"contact"/""), hits: [[seconds, source], ...], run_time,
## dash_empty, hearts_max, shield_used}. Returns {"headline": String, "detail": String}.
static func build(info: Dictionary) -> Dictionary:
	var killer: String = str(info.get("killer", ""))
	var kind: String = str(info.get("kind", ""))
	var hits: Array = info.get("hits", [])
	var verb := "SHOT BY" if kind == "shot" else ("RAMMED BY" if kind == "contact" else "TERMINATED BY")
	var headline := ("%s  %s" % [verb, killer]) if killer != "" else "SYSTEM FAILURE"

	var parts: Array = []
	# Burst: how many hearts went in the last stretch before death
	var window := 12.0
	var recent := 0
	var now: float = float(hits[hits.size() - 1][0]) if hits.size() > 0 else 0.0
	var sources: Array = []
	for h in hits:
		if now - float(h[0]) <= window:
			recent += 1
			if not str(h[1]) in sources:
				sources.append(str(h[1]))
	if recent >= 3:
		parts.append("Lost %d hearts in %ds (%s)." % [recent, int(maxf(now - float(hits[hits.size() - recent][0]), 1.0)), " + ".join(sources)])
	elif recent == 2 and sources.size() > 1:
		parts.append("Two hits in a row: %s." % " then ".join(sources))
	if bool(info.get("dash_empty", false)):
		parts.append("Your dash was empty. Let go of dash earlier to refill it.")
	elif float(info.get("run_time", 0.0)) < 60.0:
		parts.append("Early death: keep moving, enemies are slow at the start.")
	var tip: String = TIPS.get(killer, DEFAULT_TIP)
	parts.append(tip)
	return {"headline": headline, "detail": " ".join(parts)}
