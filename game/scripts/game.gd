extends Node2D
## Flip Jar game scene: jar, drop, merge, flip, overflow, score, juice and the result screen.

const JAR_LEFT := 60.0
const JAR_RIGHT := 660.0
const JAR_TOP := 240.0      # drop side when not flipped
const JAR_BOTTOM := 1040.0  # floor when not flipped
const WALL := 24.0
const DANGER_DEPTH := 150.0 # overflow zone measured from the drop side
const MAX_FLIPS := 3
const SPAWN_TIERS := 5      # only the 5 smallest tiers are ever dropped
const DROP_DELAY := 0.55
const OVERFLOW_TIME := 1.0
const FLIP_GRACE := 1.5
const SETTLED_SPEED := 40.0
const FLIP_HINT_AFTER_DROPS := 6
const STORE_LINK := "https://play.google.com/store/apps/details?id=com.flipjar.game"

var mode := "free"
var score := 0
var flips_left := MAX_FLIPS
var flipped := false
var game_over := false
var held: Piece = null
var next_tier := 0
var drops := 0
var drop_cooldown := 0.0
var flip_grace := 0.0
var shake := 0.0
var overflow_timers := {}  # piece instance id -> seconds settled in the danger zone
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var flip_tween: Tween = null
var pulse_tween: Tween = null
var result_text := ""

@onready var camera: Camera2D = $Camera
@onready var pieces: Node2D = $Pieces
@onready var fx: Node2D = $Fx
@onready var score_label: Label = $UI/Score
@onready var flips_label: Label = $UI/Flips
@onready var mode_label: Label = $UI/Mode
@onready var hint_label: Label = $UI/Hint
@onready var toast_label: Label = $UI/Toast
@onready var flip_button: Button = $UI/FlipButton
@onready var next_preview: Node2D = $UI/NextPreview
@onready var over_panel: Control = $UI/GameOver
@onready var over_title: Label = $UI/GameOver/Box/Title
@onready var over_stats: Label = $UI/GameOver/Box/Stats
@onready var share_button: Button = $UI/GameOver/Box/Share
@onready var copy_button: Button = $UI/GameOver/Box/Copy
@onready var retry_button: Button = $UI/GameOver/Box/Retry
@onready var menu_button: Button = $UI/GameOver/Box/Menu


func _ready() -> void:
	mode = Save.mode
	RenderingServer.set_default_clear_color(Tiers.background())
	_build_jar()
	flip_button.pressed.connect(_flip)
	flip_button.pivot_offset = flip_button.size / 2.0
	retry_button.pressed.connect(_on_retry)
	share_button.pressed.connect(_share_whatsapp)
	copy_button.pressed.connect(_copy_result)
	menu_button.pressed.connect(_go_menu)
	hint_label.modulate.a = 0.0
	toast_label.modulate.a = 0.0
	_start_run()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_menu()


func _start_run() -> void:
	for p in pieces.get_children():
		p.queue_free()
	for f in fx.get_children():
		f.queue_free()
	held = null
	score = 0
	flips_left = MAX_FLIPS
	flipped = false
	game_over = false
	drops = 0
	drop_cooldown = 0.0
	flip_grace = 0.0
	shake = 0.0
	overflow_timers.clear()
	if flip_tween != null and flip_tween.is_valid():
		flip_tween.kill()
	_stop_pulse()
	camera.rotation = 0.0
	camera.offset = Vector2.ZERO
	over_panel.visible = false
	if mode == "daily":
		rng.seed = Save.daily_seed()
		mode_label.text = "DAILY #%d  ·  try %d of %d" % [Save.day_number(), Save.DAILY_ATTEMPTS - Save.attempts_left() + 1, Save.DAILY_ATTEMPTS]
	else:
		rng.randomize()
		mode_label.text = "FREE PLAY  ·  best %d" % int(Save.data["best_free"])
	next_tier = _roll_tier()
	next_preview.set_tier(next_tier)
	if not Save.data["first_run_done"]:
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


