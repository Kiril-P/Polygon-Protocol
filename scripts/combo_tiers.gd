class_name ComboTiers
extends RefCounted
## Escalating combo tiers shared by the HUD (name, colour) and the player (juice on tier-up).
## Tier -1 means "no combo yet" (fewer than 5 chained kills).

const TIERS := [
	{"min": 5, "name": "CHAIN", "color": Color(0.85, 0.95, 1.0)},
	{"min": 10, "name": "SURGE", "color": Color(0.2, 1.0, 1.0)},
	{"min": 20, "name": "FRENZY", "color": Color(1.0, 0.9, 0.2)},
	{"min": 35, "name": "OVERLOAD", "color": Color(1.0, 0.5, 0.12)},
	{"min": 50, "name": "SINGULARITY", "color": Color(1.0, 0.25, 0.65)},
]

static func tier_for(combo: int) -> int:
	var t := -1
	for i in TIERS.size():
		if combo >= int(TIERS[i]["min"]):
			t = i
	return t

static func color(tier: int) -> Color:
	if tier < 0:
		return Color(0.85, 0.95, 1.0)
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]["color"]

static func tier_name(tier: int) -> String:
	return "" if tier < 0 else str(TIERS[clampi(tier, 0, TIERS.size() - 1)]["name"])

## Kills to the next tier, or -1 at the top.
static func next_min(tier: int) -> int:
	return -1 if tier >= TIERS.size() - 1 else int(TIERS[tier + 1]["min"])
