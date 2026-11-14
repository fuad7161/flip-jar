class_name UiKit
## Candy-style UI: a shared theme (rounded, glossy, chunky buttons), bubbly press/idle
## animations, and pop-in helpers. Every scene calls UiKit.style_tree() once in _ready.

const CANDY := {
	"pink": Color("#ff4fa3"),
	"orange": Color("#ff9a2e"),
	"green": Color("#3fd56b"),
	"blue": Color("#3aa8ff"),
	"purple": Color("#a45cff"),
	"yellow": Color("#ffc928"),
	"teal": Color("#22d3c5"),
	"red": Color("#ff5a5a"),
}

static var _theme: Theme = null


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Nunito", "Baloo 2", "Fredoka", "Roboto", "sans-serif"])
	font.font_weight = 800
	t.default_font = font
	t.default_font_size = 30
	for cls in ["Label", "Button", "CheckButton", "LineEdit"]:
		t.set_color("font_outline_color", cls, Color(0.18, 0.05, 0.3, 0.75))
		t.set_constant("outline_size", cls, 8)
	t.set_color("font_color", "Label", Color.WHITE)
	_apply_button_styles(t, "Button", CANDY["purple"])
	# CheckButton: soft pill, no heavy candy body.
	var pill := _box(Color(1, 1, 1, 0.14), 28, 0)
	pill.content_margin_left = 18
	pill.content_margin_right = 18
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckButton", pill)
	var edit := _box(Color(1, 1, 1, 0.18), 24, 0)
	edit.border_color = Color(1, 1, 1, 0.5)
	edit.set_border_width_all(3)
	edit.content_margin_left = 20
	edit.content_margin_right = 20
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.35)
	sb.set_corner_radius_all(6)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


static func _box(bg: Color, radius: int, bottom: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(radius)
	b.border_width_bottom = bottom
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 8
	b.content_margin_bottom = 8 + bottom
	b.anti_aliasing = true
	return b


## Glossy candy button: bright body, darker "3D" lip at the bottom, light rim and a glow.
static func candy_box(c: Color, pressed := false, radius := 42) -> StyleBoxFlat:
	var lip := 4 if pressed else 10
	var b := _box(c, radius, lip)
	b.border_color = c.darkened(0.4)
	b.border_width_top = 3
	b.border_width_left = 3
	b.border_width_right = 3
	b.border_blend = false
	b.shadow_color = Color(c.r, c.g, c.b, 0.55)
	b.shadow_size = 14 if not pressed else 6
	if pressed:
		b.content_margin_top = 14
	b.bg_color = c.lightened(0.08) if not pressed else c.darkened(0.08)
	return b


static func _apply_button_styles(t: Object, cls: String, c: Color) -> void:
	var normal := candy_box(c)
	var hover := candy_box(c.lightened(0.12))
	var pressed := candy_box(c, true)
	var disabled := candy_box(Color(0.55, 0.52, 0.65))
	disabled.shadow_size = 0
	if t is Theme:
		var th := t as Theme
		th.set_stylebox("normal", cls, normal)
		th.set_stylebox("hover", cls, hover)
		th.set_stylebox("pressed", cls, pressed)
		th.set_stylebox("hover_pressed", cls, pressed)
		th.set_stylebox("disabled", cls, disabled)
		th.set_stylebox("focus", cls, StyleBoxEmpty.new())
		th.set_color("font_color", cls, Color.WHITE)
		th.set_color("font_hover_color", cls, Color.WHITE)
		th.set_color("font_pressed_color", cls, Color(1, 1, 0.85))
		th.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.6))
	else:
		var ctrl := t as Control
		ctrl.add_theme_stylebox_override("normal", normal)
		ctrl.add_theme_stylebox_override("hover", hover)
		ctrl.add_theme_stylebox_override("pressed", pressed)
		ctrl.add_theme_stylebox_override("hover_pressed", pressed)
		ctrl.add_theme_stylebox_override("disabled", disabled)


## Gives a button its colour and the bubbly press / release / idle-breathing animation.
static func candy(b: Button, color_key := "purple", breathe := true) -> void:
	_apply_button_styles(b, "Button", CANDY.get(color_key, CANDY["purple"]))
	juice(b, breathe)


static func juice(c: Control, breathe := true) -> void:
	if c.has_meta("juiced"):
		return
	c.set_meta("juiced", true)
	var center := func() -> void: c.pivot_offset = c.size / 2.0
	c.resized.connect(center)
	center.call()
	if c is BaseButton:
		var b := c as BaseButton
		b.button_down.connect(func() -> void: _tween_scale(c, Vector2(0.88, 0.84), 0.08, Tween.TRANS_QUAD))
		b.button_up.connect(func() -> void: _tween_scale(c, Vector2.ONE, 0.5, Tween.TRANS_ELASTIC))
	if breathe:
		var tw := c.create_tween().set_loops()
		var d := 0.9 + randf() * 0.5
		tw.tween_interval(randf() * 0.6)
		tw.tween_property(c, "rotation", deg_to_rad(1.2), d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(c, "rotation", deg_to_rad(-1.2), d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _tween_scale(c: Control, to: Vector2, dur: float, trans: int) -> void:
	if c.has_meta("scale_tw"):
		var old: Tween = c.get_meta("scale_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	tw.tween_property(c, "scale", to, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
	c.set_meta("scale_tw", tw)


## Quick "boing" used when a value changes (score, counters).
static func punch(c: CanvasItem, amount := 0.3) -> void:
	if c is Control:
		(c as Control).pivot_offset = (c as Control).size / 2.0
	var key := "punch_tw"
	if c.has_meta(key):
		var old: Tween = c.get_meta(key)
		if old != null and old.is_valid():
			old.kill()
	c.set("scale", Vector2.ONE * (1.0 + amount))
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	c.set_meta(key, tw)


## Pops a control in from nothing (scale + fade), optionally after a delay.
static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.2, 0.2)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)


## Applies the theme to every top-level Control under `root` and juices every Button.
static func style_tree(root: Node) -> void:
	for n in _all(root):
		if n is Control and not (n.get_parent() is Control):
			(n as Control).theme = theme()


static func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


## Rounded translucent card used for panels and history rows.
static func card(c := Color(1, 1, 1, 0.12), radius := 30) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(radius)
	b.border_color = Color(1, 1, 1, 0.28)
	b.set_border_width_all(3)
	b.shadow_color = Color(0.1, 0.0, 0.25, 0.35)
	b.shadow_size = 12
	b.content_margin_left = 24
	b.content_margin_right = 24
	b.content_margin_top = 16
	b.content_margin_bottom = 16
	b.anti_aliasing = true
	return b


## A column of related controls stacked top to bottom. Columns sit side by side in an
## HBoxContainer. No card or heading is drawn: just the buttons, in order.
static func group(_title: String, items: Array, _tint := Color.TRANSPARENT) -> Control:
	var p := MarginContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	for it in items:
		v.add_child(it)
	return p


## Hides a group column when none of its buttons are visible.
static func sync_group(p: Control) -> void:
	var any := false
	for c in p.get_child(0).get_children():
		if c is Button and c.visible:
			any = true
	p.visible = any
