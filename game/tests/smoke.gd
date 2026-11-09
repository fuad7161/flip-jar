extends SceneTree
## Headless smoke test:
##   godot --headless --path game --script res://tests/smoke.gd
## Loads the menu, then plays a daily run: drops pieces, flips twice while holding a piece,
## waits for overflow, checks the result screen and restart.
## Exits 0 on success, 1 on failure (no asserts: a failed assert stalls the editor binary).

const MAX_FRAMES := 6000

var main: Node2D
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		printerr("FAIL: " + msg)


func _run() -> void:
	await process_frame
	var save: Node = root.get_node("Save")
	save.disabled = true
	save.data = save._defaults()
	save.mode = "daily"
	_check(save.daily_seed() == save.daily_seed(), "daily seed must be stable within a day")
	_check(save.day_number() >= 1, "day number should count from the epoch")
	_check(save.attempts_left() == 3, "fresh save should have 3 daily attempts")

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("UI/Box/Themes").get_child_count() == 3, "menu should list 3 themes")
	menu.queue_free()
	await process_frame

	save.data["history"] = [{"t": 1762600000, "mode": "free", "score": 50, "merges": 4, "best_tier": 3, "flips": 1, "shakes": 0, "secs": 70}]
	var prof: Node = load("res://scenes/profile.tscn").instantiate()
	root.add_child(prof)
	await process_frame
	await process_frame
	_check(prof.history_box.get_child_count() == 1, "profile should list one history row")
	prof.queue_free()
	save.data["history"] = []
	await process_frame

	main = load("res://scenes/game.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_check(main.mode == "daily", "game should start in the mode chosen on the menu")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var frames := 0
	var drops := 0
	var max_tier := 0
	var flip_after := [40, 90]
	var last_score := 0
	var last_flip_frame := -1000
	var landed_count := 0
	var seen_stretch := false
	var seen_fx := false
	var shook := false
	while not main.game_over and frames < MAX_FRAMES:
		await physics_frame
		frames += 1
		for p in main.pieces.get_children():
			if p is Piece:
				max_tier = maxi(max_tier, p.tier)
				if p.squash != null and absf(p.squash.scale.x - 1.0) > 0.03:
					seen_stretch = true
		if main.fx.get_child_count() > 0:
			seen_fx = true
		if main.held != null:
			if drops in flip_after:
				# Flip while a piece is held, which is how players actually do it.
				var before: int = main.flips_left
				main._flip()
				flip_after.erase(drops)
				last_flip_frame = frames
				_check(main.flips_left == before - 1, "flip should consume one flip")
				_check(is_equal_approx(main.held.gravity_scale, -1.0 if main.flipped else 1.0), "held piece must follow the new gravity")
				print("flip at drop %d: pieces=%d flipped=%s" % [drops, main.pieces.get_child_count(), main.flipped])
			if drops == 60 and not shook:
				var sb: int = main.shakes_left
				main._shake_jar()
				shook = true
				_check(main.shakes_left == sb - 1, "shake should consume one shake")
			var x: float = rng.randf_range(main.JAR_LEFT + 60.0, main.JAR_RIGHT - 60.0)
			main.held.position.x = clampf(x, main.JAR_LEFT + main.held.radius, main.JAR_RIGHT - main.held.radius)
			main._drop()
			drops += 1
		if main.game_over and not main.over_panel.visible:
			_check(false, "game over should show the result panel")
		if main.game_over and frames - last_flip_frame < 240:
			_check(false, "jar overflowed within 4 s of a flip; the flip itself probably caused it")
		if frames % 600 == 0:
			print("frame %d drops=%d pieces=%d score=%d max_tier=%d fx=%d" % [
				frames, drops, main.pieces.get_child_count(), main.score, max_tier, main.fx.get_child_count()])
			_check(main.score > last_score or main.game_over, "score should keep growing while playing")
			last_score = main.score

	var survived: bool = not main.game_over
	if survived:
		# Combos, mega pops and bonus flips/shakes keep a run alive much longer now; end it by hand.
		main._end_game()
	print("survived the whole test: %s" % survived)
	print("END frames=%d drops=%d pieces=%d score=%d max_tier=%d game_over=%s flips_left=%d" % [
		frames, drops, main.pieces.get_child_count(), main.score, max_tier, main.game_over, main.flips_left])
	_check(main.score > 0, "expected merges to score")
	_check(max_tier >= 5, "expected merges to reach tier 5 or higher")
	_check(seen_stretch, "pieces should visibly stretch or squash during play")
	_check(seen_fx, "merge effects should spawn")
	_check(main.over_panel.visible, "game over panel should show")
	_check(save.attempts_left() == 2, "a finished daily run should use one attempt")
	_check(save.daily_best() == main.score, "daily best should record the score")
	_check(save.current_streak() == 1, "first daily run should start a 1-day streak")
	_check(main.result_text.contains("Day %d" % save.day_number()), "share text should name the day")
	var hist: Array = save.data["history"]
	_check(hist.size() == 1 and int(hist[0]["score"]) == main.score, "the run should be stored in history")
	print("history[0] = ", hist[0])
	_check(main.retry_button.visible, "retry should be offered while attempts remain")

	main._start_run()
	await physics_frame
	await physics_frame
	print("after restart: score=%d flips=%d pieces=%d over_visible=%s" % [
		main.score, main.flips_left, main.pieces.get_child_count(), main.over_panel.visible])
	_check(main.score == 0 and main.flips_left == 3 and main.shakes_left == main.START_SHAKES and not main.over_panel.visible, "restart should reset state")
	_check(main.pieces.get_child_count() == 1 and main.held != null, "restart should leave only the held piece")

	# Free mode records its own best.
	var res: Dictionary = save.record_run("free", 123)
	_check(res["new_best"] and int(save.data["best_free"]) == 123, "free run should set best_free")
	_check(save.attempts_left() == 2, "free runs must not use daily attempts")

	if failures.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		print("SMOKE FAILED (%d)" % failures.size())
		quit(1)
