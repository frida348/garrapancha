extends Node2D

var _slots: Array = []
var _size: Vector2


func setup(positions: Array, size: Vector2) -> void:
	_slots = positions
	_size = size
	queue_redraw()


func _draw() -> void:
	for pos in _slots:
		draw_rect(Rect2(pos, _size), Color(1.0, 1.0, 1.0, 0.12), true)
		draw_rect(Rect2(pos, _size), Color(1.0, 1.0, 1.0, 0.55), false, 2.5)
