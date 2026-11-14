class_name LevelBar
extends Control
## Level HUD under the jar, no raw numbers:
##   top    GOAL tube: fills left to right as you score, pink -> orange -> yellow -> green,
##          a glowing leading edge that sparkles on every score, a trophy at the finish.
##   bottom TIME tube: drains right to left; green while 3 stars are possible, then yellow, then red.
##          Star chips sit on it at the 3-star and 2-star cut-offs and go dark once passed.
## Both are drawn as glossy candy tubes (vertex-shaded triangle strips). Touches pass through.

const BADGE_R := 36.0
const GOAL_H := 64.0
const TIME_H := 46.0
const SLICE := 3.0             # horizontal resolution of the tube mesh (px)
const ROWS := [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
const GOAL_STOPS := [[0.0, Color("#ff4fa3")], [0.4, Color("#ff9a2e")], [0.72, Color("#ffd23f")], [1.0, Color("#3fd56b")]]

var limit := 200.0
var used := 0.0
var score := 0
var target := 200
var t := 0.0
var shown_goal := 0.0
var bump_amt := 0.0
var sparks: Array = []         # [pos, vel, life]
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset(new_limit: float, new_target: int) -> void:
	limit = new_limit
	target = new_target
	used = 0.0
	score = 0
	shown_goal = 0.0
	sparks.clear()
	queue_redraw()


func set_score(new_score: int) -> void:
	if new_score > score:
		bump_amt = 1.0
		var edge := _goal_rect()
		var x := _fill_x(edge, float(new_score) / maxf(1.0, float(target)), true)
		for i in 7:
			var a := rng.randf_range(-PI, PI)
			sparks.append([Vector2(x, edge.get_center().y), Vector2(cos(a), sin(a)) * rng.randf_range(60.0, 180.0), 1.0])
	score = new_score


func _process(delta: float) -> void:
	t += delta
	var goal := clampf(float(score) / maxf(1.0, float(target)), 0.0, 1.0)
	shown_goal = lerpf(shown_goal, goal, minf(1.0, delta * 7.0))
	bump_amt = move_toward(bump_amt, 0.0, delta * 3.0)
	for s in sparks:
		s[0] += s[1] * delta
		s[1] *= 0.9
		s[2] -= delta * 1.8
	sparks = sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	queue_redraw()


func _goal_rect() -> Rect2:
	return Rect2(BADGE_R * 0.9, 10.0, size.x - BADGE_R * 1.8, GOAL_H)


func _time_rect() -> Rect2:
	return Rect2(BADGE_R * 0.9, 10.0 + GOAL_H + 46.0, size.x - BADGE_R * 1.8, TIME_H)


## Where a fill of `frac` ends: 0 is just past the left badge, 1 is the bar end
## (or the edge of the trophy badge), so even a sliver of progress is visible.
func _fill_x(r: Rect2, frac: float, right_badge: bool) -> float:
	var a := r.position.x + BADGE_R * 0.85
	var b := r.end.x - (BADGE_R * 0.85 if right_badge else 6.0)
	return a + (b - a) * clampf(frac, 0.0, 1.0)


func _draw() -> void:
	_draw_goal()
	_draw_time()


# --- GOAL ----------------------------------------------------------------------------

func _draw_goal() -> void:
	var r := _goal_rect()
	var swell := 4.0 * bump_amt
	r = r.grow_individual(0, swell, 0, swell)
	_track(r)
	# Quarter notches on the track, under the fill.
	for q in [0.25, 0.5, 0.75]:
		var x: float = _fill_x(r, q, true)
		draw_line(Vector2(x, r.position.y + 10), Vector2(x, r.end.y - 10), Color(1, 1, 1, 0.18), 3.0, true)
	var f := shown_goal
	var x1 := _fill_x(r, f, true)
	_caption(r, "GOAL", x1)
	if f > 0.004:
		var inner := r.grow(-6.0)
		var gx0 := _fill_x(r, 0.0, true)
		var gw := _fill_x(r, 1.0, true) - gx0
		_tube(Rect2(inner.position, Vector2(x1 - inner.position.x, inner.size.y)),
			func(x: float) -> Color: return _gradient((x - gx0) / gw), true)
		# Glowing leading edge.
		var cy := r.get_center().y
		var ex := x1
		for k in 4:
			draw_circle(Vector2(ex, cy), inner.size.y * (0.75 - k * 0.14), Color(1, 1, 0.85, 0.07 + 0.05 * k + 0.12 * bump_amt))
		draw_line(Vector2(ex - 3, cy - inner.size.y * 0.32), Vector2(ex - 3, cy + inner.size.y * 0.32), Color(1, 1, 1, 0.75), 4.0, true)
		if f > 0.85:
			# Almost there: the whole tube breathes.
			var glow := 0.18 + 0.12 * sin(t * 7.0)
			draw_style_box(_rim(r, Color(0.6, 1, 0.6, glow), 6), r.grow(4.0))
	for s in sparks:
		_sparkle(s[0], 7.0 * s[2], Color(1, 1, 0.8, s[2]))
	_badge(Vector2(r.position.x, r.get_center().y), Color("#ff4fa3"), "target", 1.0 + 0.12 * bump_amt)
	_badge(Vector2(r.end.x, r.get_center().y), Color("#ffc928") if f >= 0.999 else Color("#7a5cc4"), "trophy", 1.0)


func _gradient(p: float) -> Color:
	p = clampf(p, 0.0, 1.0)
	for i in range(1, GOAL_STOPS.size()):
		var a: Array = GOAL_STOPS[i - 1]
		var b: Array = GOAL_STOPS[i]
		if p <= float(b[0]):
			return (a[1] as Color).lerp(b[1], (p - float(a[0])) / (float(b[0]) - float(a[0])))
	return GOAL_STOPS[-1][1]


# --- TIME ------------------------------------------------------------------------------

func _draw_time() -> void:
	var r := _time_rect()
	var left_s := limit - used
	if left_s <= 10.0 and left_s > 0.0:
		r.position.x += sin(t * 40.0) * 2.5  # nervous shake in the last seconds
	_track(r)
	var used_frac := clampf(used / limit, 0.0, 1.0)
	var frac := 1.0 - used_frac
	_caption(r, "TIME", _fill_x(r, frac, false))
	var col := Color("#3fd56b")
	if used_frac > Levels.TWO_STAR:
		col = Color("#ff5a5a")
	elif used_frac > Levels.THREE_STAR:
		col = Color("#ffc928")
	if left_s <= 10.0 and left_s > 0.0:
		col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(t * 14.0))
	if frac > 0.004:
		var inner := r.grow(-5.0)
		_tube(Rect2(inner.position, Vector2(_fill_x(r, frac, false) - inner.position.x, inner.size.y)),
			func(_x: float) -> Color: return col, false)
	# Star chips at the cut-offs.
	for m in [[Levels.THREE_STAR, 3], [Levels.TWO_STAR, 2]]:
		var x: float = _fill_x(r, 1.0 - float(m[0]), false)
		var alive := used_frac <= float(m[0])
		draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y - 6), Color(1, 1, 1, 0.8 if alive else 0.25), 3.0, true)
		var n: int = m[1]
		var chip := Rect2(x - (n * 21.0 + 14.0) / 2.0, r.position.y - 34.0, n * 21.0 + 14.0, 30.0)
		var bg := Color(0.16, 0.04, 0.36, 0.92) if alive else Color(0.16, 0.04, 0.36, 0.5)
		var sb := _rim(chip, Color(1, 1, 1, 0.7 if alive else 0.25), 2)
		sb.draw_center = true
		sb.bg_color = bg
		draw_style_box(sb, chip)
		# Little pointer from the chip down to the tick.
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, chip.end.y - 1), Vector2(x + 6, chip.end.y - 1), Vector2(x, chip.end.y + 6)]), bg)
		for k in n:
			Levels.draw_star(self, Vector2(chip.position.x + 17.0 + k * 21.0, chip.get_center().y + 1.0), 9.5, alive)
	var warn := left_s <= 10.0 and left_s > 0.0
	_badge(Vector2(r.position.x, r.get_center().y), Color("#ff5a5a") if warn else Color("#3aa8ff"), "clock",
		1.0 + (0.1 * absf(sin(t * 7.0)) if warn else 0.0), 0.86)


