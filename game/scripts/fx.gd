class_name Fx
## Small one-shot visual effects: merge ring, confetti burst, floating score.


class Ring extends Node2D:
	const DUR := 0.4
	var color := Color.WHITE
	var r0 := 20.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= DUR:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / DUR
		var r := r0 * (1.0 + 1.3 * k)
		var c := Color(color.r, color.g, color.b, 1.0 - k)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 7.0 * (1.0 - k) + 1.0, true)


class ScorePopup extends Node2D:
	const DUR := 0.8
	var text := ""
	var color := Color.WHITE
	var t := 0.0
	var up := Vector2.UP
	var label: Label

	func _ready() -> void:
		label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 38)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 6)
		label.size = Vector2(240, 50)
		label.position = Vector2(-120, -25)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

	func _process(delta: float) -> void:
		t += delta
		if t >= DUR:
			queue_free()
			return
		position += up * 70.0 * delta
		var k := t / DUR
		modulate.a = 1.0 - k * k
		scale = Vector2.ONE * (1.0 + 0.25 * sin(k * PI))


static func ring(parent: Node, pos: Vector2, color: Color, r0: float) -> void:
	var ring := Ring.new()
	ring.position = pos
	ring.color = color
	ring.r0 = r0
	parent.add_child(ring)


## Floating "+N" text. `up` is screen-up in world space; `rot` is the camera rotation
## so the text stays readable while the jar is flipped.
static func popup(parent: Node, pos: Vector2, text: String, color: Color, up: Vector2, rot: float) -> void:
	var p := ScorePopup.new()
	p.position = pos
	p.text = text
	p.color = color
	p.up = up
	p.rotation = rot
	parent.add_child(p)


static func burst(parent: Node, pos: Vector2, color: Color, r: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10 + int(r / 8.0)
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0 + r * 1.5
	p.initial_velocity_max = 260.0 + r * 2.5
	p.damping_min = 250.0
	p.damping_max = 400.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0 + r * 0.04
	p.color = color
	p.emitting = true
	parent.add_child(p)
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
