extends Node2D
## Main menu: bouncy title, then two plain rows of icon buttons with small captions:
##   LEVEL n  ·  DAILY #n
##   LEVELS  ·  SETTINGS  ·  EXIT
## SETTINGS opens a popup with sound, music, vibration and the colour themes.

const TITLE := "FLIP JAR"
const LETTER_COLORS := ["#ff4fa3", "#ff9a2e", "#ffd23f", "#3fd56b", "", "#3aa8ff", "#a45cff", "#ff5a5a"]

## Picking a theme reloads the scene; this reopens the settings popup afterwards.
static var reopen_settings := false

var t := 0.0
var art_rng := RandomNumberGenerator.new()
var letters: Array[Label] = []
var play_button: IconButton
var daily_button: IconButton
var levels_button: IconButton
var settings_button: IconButton
var exit_button: IconButton
var settings_panel: Panel
var theme_buttons: Array[IconButton] = []
var sound_button: IconButton
var music_button: IconButton
var vibrate_button: IconButton

@onready var title_box: HBoxContainer = $UI/Box/Title
@onready var box: VBoxContainer = $UI/Box
@onready var profile_button: Button = $UI/Profile


func _ready() -> void:
	art_rng.seed = 11
	RenderingServer.set_default_clear_color(Tiers.background())
	UiKit.style_tree($UI)
	UiKit.candy(profile_button, "blue", false)
	_build_title()
	profile_button.pressed.connect(_open_profile)
	var prof: Dictionary = Save.data["profile"]
	profile_button.text = "  %s  ›" % str(prof.get("name", "Player"))
	_build_buttons()
	_build_settings()
	UiKit.pop_in(profile_button, 0.2)
	if reopen_settings:
		reopen_settings = false
		_open_settings(false)


func _build_buttons() -> void:
	var lv := Save.unlocked_level()
	play_button = IconButton.make("play", "LEVEL %d" % lv, "green", 176.0)
	play_button.icon_px = 64.0
	play_button.caption_px = 30
	play_button.sub = "★ %d / %d" % [Save.total_stars(), Levels.COUNT * 3]
	play_button.pressed.connect(_play.bind("level"))

	var left := Save.attempts_left()
	var streak := Save.current_streak()
	daily_button = IconButton.make("calendar", "DAILY #%d" % Save.day_number(), "orange", 176.0)
	daily_button.icon_px = 60.0
	daily_button.caption_px = 30
	daily_button.sub = ("%d of %d tries" % [left, Save.DAILY_ATTEMPTS]) if left > 0 else "done today"
	if streak > 0:
		daily_button.sub += "  ·  streak %d" % streak
	daily_button.disabled = left <= 0
	daily_button.pressed.connect(_play.bind("daily"))

	levels_button = IconButton.make("grid", "LEVELS", "blue", 124.0)
	settings_button = IconButton.make("gear", "SETTINGS", "purple", 124.0)
	exit_button = IconButton.make("power", "EXIT", "red", 124.0)
	levels_button.pressed.connect(_open_levels)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(_exit)

	var row1 := _row([play_button, daily_button])
	var row2 := _row([levels_button, settings_button, exit_button])
	box.add_child(row1)
	box.add_child(row2)
	var i := 0
	for b in [play_button, daily_button, levels_button, settings_button, exit_button]:
		UiKit.pop_in(b, 0.3 + i * 0.07)
		i += 1


## Full-screen popup: SOUND / MUSIC / VIBRATE toggles, the themes, and a close button.
func _build_settings() -> void:
	settings_panel = Panel.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.size = Vector2(720, 1280)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.05, 0.3, 0.9)
	settings_panel.add_theme_stylebox_override("panel", bg)
	settings_panel.visible = false
	$UI.add_child(settings_panel)
	settings_panel.theme = UiKit.theme()
	var v := VBoxContainer.new()
	v.position = Vector2(40, 200)
	v.size = Vector2(640, 900)
	v.add_theme_constant_override("separation", 22)
	settings_panel.add_child(v)
	v.add_child(_heading("SETTINGS", 60, Color("#ffd23f")))

	sound_button = IconButton.make("sound", "SOUND", "purple", 124.0)
	music_button = IconButton.make("music", "MUSIC", "purple", 124.0)
	vibrate_button = IconButton.make("vibrate", "VIBRATE", "purple", 124.0)
	sound_button.pressed.connect(_toggle.bind("sound"))
	music_button.pressed.connect(_toggle.bind("music"))
	vibrate_button.pressed.connect(_toggle.bind("vibrate"))
	v.add_child(_row([sound_button, music_button, vibrate_button]))
	_sync_toggles()

	v.add_child(_heading("THEME", 28, Color(1, 0.92, 1)))
	var theme_colors := {"classic": "purple", "candy": "pink", "neon": "teal"}
	var themes: Array = []
	for key in Tiers.THEME_ORDER:
		var info: Dictionary = Tiers.THEMES[key]
		var unlocked := Save.theme_unlocked(key)
		var b := IconButton.make("palette" if unlocked else "lock", info["name"], theme_colors.get(key, "purple"), 124.0)
		if unlocked:
			b.sub = "✓ in use" if Tiers.theme == key else ""
			b.pressed.connect(_pick_theme.bind(key))
		else:
			b.sub = "%d-day streak" % int(info["unlock"])
			b.disabled = true
		theme_buttons.append(b)
		themes.append(b)
	v.add_child(_row(themes))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	var close := IconButton.make("close", "CLOSE", "green", 124.0)
	close.pressed.connect(_close_settings)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(240, 124)
	close_row.add_child(close)
	v.add_child(close_row)


