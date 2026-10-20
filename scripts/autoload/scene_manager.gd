## Gestor de transiciones de fundido.
##
## Crea por código una capa de interfaz con un rectángulo a pantalla completa
## y lo anima con un [Tween]. Al ser infraestructura global, no requiere una
## escena propia y funciona en cualquier nivel.
## [br][br]también gestiona las visitas a las celdas de la prisión
## ([method enter_cell] y [method exit_cell]): cambia de escena con fundido y
## deja en [GameState] los datos que necesita el destino (qué celda mostrar y
## adónde volver).
extends Node

## Color del fundido.
const FADE_COLOR: Color = Color.BLACK

## Capa de dibujo del fundido. Un valor alto lo mantiene sobre cualquier HUD.
const FADE_LAYER: int = 100

## escena de interior que contiene todas las celdas. Qué celda se
## muestra lo decide [method GameState.get_cell_id].
const CELL_INTERIOR_SCENE: String = "res://scenes/levels/interior_celdas.tscn"

## Capa de interfaz que contiene el rectángulo de fundido.
var _canvas_layer: CanvasLayer

## Rectángulo a pantalla completa que produce el fundido.
var _fade_rect: ColorRect

## Tween del fundido en curso. [code]null[/code] si no hay ninguno activo.
var _tween: Tween


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = FADE_LAYER
	add_child(_canvas_layer)

	_fade_rect = ColorRect.new()
	# Inicia transparente para no cubrir el juego al cargar.
	_fade_rect.color = Color(FADE_COLOR, 0.0)
	# El rectángulo cubre toda la pantalla; sin este filtro bloquearía los
	# clics destinados a la interfaz.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_fade_rect)


## Oscurece la pantalla hasta cubrirla por completo.
## Puede esperarse con [code]await[/code].
## [param duration] es la duración del fundido, en segundos.
func fade_out(duration: float) -> void:
	await _fade_to(1.0, duration)


## Aclara la pantalla hasta hacerla totalmente visible.
## Puede esperarse con [code]await[/code].
## [param duration] es la duración del fundido, en segundos.
func fade_in(duration: float) -> void:
	await _fade_to(0.0, duration)


## Anima la opacidad del rectángulo hacia [param target_alpha].
func _fade_to(target_alpha: float, duration: float) -> void:
	_kill_previous_tween()
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await _tween.finished


## Cancela el fundido en curso, si existe, para que nunca compitan dos a la
## vez. Prevalece el último solicitado.
func _kill_previous_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null


## entra a la celda [param cell_id] desde la escena actual.
## Guarda en [GameState] la celda y el punto de regreso, funde a negro y
## carga [constant CELL_INTERIOR_SCENE]. Puede esperarse con [code]await[/code].
## [br]El interior debe llamar a [method fade_in] al iniciar, o la pantalla
## quedará negra.
## [br]Devuelve [constant OK] si el cambio se inició; si falla, la pantalla se
## aclara de nuevo y devuelve el error, para que quien llama devuelva el
## control al jugador.
## [param cell_id] es el número de la celda (el de su nodo [code]celda_N[/code]).
## [param from_scene] es la ruta de la escena a la que se volverá al salir.
## [param return_position] es la posición global donde reaparece el jugador.
## [param fade_time] es la duración del fundido, en segundos; con cero o menos
## el corte es directo.
func enter_cell(cell_id: int, from_scene: String, return_position: Vector2,
		fade_time: float = 0.4) -> Error:
	GameState.begin_cell_visit(cell_id, from_scene, return_position)
	return await _change_scene(CELL_INTERIOR_SCENE, fade_time)


## sale de la celda y regresa a la escena guardada por
## [method enter_cell]. Marca el regreso en [GameState] para que esa escena
## coloque al jugador frente a la puerta, y funde a negro antes de cambiar.
## Puede esperarse con [code]await[/code].
## [br]La escena de destino debe llamar a [method fade_in] al iniciar.
## [br]Devuelve [constant OK] si el cambio se inició, o el error si no se pudo
## (por ejemplo [constant ERR_UNCONFIGURED] si no hay escena de regreso
## guardada, como al probar el interior directamente con F6).
## [param fade_time] es la duración del fundido, en segundos.
func exit_cell(fade_time: float = 0.4) -> Error:
	var target: String = GameState.get_cell_return_scene()
	if target.is_empty():
		push_error("SceneManager: no hay escena de regreso guardada para salir de la celda.")
		return ERR_UNCONFIGURED
	GameState.mark_returning_from_cell()
	return await _change_scene(target, fade_time)


## funde a negro (si [param fade_time] es mayor que cero) y cambia a la
## escena [param path]. Si el cambio falla, aclara la pantalla otra vez.
## Devuelve el resultado de [method SceneTree.change_scene_to_file].
func _change_scene(path: String, fade_time: float) -> Error:
	if fade_time > 0.0:
		await fade_out(fade_time)

	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: no se pudo cargar " + path)
		if fade_time > 0.0:
			# Sin await: la pantalla se aclara mientras el llamador recupera el control.
			fade_in(fade_time)
	return error
