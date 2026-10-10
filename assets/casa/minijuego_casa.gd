extends Node2D

const LANDSCAPE_SIZE: Vector2i = Vector2i(1600, 720)
const ESCENA_CASA: String = "res://assets/casa/casa.tscn"
const ESCENA_MINIJUEGO: String = "res://assets/casa/minijuego_casa.tscn"
const COLOR_PANEL_BASE: Color = Color(1, 1, 1, 0.96)
const COLOR_BORDE_BASE: Color = Color(0, 0, 0, 1)

#Duracion del minijuego en segundos
const DURACION_MINIJUEGO_SEGUNDOS: float = 120.0
const INTRO_TYPING_SECONDS_PER_STEP: float = 0.02
const INTRO_TYPING_SECONDS_PER_PAUSE_STEP: float = 0.3
const INTRO_TYPING_PAUSE_CHARACTERS: String = ".?!"
const INTRO_TYPING_SKIP_PAUSE_IF_FOLLOWED_BY: String = ")\""
const INTRO_TYPING_SKIP_PAUSE_ABBREVIATIONS: PackedStringArray = ["Mr", "Mrs", "Ms", "Dr", "etc", "eg", "ex"]
const MENSAJE_CONFIRMACION_SALIDA: String = "¿Seguro que quieres dejar de jugar?"

var total_correctos: int = 0
var encontrados: int = 0
var juego_terminado: bool = false

var _tamano_ventana_original: Vector2i = Vector2i.ZERO
var _escala_contenido_original: Vector2i = Vector2i.ZERO
var _toast_tween: Tween
var _intro_texto_completo: String = ""
var _intro_typing_activo: bool = false
var _intro_typing_espera: float = 0.0
var _intro_ultimo_indice_pausa: int = -1
var _temporizador_activo: bool = false
var _tiempo_restante: float = DURACION_MINIJUEGO_SEGUNDOS
var _ultimo_segundo_mostrado: int = -1

@onready var escenario: Node2D = $Escenario
@onready var fondo: Sprite2D = $Escenario/Fondo
@onready var objetos_interactivos: Array[Node] = $Escenario/ObjetosInteractivos.get_children()
@onready var audio_click_correcto: AudioStreamPlayer = $AudioClickCorrecto
@onready var audio_click_incorrecto: AudioStreamPlayer = $AudioClickIncorrecto
@onready var audio_intro_typing: AudioStreamPlayer = $AudioIntroTyping
@onready var contador_label: Label = $CanvasLayer/HUD/CounterPanel/MarginContainer/CounterLabel
@onready var tiempo_panel: PanelContainer = $CanvasLayer/HUD/TimePanel
@onready var tiempo_label: Label = $CanvasLayer/HUD/TimePanel/MarginContainer/VBoxContainer/TimeLabel
@onready var notificacion_panel: PanelContainer = $CanvasLayer/HUD/NotificationPanel
@onready var notificacion_label: Label = $CanvasLayer/HUD/NotificationPanel/MarginContainer/NotificationLabel
@onready var overlay_confirmacion_salida: ColorRect = $CanvasLayer/HUD/LeaveConfirmOverlay
@onready var panel_confirmacion_salida: PanelContainer = $CanvasLayer/HUD/LeaveConfirmOverlay/LeaveConfirmPanel
@onready var label_confirmacion_salida: Label = $CanvasLayer/HUD/LeaveConfirmOverlay/LeaveConfirmPanel/MarginContainer/VBoxContainer/LeaveConfirmLabel
@onready var overlay_intro: ColorRect = $CanvasLayer/HUD/IntroOverlay
@onready var panel_intro: PanelContainer = $CanvasLayer/HUD/IntroOverlay/IntroPanel
@onready var jorgito: AnimatedSprite2D = $CanvasLayer/HUD/IntroOverlay/Jorgito
@onready var intro_label: Label = $CanvasLayer/HUD/IntroOverlay/IntroPanel/MarginContainer/VBoxContainer/IntroLabel
@onready var overlay_final: ColorRect = $CanvasLayer/HUD/FinalOverlay
@onready var panel_final: PanelContainer = $CanvasLayer/HUD/FinalOverlay/FinalPanel
@onready var titulo_final_label: Label = $CanvasLayer/HUD/FinalOverlay/FinalPanel/MarginContainer/VBoxContainer/TituloFinalLabel
@onready var resumen_final_label: Label = $CanvasLayer/HUD/FinalOverlay/FinalPanel/MarginContainer/VBoxContainer/ResumenFinalLabel
@onready var boton_volver_casa: Button = $CanvasLayer/HUD/TopButtons/VolverCasaButton
@onready var boton_confirmar_salida: Button = $CanvasLayer/HUD/LeaveConfirmOverlay/LeaveConfirmPanel/MarginContainer/VBoxContainer/ButtonRow/ConfirmLeaveButton
@onready var boton_cancelar_salida: Button = $CanvasLayer/HUD/LeaveConfirmOverlay/LeaveConfirmPanel/MarginContainer/VBoxContainer/ButtonRow/CancelLeaveButton
@onready var boton_iniciar_juego: Button = $CanvasLayer/HUD/IntroOverlay/IntroPanel/MarginContainer/VBoxContainer/IntroButtonRow/StartGameButton
@onready var boton_final_reiniciar: Button = $CanvasLayer/HUD/FinalOverlay/FinalPanel/MarginContainer/VBoxContainer/ButtonRow/RestartFinalButton
@onready var boton_final_volver: Button = $CanvasLayer/HUD/FinalOverlay/FinalPanel/MarginContainer/VBoxContainer/ButtonRow/VolverCasaFinalButton


