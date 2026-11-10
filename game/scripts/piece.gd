class_name Piece
extends RigidBody2D
## One droppable jelly piece. Stretches like a droplet in flight, squashes and wobbles
## on impact, pops in when spawned, and reports same-tier contacts for merging.

signal merge_requested(a: Piece, b: Piece)
signal landed(piece: Piece, impact: float)

const MAX_STRETCH := 0.28
const MAX_SQUASH := 0.38

var tier := 0
var radius := 10.0
var merging := false

var impact_amt := 0.0     # > 0 compresses along the travel direction; elastic tween makes it wobble
var squash_dir := 0.0     # world angle of the last impact
var spawn_scale := 1.0
var prev_vel := Vector2.ZERO
var impact_tween: Tween
var squash: Node2D
var face: Node2D


class Face extends Node2D:
	var piece: Piece

	func _draw() -> void:
		Tiers.draw_piece(self, piece.tier, piece.radius)


func setup(new_tier: int, pop := true) -> void:
	tier = new_tier
	radius = Tiers.radius(tier)

	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	squash = Node2D.new()
	face = Face.new()
	face.piece = self
	squash.add_child(face)
	add_child(squash)

	mass = radius * radius / 400.0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.1
	physics_material_override = pm
	linear_damp = 0.3
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # no tunnelling through walls at flip speed
	angular_damp = 0.6
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

	if pop:
		spawn_scale = 0.3
		var tw := create_tween()
		tw.tween_property(self, "spawn_scale", 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(_delta: float) -> void:
	prev_vel = linear_velocity


func _process(_delta: float) -> void:
	var v := linear_velocity
	var speed := v.length()
	var stretch := 0.0
	if not freeze:
		stretch = clampf((speed - 150.0) / 3000.0, 0.0, MAX_STRETCH)
	var ang := v.angle() if speed > 150.0 else squash_dir
	# Align the squash axis with the world travel direction, keep the face on the body.
	squash.rotation = ang - rotation
	face.rotation = -squash.rotation
	var sx := (1.0 + stretch) * (1.0 - impact_amt) * spawn_scale
	var sy := (1.0 - stretch) * (1.0 + impact_amt) * spawn_scale
	squash.scale = Vector2(sx, sy)


func _on_body_entered(body: Node) -> void:
	var impact := (prev_vel - linear_velocity).length()
	if impact > 120.0:
		_squash(impact, prev_vel.angle())
		landed.emit(self, impact)
	if merging or not (body is Piece):
		return
	var other := body as Piece
	if other.merging or other.tier != tier:
		return
	# Only the lower instance id reports the pair, so a contact is handled once.
	if get_instance_id() > other.get_instance_id():
		return
	merging = true
	other.merging = true
	merge_requested.emit(self, other)


func _squash(impact: float, dir: float) -> void:
	var amt := clampf(impact / 1600.0, 0.0, MAX_SQUASH)
	if amt < impact_amt:
		return
	squash_dir = dir
	impact_amt = amt
	if impact_tween != null and impact_tween.is_valid():
		impact_tween.kill()
	impact_tween = create_tween()
	impact_tween.tween_property(self, "impact_amt", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
