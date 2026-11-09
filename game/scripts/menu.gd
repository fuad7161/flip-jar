extends Node2D
## Main menu: bouncy title, daily challenge, free play, profile, streak, themes and settings.

const TITLE := "FLIP JAR"
const LETTER_COLORS := ["#ff4fa3", "#ff9a2e", "#ffd23f", "#3fd56b", "", "#3aa8ff", "#a45cff", "#ff5a5a"]

var t := 0.0
var art_rng := RandomNumberGenerator.new()
var letters: Array[Label] = []

@onready var title_box: HBoxContainer = $UI/Box/Title
@onready var profile_button: Button = $UI/Profile
@onready var daily_button: Button = $UI/Box/Daily
@onready var daily_info: Label = $UI/Box/DailyInfo
@onready var free_button: Button = $UI/Box/Free
@onready var free_info: Label = $UI/Box/FreeInfo
@onready var streak_label: Label = $UI/Box/Streak
@onready var themes_box: HBoxContainer = $UI/Box/Themes
@onready var sound_toggle: CheckButton = $UI/Box/Settings/Sound
@onready var vibrate_toggle: CheckButton = $UI/Box/Settings/Vibrate


func _ready() -> void:
	art_rng.seed = 11
	RenderingServer.set_default_clear_color(Tiers.background())
	UiKit.style_tree($UI)
	UiKit.candy(daily_button, "orange")
	UiKit.candy(free_button, "green")
	UiKit.candy(profile_button, "blue", false)
	UiKit.juice(sound_toggle, false)
	UiKit.juice(vibrate_toggle, false)
	_build_title()
	daily_button.pressed.connect(_play.bind("daily"))
	free_button.pressed.connect(_play.bind("free"))
	profile_button.pressed.connect(_open_profile)
	sound_toggle.button_pressed = Save.data["sound"]
	vibrate_toggle.button_pressed = Save.data["vibrate"]
	sound_toggle.toggled.connect(func(on: bool) -> void: Save.data["sound"] = on; Save.save(); Sfx.play("click"))
	vibrate_toggle.toggled.connect(func(on: bool) -> void: Save.data["vibrate"] = on; Save.save(); Save.vibrate(30))
	_refresh()
	# Everything bubbles in one after another.
	var i := 0
	for c in [profile_button, daily_button, daily_info, free_button, free_info, streak_label, themes_box]:
		UiKit.pop_in(c, 0.25 + i * 0.07)
		i += 1


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
		get_tree().quit()


func _refresh() -> void:
	var prof: Dictionary = Save.data["profile"]
	profile_button.text = "  %s  ›" % str(prof.get("name", "Player"))
	var left := Save.attempts_left()
	daily_button.text = "DAILY  #%d" % Save.day_number()
	daily_button.disabled = left <= 0
	if left > 0:
		daily_info.text = "%d of %d tries left   ·   today's best %d" % [left, Save.DAILY_ATTEMPTS, Save.daily_best()]
	else:
		daily_info.text = "Done for today: %d   ·   new jar at 00:00 UTC" % Save.daily_best()
	free_info.text = "best %d   ·   %d games played" % [int(Save.data["best_free"]), int(Save.data["games_played"])]
	var streak := Save.current_streak()
	if streak > 0:
		streak_label.text = "Daily streak: %d day%s   (best %d)" % [streak, "" if streak == 1 else "s", int(Save.data["streak_best"])]
	else:
		streak_label.text = "Play the daily jar to start a streak"
	for b in themes_box.get_children():
		b.queue_free()
	var theme_colors := {"classic": "purple", "candy": "pink", "neon": "teal"}
	for key in Tiers.THEME_ORDER:
		var info: Dictionary = Tiers.THEMES[key]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		UiKit.candy(b, theme_colors.get(key, "purple"), false)
		if Save.theme_unlocked(key):
			b.text = ("✓ " if Tiers.theme == key else "") + info["name"]
			b.pressed.connect(_pick_theme.bind(key))
		else:
			b.text = "%s\n%d-day streak" % [info["name"], int(info["unlock"])]
			b.add_theme_font_size_override("font_size", 20)
			b.disabled = true
		themes_box.add_child(b)
	queue_redraw()


func _pick_theme(key: String) -> void:
	Sfx.play("click")
	Save.set_theme(key)
	RenderingServer.set_default_clear_color(Tiers.background())
	# Reload so the background picks up the new palette.
	get_tree().reload_current_scene()


func _play(mode: String) -> void:
	Sfx.play("click")
	Save.mode = mode
	get_tree().change_scene_to_file("res://scenes/game.tscn")


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
	for i in 9:
		var tier := art_rng.randi_range(1, 6)
		var x := art_rng.randf_range(80.0, 640.0)
		var y := art_rng.randf_range(345.0, 440.0)
		var phase := art_rng.randf() * TAU
		var r := Tiers.radius(tier) * 0.55
		var bob := sin(t * 1.4 + phase) * 10.0
		var sq := 1.0 + 0.08 * sin(t * 2.8 + phase)
		draw_set_transform(Vector2(x, y + bob), sin(t + phase) * 0.15, Vector2(sq, 2.0 - sq))
		Tiers.draw_piece(self, tier, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
