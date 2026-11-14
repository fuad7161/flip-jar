class_name Levels
## The level ladder: each level asks for a goal score inside a time limit, and every level
## is a little harder than the one before. Stars come from how much of the time you used.
##
## Config keys (shared with the daily jar):
##   flips/shakes   what you start with
##   spawn          how many of the smallest tiers can be dropped (more = messier jar)
##   drop_delay     seconds before the next piece appears
##   danger         depth of the overflow zone from the drop side (px)
##   overflow       seconds a piece may rest in the danger zone before game over
##   combo_window   max seconds between merges of one chain (a new drop also ends the chain)
##   reward_combo   merges in a row that earn a random +1 flip or +1 shake
##   blast_combo    merges in a row that shrink the biggest piece by one size
##   blast_cooldown seconds between blasts
##   vanish_tier    a piece of this tier pops by itself (10 = Sun, the biggest)
##   target/time    level goal: reach `target` points within `time` seconds

const COUNT := 60
## Fraction of the time limit you may use and still get 3 or 2 stars. Anything slower is 1 star.
const THREE_STAR := 0.5
const TWO_STAR := 0.75

## The daily jar is the same for everyone and doesn't change with level progress.
const DAILY := {"flips": 2, "shakes": 1, "spawn": 5, "drop_delay": 0.55, "danger": 150.0,
	"overflow": 1.0, "combo_window": 0.7, "reward_combo": 3, "blast_combo": 4, "blast_cooldown": 15.0,
	"vanish_tier": 10}


## Settings for level `n` (1-based). Levels get harder in three ways at once: you need more
## points per second, the jar gets stricter, and you start with fewer flips and shakes.
static func config(n: int) -> Dictionary:
	n = clampi(n, 1, COUNT)
	var i := n - 1
	var h := clampf(i / 29.0, 0.0, 1.0)  # strictness ramps over the first 30 levels, then holds
	return {
		"target": goal(n),
		"time": time_limit(n),
		"flips": 3 if n <= 4 else (2 if n <= 14 else 1),
		"shakes": 2 if n <= 3 else (1 if n <= 24 else 0),
		"spawn": 4 if n <= 3 else 5,
		"drop_delay": lerpf(0.6, 0.45, h),
		"danger": lerpf(140.0, 190.0, h),
		"overflow": lerpf(1.5, 0.8, h),
		"combo_window": lerpf(0.9, 0.5, h),
		"reward_combo": 3 if n <= 12 else 4,
		"blast_combo": 4 if n <= 12 else 5,
		"blast_cooldown": lerpf(8.0, 25.0, h),
		"vanish_tier": 10,
	}


## Points needed to clear level `n`: 200 on level 1, about 1500 on level 60.
static func goal(n: int) -> int:
	return int(round((200.0 + 22.0 * (n - 1)) / 10.0)) * 10


## Points per second you need to average for 1 star: 1.0 on level 1, rising to 7.5 on level 60.
## 3 stars needs twice this rate. (A tuning bot dropping every 1.2 s scores about 6-7 per second.)
static func pace(n: int) -> float:
	return 1.0 + 6.5 * pow(float(n - 1) / float(COUNT - 1), 0.75)


## Seconds allowed for level `n`. Level 1 is 200 s for 200 points.
static func time_limit(n: int) -> int:
	return int(round(goal(n) / pace(n)))


## 3 stars for finishing in half the time or less, 2 for three quarters or less, else 1.
static func stars_for(secs: float, limit: float) -> int:
	if secs <= limit * THREE_STAR:
		return 3
	if secs <= limit * TWO_STAR:
		return 2
	return 1


## "1:40.3"
static func fmt_time(secs: float) -> String:
	var tenths := int(floor(secs * 10.0 + 0.0001))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


## "3:20"
static func fmt_clock(secs: float) -> String:
	var s := int(ceil(maxf(secs, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


## Draws a five-point star on any CanvasItem.
static func draw_star(ci: CanvasItem, center: Vector2, r: float, filled: bool, color := Color("#ffd23f")) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	var outline := pts.duplicate()
	outline.append(pts[0])
	if filled:
		ci.draw_colored_polygon(pts, color)
		ci.draw_polyline(outline, color.darkened(0.45), maxf(2.0, r * 0.12), true)
		ci.draw_circle(center + Vector2(-r * 0.18, -r * 0.2), r * 0.14, Color(1, 1, 1, 0.55))
	else:
		ci.draw_colored_polygon(pts, Color(0.1, 0.0, 0.25, 0.35))
		ci.draw_polyline(outline, Color(1, 1, 1, 0.45), maxf(2.0, r * 0.1), true)