func _draw() -> void:
	var solid := Color(0.85, 0.9, 1.0, 0.95)
	var faint := Color(0.85, 0.9, 1.0, 0.18)
	var w := 6.0
	draw_line(Vector2(JAR_LEFT, JAR_TOP), Vector2(JAR_LEFT, JAR_BOTTOM), solid, w)
	draw_line(Vector2(JAR_RIGHT, JAR_TOP), Vector2(JAR_RIGHT, JAR_BOTTOM), solid, w)
	# The pile side is drawn solid, the drop side faint.
	draw_line(Vector2(JAR_LEFT, JAR_BOTTOM), Vector2(JAR_RIGHT, JAR_BOTTOM), faint if flipped else solid, w)
	draw_line(Vector2(JAR_LEFT, JAR_TOP), Vector2(JAR_RIGHT, JAR_TOP), solid if flipped else faint, w)
	var y := _danger_line_y()
	draw_dashed_line(Vector2(JAR_LEFT, y), Vector2(JAR_RIGHT, y), Color(1.0, 0.4, 0.4, 0.85), 3.0, 16.0)
	# Drop guide from the held piece to the far side of the jar.
	if held != null and not game_over:
		var from := held.position + Vector2(0.0, -held.radius if flipped else held.radius)
		var to := Vector2(held.position.x, JAR_TOP if flipped else JAR_BOTTOM)
		var c := Tiers.color(held.tier)
		draw_dashed_line(from, to, Color(c.r, c.g, c.b, 0.35), 2.0, 12.0)


func _danger_line_y() -> float:
	return JAR_BOTTOM - DANGER_DEPTH if flipped else JAR_TOP + DANGER_DEPTH


func _spawn_y(r: float) -> float:
	return JAR_BOTTOM - r - 8.0 if flipped else JAR_TOP + r + 8.0


func _in_danger(p: Piece) -> bool:
	return p.position.y > _danger_line_y() if flipped else p.position.y < _danger_line_y()


func _screen_up() -> Vector2:
	return Vector2.UP.rotated(camera.rotation)


# --- Pieces ------------------------------------------------------------------

func _roll_tier() -> int:
	return rng.randi_range(0, SPAWN_TIERS - 1)


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
	drop_cooldown = DROP_DELAY
	drops += 1
	if drops == 1:
		_hide_hint()
	if drops == FLIP_HINT_AFTER_DROPS and not Save.data["flip_hint_done"]:
		_show_hint("Try FLIP to turn the jar!")
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
	if not (is_instance_valid(a) and is_instance_valid(b)):
		return
	var tier := a.tier
	var mid := (a.position + b.position) / 2.0
	var vel := (a.linear_velocity + b.linear_velocity) / 2.0
	overflow_timers.erase(a.get_instance_id())
	overflow_timers.erase(b.get_instance_id())
	a.queue_free()
	b.queue_free()
	var points := Tiers.merge_score(tier)
	var color := Tiers.color(tier)
	var r := Tiers.radius(tier)
	if tier + 1 < Tiers.count():
		var p := _make_piece(tier + 1, mid)
		p.linear_velocity = vel
		color = Tiers.color(tier + 1)
		r = Tiers.radius(tier + 1)
	else:
		points += 100  # two Suns clear the jar space
	score += points
	Fx.ring(fx, mid, color, r)
	Fx.burst(fx, mid, color, r)
	Fx.popup(fx, mid, "+%d" % points, color.lightened(0.3), _screen_up(), camera.rotation)
	Sfx.play("pop", clampf(1.7 - tier * 0.12, 0.6, 1.7) + fx_rng.randf_range(-0.04, 0.04))
	shake = maxf(shake, 2.0 + tier * 1.2)
	Save.vibrate(15 + tier * 4)
	_update_ui()


# --- Flip --------------------------------------------------------------------

