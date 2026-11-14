extends Node2D
## Flip Jar game scene: jar, drop, merge, flip, shake, combos, overflow, score, juice and results.

const JAR_LEFT := 60.0
const JAR_RIGHT := 660.0
const JAR_TOP := 240.0      # drop side when not flipped
const JAR_BOTTOM := 1040.0  # floor when not flipped
const WALL := 120.0          # thick walls so fast pieces can't tunnel through after a flip
const MAX_STOCK := 5        # most flips or shakes you can bank
const FLIP_GRACE := 1.5
const SHAKE_GRACE := 1.8
const SETTLED_SPEED := 40.0
const FLIP_HINT_AFTER_DROPS := 6
const STORE_LINK := "https://play.google.com/store/apps/details?id=com.flipjar.game"

# Tuning lives in levels.gd: Levels.config(n) for each level and Levels.DAILY for the daily jar.
const VANISH_DELAY := 1.2
const VANISH_BONUS := 3        # vanish points = merge_score(tier) * this
const BLAST_MIN_TIER := 4      # combos only shrink pieces at least this big (Pudding+)
const BLAST_BONUS := 2         # shrink points = merge_score(tier) * this
const SHAKE_ACCEL := 24.0      # m/s^2; a real shake easily passes 2.5 g, tilting never does
const SHAKE_COOLDOWN := 1.5

var mode := "level"
var level := 1
var cfg: Dictionary = Levels.DAILY
var target := 0          # level goal score (0 in daily mode)
var time_limit := 0.0    # level clock in seconds (0 in daily mode)
var won := false
var last_tick := -1      # last whole second announced by the final countdown
var score := 0
var flips_left := 0
var shakes_left := 0
var flips_used := 0
var shakes_used := 0
var flipped := false
var game_over := false
var held: Piece = null
var next_tier := 0
var drops := 0
var merges := 0
var best_tier := 0
var run_time := 0.0
var combo := 0
var chain_from_drop := false  # flip/shake chains score, but only drop chains earn rewards and blasts
var last_merge_time := -10.0
var last_blast_time := -100.0
var drop_cooldown := 0.0
var flip_grace := 0.0
var shake_cooldown := 0.0
var shake := 0.0
var t := 0.0
var overflow_timers := {}  # piece instance id -> seconds settled in the danger zone
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var flip_tween: Tween = null
var pulse_tween: Tween = null
var hint_tween: Tween = null
var result_text := ""
var shown_score := 0

@onready var camera: Camera2D = $Camera
@onready var pieces: Node2D = $Pieces
@onready var fx: Node2D = $Fx
@onready var score_label: Label = $UI/Score
@onready var mode_label: Label = $UI/Mode
@onready var hint_label: Label = $UI/Hint
@onready var toast_label: Label = $UI/Toast
@onready var banners: Control = $UI/Banners
@onready var flip_button: Button = $UI/FlipButton
@onready var shake_button: Button = $UI/ShakeButton
@onready var charge_bar: ProgressBar = $UI/Charge
@onready var charge_label: Label = $UI/ChargeLabel
@onready var next_preview: Node2D = $UI/NextPreview
@onready var over_panel: Control = $UI/GameOver
@onready var over_box: VBoxContainer = $UI/GameOver/Box
@onready var over_title: Label = $UI/GameOver/Box/Title
@onready var over_stats: Label = $UI/GameOver/Box/Stats
@onready var pause_button: Button = $UI/PauseButton
@onready var pause_panel: Control = $UI/Pause
@onready var pause_box: VBoxContainer = $UI/Pause/Box
@onready var pause_info: Label = $UI/Pause/Box/Info
@onready var level_bar: LevelBar = $UI/LevelBar
var star_row: StarRow
# Result and pause actions: icon buttons in group cards, built in code.
var next_button: IconButton
var retry_button: IconButton
var over_levels_button: IconButton
var menu_button: IconButton
var share_button: IconButton
var copy_button: IconButton
var over_groups: Array[Control] = []
var resume_button: IconButton
var restart_button: IconButton
var pause_levels_button: IconButton
var quit_button: IconButton
var pause_groups: Array[Control] = []


func _ready() -> void:
	mode = Save.mode
	if mode == "level":
		level = clampi(Save.level, 1, Save.unlocked_level())
		cfg = Levels.config(level)
		target = int(cfg["target"])
		time_limit = float(cfg["time"])
	else:
		cfg = Levels.DAILY
	_build_result_extras()
	_build_pause_actions()
	RenderingServer.set_default_clear_color(Tiers.background())
	UiKit.style_tree($UI)
	UiKit.candy(flip_button, "pink")
	UiKit.candy(shake_button, "teal")
	UiKit.candy(pause_button, "purple", false)
	_style_charge_bar()
	_build_jar()
	flip_button.pressed.connect(_flip)
	shake_button.pressed.connect(_shake_jar)
	pause_button.pressed.connect(_pause)
	level_bar.visible = mode == "level"
	if mode == "level":
		score_label.add_theme_font_size_override("font_size", 54)
	hint_label.modulate.a = 0.0
	toast_label.modulate.a = 0.0
	_start_run()
	# Bubble the top bar in.
	UiKit.pop_in(score_label, 0.0)
	UiKit.pop_in(pause_button, 0.04)
	UiKit.pop_in(flip_button, 0.08)
	UiKit.pop_in(shake_button, 0.16)
	UiKit.pop_in(charge_bar, 0.24)


