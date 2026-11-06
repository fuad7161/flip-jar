extends Node2D
## Draws the upcoming piece in the UI layer.

var tier := 0


func set_tier(new_tier: int) -> void:
	tier = new_tier
	queue_redraw()


func _draw() -> void:
	Tiers.draw_piece(self, tier, 30.0)
