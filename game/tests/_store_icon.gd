extends Node2D
func _draw() -> void:
	var c := Color(0.85, 0.9, 1.0)
	draw_line(Vector2(104, 100), Vector2(104, 440), c, 20.0)
	draw_line(Vector2(408, 100), Vector2(408, 440), c, 20.0)
	draw_line(Vector2(94, 440), Vector2(418, 440), c, 20.0)
	draw_set_transform(Vector2(256, 300), 0.0, Vector2.ONE)
	Tiers.draw_piece(self, 10, 118.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
