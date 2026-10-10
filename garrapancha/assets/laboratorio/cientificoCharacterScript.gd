extends Node2D

var input_vector: Vector2 = Vector2.ZERO
const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: String = "res://dialogue/cientifico.dialogue"
@export var dialogue_start: String = "start"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 👉 1. Start the "idle" animation immediately when the scene loads
	anim.play("idle")
	
	# Connect to the global signal
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("interact"):
		
		# 👉 2. Switch to "talk" when clicked
		anim.play("talk")

		# Instantiate the balloon
		var balloon: Node = Balloon.instantiate()
		get_tree().current_scene.add_child(balloon)
		balloon.start(load(dialogue_resource), dialogue_start)

		get_viewport().set_input_as_handled()

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# 👉 3. Switch back to "idle" when dialogue finishes
	anim.play("idle")
