extends SceneTree
## Level tuning bot: plays chosen levels at a human-like pace and prints how long each clear took.
##   godot --headless --fixed-fps 60 --path game --script res://tests/level_sim.gd -- 1,5,10 1.2 3
## Args after "--": level list, seconds between drops, runs per level.
## The bot aims the held piece at the nearest same-size piece near the top of the pile,
## otherwise at a random spot, and flips when the pile gets close to the danger line.

var levels := [1, 5, 10, 20, 30, 45, 60]
var pace := 1.2
var runs := 2
var curve := false  # 4th arg "curve": ignore the goal, print score every minute until overflow


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		levels = []
		for x in args[0].split(","):
			levels.append(int(x))
	if args.size() > 1:
		pace = float(args[1])
	if args.size() > 2:
		runs = int(args[2])
	curve = args.size() > 3 and args[3] == "curve"
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var save: Node = root.get_node("Save")
	save.disabled = true
	save.data = save._defaults()
	save.data["first_run_done"] = true
	save.data["flip_hint_done"] = true
	save.data["sound"] = false
	save.data["music"] = false
	for n in levels:
		for k in runs:
			for i in range(1, n):  # unlock everything below
				save.data["levels"][str(i)] = {"stars": 1, "secs": 1.0}
			save.mode = "level"
			save.level = n
			var g: Node = load("res://scenes/game.tscn").instantiate()
			root.add_child(g)
			await physics_frame
			var marks := []
			if curve:
				g.target = 1000000
				g.time_limit = 900.0
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 100 + k
			var wait := 0.0
			while not g.game_over:
				await physics_frame
				if curve and int(g.run_time * 60.0) % 3600 == 0 and g.run_time > 1.0:
					marks.append(g.score)
				wait -= 1.0 / 60.0
				if g.held == null or wait > 0.0:
					continue
				wait = pace * rng.randf_range(0.8, 1.2)
				g.held.position.x = _aim(g, rng)
				if g.flips_left > 0 and _pile_near_danger(g):
					g._flip()
				g._drop()
			var reason := "WIN" if g.won else ("TIME" if g.run_time >= g.time_limit else "OVERFLOW")
			var stars: int = Levels.stars_for(g.run_time, g.time_limit) if g.won else 0
			print("L%-2d run %d  %-8s  score %5d / %5d  time %6.1f / %4d  stars %d" % [
				n, k, reason, g.score, g.target, g.run_time, int(g.time_limit), stars])
			if curve:
				print("    score per minute: ", marks)
			g.queue_free()
			await process_frame
	quit(0)


func _aim(g: Node, rng: RandomNumberGenerator) -> float:
	var held: Piece = g.held
	var best_x := rng.randf_range(g.JAR_LEFT + held.radius, g.JAR_RIGHT - held.radius)
	var best_depth := INF
	for node in g.pieces.get_children():
		var p := node as Piece
		if p == null or p == held or p.tier != held.tier:
			continue
		# Depth from the drop side: lower = easier to reach.
		var depth: float = (g.JAR_BOTTOM - p.position.y) if g.flipped else (p.position.y - g.JAR_TOP)
		if depth < best_depth:
			best_depth = depth
			best_x = p.position.x
	return clampf(best_x, g.JAR_LEFT + held.radius + 2.0, g.JAR_RIGHT - held.radius - 2.0)


func _pile_near_danger(g: Node) -> bool:
	for node in g.pieces.get_children():
		var p := node as Piece
		if p == null or p == g.held:
			continue
		var gap: float = (g._danger_line_y() - p.position.y) if g.flipped else (p.position.y - g._danger_line_y())
		if gap < p.radius + 40.0 and p.linear_velocity.length() < 60.0:
			return true
	return false
