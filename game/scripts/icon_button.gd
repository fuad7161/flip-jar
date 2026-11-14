class_name IconButton
extends Button
## Candy button that shows a drawn icon with a small caption under it (and an optional
## smaller sub-caption). `off` greys it and draws a red slash, for settings toggles.

var icon_name := "play"
var caption := "":
	set(v):
		caption = v
		queue_redraw()
var sub := "":
	set(v):
		sub = v
		queue_redraw()
var off := false:
	set(v):
		off = v
		queue_redraw()
var icon_px := 46.0
var caption_px := 21


static func make(icon_id: String, cap: String, color := "purple", h := 118.0) -> IconButton:
	var b := IconButton.new()
	b.icon_name = icon_id
	b.caption = cap
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.candy(b, color, false)
	return b


func _draw() -> void:
	var font := get_theme_default_font()
	var pressed_shift := 5.0 if is_pressed() or button_pressed else 0.0
	var lines := 1 if sub == "" else 2
	var text_h := caption_px * 1.15 + (caption_px * 0.85 if lines == 2 else 0.0)
	var top := (size.y - 10.0 - icon_px - 6.0 - text_h) / 2.0 + pressed_shift
	var c := Vector2(size.x / 2.0, top + icon_px / 2.0)
	var col := Color(1, 1, 1, 0.55) if off or disabled else Color.WHITE
	# Soft shadow under the icon so it pops off the candy body.
	Icons.draw(self, icon_name, c + Vector2(0, 3), icon_px, Color(0.15, 0.03, 0.3, 0.35))
	Icons.draw(self, icon_name, c, icon_px, col)
	if off:
		Icons.slash(self, c, icon_px)
	var y := top + icon_px + 6.0 + caption_px
	_text(font, caption, y, caption_px, col)
	if sub != "":
		_text(font, sub, y + caption_px * 0.95, int(caption_px * 0.78), Color(col.r, col.g, col.b * 0.8, 0.85))


func _text(font: Font, s: String, baseline: float, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((size.x - w) / 2.0, baseline)
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 4), Color(0.18, 0.05, 0.3, 0.75))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
