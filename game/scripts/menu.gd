extends Node2D
## Main menu: daily challenge, free play, streak, themes and settings.

var t := 0.0
var art_rng := RandomNumberGenerator.new()

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
	daily_button.pressed.connect(_play.bind("daily"))
	free_button.pressed.connect(_play.bind("free"))
	sound_toggle.button_pressed = Save.data["sound"]
	vibrate_toggle.button_pressed = Save.data["vibrate"]
	sound_toggle.toggled.connect(func(on: bool) -> void: Save.data["sound"] = on; Save.save(); Sfx.play("click"))
	vibrate_toggle.toggled.connect(func(on: bool) -> void: Save.data["vibrate"] = on; Save.save(); Save.vibrate(30))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _refresh() -> void:
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
	for key in Tiers.THEME_ORDER:
		var info: Dictionary = Tiers.THEMES[key]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		if Save.theme_unlocked(key):
			b.text = info["name"]
			b.toggle_mode = true
			b.button_pressed = Tiers.theme == key
			b.pressed.connect(_pick_theme.bind(key))
		else:
			b.text = "%s\n%d-day streak" % [info["name"], int(info["unlock"])]
			b.disabled = true
		themes_box.add_child(b)
	queue_redraw()


func _pick_theme(key: String) -> void:
	Sfx.play("click")
	Save.set_theme(key)
	RenderingServer.set_default_clear_color(Tiers.background())
	_refresh()


func _play(mode: String) -> void:
	Sfx.play("click")
	Save.mode = mode
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	# A few jelly pieces bobbing behind the title.
	art_rng.seed = 11
	for i in 8:
		var tier := art_rng.randi_range(1, 6)
		var x := art_rng.randf_range(80.0, 640.0)
		var y := art_rng.randf_range(335.0, 440.0)
		var phase := art_rng.randf() * TAU
		var r := Tiers.radius(tier) * 0.55
		var bob := sin(t * 1.4 + phase) * 8.0
		var sq := 1.0 + 0.06 * sin(t * 2.8 + phase)
		draw_set_transform(Vector2(x, y + bob), 0.0, Vector2(sq, 2.0 - sq))
		Tiers.draw_piece(self, tier, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
