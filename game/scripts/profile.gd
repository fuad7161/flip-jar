extends Node2D
## Profile: local name + avatar (no login), lifetime stats, and the history of every game.
## The whole UI is built in code so it stays easy to tweak.

const AVATARS := [0, 1, 2, 3, 4, 5, 6, 7]

var root: VBoxContainer
var avatar_view: Avatar
var name_edit: LineEdit
var history_box: VBoxContainer


## A Control that draws one jelly face; tap to pick it.
class Avatar extends Control:
	var tier := 0
	var selected := false
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.4
		var c := size / 2.0
		if selected:
			draw_circle(c, r * 1.25, Color(1, 1, 0.6, 0.35 + 0.15 * sin(t * 4.0)))
		var sq := 1.0 + 0.05 * sin(t * 3.0 + tier)
		draw_set_transform(c + Vector2(0, sin(t * 2.0 + tier) * 3.0), 0.0, Vector2(sq, 2.0 - sq))
		Tiers.draw_piece(self, tier, r)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Tiers.background())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
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
	root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	UiKit.style_tree($UI)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _build() -> void:
	var prof: Dictionary = Save.data["profile"]
	# Top bar: back + title.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var back := Button.new()
	back.text = "‹ BACK"
	back.custom_minimum_size = Vector2(190, 80)
	back.add_theme_font_size_override("font_size", 28)
	UiKit.candy(back, "purple", false)
	back.pressed.connect(_back)
	bar.add_child(back)
	var title := _label("MY PROFILE", 48, Color("#ffd23f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	root.add_child(bar)

	# Avatar + name card.
	var card := _card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	avatar_view = Avatar.new()
	avatar_view.tier = int(prof.get("avatar", 2))
	avatar_view.custom_minimum_size = Vector2(0, 170)
	cv.add_child(avatar_view)
	name_edit = LineEdit.new()
	name_edit.text = str(prof.get("name", "Player"))
	name_edit.max_length = 16
	name_edit.placeholder_text = "Your name"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 80)
	name_edit.add_theme_font_size_override("font_size", 36)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_s: String) -> void: name_edit.release_focus())
	cv.add_child(name_edit)
	cv.add_child(_label("Pick your buddy", 22, Color(1, 0.92, 1)))
	var picks := HBoxContainer.new()
	picks.add_theme_constant_override("separation", 4)
	for tier in AVATARS:
		var a := Avatar.new()
		a.tier = tier
		a.selected = tier == avatar_view.tier
		a.custom_minimum_size = Vector2(72, 72)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.mouse_filter = Control.MOUSE_FILTER_STOP
		a.gui_input.connect(_on_avatar_input.bind(a, picks))
		picks.add_child(a)
	cv.add_child(picks)
	root.add_child(card)

	# Lifetime stats grid.
	root.add_child(_label("STATS", 30, Color("#7cf7ff")))
	var stats_card := _card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	stats_card.add_child(grid)
	var games := int(Save.data["games_played"])
	var total := int(Save.data["total_score"])
	var hist: Array = Save.data["history"]
	var best_any := 0
	for h in hist:
		best_any = maxi(best_any, int(h.get("score", 0)))
	best_any = maxi(best_any, int(Save.data["best_free"]))
	var stats := [
		["Games", str(games)],
		["Best score", str(best_any)],
		["Total score", str(total)],
		["Average", str(total / games) if games > 0 else "-"],
		["Merges", str(int(Save.data["total_merges"]))],
		["Biggest buddy", Tiers.tier_name(int(Save.data["best_tier"]))],
		["Daily streak", "%d (best %d)" % [Save.current_streak(), int(Save.data["streak_best"])]],
		["Play time", _fmt_long(int(Save.data["total_secs"]))],
	]
	for s in stats:
		grid.add_child(_stat_tile(s[0], s[1]))
	root.add_child(stats_card)

	# Game history.
	root.add_child(_label("HISTORY", 30, Color("#ff9ad5")))
	history_box = VBoxContainer.new()
	history_box.add_theme_constant_override("separation", 12)
	root.add_child(history_box)
	if hist.is_empty():
		history_box.add_child(_label("No games yet. Go drop some buddies!", 26, Color(1, 1, 1, 0.85)))
	var i := 0
	for h in hist:
		var row := _history_row(h, games - i)
		history_box.add_child(row)
		if i < 8:
			UiKit.pop_in(row, 0.2 + i * 0.06)
		i += 1
	UiKit.pop_in(card, 0.0)
	UiKit.pop_in(stats_card, 0.1)


func _history_row(h: Dictionary, number: int) -> Control:
	var daily: bool = h.get("mode", "free") == "daily"
	var panel := PanelContainer.new()
	var tint := Color("#ff9a2e") if daily else Color("#3fd56b")
	panel.add_theme_stylebox_override("panel", UiKit.card(Color(tint.r, tint.g, tint.b, 0.28), 26))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var face := Avatar.new()
	face.tier = clampi(int(h.get("best_tier", 0)), 0, Tiers.count() - 1)
	face.custom_minimum_size = Vector2(76, 76)
	face.set_process(false)
	hb.add_child(face)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	var head := "#%d  %s" % [number, "DAILY" if daily else str(h.get("diff", "medium")).to_upper()]
	if h.get("new_best", false):
		head += "  ★ BEST"
	left.add_child(_label(head, 24, Color("#ffe14d") if h.get("new_best", false) else Color.WHITE, false))
	var when := Time.get_datetime_string_from_unix_time(int(h.get("t", 0)) + _tz_offset(), true)
	left.add_child(_label(when.substr(0, 16), 18, Color(1, 1, 1, 0.75), false))
	left.add_child(_label("%d merges · %d flips · %d shakes · %s" % [
		int(h.get("merges", 0)), int(h.get("flips", 0)), int(h.get("shakes", 0)), _fmt_short(int(h.get("secs", 0)))],
		18, Color(1, 1, 1, 0.85), false))
	hb.add_child(left)
	var score := _label(str(int(h.get("score", 0))), 44, Color("#ffe14d"), false)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(score)
	return panel


func _stat_tile(title: String, value: String) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(title.to_upper(), 18, Color(1, 0.9, 1, 0.8), false))
	v.add_child(_label(value, 34, Color.WHITE, false))
	return v


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.card())
	return p


func _label(text: String, size: int, color := Color.WHITE, center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = false
	return l


func _on_name_changed(text: String) -> void:
	var clean := text.strip_edges()
	Save.data["profile"]["name"] = clean if clean != "" else "Player"
	Save.save()


func _on_avatar_input(event: InputEvent, a: Avatar, picks: HBoxContainer) -> void:
	var tapped: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
	if not tapped:
		return
	for c in picks.get_children():
		(c as Avatar).selected = c == a
	avatar_view.tier = a.tier
	UiKit.punch(avatar_view, 0.3)
	UiKit.punch(a, 0.4)
	Save.data["profile"]["avatar"] = a.tier
	Save.save()
	Sfx.play("pop", 1.4)
	Save.vibrate(20)


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _fmt_short(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]


static func _fmt_long(secs: int) -> String:
	if secs >= 3600:
		return "%dh %dm" % [secs / 3600, (secs % 3600) / 60]
	return "%dm %ds" % [secs / 60, secs % 60]