func _ready() -> void:
	_configurar_pantalla_horizontal()
	_configurar_escenario()
	_configurar_interfaz()
	desactivar_objetos()

	total_correctos = contar_objetos_correctos()
	_actualizar_contador()


func _exit_tree() -> void:
	_detener_temporizador()
	_restaurar_pantalla_original()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not _minijuego_acepta_clicks():
		return

	if _clic_sobre_objeto_interactivo(mouse_event.position):
		return

	if audio_click_incorrecto.stream != null:
		audio_click_incorrecto.play()


func _process(delta: float) -> void:
	if _intro_typing_activo:
		_actualizar_typing_intro(delta)

	if _temporizador_activo:
		_actualizar_temporizador(delta)


func contar_objetos_correctos() -> int:
	var total: int = 0
	for objeto in objetos_interactivos:
		if objeto is Area2D and bool(objeto.get("es_correcto")):
			total += 1
	return total


func activar_objetos() -> void:
	for objeto in objetos_interactivos:
		if objeto is Area2D:
			objeto.set("juego_activo", true)
			objeto.set("ya_seleccionado", false)


func desactivar_objetos() -> void:
	for objeto in objetos_interactivos:
		if objeto is Area2D:
			objeto.set("juego_activo", false)


func registrar_acierto(objeto: Node) -> void:
	if juego_terminado:
		return

	encontrados += 1
	if audio_click_correcto.stream != null:
		audio_click_correcto.play()
	_actualizar_contador()
	_mostrar_notificacion(str(objeto.get("mensaje_correcto")), Color(0.20, 0.55, 0.30, 0.94))

	if encontrados >= total_correctos:
		_terminar_minijuego()


func registrar_repetido(_objeto: Node) -> void:
	_mostrar_notificacion("Ya fue identificado anteriormente", Color(0.50, 0.35, 0.08, 0.94))


func registrar_error(objeto: Node) -> void:
	_mostrar_notificacion(str(objeto.get("mensaje_incorrecto")), Color(0.56, 0.18, 0.18, 0.94))


func _configurar_pantalla_horizontal() -> void:
	var raiz: Window = get_tree().root
	_tamano_ventana_original = get_window().size
	_escala_contenido_original = raiz.content_scale_size

	raiz.content_scale_size = LANDSCAPE_SIZE
	get_window().size = LANDSCAPE_SIZE


func _restaurar_pantalla_original() -> void:
	var raiz: Window = get_tree().root
	if _escala_contenido_original != Vector2i.ZERO:
		raiz.content_scale_size = _escala_contenido_original
	if _tamano_ventana_original != Vector2i.ZERO:
		get_window().size = _tamano_ventana_original


