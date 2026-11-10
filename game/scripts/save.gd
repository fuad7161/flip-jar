extends Node
## Autoload "Save": local progress, daily attempts, streaks and settings (user://save.json).

const PATH := "user://save.json"
const EPOCH_DATE := "2026-11-01"  # day number 1
const DAILY_ATTEMPTS := 3
const HISTORY_MAX := 100

var data := {}
var disabled := false   # tests set this so nothing is written to disk
var mode := "free"      # "free" or "daily", chosen on the menu


func _ready() -> void:
	load_data()
	Tiers.theme = data["theme"] if Tiers.THEMES.has(data["theme"]) else "classic"


func _defaults() -> Dictionary:
	return {
		"best_free": 0,
		"daily": {"date": "", "attempts": 0, "best": 0},
		"streak": 0,
		"streak_best": 0,
		"last_daily_date": "",
		"first_run_done": false,
		"flip_hint_done": false,
		"sound": true,
		"music": true,
		"vibrate": true,
		"theme": "classic",
		"games_played": 0,
		"profile": {"name": "Player", "avatar": 2},
		"history": [],      # newest first: {t, mode, score, merges, best_tier, flips, shakes, secs}
		"total_score": 0,
		"total_merges": 0,
		"total_secs": 0,
		"best_tier": 0,
		"difficulty": "medium",
		"best_diff": {"easy": 0, "medium": 0, "hard": 0},
	}


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]
	if not (data["history"] is Array):
		data["history"] = []
	if not (data["best_diff"] is Dictionary):
		data["best_diff"] = {"easy": 0, "medium": 0, "hard": 0}
	if not (data["profile"] is Dictionary):
		data["profile"] = {"name": "Player", "avatar": 2}


func save() -> void:
	if disabled:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


static func today() -> String:
	return Time.get_date_string_from_system(true)


static func yesterday() -> String:
	var u := Time.get_unix_time_from_datetime_string(today()) - 86400
	return Time.get_date_string_from_unix_time(u)


static func day_number() -> int:
	var now := Time.get_unix_time_from_datetime_string(today())
	var epoch := Time.get_unix_time_from_datetime_string(EPOCH_DATE)
	return int((now - epoch) / 86400) + 1


## Same seed for everyone on the same UTC day, so the drop order is shared.
static func daily_seed() -> int:
	return hash("flipjar-" + today())


func daily_sync() -> void:
	if data["daily"]["date"] != today():
		data["daily"] = {"date": today(), "attempts": 0, "best": 0}


func attempts_left() -> int:
	daily_sync()
	return DAILY_ATTEMPTS - int(data["daily"]["attempts"])


func daily_best() -> int:
	daily_sync()
	return int(data["daily"]["best"])


## Records a finished run. `stats` may hold merges, best_tier, flips, shakes, secs.
## Returns {"new_best": bool, "best": int}.
func record_run(run_mode: String, score: int, stats := {}) -> Dictionary:
	var new_best := false
	var best := 0
	if run_mode == "daily":
		daily_sync()
		data["daily"]["attempts"] = int(data["daily"]["attempts"]) + 1
		new_best = score > int(data["daily"]["best"])
		data["daily"]["best"] = maxi(score, int(data["daily"]["best"]))
		best = int(data["daily"]["best"])
		_update_streak()
	else:
		var diff: String = stats.get("diff", "medium")
		var bd: Dictionary = data["best_diff"]
		new_best = score > int(bd.get(diff, 0))
		bd[diff] = maxi(score, int(bd.get(diff, 0)))
		best = int(bd[diff])
		data["best_free"] = maxi(score, int(data["best_free"]))
	data["games_played"] = int(data["games_played"]) + 1
	data["first_run_done"] = true
	var entry := {
		"t": int(Time.get_unix_time_from_system()),
		"mode": run_mode,
		"score": score,
		"merges": int(stats.get("merges", 0)),
		"best_tier": int(stats.get("best_tier", 0)),
		"flips": int(stats.get("flips", 0)),
		"shakes": int(stats.get("shakes", 0)),
		"secs": int(stats.get("secs", 0)),
		"diff": str(stats.get("diff", "medium")),
		"new_best": new_best,
	}
	var hist: Array = data["history"]
	hist.push_front(entry)
	if hist.size() > HISTORY_MAX:
		hist.resize(HISTORY_MAX)
	data["history"] = hist
	data["total_score"] = int(data["total_score"]) + score
	data["total_merges"] = int(data["total_merges"]) + entry["merges"]
	data["total_secs"] = int(data["total_secs"]) + entry["secs"]
	data["best_tier"] = maxi(int(data["best_tier"]), entry["best_tier"])
	save()
	return {"new_best": new_best, "best": best}


## Best free-play score on one difficulty.
func best_for(diff: String) -> int:
	return int(data["best_diff"].get(diff, 0))


func _update_streak() -> void:
	var last: String = data["last_daily_date"]
	if last == today():
		return
	if last == yesterday():
		data["streak"] = int(data["streak"]) + 1
	else:
		data["streak"] = 1
	data["streak_best"] = maxi(int(data["streak"]), int(data["streak_best"]))
	data["last_daily_date"] = today()


## The streak shown on the menu: 0 if the player missed a day.
func current_streak() -> int:
	var last: String = data["last_daily_date"]
	if last == today() or last == yesterday():
		return int(data["streak"])
	return 0


func theme_unlocked(key: String) -> bool:
	return int(data["streak_best"]) >= int(Tiers.THEMES[key]["unlock"])


func set_theme(key: String) -> void:
	if theme_unlocked(key):
		data["theme"] = key
		Tiers.theme = key
		save()


func vibrate(ms: int) -> void:
	if data["vibrate"]:
		Input.vibrate_handheld(ms)
