extends Node
## Anonymous per-run telemetry. Autoload name: Telemetry.
##
## One record per finished run: protocols picked, upgrade picks in order, what killed the
## player, and the headline numbers. There is no player name, no player_id and no install id,
## so records cannot be tied to a person or linked to each other.
##
## Every record is appended to user://telemetry.jsonl (local, last MAX_LOG_LINES runs).
## When "SHARE RUN DATA" is on (Accessibility menu) it is also posted to the SilentWolf board
## BOARD. Debug builds, tests and the trailer capture never post.

const SCHEMA := 1
const BOARD := "telemetry_v1"
const LOG_PATH := "user://telemetry.jsonl"
const MAX_LOG_LINES := 100
const POST_TIMEOUT := 8.0

## Tests set this to false so they never reach the network; editor runs are skipped via is_debug_build().
var post_enabled := true

var _picks: Array = []   # [[level, upgrade_id], ...] in the order they were taken
var _hits: Array = []    # [[seconds_into_run, source], ...]
var _active := false
var _posting := false

func begin_run():
	_picks.clear()
	_hits.clear()
	_active = true

func note_pick(upgrade_id: String, level: int):
	if _active:
		_picks.append([level, upgrade_id])

func note_hit(source: String, run_clock: float):
	if _active:
		_hits.append([snappedf(run_clock, 0.1), source])

## Hits so far as [[seconds, source], ...] (the death screen reads this).
func hits() -> Array:
	return _hits

## Builds the record. Kept separate from sending so tests can inspect it.
func build_record(stats: Dictionary) -> Dictionary:
	var gd = get_node("/root/GlobalData")
	var syn: Array = []
	for sid in get_node("/root/UpgradeManager").active_synergies:
		syn.append(str(sid))
	var last_hits: Array = _hits.slice(maxi(_hits.size() - 6, 0))
	return {
		"schema": SCHEMA,
		"build": str(ProjectSettings.get_setting("application/config/version", "unversioned")),
		"platform": OS.get_name(),
		"mode": str(stats.get("mode", "standard")),
		"protocols": stats.get("protocols", []),
		"shape": str(stats.get("shape", "circle")),
		"difficulty": int(gd.difficulty_level),
		"first_run": bool(stats.get("first_run", false)),
		"killed_by": str(stats.get("killed_by", "")),
		"hits": last_hits,
		"hearts_lost": _hits.size(),
		"dash_empty": bool(stats.get("dash_empty", false)),
		"level": int(stats.get("level", 1)),
		"time": snappedf(float(stats.get("time", 0.0)), 0.1),
		"kills": int(stats.get("kills", 0)),
		"score": int(stats.get("score", 0)),
		"combo": int(stats.get("highest_combo", 0)),
		"picks": _picks.duplicate(),
		"synergies": syn,
	}

## Call once when the run ends.
func end_run(stats: Dictionary):
	if not _active:
		return
	_active = false
	var gd = get_node("/root/GlobalData")
	if gd.saving_disabled:
		return
	var rec := build_record(stats)
	_append_log(rec)
	if _should_post():
		_post(rec)

func _should_post() -> bool:
	if not post_enabled or OS.is_debug_build():
		return false
	if not get_node("/root/GameSettings").share_run_data:
		return false
	return get_node("/root/GlobalData").online_submit_enabled

func _post(rec: Dictionary):
	if _posting:
		return
	var sw := get_node_or_null("/root/SilentWolf")
	if sw == null:
		return
	_posting = true
	get_tree().create_timer(POST_TIMEOUT, true, false, true).timeout.connect(func(): _posting = false)
	# "anon" is a constant on purpose: nothing identifying leaves the machine.
	var res = await sw.Scores.save_score("anon", int(rec["score"]), BOARD, rec).sw_save_score_complete
	_posting = false
	if not res.get("success", false):
		push_warning("Telemetry post failed (ignored)")

func _append_log(rec: Dictionary):
	var lines: PackedStringArray = []
	if FileAccess.file_exists(LOG_PATH):
		lines = FileAccess.get_file_as_string(LOG_PATH).split("\n", false)
	lines.append(JSON.stringify(rec))
	if lines.size() > MAX_LOG_LINES:
		lines = lines.slice(lines.size() - MAX_LOG_LINES)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