func _heading(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", maxi(6, fs / 5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _open_settings(sound := true) -> void:
	if sound:
		Sfx.play("click")
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	settings_panel.create_tween().tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	var i := 0
	for b in [sound_button, music_button, vibrate_button] + theme_buttons:
		UiKit.pop_in(b, 0.05 + i * 0.04)
		i += 1


func _close_settings() -> void:
	Sfx.play("click")
	settings_panel.visible = false


func _exit() -> void:
	Sfx.play("click")
	get_tree().quit()


func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for c in items:
		row.add_child(c)
	return row


func _toggle(key: String) -> void:
	Save.data[key] = not Save.data[key]
	Save.save()
	if key == "music":
		Sfx.update_music()
	if key == "vibrate":
		Save.vibrate(30)
	Sfx.play("click")
	_sync_toggles()


func _sync_toggles() -> void:
	sound_button.off = not Save.data["sound"]
	music_button.off = not Save.data["music"]
	vibrate_button.off = not Save.data["vibrate"]
	sound_button.sub = "on" if Save.data["sound"] else "off"
	music_button.sub = "on" if Save.data["music"] else "off"
	vibrate_button.sub = "on" if Save.data["vibrate"] else "off"


func _build_title() -> void:
	for i in TITLE.length():
		var l := Label.new()
		l.text = TITLE[i] if TITLE[i] != " " else "  "
		l.add_theme_font_size_override("font_size", 104)
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.4))
		if LETTER_COLORS[i] != "":
			l.add_theme_color_override("font_color", Color(LETTER_COLORS[i]))
		title_box.add_child(l)
		letters.append(l)
		# Drop each letter in with a bounce.
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(l, "modulate:a", 1.0, 0.15)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_panel != null and settings_panel.visible:
			_close_settings()
		else:
			get_tree().quit()


func _pick_theme(key: String) -> void:
	Sfx.play("click")
	Save.set_theme(key)
	reopen_settings = true
	RenderingServer.set_default_clear_color(Tiers.background())
	# Reload so the background picks up the new palette.
	get_tree().reload_current_scene()


func _play(mode: String) -> void:
	Sfx.play("click")
	Save.mode = mode
	Save.level = Save.unlocked_level()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _open_levels() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/levels.tscn")


func _open_profile() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


func _process(delta: float) -> void:
	t += delta
	# Wavy candy title.
	for i in letters.size():
		var l := letters[i]
		l.pivot_offset = l.size / 2.0
		var ph := t * 3.0 - i * 0.55
		l.position.y = sin(ph) * 10.0
		l.rotation = sin(ph + 0.6) * 0.08
		var sq := 1.0 + 0.06 * sin(ph * 2.0)
		l.scale = Vector2(sq, 2.0 - sq)
	queue_redraw()


func _draw() -> void:
	# A few jelly pieces bobbing behind the title.
	art_rng.seed = 11
	var gap := ($UI/Box/Spacer as Control).get_global_rect()
	for i in 9:
		var tier := art_rng.randi_range(1, 6)
		var x := art_rng.randf_range(80.0, 640.0)
		var y := gap.position.y + gap.size.y * art_rng.randf_range(0.25, 0.75)
		var phase := art_rng.randf() * TAU
		var r := Tiers.radius(tier) * 0.55
		var bob := sin(t * 1.4 + phase) * 10.0
		var sq := 1.0 + 0.08 * sin(t * 2.8 + phase)
		draw_set_transform(Vector2(x, y + bob), sin(t + phase) * 0.15, Vector2(sq, 2.0 - sq))
		Tiers.draw_piece(self, tier, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
