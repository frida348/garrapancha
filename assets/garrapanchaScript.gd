extends AnimatedSprite2D

var input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		DialogueManager.show_example_dialogue_balloon(load("res://dialogue/garrapancha.dialogue"), "start")
		return