func _style_charge_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.18)
	bg.set_corner_radius_all(14)
	bg.border_color = Color(1, 1, 1, 0.45)
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.CANDY["pink"]
	fill.set_corner_radius_all(14)
	fill.shadow_color = Color(1, 0.3, 0.7, 0.6)
	fill.shadow_size = 8
	charge_bar.add_theme_stylebox_override("background", bg)
	charge_bar.add_theme_stylebox_override("fill", fill)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Back: close the pause menu, open it mid-run, or leave the result screen.
		if is_paused():
			_resume()
		elif game_over:
			_go_menu()
		else:
			_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Switching apps or taking a call pauses the run instead of letting the jar overflow.
		if not game_over and is_inside_tree():
			_pause()


func _start_run() -> void:
	for p in pieces.get_children():
		p.queue_free()
	for f in fx.get_children():
		f.queue_free()
	held = null
	score = 0
	shown_score = 0
	flips_left = int(cfg["flips"])
	shakes_left = int(cfg["shakes"])
	flips_used = 0
	shakes_used = 0
	flipped = false
	game_over = false
	drops = 0
	merges = 0
	best_tier = 0
	run_time = 0.0
	won = false
	last_tick = -1
	combo = 0
	last_merge_time = -10.0
	last_blast_time = -100.0
	drop_cooldown = 0.0
	flip_grace = 0.0
	shake_cooldown = 0.0
	shake = 0.0
	overflow_timers.clear()
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	_stop_pulse()
	camera.rotation = 0.0
	camera.offset = Vector2.ZERO
	over_panel.visible = false
	pause_panel.visible = false
	pause_button.visible = true
	if mode == "daily":
		rng.seed = Save.daily_seed()
		mode_label.text = "DAILY #%d  ·  try %d of %d" % [Save.day_number(), Save.DAILY_ATTEMPTS - Save.attempts_left() + 1, Save.DAILY_ATTEMPTS]
	else:
		rng.randomize()
		level_bar.reset(time_limit, target)
		score_label.text = "LEVEL %d" % level
		mode_label.text = "Fill GOAL before TIME runs out"
		Fx.banner(banners, "LEVEL %d" % level, UiKit.CANDY["yellow"], 470.0)
		var goal_text := "Fill the GOAL bar\nbefore the TIME bar runs out!"
		if not Save.data["first_run_done"]:
			goal_text += "\nDrag to aim, release to drop"
		_show_hint(goal_text)
	next_tier = _roll_tier()
	next_preview.set_tier(next_tier)
	if not Save.data["first_run_done"] and mode == "daily":
		_show_hint("Drag to aim, release to drop")
	_update_ui()
	queue_redraw()


# --- Jar ---------------------------------------------------------------------

func _build_jar() -> void:
	var jar := StaticBody2D.new()
	jar.name = "Jar"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.05
	jar.physics_material_override = pm
	var mid_y := (JAR_TOP + JAR_BOTTOM) / 2.0
	var mid_x := (JAR_LEFT + JAR_RIGHT) / 2.0
	var side := Vector2(WALL, JAR_BOTTOM - JAR_TOP + 2.0 * WALL)
	var cap := Vector2(JAR_RIGHT - JAR_LEFT + 2.0 * WALL, WALL)
	_add_wall(jar, Vector2(JAR_LEFT - WALL / 2.0, mid_y), side)
	_add_wall(jar, Vector2(JAR_RIGHT + WALL / 2.0, mid_y), side)
	_add_wall(jar, Vector2(mid_x, JAR_BOTTOM + WALL / 2.0), cap)
	_add_wall(jar, Vector2(mid_x, JAR_TOP - WALL / 2.0), cap)
	add_child(jar)


