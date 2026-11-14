class_name Icons
## Simple vector icons drawn in code (no font or emoji needed), all centred on `c` and `s` px tall.

const W := Color.WHITE


static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col := W) -> void:
	var k := s / 48.0
	var lw := maxf(3.0, 5.0 * k)
	match name:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -18) * k, c + Vector2(20, 0) * k, c + Vector2(-13, 18) * k]), col)
		"next":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -16) * k, c + Vector2(4, 0) * k, c + Vector2(-20, 16) * k]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -16) * k, c + Vector2(22, 0) * k, c + Vector2(-2, 16) * k]), col)
		"replay":
			ci.draw_arc(c, 17.0 * k, deg_to_rad(-60), deg_to_rad(250), 28, col, lw, true)
			var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * 17.0 * k
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -9) * k, tip + Vector2(9, -2) * k, tip + Vector2(-2, 9) * k]), col)
		"grid":
			for gx in 3:
				for gy in 3:
					var p := c + Vector2((gx - 1) * 14.0, (gy - 1) * 14.0) * k
					_round_rect(ci, Rect2(p - Vector2(5.5, 5.5) * k, Vector2(11, 11) * k), 3.0 * k, col)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -21) * k, c + Vector2(22, -1) * k, c + Vector2(-22, -1) * k]), col)
			_round_rect(ci, Rect2(c + Vector2(-15, -3) * k, Vector2(30, 22) * k), 2.0 * k, col)
			_round_rect(ci, Rect2(c + Vector2(-5, 6) * k, Vector2(10, 13) * k), 2.0 * k, Color(0, 0, 0, 0.35))
		"share":
			var a := c + Vector2(-14, 0) * k
			var b := c + Vector2(13, -14) * k
			var d := c + Vector2(13, 14) * k
			ci.draw_line(a, b, col, lw * 0.8, true)
			ci.draw_line(a, d, col, lw * 0.8, true)
			for p in [a, b, d]:
				ci.draw_circle(p, 7.5 * k, col)
		"copy":
			var r1 := Rect2(c + Vector2(-17, -19) * k, Vector2(24, 28) * k)
			var r2 := Rect2(c + Vector2(-6, -8) * k, Vector2(24, 28) * k)
			_round_outline(ci, r1, 4.0 * k, col, lw * 0.8)
			_round_rect(ci, r2, 4.0 * k, col)
		"calendar":
			_round_rect(ci, Rect2(c + Vector2(-19, -15) * k, Vector2(38, 34) * k), 5.0 * k, col)
			ci.draw_rect(Rect2(c + Vector2(-19, -6) * k, Vector2(38, 3) * k), Color(0, 0, 0, 0.3))
			ci.draw_line(c + Vector2(-9, -21) * k, c + Vector2(-9, -11) * k, col, lw, true)
			ci.draw_line(c + Vector2(9, -21) * k, c + Vector2(9, -11) * k, col, lw, true)
			for gx in 3:
				for gy in 2:
					ci.draw_rect(Rect2(c + Vector2(-13 + gx * 10, 1 + gy * 8) * k, Vector2(6, 5) * k), Color(0, 0, 0, 0.3))
		"sound":
			_speaker(ci, c, k, col)
			ci.draw_arc(c + Vector2(4, 0) * k, 10.0 * k, -0.8, 0.8, 10, col, lw * 0.8, true)
			ci.draw_arc(c + Vector2(4, 0) * k, 18.0 * k, -0.8, 0.8, 12, col, lw * 0.8, true)
		"music":
			ci.draw_line(c + Vector2(-6, 12) * k, c + Vector2(-6, -18) * k, col, lw, true)
			ci.draw_line(c + Vector2(14, 7) * k, c + Vector2(14, -22) * k, col, lw, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -19) * k, c + Vector2(16, -24) * k,
				c + Vector2(16, -15) * k, c + Vector2(-8, -10) * k]), col)
			ci.draw_circle(c + Vector2(-11, 13) * k, 7.0 * k, col)
			ci.draw_circle(c + Vector2(9, 8) * k, 7.0 * k, col)
		"vibrate":
			_round_outline(ci, Rect2(c + Vector2(-9, -18) * k, Vector2(18, 36) * k), 4.0 * k, col, lw * 0.8)
			ci.draw_circle(c + Vector2(0, 12) * k, 2.0 * k, col)
			for side in [-1, 1]:
				ci.draw_line(c + Vector2(side * 15, -9) * k, c + Vector2(side * 19, -3) * k, col, lw * 0.7, true)
				ci.draw_line(c + Vector2(side * 19, -3) * k, c + Vector2(side * 15, 3) * k, col, lw * 0.7, true)
				ci.draw_line(c + Vector2(side * 15, 3) * k, c + Vector2(side * 19, 9) * k, col, lw * 0.7, true)
		"lock":
			ci.draw_arc(c + Vector2(0, -6) * k, 10.0 * k, PI, TAU, 16, col, lw, true)
			ci.draw_line(c + Vector2(-10, -6) * k, c + Vector2(-10, 0) * k, col, lw, true)
			ci.draw_line(c + Vector2(10, -6) * k, c + Vector2(10, 0) * k, col, lw, true)
			_round_rect(ci, Rect2(c + Vector2(-15, -1) * k, Vector2(30, 22) * k), 4.0 * k, col)
		"flame":
			# Teardrop flame with a pointed tip, yellow outside and white-hot inside.
			var outer := Color("#ffe14d") if col.a > 0.9 else col
			ci.draw_colored_polygon(_flame(c + Vector2(0, 4) * k, 15.0 * k, 22.0 * k), outer)
			if col.a > 0.9:
				ci.draw_colored_polygon(_flame(c + Vector2(0, 11) * k, 8.0 * k, 12.0 * k), Color.WHITE)
		"user":
			ci.draw_circle(c + Vector2(0, -9) * k, 10.0 * k, col)
			ci.draw_colored_polygon(_arc_poly(c + Vector2(0, 20) * k, 19.0 * k, PI, TAU), col)
		"palette":
			ci.draw_circle(c, 20.0 * k, col)
			var dots := [Color("#ff4fa3"), Color("#ffc928"), Color("#3fd56b"), Color("#3aa8ff")]
			for i in 4:
				var a := -2.4 + i * 0.85
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * 11.0 * k, 4.5 * k, dots[i])
			ci.draw_circle(c + Vector2(8, 9) * k, 4.0 * k, Color(0, 0, 0, 0.35))
		"gear":
			for i in 8:
				var ang := TAU * i / 8.0
				var d := Vector2(cos(ang), sin(ang))
				ci.draw_line(c + d * 12.0 * k, c + d * 21.0 * k, col, 8.0 * k, true)
			ci.draw_circle(c, 15.0 * k, col)
			ci.draw_circle(c, 6.0 * k, Color(0.18, 0.05, 0.3, 0.55))
		"power":
			ci.draw_arc(c + Vector2(0, 2) * k, 17.0 * k, deg_to_rad(-55), deg_to_rad(235), 28, col, lw, true)
			ci.draw_line(c + Vector2(0, -21) * k, c + Vector2(0, -2) * k, col, lw, true)
		"close":
			ci.draw_line(c + Vector2(-15, -15) * k, c + Vector2(15, 15) * k, col, lw * 1.2, true)
			ci.draw_line(c + Vector2(15, -15) * k, c + Vector2(-15, 15) * k, col, lw * 1.2, true)
		"pause":
			_round_rect(ci, Rect2(c + Vector2(-14, -17) * k, Vector2(10, 34) * k), 3.0 * k, col)
			_round_rect(ci, Rect2(c + Vector2(4, -17) * k, Vector2(10, 34) * k), 3.0 * k, col)


