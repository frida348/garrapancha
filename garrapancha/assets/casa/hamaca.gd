extends Node2D
var input_vector: Vector2 = Vector2.ZERO

const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: String = "res://dialogue/hamaca.dialogue"
@export var dialogue_start: String = "start"

func _ready() -> void:
	pass

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# 1. Check if the event is a mouse button press
	if event is InputEventMouseButton:
		
		# 2. Check if the "interact" action was just pressed
		if event.is_action_pressed("interact"):
			
			# --- Move Instantiation HERE (Inside the check) ---
			var balloon: Node = Balloon.instantiate()
			get_tree().current_scene.add_child(balloon)
			
			# 3. If it was, trigger the dialogue
			# The DialogueManager typically expects a loaded resource, not a path string.
			balloon.start(load(dialogue_resource), dialogue_start) 
			
			# 4. Stop the input event from propagating further
			get_viewport().set_input_as_handled()