func _add_wall(parent: Node, pos: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


func _glow_line(a: Vector2, b: Vector2, c: Color, w: float, strength := 1.0) -> void:
	draw_line(a, b, Color(c.r, c.g, c.b, 0.08 * strength), w * 5.0, true)
	draw_line(a, b, Color(c.r, c.g, c.b, 0.16 * strength), w * 3.0, true)
	draw_line(a, b, Color(c.r, c.g, c.b, 0.9 * strength), w, true)
	draw_line(a, b, Color(1, 1, 1, 0.6 * strength), w * 0.35, true)


func _draw() -> void:
	var glows: Array = Tiers.glow_colors()
	var pulse := 0.8 + 0.2 * sin(t * 2.2)
	# Glassy jar body.
	draw_rect(Rect2(JAR_LEFT, JAR_TOP, JAR_RIGHT - JAR_LEFT, JAR_BOTTOM - JAR_TOP), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(JAR_LEFT + 14, JAR_TOP + 20, 18, JAR_BOTTOM - JAR_TOP - 40), Color(1, 1, 1, 0.07))
	var wall_c: Color = glows[1]
	var w := 7.0
	_glow_line(Vector2(JAR_LEFT, JAR_TOP), Vector2(JAR_LEFT, JAR_BOTTOM), wall_c, w, pulse)
	_glow_line(Vector2(JAR_RIGHT, JAR_TOP), Vector2(JAR_RIGHT, JAR_BOTTOM), wall_c, w, pulse)
	# The pile side is drawn solid, the drop side faint.
	var floor_c: Color = glows[0]
	_glow_line(Vector2(JAR_LEFT, JAR_BOTTOM), Vector2(JAR_RIGHT, JAR_BOTTOM), floor_c, w, 0.3 if flipped else pulse)
	_glow_line(Vector2(JAR_LEFT, JAR_TOP), Vector2(JAR_RIGHT, JAR_TOP), floor_c, w, pulse if flipped else 0.3)
	var y := _danger_line_y()
	var danger := Color(1.0, 0.35, 0.45, 0.6 + 0.3 * sin(t * 5.0))
	draw_line(Vector2(JAR_LEFT, y), Vector2(JAR_RIGHT, y), Color(danger.r, danger.g, danger.b, 0.12), 14.0)
	draw_dashed_line(Vector2(JAR_LEFT, y), Vector2(JAR_RIGHT, y), danger, 4.0, 18.0)
	# Drop guide from the held piece to the far side of the jar.
	if held != null and not game_over:
		var from := held.position + Vector2(0.0, -held.radius if flipped else held.radius)
		var to := Vector2(held.position.x, JAR_TOP if flipped else JAR_BOTTOM)
		var c := Tiers.color(held.tier)
		draw_line(from, to, Color(c.r, c.g, c.b, 0.12), 12.0)
		draw_dashed_line(from, to, Color(c.r, c.g, c.b, 0.6), 3.0, 12.0)


func _danger_line_y() -> float:
	var depth: float = cfg["danger"]
	return JAR_BOTTOM - depth if flipped else JAR_TOP + depth


func _spawn_y(r: float) -> float:
	return JAR_BOTTOM - r - 8.0 if flipped else JAR_TOP + r + 8.0


func _in_danger(p: Piece) -> bool:
	return p.position.y > _danger_line_y() if flipped else p.position.y < _danger_line_y()


func _screen_up() -> Vector2:
	return Vector2.UP.rotated(camera.rotation)


# --- Pieces ------------------------------------------------------------------

func _roll_tier() -> int:
	return rng.randi_range(0, int(cfg["spawn"]) - 1)


func _make_piece(tier: int, pos: Vector2, pop := true) -> Piece:
	var p := Piece.new()
	p.position = pos
	p.setup(tier, pop)
	p.gravity_scale = -1.0 if flipped else 1.0
	p.merge_requested.connect(_on_merge_requested)
	p.landed.connect(_on_landed)
	pieces.add_child(p)
	return p


func _spawn_held() -> void:
	var r := Tiers.radius(next_tier)
	var p := _make_piece(next_tier, Vector2((JAR_LEFT + JAR_RIGHT) / 2.0, _spawn_y(r)))
	p.freeze = true
	p.collision_layer = 0
	p.collision_mask = 0
	held = p
	next_tier = _roll_tier()
	next_preview.set_tier(next_tier)
	UiKit.punch(next_preview, 0.35)


func _aim(screen_pos: Vector2) -> void:
	if held == null:
		return
	var world := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	held.position.x = clampf(world.x, JAR_LEFT + held.radius + 2.0, JAR_RIGHT - held.radius - 2.0)


func _drop() -> void:
	if held == null:
		return
	held.collision_layer = 1
	held.collision_mask = 1
	held.freeze = false
	held.sleeping = false
	held = null
	drop_cooldown = cfg["drop_delay"]
	drops += 1
	combo = 0  # a combo is the chain of merges caused by a single drop
	chain_from_drop = flip_grace <= 0.0  # drops while the jar is still tumbling don't count
	if drops == 1:
		_hide_hint()
	if drops == FLIP_HINT_AFTER_DROPS and not Save.data["flip_hint_done"]:
		_show_hint("Try FLIP to turn the jar!\nOr SHAKE your phone!")
		_start_pulse()


func _on_landed(p: Piece, impact: float) -> void:
	if impact < 220.0:
		return
	var pitch := 1.5 - (p.radius / 140.0) * 0.9
	var vol := clampf(-16.0 + impact / 90.0, -16.0, 0.0)
	Sfx.play("drop", pitch + fx_rng.randf_range(-0.05, 0.05), vol)
	if p.radius > 60.0 and impact > 600.0:
		shake = maxf(shake, 2.0 + p.radius * 0.03)


func _on_merge_requested(a: Piece, b: Piece) -> void:
	# Contacts are reported during the physics step; mutate the tree afterwards.
	_merge.call_deferred(a, b)


func _merge(a: Piece, b: Piece) -> void:
	if game_over or not (is_instance_valid(a) and is_instance_valid(b)):
		return
	# A restart in the same frame queues every old piece for deletion; don't merge leftovers.
	if a.is_queued_for_deletion() or b.is_queued_for_deletion():
		return
	var tier := a.tier
	var mid := (a.position + b.position) / 2.0
	var vel := (a.linear_velocity + b.linear_velocity) / 2.0
	overflow_timers.erase(a.get_instance_id())
	overflow_timers.erase(b.get_instance_id())
	a.queue_free()
	b.queue_free()
	merges += 1
	var points := Tiers.merge_score(tier)
	var color := Tiers.color(tier)
	var r := Tiers.radius(tier)
	if tier + 1 < Tiers.count():
		var p := _make_piece(tier + 1, mid)
		p.linear_velocity = vel
		color = Tiers.color(tier + 1)
		r = Tiers.radius(tier + 1)
		best_tier = maxi(best_tier, tier + 1)
		if tier + 1 >= int(cfg["vanish_tier"]):
			_start_vanish(p)
	else:
		points += 100  # two Suns clear the jar space
	_add_score(points)
	Fx.ring(fx, mid, color, r)
	Fx.burst(fx, mid, color, r)
	Fx.popup(fx, mid, "+%d" % points, color.lightened(0.3), _screen_up(), camera.rotation)
	Sfx.play("pop", clampf(1.7 - tier * 0.12, 0.6, 1.7) + fx_rng.randf_range(-0.04, 0.04))
	shake = maxf(shake, 2.0 + tier * 1.2)
	Save.vibrate(15 + tier * 4)
	_register_combo(mid)
	_update_ui()


## Merges in quick succession build a combo: at reward_combo you earn a random flip or shake,
## at blast_combo the biggest piece on the board is blasted away.
func _register_combo(at: Vector2) -> void:
	if run_time - last_merge_time <= float(cfg["combo_window"]):
		combo += 1
	else:
		combo = 1
	last_merge_time = run_time
	if combo < 2:
		return
	var colors := ["#ffe14d", "#7cf7ff", "#ff7ad9", "#9dff6b"]
	Fx.banner(banners, "COMBO x%d!" % combo, Color(colors[(combo - 2) % colors.size()]))
	Fx.confetti(fx, at, 30.0)
	Sfx.play("best", 1.0 + 0.1 * combo, -6.0)
	UiKit.punch(charge_bar, 0.2)
	if not chain_from_drop:
		return
	if combo == int(cfg["reward_combo"]):
		_grant_reward()
	if combo == int(cfg["blast_combo"]) and run_time - last_blast_time >= float(cfg["blast_cooldown"]):
		if _shrink_biggest() > 0:
			last_blast_time = run_time


## A combo blast no longer deletes the biggest piece: it knocks it down one size,
## so big pieces stay a real problem you have to merge away.
func _shrink_biggest() -> int:
	var biggest: Piece = null
	for node in pieces.get_children():
		var p := node as Piece
		if p == null or p == held or p.merging or p.is_queued_for_deletion() or p.tier < BLAST_MIN_TIER:
			continue
		if biggest == null or p.tier > biggest.tier:
			biggest = p
	if biggest == null:
		return 0
	_shrink_piece(biggest)
	return 1


func _shrink_piece(p: Piece) -> void:
	if game_over or not is_instance_valid(p):
		return
	var pts := Tiers.merge_score(p.tier) * BLAST_BONUS
	var pos := p.position
	var vel := p.linear_velocity
	var c := Tiers.color(p.tier)
	overflow_timers.erase(p.get_instance_id())
	Fx.ring(fx, pos, Color.WHITE, p.radius)
	Fx.burst(fx, pos, c, p.radius)
	Fx.popup(fx, pos, "SHRINK +%d" % pts, Color(1, 0.95, 0.5), _screen_up(), camera.rotation, 46)
	Sfx.play("pop", 0.7, 0.0)
	shake = maxf(shake, 8.0)
	Save.vibrate(45)
	_add_score(pts)
	p.queue_free()
	var smaller := _make_piece(p.tier - 1, pos)
	smaller.linear_velocity = vel


## Removes a piece with a big celebration and bonus points.
func _pop_piece(p: Piece, mult: int, word: String) -> void:
	if game_over or not is_instance_valid(p):
		return
	var pts := Tiers.merge_score(p.tier) * mult
	var c := Tiers.color(p.tier)
	overflow_timers.erase(p.get_instance_id())
	Fx.ring(fx, p.position, Color.WHITE, p.radius)
	Fx.ring(fx, p.position, c, p.radius * 1.3)
	Fx.burst(fx, p.position, c, p.radius * 1.5)
	Fx.confetti(fx, p.position, p.radius)
	Fx.popup(fx, p.position, "%s +%d" % [word, pts], Color(1, 0.95, 0.5), _screen_up(), camera.rotation, 46)
	Sfx.play("pop", 0.55, 2.0)
	shake = maxf(shake, 12.0)
	Save.vibrate(60)
	_add_score(pts)
	p.merging = true
	p.collision_layer = 0
	p.collision_mask = 0
	var tw := p.create_tween()
	tw.tween_property(p, "spawn_scale", 1.35, 0.08)
	tw.tween_property(p, "spawn_scale", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)


## A piece at the size limit glows and pulses for a moment, then pops on its own.
func _start_vanish(p: Piece) -> void:
	p.merging = true  # it can no longer merge or end the game
	var tw := p.create_tween()
	tw.tween_interval(0.3)
	for i in 3:
		tw.tween_property(p, "spawn_scale", 1.12, VANISH_DELAY / 6.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "spawn_scale", 0.95, VANISH_DELAY / 6.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if game_over:
			return
		Fx.banner(banners, "MEGA POP!", Color("#ffe14d"), 440.0)
		_pop_piece(p, VANISH_BONUS, "MEGA"))


# --- Combo reward --------------------------------------------------------------

## Random +1 flip or +1 shake (whichever still has room).
func _grant_reward() -> void:
	var give_flip := fx_rng.randf() < 0.5
	if give_flip and flips_left >= MAX_STOCK:
		give_flip = false
	elif not give_flip and shakes_left >= MAX_STOCK:
		give_flip = true
	if give_flip and flips_left < MAX_STOCK:
		flips_left += 1
		Fx.banner(banners, "+1 FLIP!", UiKit.CANDY["pink"], 300.0)
		UiKit.punch(flip_button, 0.35)
	elif shakes_left < MAX_STOCK:
		shakes_left += 1
		Fx.banner(banners, "+1 SHAKE!", UiKit.CANDY["teal"], 300.0)
		UiKit.punch(shake_button, 0.35)
	else:
		_add_score(25)
		Fx.banner(banners, "+25 BONUS", UiKit.CANDY["yellow"], 300.0)
	Sfx.play("best", 1.4, -8.0)
	_update_ui()


# --- Flip & shake ----------------------------------------------------------------

func _flip() -> void:
	if game_over or flips_left <= 0:
		return
	flips_left -= 1
	flips_used += 1
	combo = 0
	chain_from_drop = false
	flipped = not flipped
	flip_grace = FLIP_GRACE
	overflow_timers.clear()
	for node in pieces.get_children():
		var p := node as Piece
		if p == null:
			continue
		p.gravity_scale = -1.0 if flipped else 1.0
		if p == held:
			continue  # the held piece is frozen; it only needs its gravity updated
		p.sleeping = false
		# A small sideways nudge so the tumble never looks identical.
		p.apply_central_impulse(Vector2(fx_rng.randf_range(-60.0, 60.0), 0.0) * p.mass)
	if held != null:
		held.position.y = _spawn_y(held.radius)
	# Rapid double taps must not leave two tweens fighting over the camera.
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(camera, "rotation", PI if flipped else 0.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	shake = 10.0
	Sfx.play("flip")
	Save.vibrate(50)
	Fx.banner(banners, "FLIP!", UiKit.CANDY["pink"], 560.0)
	if not Save.data["flip_hint_done"]:
		Save.data["flip_hint_done"] = true
		Save.save()
	_stop_pulse()
	_hide_hint()
	_update_ui()
	queue_redraw()


## Shuffles the pile: every piece gets kicked toward the open side and sideways.
func _shake_jar() -> void:
	if game_over or shakes_left <= 0:
		return
	shakes_left -= 1
	shakes_used += 1
	combo = 0
	chain_from_drop = false
	shake_cooldown = SHAKE_COOLDOWN
	flip_grace = SHAKE_GRACE
	overflow_timers.clear()
	var away := Vector2.DOWN if flipped else Vector2.UP  # toward the drop side
	for node in pieces.get_children():
		var p := node as Piece
		if p == null or p == held or p.merging:
			continue
		p.sleeping = false
		var kick := away * fx_rng.randf_range(350.0, 800.0) + Vector2(fx_rng.randf_range(-420.0, 420.0), 0.0)
		p.apply_central_impulse(kick * p.mass)
		p.apply_torque_impulse(fx_rng.randf_range(-3000.0, 3000.0) * p.mass)
	shake = 22.0
	Sfx.play("flip", 1.35)
	Save.vibrate(90)
	Fx.banner(banners, "SHAKE!", UiKit.CANDY["teal"], 560.0)
	if not Save.data["flip_hint_done"]:
		Save.data["flip_hint_done"] = true
		Save.save()
	_stop_pulse()
	_hide_hint()
	_update_ui()


# --- Loop --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_aim(event.position)
		else:
			_aim(event.position)
			_drop()
	elif event is InputEventScreenDrag:
		_aim(event.position)


func _process(delta: float) -> void:
	t += delta
	if shake > 0.0:
		camera.offset = Vector2(fx_rng.randf_range(-shake, shake), fx_rng.randf_range(-shake, shake))
		shake = move_toward(shake, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	# Phone shake gesture.
	shake_cooldown -= delta
	if not game_over and shake_cooldown <= 0.0 and shakes_left > 0:
		var a := Input.get_accelerometer()
		if a.length() > SHAKE_ACCEL:
			_shake_jar()
	# Score rolls up instead of jumping.
	if shown_score != score and mode != "level":
		shown_score = mini(score, shown_score + maxi(1, int((score - shown_score) * 0.2)))
		score_label.text = str(shown_score)
	# Combo meter: fills toward the blast, drains when the chain breaks.
	var live := run_time - last_merge_time <= float(cfg["combo_window"])
	var target := float(combo) / float(cfg["blast_combo"]) if live else 0.0
	charge_bar.value = lerpf(charge_bar.value, minf(target, 1.0), minf(1.0, delta * 10.0))
	charge_label.text = "COMBO x%d" % combo if live and combo >= 2 else "COMBO"
	if mode == "level" and not game_over:
		level_bar.used = run_time
		level_bar.set_score(score)
		var left := int(ceil(time_limit - run_time))
		if left <= 10 and left != last_tick and left > 0:
			last_tick = left
			Sfx.play("click", 1.6 if left > 3 else 2.0, -4.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if game_over:
		return
	run_time += delta
	drop_cooldown -= delta
	flip_grace -= delta
	if mode == "level":
		if score >= target:
			_end_game("win")
			return
		if run_time >= time_limit:
			_end_game("time")
			return
	if held == null and drop_cooldown <= 0.0:
		_spawn_held()
	if flip_grace > 0.0:
		return
	for node in pieces.get_children():
		var p := node as Piece
		if p == null or p == held or p.merging:
			continue
		_rescue_if_escaped(p)
		var id := p.get_instance_id()
		if _in_danger(p) and p.linear_velocity.length() < SETTLED_SPEED:
			overflow_timers[id] = overflow_timers.get(id, 0.0) + delta
			if overflow_timers[id] >= float(cfg["overflow"]):
				_end_game("overflow")
				return
		else:
			overflow_timers.erase(id)


## Safety net: a piece that somehow ended up outside the jar is put back inside.
func _rescue_if_escaped(p: Piece) -> void:
	var pos := p.position
	var r := p.radius
	if pos.x > JAR_LEFT and pos.x < JAR_RIGHT and pos.y > JAR_TOP and pos.y < JAR_BOTTOM:
		return
	p.position = Vector2(clampf(pos.x, JAR_LEFT + r, JAR_RIGHT - r), clampf(pos.y, JAR_TOP + r, JAR_BOTTOM - r))
	p.linear_velocity = Vector2.ZERO


# --- Results -----------------------------------------------------------------

## Ends the run. `reason` is "win" (level goal reached), "time" (level clock ran out) or "overflow".
func _end_game(reason := "overflow") -> void:
	game_over = true
	won = reason == "win"
	if held != null:
		held.queue_free()
		held = null
	_stop_pulse()
	_fade_hint(0.0, 0.0)
	shake = 4.0 if won else 14.0
	Save.vibrate(60 if won else 120)
	var secs := minf(run_time, time_limit) if mode == "level" else run_time
	var stars := Levels.stars_for(secs, time_limit) if won else 0
	var prev: Dictionary = Save.level_info(level).duplicate() if mode == "level" else {}
	var res: Dictionary = Save.record_run(mode, score, _run_stats(stars))
	star_row.visible = mode == "level" and won
	next_button.visible = false
	over_levels_button.visible = mode == "level"
	share_button.visible = mode == "daily" or won
	copy_button.visible = share_button.visible
	var lines := []
	if mode == "level":
		if won:
			over_title.text = "LEVEL %d CLEAR!" % level
			star_row.set_stars(stars, true)
			Sfx.play("best")
			Fx.confetti(fx, camera.get_screen_center_position(), 120.0)
			lines.append("Time  %s  /  %s" % [Levels.fmt_time(secs), Levels.fmt_clock(time_limit)])
			if prev.is_empty():
				lines.append("First clear!")
			elif res["new_best"]:
				lines.append("NEW BEST TIME!  (was %s)" % Levels.fmt_time(float(prev["secs"])))
			else:
				lines.append("Best  %s" % Levels.fmt_time(float(prev["secs"])))
			if stars < 3:
				var need := Levels.THREE_STAR if stars == 2 else Levels.TWO_STAR
				lines.append("Finish in %s for %d stars" % [Levels.fmt_time(time_limit * need), stars + 1])
			if level < Levels.COUNT:
				next_button.visible = true
				next_button.sub = "Level %d" % (level + 1)
			retry_button.caption = "REPLAY"
			retry_button.sub = ""
			result_text = "FLIP JAR  Level %d\n%s  in %s\nCan you beat me? %s" % [
				level, "★".repeat(stars) + "☆".repeat(3 - stars), Levels.fmt_time(secs), STORE_LINK]
		else:
			over_title.text = "Time's up!" if reason == "time" else "Jar overflowed!"
			Sfx.play("over")
			lines.append("Score  %d  /  %d" % [score, target])
			lines.append("%d more points to go" % maxi(target - score, 0))
			if not prev.is_empty():
				lines.append("Best  %s   %s" % [Levels.fmt_time(float(prev["secs"])), "★".repeat(int(prev["stars"]))])
			retry_button.caption = "RETRY"
			retry_button.sub = ""
		retry_button.visible = true
	else:
		if res["new_best"] and score > 0:
			over_title.text = "NEW BEST!"
			Sfx.play("best")
			Fx.confetti(fx, camera.get_screen_center_position(), 120.0)
		else:
			over_title.text = "Jar overflowed!"
			Sfx.play("over")
		lines.append("Score  %d" % score)
		lines.append("Merges  %d   ·   Biggest  %s" % [merges, Tiers.tier_name(best_tier)])
		lines.append("Flips  %d   ·   Shakes  %d" % [flips_used, shakes_used])
		lines.append("Time  %s" % _fmt_time(int(run_time)))
		lines.append("Today's best  %d" % int(res["best"]))
		lines.append("Streak  %d day%s" % [Save.current_streak(), "" if Save.current_streak() == 1 else "s"])
		var left := Save.attempts_left()
		retry_button.visible = left > 0
		retry_button.caption = "RETRY"
		retry_button.sub = "%d left" % left
		result_text = "FLIP JAR  Day %d\nScore: %d\nFlips used: %d\nStreak: %d days\nCan you beat me? %s" % [
			Save.day_number(), score, flips_used, Save.current_streak(), STORE_LINK]
	over_stats.text = "\n".join(lines)
	menu_button.visible = true
	for g in over_groups:
		UiKit.sync_group(g)
	pause_button.visible = false
	over_panel.visible = true
	over_panel.modulate.a = 0.0
	create_tween().tween_property(over_panel, "modulate:a", 1.0, 0.3)
	var i := 0
	for c in over_box.get_children():
		if c is Control and c.visible:
			UiKit.pop_in(c, 0.15 + i * 0.08)
			i += 1
	_update_ui()


func _run_stats(stars := 0) -> Dictionary:
	return {"merges": merges, "best_tier": best_tier, "flips": flips_used, "shakes": shakes_used,
		"secs": int(run_time), "level": level if mode == "level" else 0, "won": won, "stars": stars,
		"time": minf(run_time, time_limit) if mode == "level" else run_time}


## Star row and the action cards on the result screen:
##   PLAY (next / retry)   GO TO (levels / home)   SHARE (WhatsApp / copy)
func _build_result_extras() -> void:
	star_row = StarRow.new()
	star_row.custom_minimum_size = Vector2(0, 130)
	over_box.add_child(star_row)
	over_box.move_child(star_row, over_title.get_index() + 1)
	next_button = IconButton.make("next", "NEXT", "orange")
	retry_button = IconButton.make("replay", "RETRY", "green")
	over_levels_button = IconButton.make("grid", "LEVELS", "blue")
	menu_button = IconButton.make("home", "HOME", "purple")
	share_button = IconButton.make("share", "SHARE", "green")
	copy_button = IconButton.make("copy", "COPY", "blue")
	next_button.pressed.connect(_on_next)
	retry_button.pressed.connect(_on_retry)
	over_levels_button.pressed.connect(_go_levels)
	menu_button.pressed.connect(_go_menu)
	share_button.pressed.connect(_share_whatsapp)
	copy_button.pressed.connect(_copy_result)
	over_groups = [
		UiKit.group("PLAY", [next_button, retry_button], Color(1, 0.6, 0.2, 0.16)),
		UiKit.group("GO TO", [over_levels_button, menu_button], Color(0.3, 0.6, 1, 0.16)),
		UiKit.group("SHARE", [share_button, copy_button], Color(0.3, 1, 0.5, 0.14)),
	]
	over_box.add_child(_group_row(over_groups))


## The pause screen: GAME (resume / restart) and GO TO (levels / home) side by side.
func _build_pause_actions() -> void:
	resume_button = IconButton.make("play", "RESUME", "green", 130.0)
	restart_button = IconButton.make("replay", "RESTART", "orange", 130.0)
	pause_levels_button = IconButton.make("grid", "LEVELS", "blue", 130.0)
	quit_button = IconButton.make("home", "HOME", "purple", 130.0)
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart_from_pause.bind(""))
	pause_levels_button.pressed.connect(_levels_from_pause)
	quit_button.pressed.connect(_quit_from_pause)
	pause_groups = [
		UiKit.group("GAME", [resume_button, restart_button], Color(0.3, 1, 0.5, 0.14)),
		UiKit.group("GO TO", [pause_levels_button, quit_button], Color(0.3, 0.6, 1, 0.16)),
	]
	pause_box.add_child(_group_row(pause_groups))


func _group_row(groups: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for g in groups:
		row.add_child(g)
	return row


static func _fmt_time(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]


func _on_retry() -> void:
	Sfx.play("click")
	if mode == "daily" and Save.attempts_left() <= 0:
		_go_menu()
		return
	_start_run()


func _on_next() -> void:
	Sfx.play("click")
	Save.level = mini(level + 1, Levels.COUNT)
	get_tree().reload_current_scene()


func _go_levels() -> void:
	Sfx.play("click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels.tscn")


func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# --- Pause -------------------------------------------------------------------

func is_paused() -> bool:
	return pause_panel.visible


func _pause() -> void:
	if game_over or is_paused():
		return
	Sfx.play("click")
	get_tree().paused = true
	if mode == "daily":
		pause_info.text = "Score %d   ·   Daily #%d" % [score, Save.day_number()]
		if drops > 0:
			pause_info.text += "\nRestarting or quitting uses this try."
	else:
		pause_info.text = "Level %d   ·   goal %d%% done" % [level, int(100.0 * minf(1.0, float(score) / target))]
	pause_levels_button.visible = mode == "level"
	for g in pause_groups:
		UiKit.sync_group(g)
	pause_panel.visible = true
	pause_panel.modulate.a = 0.0
	pause_panel.create_tween().tween_property(pause_panel, "modulate:a", 1.0, 0.2)
	var i := 0
	for c in pause_box.get_children():
		if c is Control and c.visible:
			UiKit.pop_in(c, 0.05 + i * 0.05)
			i += 1


func _resume() -> void:
	if not is_paused():
		return
	Sfx.play("click")
	pause_panel.visible = false
	get_tree().paused = false


## Ends the current run (it still counts if anything was dropped) and starts a new one.
func _restart_from_pause(_unused := "") -> void:
	Sfx.play("click")
	_abandon_run()
	get_tree().paused = false
	if mode == "daily" and Save.attempts_left() <= 0:
		_go_menu()
		return
	_start_run()


func _levels_from_pause() -> void:
	_abandon_run()
	_go_levels()


func _quit_from_pause() -> void:
	Sfx.play("click")
	_abandon_run()
	_go_menu()


## Saves a run that was quit midway, so daily tries can't be dodged and it shows in history.
func _abandon_run() -> void:
	if game_over or drops == 0:
		return
	game_over = true
	Save.record_run(mode, score, _run_stats())


func _share_whatsapp() -> void:
	Sfx.play("click")
	OS.shell_open("https://wa.me/?text=" + result_text.uri_encode())


func _copy_result() -> void:
	Sfx.play("click")
	DisplayServer.clipboard_set(result_text)
	_toast("Copied! Paste it anywhere")


# --- UI ----------------------------------------------------------------------

func _add_score(points: int) -> void:
	score += points
	if mode != "level":
		UiKit.punch(score_label, clampf(0.12 + points * 0.01, 0.12, 0.45))


func _update_ui() -> void:
	if game_over or shown_score > score:
		shown_score = score
	score_label.text = "LEVEL %d" % level if mode == "level" else str(shown_score)
	flip_button.text = "FLIP %d" % flips_left
	shake_button.text = "SHAKE %d" % shakes_left
	flip_button.disabled = flips_left <= 0 or game_over
	shake_button.disabled = shakes_left <= 0 or game_over


func _show_hint(text: String) -> void:
	hint_label.text = text
	_fade_hint(1.0, 0.3)


func _hide_hint() -> void:
	_fade_hint(0.0, 0.4)


## One hint animation at a time, so a hide always wins over an earlier show.
func _fade_hint(to: float, secs: float) -> void:
	if hint_tween != null and hint_tween.is_valid():
		hint_tween.kill()
	if secs <= 0.0:
		hint_label.modulate.a = to
		return
	hint_tween = create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", to, secs)


func _toast(text: String) -> void:
	toast_label.text = text
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)


func _start_pulse() -> void:
	_stop_pulse()
	pulse_tween = create_tween().set_loops()
	for b in [flip_button, shake_button]:
		pulse_tween.tween_property(b, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null
	if flip_button != null:
		flip_button.scale = Vector2.ONE
		shake_button.scale = Vector2.ONE
