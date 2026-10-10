extends Node2D

var input_vector: Vector2 = Vector2.ZERO

const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: String = "res://dialogue/garrapancha.dialogue"
@export var dialogue_start: String = "start"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	anim.play("idle")
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("interact"):
		anim.play("talk")

		var balloon: Node = Balloon.instantiate()
		get_tree().current_scene.add_child(balloon)
		balloon.start(load(dialogue_resource), dialogue_start, [self])

		get_viewport().set_input_as_handled()

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	anim.play("idle")

func go_to_rompecabezas() -> void:
	get_tree().change_scene_to_file("res://assets/monte/rompecabezas.tscn")

func go_to_memorama() -> void:
	get_tree().change_scene_to_file("res://assets/monte/memorama.tscn")
