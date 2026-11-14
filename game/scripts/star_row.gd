class_name StarRow
extends Control
## Three stars in a row. `play_in()` fills the earned ones one after another with a pop.

var earned := 0
var shown := 0          # stars currently drawn filled (animates up to `earned`)
var star_scale := [1.0, 1.0, 1.0]
var t := 0.0


func set_stars(n: int, animate := false) -> void:
	earned = clampi(n, 0, 3)
	star_scale = [1.0, 1.0, 1.0]
	if not animate:
		shown = earned
		queue_redraw()
		return
	shown = 0
	var tw := create_tween()
	tw.tween_interval(0.35)
	for i in earned:
		tw.tween_callback(_fill.bind(i))
		tw.tween_method(_set_scale.bind(i), 1.7, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12)


func _fill(i: int) -> void:
	shown = i + 1
	Sfx.play("star", 1.0 + 0.12 * i)
	Save.vibrate(25)


func _set_scale(v: float, i: int) -> void:
	star_scale[i] = v
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if shown > 0:
		queue_redraw()


func _draw() -> void:
	var r := minf(size.y * 0.42, size.x / 7.0)
	var gap := r * 2.3
	var mid := size / 2.0
	for i in 3:
		# The middle star sits a bit higher and bigger, like a podium.
		var c := mid + Vector2((i - 1) * gap, -r * 0.25 if i == 1 else r * 0.1)
		var rr: float = r * (1.15 if i == 1 else 0.95) * float(star_scale[i])
		var on := i < shown
		if on:
			draw_circle(c, rr * 1.25, Color(1, 0.9, 0.3, 0.12 + 0.06 * sin(t * 4.0 + i)))
		Levels.draw_star(self, c, rr, on)
