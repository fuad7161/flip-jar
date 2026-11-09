extends Node2D
## Animated glowing backdrop: theme gradient, drifting light orbs and twinkling sparkles.
## Lives in a CanvasLayer below everything, so the jar flip does not rotate it.

const W := 720.0
const H := 1280.0
const ORBS := 9
const SPARKS := 34

var t := 0.0
var orbs := []
var sparks := []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var glows: Array = Tiers.glow_colors()
	for i in ORBS:
		orbs.append({
			"pos": Vector2(rng.randf_range(0, W), rng.randf_range(0, H)),
			"r": rng.randf_range(120.0, 260.0),
			"c": glows[i % glows.size()],
			"sp": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * rng.randf_range(6.0, 16.0),
			"ph": rng.randf() * TAU,
		})
	for i in SPARKS:
		sparks.append({
			"pos": Vector2(rng.randf_range(0, W), rng.randf_range(0, H)),
			"s": rng.randf_range(2.0, 5.0),
			"ph": rng.randf() * TAU,
			"f": rng.randf_range(1.0, 3.0),
		})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var top := Tiers.bg_top()
	var bottom := Tiers.bg_bottom()
	# Vertical gradient as a single quad with per-vertex colours.
	draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(W + 40, -40), Vector2(W + 40, H + 40), Vector2(-40, H + 40)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Glowing orbs: layered translucent circles fake a bloom.
	for o in orbs:
		var p: Vector2 = o["pos"] + o["sp"] * sin(t * 0.3 + o["ph"]) * 8.0
		var r: float = o["r"] * (1.0 + 0.08 * sin(t * 0.8 + o["ph"]))
		var c: Color = o["c"]
		for k in 5:
			var f := 1.0 - k * 0.18
			draw_circle(p, r * f, Color(c.r, c.g, c.b, 0.035 + k * 0.012))
	# Sparkles: little twinkling four-point stars.
	for s in sparks:
		var a: float = 0.5 + 0.5 * sin(t * s["f"] + s["ph"])
		var sz: float = s["s"] * (0.6 + a)
		var p: Vector2 = s["pos"] + Vector2(0, fmod(t * 6.0 * s["f"], 40.0) - 20.0)
		var c := Color(1, 1, 1, 0.15 + 0.6 * a)
		draw_line(p - Vector2(sz * 2, 0), p + Vector2(sz * 2, 0), c, 2.0, true)
		draw_line(p - Vector2(0, sz * 2), p + Vector2(0, sz * 2), c, 2.0, true)
		draw_circle(p, sz * 0.6, c)