## Diagonal "off" slash drawn over an icon.
static func slash(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 48.0
	ci.draw_line(c + Vector2(-20, -20) * k, c + Vector2(20, 20) * k, Color(0.18, 0.05, 0.3), 9.0 * k, true)
	ci.draw_line(c + Vector2(-20, -20) * k, c + Vector2(20, 20) * k, Color("#ff5a5a"), 5.0 * k, true)


## Round bottom of radius `r` around `base`, pinching to a point `h` above it.
static func _flame(base: Vector2, r: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(0.0, PI, i / 12.0)  # bottom half circle, right to left
		pts.append(base + Vector2(cos(a), sin(a)) * r)
	for i in range(1, 8):
		var u := i / 8.0
		pts.append(base + Vector2(-r * (1.0 - u) * (1.0 - u * 0.3), -h * u + sin(u * PI) * 2.0))
	pts.append(base + Vector2(r * 0.15, -h - r * 0.4))
	for i in range(7, 0, -1):
		var u := i / 8.0
		pts.append(base + Vector2(r * (1.0 - u) * (1.0 - u * 0.3), -h * u))
	return pts


static func _speaker(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -7) * k, c + Vector2(-11, -7) * k, c + Vector2(0, -17) * k,
		c + Vector2(0, 17) * k, c + Vector2(-11, 7) * k, c + Vector2(-20, 7) * k]), col)


static func _arc_poly(center: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _round_outline(ci: CanvasItem, r: Rect2, rad: float, col: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(w))
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