func _configurar_escenario() -> void:
	var textura_fondo: Texture2D = fondo.texture
	if textura_fondo == null:
		return

	fondo.centered = false

	var tamano_base: Vector2 = Vector2(textura_fondo.get_size())
	var escala_horizontal: float = float(LANDSCAPE_SIZE.x) / tamano_base.x
	var escala_vertical: float = float(LANDSCAPE_SIZE.y) / tamano_base.y
	var escala: float = min(escala_horizontal, escala_vertical)

	escenario.scale = Vector2.ONE * escala

	var tamano_escalado: Vector2 = tamano_base * escala
	var tamano_pantalla: Vector2 = Vector2(LANDSCAPE_SIZE)
	escenario.position = (tamano_pantalla - tamano_escalado) * 0.5


func _configurar_interfaz() -> void:
	_aplicar_estilo_panel(tiempo_panel, COLOR_PANEL_BASE, COLOR_BORDE_BASE)
	notificacion_panel.visible = false
	notificacion_panel.modulate.a = 0.0
	_aplicar_estilo_panel(notificacion_panel, COLOR_PANEL_BASE, COLOR_BORDE_BASE)
	_aplicar_estilo_panel(panel_confirmacion_salida, COLOR_PANEL_BASE, COLOR_BORDE_BASE)
	_aplicar_estilo_panel(panel_intro, COLOR_PANEL_BASE, COLOR_BORDE_BASE)
	_aplicar_estilo_panel(panel_final, COLOR_PANEL_BASE, COLOR_BORDE_BASE)
	label_confirmacion_salida.text = MENSAJE_CONFIRMACION_SALIDA
	overlay_confirmacion_salida.visible = false
	overlay_intro.visible = true
	_iniciar_animacion_jorgito()
	overlay_final.visible = false
	_reiniciar_temporizador()

	boton_volver_casa.pressed.connect(_mostrar_confirmacion_salida)
	boton_confirmar_salida.pressed.connect(_confirmar_salida)
	boton_cancelar_salida.pressed.connect(_cerrar_confirmacion_salida)
	boton_iniciar_juego.pressed.connect(_iniciar_minijuego)
	boton_final_reiniciar.pressed.connect(_reiniciar_minijuego)
	boton_final_volver.pressed.connect(_volver_a_casa)
	audio_intro_typing.finished.connect(_reanudar_audio_intro_si_aplica)
	_preparar_typing_intro()


func _iniciar_animacion_jorgito() -> void:
	if jorgito == null or jorgito.sprite_frames == null:
		return

	if jorgito.sprite_frames.has_animation(&"idle") and jorgito.animation != &"idle":
		jorgito.animation = &"idle"

	if jorgito.sprite_frames.has_animation(&"idle") and not jorgito.is_playing():
		jorgito.play("idle")


func _actualizar_contador() -> void:
	contador_label.text = "%d/%d encontrados" % [encontrados, total_correctos]


