extends SceneTree
## Renders Play Store assets into ../store: 512 icon, 1024x500 feature graphic, 720x1280 screenshots.
const OUT := "/home/fuad71/Desktop/Projects/Game-one/store/"
var save: Node

func _init() -> void:
	root.gui_disable_input = true
	_run.call_deferred()

func _grab(vp: SubViewport, name: String) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + name)
	print("saved " + name)

func _make_vp(w: int, h: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	root.add_child(vp)
	return vp

func _run() -> void:
	await process_frame
	save = root.get_node("Save")
	save.disabled = true
	save.data = save._defaults()
	save.data["streak_best"] = 3
	save.data["streak"] = 3
	save.data["last_daily_date"] = save.today()
	save.data["best_free"] = 3120
	save.data["games_played"] = 41
	save.data["first_run_done"] = true
	save.data["flip_hint_done"] = true

	# Feature graphic 1024x500
	var fg := _make_vp(1024, 500)
	var bg := ColorRect.new()
	bg.color = Tiers.background()
	bg.size = Vector2(1024, 500)
	fg.add_child(bg)
	var art := Node2D.new()
	art.set_script(load("res://tests/_store_art.gd"))
	fg.add_child(art)
	var title := Label.new()
	title.text = "FLIP JAR"
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("outline_size", 16)
	title.position = Vector2(60, 110)
	fg.add_child(title)
	var sub := Label.new()
	sub.text = "Drop. Merge. Flip the whole jar."
	sub.add_theme_font_size_override("font_size", 44)
	sub.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	sub.position = Vector2(66, 290)
	fg.add_child(sub)
	await _grab(fg, "feature_graphic_1024x500.png")
	fg.queue_free()

	# Icon 512 (full bleed, Play applies its own mask)
	var ic := _make_vp(512, 512)
	var icbg := ColorRect.new()
	icbg.color = Tiers.background()
	icbg.size = Vector2(512, 512)
	ic.add_child(icbg)
	var icon_art := Node2D.new()
	icon_art.set_script(load("res://tests/_store_icon.gd"))
	ic.add_child(icon_art)
	await _grab(ic, "icon_512.png")
	ic.queue_free()

	# Screenshots 720x1280
	var sv := _make_vp(720, 1280)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	sv.add_child(menu)
	for i in range(30): await process_frame
	await _grab(sv, "screenshot_1_menu.png")
	menu.queue_free()
	await process_frame
	save.mode = "daily"
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	sv.add_child(game)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var drops := 0
	var frames := 0
	var got := {}
	while not game.game_over and frames < 7000:
		await physics_frame
		frames += 1
		if game.held != null:
			if drops == 70 and not got.has("mid"):
				for i in range(60): await physics_frame
				await _grab(sv, "screenshot_2_play.png")
				got["mid"] = true
			if drops == 71 and not got.has("flip"):
				game._flip()
				for i in range(14): await physics_frame
				await _grab(sv, "screenshot_3_flip.png")
				for i in range(100): await physics_frame
				await _grab(sv, "screenshot_4_flipped.png")
				got["flip"] = true
			game.held.position.x = clampf(rng.randf_range(game.JAR_LEFT + 60.0, game.JAR_RIGHT - 60.0), game.JAR_LEFT + game.held.radius, game.JAR_RIGHT - game.held.radius)
			game._drop()
			drops += 1
	for i in range(30): await physics_frame
	await _grab(sv, "screenshot_5_result.png")
	quit(0)
