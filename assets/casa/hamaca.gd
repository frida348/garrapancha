extends Node2D

const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: String = "res://dialogue/hamaca.dialogue"
@export var dialogue_start: String = "start"

var juego_activado := false

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("interact"):
		MusicaGlobal.reproducir_sonido_boton()
		var balloon: Node = Balloon.instantiate()
		get_tree().current_scene.add_child(balloon)

		# Le pasamos self al diálogo
		balloon.start(load(dialogue_resource), dialogue_start, [self])

		# Cuando el balloon se cierre, revisamos si hay que entrar al minijuego
		balloon.tree_exited.connect(_on_balloon_closed)

		get_viewport().set_input_as_handled()


func activar_juego() -> void:
	juego_activado = true
	print("El jugador eligió entrar al minijuego")


func _on_balloon_closed() -> void:
	if juego_activado:
		MusicaGlobal.cambiar_escena("res://assets/casa/minijuego_casa.tscn")

func ready() -> void:
	$AnimationPlayer.play("idle_personajes")
	print("animacion iniciada")
	##$AnimationPlayer.play("idle_personajes")