func _mostrar_notificacion(mensaje: String, color_fondo: Color) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	var color_panel: Color = COLOR_PANEL_BASE.lerp(color_fondo, 0.18)
	var color_borde: Color = COLOR_BORDE_BASE.lerp(color_fondo, 0.55)
	_aplicar_estilo_panel(notificacion_panel, color_panel, color_borde)
	notificacion_label.text = mensaje
	notificacion_panel.visible = true
	notificacion_panel.modulate.a = 0.0

	_toast_tween = create_tween()
	_toast_tween.tween_property(notificacion_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(notificacion_panel, "modulate:a", 0.0, 0.2)
	_toast_tween.finished.connect(func() -> void:
		notificacion_panel.visible = false
	)


func _terminar_minijuego() -> void:
	juego_terminado = true
	_detener_temporizador()
	desactivar_objetos()
	_mostrar_notificacion("Excelente! Encontraste todos los factores de riesgo.", Color(0.11, 0.42, 0.24, 0.96))
	_mostrar_overlay_final(
		"Excelente!",
		"Completaste el recorrido e identificaste los 10 factores de riesgo.",
		Color(0.11, 0.42, 0.24, 0.96),
		false
	)


func _terminar_minijuego_por_tiempo() -> void:
	if juego_terminado:
		return

	juego_terminado = true
	_detener_temporizador()
	desactivar_objetos()
	_tiempo_restante = 0.0
	_actualizar_tiempo_label(true)
	_mostrar_notificacion("Se termino el tiempo.", Color(0.56, 0.18, 0.18, 0.94))
	_mostrar_overlay_final(
		"Tiempo agotado",
		"No encontraste los 10 factores de riesgo a tiempo. Puedes volver a intentarlo o regresar a la casa.",
		Color(0.56, 0.18, 0.18, 0.94),
		true
	)


func _mostrar_confirmacion_salida() -> void:
	label_confirmacion_salida.text = MENSAJE_CONFIRMACION_SALIDA
	overlay_confirmacion_salida.visible = true


func _cerrar_confirmacion_salida() -> void:
	overlay_confirmacion_salida.visible = false


func _iniciar_minijuego() -> void:
	_detener_typing_intro(false)
	overlay_intro.visible = false
	activar_objetos()
	_reiniciar_temporizador()
	_iniciar_temporizador()


func _confirmar_salida() -> void:
	_cerrar_confirmacion_salida()
	_volver_a_casa()


func _reiniciar_minijuego() -> void:
	MusicaGlobal.cambiar_escena(ESCENA_MINIJUEGO)


func _volver_a_casa() -> void:
	MusicaGlobal.cambiar_escena(ESCENA_CASA)


func _minijuego_acepta_clicks() -> bool:
	return not overlay_intro.visible and not overlay_confirmacion_salida.visible and not overlay_final.visible and not juego_terminado


func _clic_sobre_objeto_interactivo(posicion_click: Vector2) -> bool:
	var parametros := PhysicsPointQueryParameters2D.new()
	parametros.position = posicion_click
	parametros.collide_with_areas = true
	parametros.collide_with_bodies = false

	var resultados: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(parametros)
	for resultado in resultados:
		var collider: Node = resultado.get("collider")
		if collider in objetos_interactivos:
			return true

	return false


func _aplicar_estilo_panel(panel: PanelContainer, color_fondo: Color, color_borde: Color) -> void:
	var estilo_actual: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var estilo: StyleBoxFlat
	if estilo_actual is StyleBoxFlat:
		estilo = estilo_actual.duplicate()
	else:
		estilo = StyleBoxFlat.new()

	estilo.bg_color = color_fondo
	estilo.border_color = color_borde
	panel.add_theme_stylebox_override("panel", estilo)


func _iniciar_temporizador() -> void:
	_temporizador_activo = true


func _detener_temporizador() -> void:
	_temporizador_activo = false


func _reiniciar_temporizador() -> void:
	_detener_temporizador()
	_tiempo_restante = DURACION_MINIJUEGO_SEGUNDOS
	_ultimo_segundo_mostrado = -1
	_actualizar_tiempo_label(true)


func _actualizar_temporizador(delta: float) -> void:
	_tiempo_restante = max(_tiempo_restante - delta, 0.0)
	_actualizar_tiempo_label()

	if _tiempo_restante <= 0.0:
		_terminar_minijuego_por_tiempo()


func _actualizar_tiempo_label(forzar: bool = false) -> void:
	var segundos_restantes: int = int(ceil(_tiempo_restante))
	if _tiempo_restante <= 0.0:
		segundos_restantes = 0

	if not forzar and segundos_restantes == _ultimo_segundo_mostrado:
		return

	_ultimo_segundo_mostrado = segundos_restantes
	tiempo_label.text = _formatear_tiempo(segundos_restantes)


func _formatear_tiempo(segundos_totales: int) -> String:
	var minutos: int = segundos_totales / 60
	var segundos: int = segundos_totales % 60
	return "%02d:%02d" % [minutos, segundos]


func _mostrar_overlay_final(titulo: String, resumen: String, color_estado: Color, mostrar_reiniciar: bool) -> void:
	overlay_confirmacion_salida.visible = false
	overlay_intro.visible = false
	titulo_final_label.text = titulo
	resumen_final_label.text = resumen
	boton_final_reiniciar.visible = mostrar_reiniciar
	_aplicar_estilo_panel(panel_final, COLOR_PANEL_BASE.lerp(color_estado, 0.12), COLOR_BORDE_BASE.lerp(color_estado, 0.4))
	overlay_final.visible = true


func _preparar_typing_intro() -> void:
	_intro_texto_completo = intro_label.text
	intro_label.visible_characters = 0
	_intro_typing_espera = 0.0
	_intro_ultimo_indice_pausa = -1
	_intro_typing_activo = not _intro_texto_completo.is_empty()

	if _intro_typing_activo:
		_iniciar_audio_intro()


func _actualizar_typing_intro(delta: float) -> void:
	if intro_label.visible_characters >= _intro_texto_completo.length():
		_detener_typing_intro(true)
		return

	if _intro_typing_espera > 0.0:
		_intro_typing_espera -= delta

	if _intro_typing_espera <= 0.0:
		_escribir_siguiente_caracter_intro(delta, _intro_typing_espera)


func _escribir_siguiente_caracter_intro(delta: float, segundos_necesarios: float) -> void:
	if intro_label.visible_characters >= _intro_texto_completo.length():
		_detener_typing_intro(true)
		return

	var pausa_actual: float = INTRO_TYPING_SECONDS_PER_PAUSE_STEP if _intro_debe_hacer_pausa() else 0.0
	if _intro_ultimo_indice_pausa != intro_label.visible_characters and pausa_actual > 0.0:
		_intro_ultimo_indice_pausa = intro_label.visible_characters
		_intro_typing_espera += pausa_actual
		return

	intro_label.visible_characters += 1
	segundos_necesarios += INTRO_TYPING_SECONDS_PER_STEP
	if segundos_necesarios > delta:
		_intro_typing_espera += segundos_necesarios
	else:
		_escribir_siguiente_caracter_intro(delta, segundos_necesarios)


func _intro_debe_hacer_pausa() -> bool:
	var indice_visible: int = intro_label.visible_characters
	if indice_visible == 0 or indice_visible >= _intro_texto_completo.length():
		return false

	if _intro_texto_completo[indice_visible] in INTRO_TYPING_SKIP_PAUSE_IF_FOLLOWED_BY.split():
		return false

	if indice_visible > 3 and _intro_texto_completo[indice_visible - 1] == ".":
		var posible_numero: String = _intro_texto_completo.substr(indice_visible - 2, 3)
		if str(float(posible_numero)).pad_decimals(1) == posible_numero:
			return false

	if "." in INTRO_TYPING_PAUSE_CHARACTERS and _intro_texto_completo[indice_visible - 1] == ".":
		for abreviatura in INTRO_TYPING_SKIP_PAUSE_ABBREVIATIONS:
			if indice_visible >= abreviatura.length():
				var caracteres_previos: String = _intro_texto_completo.substr(indice_visible - abreviatura.length() - 1, abreviatura.length())
				if caracteres_previos == abreviatura:
					return false

	var otros_caracteres_pausa: PackedStringArray = INTRO_TYPING_PAUSE_CHARACTERS.replace(".", "").split()
	if indice_visible > 1 and _intro_texto_completo[indice_visible - 1] in otros_caracteres_pausa and _intro_texto_completo[indice_visible] in otros_caracteres_pausa:
		return false

	return _intro_texto_completo[indice_visible - 1] in INTRO_TYPING_PAUSE_CHARACTERS.split()


func _iniciar_audio_intro() -> void:
	if audio_intro_typing.stream == null:
		return

	if audio_intro_typing.playing:
		audio_intro_typing.stop()
	audio_intro_typing.play()


func _detener_audio_intro() -> void:
	if audio_intro_typing.playing:
		audio_intro_typing.stop()


func _reanudar_audio_intro_si_aplica() -> void:
	if _intro_typing_activo:
		audio_intro_typing.play()


func _detener_typing_intro(mostrar_texto_completo: bool) -> void:
	_intro_typing_activo = false
	_intro_typing_espera = 0.0
	_detener_audio_intro()
	if mostrar_texto_completo:
		intro_label.visible_characters = -1