func _flip() -> void:
	if game_over or flips_left <= 0:
		return
	flips_left -= 1
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
	if not Save.data["flip_hint_done"]:
		Save.data["flip_hint_done"] = true
		Save.save()
	_stop_pulse()
	_hide_hint()
	_update_ui()
	queue_redraw()


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
	if shake > 0.0:
		camera.offset = Vector2(fx_rng.randf_range(-shake, shake), fx_rng.randf_range(-shake, shake))
		shake = move_toward(shake, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	if held != null:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if game_over:
		return
	drop_cooldown -= delta
	flip_grace -= delta
	if held == null and drop_cooldown <= 0.0:
		_spawn_held()
	if flip_grace > 0.0:
		return
	for node in pieces.get_children():
		var p := node as Piece
		if p == null or p == held or p.merging:
			continue
		var id := p.get_instance_id()
		if _in_danger(p) and p.linear_velocity.length() < SETTLED_SPEED:
			overflow_timers[id] = overflow_timers.get(id, 0.0) + delta
			if overflow_timers[id] >= OVERFLOW_TIME:
				_end_game()
				return
		else:
			overflow_timers.erase(id)


# --- Results -----------------------------------------------------------------

func _end_game() -> void:
	game_over = true
	if held != null:
		held.queue_free()
		held = null
	_stop_pulse()
	_hide_hint()
	shake = 14.0
	Save.vibrate(120)
	var res: Dictionary = Save.record_run(mode, score)
	var flips_used := MAX_FLIPS - flips_left
	if res["new_best"] and score > 0:
		over_title.text = "NEW BEST!"
		Sfx.play("best")
	else:
		over_title.text = "Jar overflowed!"
		Sfx.play("over")
	var lines := ["Score  %d" % score, "Flips used  %d of %d" % [flips_used, MAX_FLIPS]]
	if mode == "daily":
		lines.append("Today's best  %d" % int(res["best"]))
		lines.append("Streak  %d day%s" % [Save.current_streak(), "" if Save.current_streak() == 1 else "s"])
		var left := Save.attempts_left()
		retry_button.visible = left > 0
		retry_button.text = "TRY AGAIN  (%d left)" % left
		result_text = "FLIP JAR  Day %d\nScore: %d\nFlips used: %d/%d\nStreak: %d days\nCan you beat me? %s" % [
			Save.day_number(), score, flips_used, MAX_FLIPS, Save.current_streak(), STORE_LINK]
	else:
		lines.append("Best  %d" % int(res["best"]))
		retry_button.visible = true
		retry_button.text = "PLAY AGAIN"
		result_text = "FLIP JAR  Free Play\nScore: %d\nFlips used: %d/%d\nCan you beat me? %s" % [
			score, flips_used, MAX_FLIPS, STORE_LINK]
	over_stats.text = "\n".join(lines)
	over_panel.visible = true
	_update_ui()


func _on_retry() -> void:
	Sfx.play("click")
	if mode == "daily" and Save.attempts_left() <= 0:
		_go_menu()
		return
	_start_run()


func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _share_whatsapp() -> void:
	Sfx.play("click")
	OS.shell_open("https://wa.me/?text=" + result_text.uri_encode())


func _copy_result() -> void:
	Sfx.play("click")
	DisplayServer.clipboard_set(result_text)
	_toast("Copied! Paste it anywhere")


# --- UI ----------------------------------------------------------------------

func _update_ui() -> void:
	score_label.text = str(score)
	flips_label.text = "Flips %d" % flips_left
	flip_button.text = "FLIP (%d)" % flips_left
	flip_button.disabled = flips_left <= 0 or game_over


func _show_hint(text: String) -> void:
	hint_label.text = text
	var tw := create_tween()
	tw.tween_property(hint_label, "modulate:a", 1.0, 0.3)


func _hide_hint() -> void:
	if hint_label.modulate.a <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(hint_label, "modulate:a", 0.0, 0.4)


func _toast(text: String) -> void:
	toast_label.text = text
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)


func _start_pulse() -> void:
	_stop_pulse()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(flip_button, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(flip_button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null
	if flip_button != null:
		flip_button.scale = Vector2.ONE
