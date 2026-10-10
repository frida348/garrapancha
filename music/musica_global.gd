extends Node

const GRUPO_SONIDO_BOTON_REGISTRADO: StringName = &"sonido_boton_registrado"
const COOLDOWN_SONIDO_MS: int = 50
const COOLDOWN_CAMBIO_ESCENA_MS: int = 150

@onready var reproductor_botones: AudioStreamPlayer = $AudioStreamPlayerBotones
@onready var reproductor_cambio_escena: AudioStreamPlayer = $AudioStreamPlayerCambioEscena

var _ultimo_sonido_boton_ms: int = -COOLDOWN_SONIDO_MS
var _ultimo_cambio_escena_ms: int = -COOLDOWN_CAMBIO_ESCENA_MS


func _ready() -> void:
	get_tree().node_added.connect(_registrar_nodo_si_es_boton)
	_registrar_botones_en_arbol(get_tree().root)


func _registrar_botones_en_arbol(nodo: Node) -> void:
	_registrar_nodo_si_es_boton(nodo)
	for hijo in nodo.get_children():
		_registrar_botones_en_arbol(hijo)


func _registrar_nodo_si_es_boton(nodo: Node) -> void:
	if nodo is not BaseButton:
		return

	if nodo.is_in_group(GRUPO_SONIDO_BOTON_REGISTRADO):
		return

	nodo.add_to_group(GRUPO_SONIDO_BOTON_REGISTRADO)
	nodo.pressed.connect(reproducir_sonido_boton)


func reproducir_sonido_boton() -> void:
	if reproductor_botones.stream == null:
		return

	var tiempo_actual_ms: int = Time.get_ticks_msec()
	if tiempo_actual_ms - _ultimo_sonido_boton_ms < COOLDOWN_SONIDO_MS:
		return

	_ultimo_sonido_boton_ms = tiempo_actual_ms
	reproductor_botones.play()


func cambiar_escena(ruta_escena: String) -> Error:
	var tiempo_actual_ms: int = Time.get_ticks_msec()
	if tiempo_actual_ms - _ultimo_cambio_escena_ms < COOLDOWN_CAMBIO_ESCENA_MS:
		return ERR_BUSY

	_ultimo_cambio_escena_ms = tiempo_actual_ms
	reproducir_sonido_cambio_escena()
	return get_tree().change_scene_to_file(ruta_escena)


func reproducir_sonido_cambio_escena() -> void:
	if reproductor_cambio_escena.stream == null:
		return

	if reproductor_cambio_escena.playing:
		reproductor_cambio_escena.stop()
	reproductor_cambio_escena.play()
