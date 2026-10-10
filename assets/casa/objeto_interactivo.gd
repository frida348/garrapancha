extends Area2D

@export var es_correcto: bool = false
@export var mensaje_correcto: String = "Factor de riesgo identificado!"
@export var mensaje_incorrecto: String = "Ese objeto no es un factor de riesgo."
@export var nombre_objeto: String = ""

var ya_seleccionado := false
var juego_activo := false

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not juego_activo:
		return

	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var escena := get_tree().current_scene

	if ya_seleccionado:
		if escena.has_method("registrar_repetido"):
			escena.registrar_repetido(self)
		get_viewport().set_input_as_handled()
		return

	ya_seleccionado = true

	if es_correcto:
		_marcar_como_identificado()
		if escena.has_method("registrar_acierto"):
			escena.registrar_acierto(self)
	else:
		if escena.has_method("registrar_error"):
			escena.registrar_error(self)

	get_viewport().set_input_as_handled()

func _marcar_como_identificado() -> void:
	hide()
	visible = false
	input_pickable = false
	monitoring = false
	monitorable = false

	var area := get_node_or_null("Area2D") as Area2D
	if area != null:
		area.monitoring = false
		area.monitorable = false

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
