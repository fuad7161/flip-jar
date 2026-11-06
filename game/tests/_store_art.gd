extends Node2D
func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# A jar on the right with a pile of jelly pieces.
	var jl := 700.0
	var jr := 980.0
	var jt := 40.0
	var jb := 470.0
	draw_line(Vector2(jl, jt), Vector2(jl, jb), Color(0.85, 0.9, 1.0), 6.0)
	draw_line(Vector2(jr, jt), Vector2(jr, jb), Color(0.85, 0.9, 1.0), 6.0)
	draw_line(Vector2(jl, jb), Vector2(jr, jb), Color(0.85, 0.9, 1.0), 6.0)
	var placed: Array = []
	for tier in [8, 7, 6, 6, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0, 0]:
		var r := Tiers.radius(tier) * 0.62
		for attempt in 300:
			var p := Vector2(rng.randf_range(jl + r + 8, jr - r - 8), rng.randf_range(jt + r + 20, jb - r - 6))
			var ok := true
			for q in placed:
				if p.distance_to(q[0]) < r + q[1] - 2:
					ok = false
					break
			if ok:
				placed.append([p, r, tier])
				break
	placed.sort_custom(func(a, b): return a[0].y < b[0].y)
	for q in placed:
		draw_set_transform(q[0], 0.0, Vector2.ONE)
		Tiers.draw_piece(self, q[2], q[1])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A few loose pieces floating near the title.
	for i in 5:
		var tier := rng.randi_range(1, 5)
		var p := Vector2(rng.randf_range(560.0, 660.0), rng.randf_range(60.0, 440.0))
		draw_set_transform(p, rng.randf_range(-0.4, 0.4), Vector2.ONE)
		Tiers.draw_piece(self, tier, Tiers.radius(tier) * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
