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
	var size := 38
	var label: Label

	func _ready() -> void:
		label = Label.new()
		label.text = text
		label.theme = UiKit.theme()
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 6)
		label.size = Vector2(600, size * 1.4)
		label.position = -label.size / 2.0
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
static func popup(parent: Node, pos: Vector2, text: String, color: Color, up: Vector2, rot: float, size := 38) -> void:
	var p := ScorePopup.new()
	p.size = size
	p.position = pos
	p.text = text
	p.color = color
	p.up = up
	p.rotation = rot
	parent.add_child(p)


## Big centred screen text ("COMBO x2!") that boings in and floats away. `parent` is a UI layer.
static func banner(parent: Node, text: String, color: Color, y := 520.0) -> void:
	var l := Label.new()
	l.theme = UiKit.theme()
	l.text = text
	l.add_theme_font_size_override("font_size", 72)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(720, 120)
	l.position = Vector2(0, y)
	l.pivot_offset = l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.scale = Vector2(0.2, 0.2)
	l.rotation = deg_to_rad(-8)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", deg_to_rad(3), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.5)
	tw.chain().set_parallel()
	tw.tween_property(l, "position:y", y - 80.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(l.queue_free)


## Rainbow confetti for combos and blasts.
static func confetti(parent: Node, pos: Vector2, r: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = 1.1
	p.spread = 180.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 300.0 + r * 2.0
	p.initial_velocity_max = 650.0 + r * 3.0
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	p.color = Color("#ff5fd2")
	p.hue_variation_min = -1.0
	p.hue_variation_max = 1.0
	p.emitting = true
	parent.add_child(p)
	parent.get_tree().create_timer(1.6).timeout.connect(p.queue_free)


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