# --- Drawing helpers ---------------------------------------------------------------------

## Half height of a capsule spanning [x0, x1] with radius rr, at x.
static func _half_h(x: float, x0: float, x1: float, rr: float) -> float:
	var dx := 0.0
	if x < x0 + rr:
		dx = x0 + rr - x
	elif x > x1 - rr:
		dx = x - (x1 - rr)
	return sqrt(maxf(rr * rr - dx * dx, 0.0))


## A glossy candy tube: per-vertex shading gives a round 3D look, a gloss band near the top,
## a darker belly, and (optionally) soft diagonal stripes that scroll.
func _tube(r: Rect2, color_at: Callable, stripes: bool) -> void:
	var rr := r.size.y / 2.0
	var x0 := r.position.x
	var x1 := r.end.x
	var cy := r.get_center().y
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var nrows: int = ROWS.size()
	var cols_n := int(ceil((x1 - x0) / SLICE)) + 1
	for i in cols_n:
		var x := minf(x0 + i * SLICE, x1)
		var hh := _half_h(x, x0, x1, rr)
		var base: Color = color_at.call(x)
		for v in ROWS:
			var y := cy + (float(v) * 2.0 - 1.0) * hh
			var c := base
			var gloss := 0.55 * exp(-pow((float(v) - 0.2) / 0.11, 2.0))
			var belly := 0.32 * smoothstep(0.55, 1.0, float(v))
			c = c.lightened(gloss).darkened(belly)
			if stripes:
				var s := sin(((x - (y - cy)) - t * 60.0) / 30.0 * TAU)
				c = c.lightened(0.09 * maxf(s, 0.0))
			pts.append(Vector2(x, y))
			cols.append(c)
	for i in cols_n - 1:
		for k in nrows - 1:
			var a := i * nrows + k
			var b := a + nrows
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## The empty groove: an inset tube, darker at the top like an inner shadow, with a light rim.
func _track(r: Rect2) -> void:
	var rr := r.size.y / 2.0
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.05, 0.0, 0.15, 0.35)
	shadow.set_corner_radius_all(int(rr))
	shadow.anti_aliasing = true
	draw_style_box(shadow, Rect2(r.position + Vector2(0, 6), r.size))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var nrows: int = ROWS.size()
	var cols_n := int(ceil(r.size.x / SLICE)) + 1
	var cy := r.get_center().y
	for i in cols_n:
		var x := minf(r.position.x + i * SLICE, r.end.x)
		var hh := _half_h(x, r.position.x, r.end.x, rr)
		for v in ROWS:
			var shade := 0.55 * (1.0 - smoothstep(0.0, 0.4, float(v)))
			var c := Color(0.17, 0.05, 0.36, 0.82).darkened(shade).lightened(0.12 * smoothstep(0.8, 1.0, float(v)))
			pts.append(Vector2(x, cy + (float(v) * 2.0 - 1.0) * hh))
			cols.append(c)
	for i in cols_n - 1:
		for k in nrows - 1:
			var a := i * nrows + k
			var b := a + nrows
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	draw_style_box(_rim(r, Color(1, 1, 1, 0.55), 3), r)


