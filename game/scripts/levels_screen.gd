extends Node2D
## Level select: every level as a tile with its best stars and best time. Cleared levels can be
## replayed to chase more stars; the next level is open; everything after it stays locked.

const COLUMNS := 4

var grid: GridContainer
var scroll: ScrollContainer


## One level tile: the number, the best stars and best time, or a padlock when locked.
class LevelTile extends Button:
	var n := 1
	var stars := 0
	var secs := -1.0
	var locked := false
	var current := false
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if current:
			queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var w := size.x
		var h := size.y
		var lift := -4.0 if not locked else 0.0  # sit above the button's 3D lip
		if current:
			var glow := 0.25 + 0.2 * sin(t * 4.0)
			draw_arc(size / 2.0, w * 0.52, 0.0, TAU, 48, Color(1, 0.95, 0.5, glow), 6.0, true)
		if locked:
			# Padlock.
			var c := Vector2(w / 2.0, h * 0.5)
			var col := Color(1, 1, 1, 0.55)
			draw_arc(c + Vector2(0, -h * 0.06), w * 0.13, PI, TAU, 24, col, 7.0, true)
			draw_rect(Rect2(c + Vector2(-w * 0.2, -h * 0.06), Vector2(w * 0.4, h * 0.26)), col)
			draw_circle(c + Vector2(0, h * 0.06), w * 0.04, Color(0.3, 0.25, 0.45))
			_text(font, str(n), Vector2(w / 2.0, h * 0.2), 24, Color(1, 1, 1, 0.5))
			return
		_text(font, str(n), Vector2(w / 2.0, h * 0.32 + lift), 52, Color.WHITE)
		var r := w * 0.1
		for i in 3:
			var c := Vector2(w / 2.0 + (i - 1) * r * 2.25, h * 0.62 + lift - (r * 0.25 if i == 1 else 0.0))
			Levels.draw_star(self, c, r * (1.12 if i == 1 else 0.95), i < stars)
		if secs >= 0.0:
			_text(font, Levels.fmt_time(secs), Vector2(w / 2.0, h * 0.84 + lift), 20, Color(1, 1, 0.85))
		else:
			_text(font, "PLAY!", Vector2(w / 2.0, h * 0.84 + lift), 22, Color(1, 1, 0.6))

	func _text(font: Font, s: String, center: Vector2, fs: int, col: Color) -> void:
		var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(center.x - sz.x / 2.0, center.y + fs * 0.35)
		draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), Color(0.18, 0.05, 0.3, 0.8))
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Tiers.background())
	scroll = ScrollContainer.new()
	scroll.size = Vector2(720, 1280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$UI.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	UiKit.style_tree($UI)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var back := Button.new()
	back.text = "‹ BACK"
	back.custom_minimum_size = Vector2(190, 80)
	back.add_theme_font_size_override("font_size", 28)
	UiKit.candy(back, "purple", false)
	back.pressed.connect(_back)
	bar.add_child(back)
	var title := _label("LEVELS", 52, Color("#ffd23f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	root.add_child(bar)

	var total := Save.total_stars()
	var summary := _label("★ %d / %d stars   ·   %d of %d cleared" % [
		total, Levels.COUNT * 3, Save.levels_cleared(), Levels.COUNT], 26, Color(1, 0.95, 0.7))
	root.add_child(summary)
	root.add_child(_label("3★ in half the time  ·  2★ in three quarters", 20, Color(1, 0.92, 1, 0.85)))

	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)
	var open := Save.unlocked_level()
	var focus: Control = null
	for n in range(1, Levels.COUNT + 1):
		var tile := LevelTile.new()
		tile.n = n
		var info := Save.level_info(n)
		tile.stars = int(info.get("stars", 0))
		tile.secs = float(info.get("secs", -1.0))
		tile.locked = n > open
		tile.current = n == open and info.is_empty()
		tile.custom_minimum_size = Vector2(0, 176)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.disabled = tile.locked
		var color := "purple"
		if not info.is_empty():
			color = "green" if tile.stars == 3 else "blue"
		elif tile.current:
			color = "orange"
		UiKit.candy(tile, color, false)
		tile.pressed.connect(_play.bind(n))
		grid.add_child(tile)
		if n == open:
			focus = tile
		if n <= 16:
			UiKit.pop_in(tile, 0.05 + n * 0.025)
	UiKit.pop_in(summary, 0.0)
	# Scroll so the newest open level is on screen.
	if focus != null:
		await get_tree().process_frame
		await get_tree().process_frame
		scroll.scroll_vertical = maxi(0, int(focus.global_position.y - 640.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _play(n: int) -> void:
	if not Save.is_unlocked(n):
		return
	Sfx.play("click")
	Save.mode = "level"
	Save.level = n
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