func _rim(r: Rect2, c: Color, w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.draw_center = false
	b.border_color = c
	b.set_border_width_all(w)
	b.set_corner_radius_all(int(r.size.y / 2.0))
	b.anti_aliasing = true
	return b


## Faint word inside the empty groove, near its right end; the fill covers it as it grows.
func _caption(r: Rect2, text: String, fill_end: float) -> void:
	var font := get_theme_default_font()
	var fs := int(r.size.y * 0.42)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(r.end.x - BADGE_R - 18.0 - w, r.get_center().y + fs * 0.36)
	if fill_end > pos.x - 30.0:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.22))


## Round bevelled badge with an icon.
func _badge(c: Vector2, col: Color, icon: String, scale_k := 1.0, size_k := 1.0) -> void:
	var rr := BADGE_R * scale_k * size_k
	draw_circle(c + Vector2(0, 5), rr, Color(0.05, 0.0, 0.15, 0.4))
	draw_circle(c, rr, col.darkened(0.3))
	draw_circle(c + Vector2(0, -2), rr * 0.86, col)
	draw_circle(c + Vector2(-rr * 0.25, -rr * 0.35), rr * 0.3, Color(1, 1, 1, 0.25))
	draw_arc(c, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0, true)
	var w := Color.WHITE
	var s := rr / BADGE_R
	match icon:
		"target":
			draw_arc(c, 20.0 * s, 0.0, TAU, 32, w, 4.0, true)
			draw_arc(c, 11.0 * s, 0.0, TAU, 32, w, 4.0, true)
			draw_circle(c, 4.5 * s, w)
		"clock":
			draw_arc(c, 19.0 * s, 0.0, TAU, 32, w, 4.0, true)
			var a := -PI / 2.0 + TAU * clampf(used / limit, 0.0, 1.0)
			draw_line(c, c + Vector2(cos(a), sin(a)) * 14.0 * s, w, 4.0, true)
			draw_line(c, c + Vector2(0, -10.0 * s), w, 4.0, true)
			draw_circle(c, 3.0 * s, w)
		"trophy":
			var cup := PackedVector2Array([c + Vector2(-14, -16) * s, c + Vector2(14, -16) * s,
				c + Vector2(10, 0) * s, c + Vector2(4, 5) * s, c + Vector2(-4, 5) * s, c + Vector2(-10, 0) * s])
			draw_colored_polygon(cup, w)
			draw_arc(c + Vector2(-14, -9) * s, 7.0 * s, PI * 0.5, PI * 1.5, 12, w, 3.0, true)
			draw_arc(c + Vector2(14, -9) * s, 7.0 * s, -PI * 0.5, PI * 0.5, 12, w, 3.0, true)
			draw_rect(Rect2(c + Vector2(-2.5, 4) * s, Vector2(5, 8) * s), w)
			draw_rect(Rect2(c + Vector2(-10, 12) * s, Vector2(20, 5) * s), w)


func _sparkle(p: Vector2, r: float, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
		p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
		p + Vector2(-r * 0.3, -r * 0.3)]), c)
