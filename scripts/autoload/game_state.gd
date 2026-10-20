## Estado global que persiste entre escenas.
##
## Por ahora solo almacena el checkpoint del jugador. Es deliberadamente
## mínimo y no contiene lógica de juego: los niveles deciden cuándo guardar
## y cuándo leer. Puede ampliarse más adelante con inventario y progreso.
## [br][br]también guarda los datos de la visita a una celda (cuál
## celda mostrar y a dónde volver), porque las variables de una escena se
## pierden al cambiar de escena.
extends Node

## Última posición segura guardada, en coordenadas globales.
## [constant Vector2.ZERO] indica que aún no se ha guardado ninguna.
var _checkpoint: Vector2 = Vector2.ZERO


## Guarda [param pos] como posición de respawn.
## Debe invocarse desde el nivel al iniciar y al cruzar zonas seguras.
func set_checkpoint(pos: Vector2) -> void:
	_checkpoint = pos


## Devuelve la posición del checkpoint guardado.
## Un nivel debe haber invocado [method set_checkpoint] antes de leerlo.
func get_checkpoint() -> Vector2:
	return _checkpoint


## Banderas de progreso de la partida (misiones completadas, eventos vistos).
## Clave: nombre de la bandera; valor: [code]true[/code]/[code]false[/code].
var _flags: Dictionary = {}


## Marca la bandera [param flag_name] con [param value].
## Ejemplo: [code]GameState.set_flag("llorona_en_paz")[/code].
func set_flag(flag_name: String, value: bool = true) -> void:
	_flags[flag_name] = value


## Indica si la bandera [param flag_name] está activa.
## Una bandera que nunca se marcó se considera [code]false[/code].
func has_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)


## número de la celda que debe mostrar el interior. Cero indica que
## no se ha entrado a ninguna.
var _cell_id: int = 0

## ruta de la escena a la que se vuelve al salir de la celda.
var _cell_return_scene: String = ""

## posición global donde reaparece el jugador al volver, en la escena
## de regreso.
var _cell_return_position: Vector2 = Vector2.ZERO

## [code]true[/code] desde que el jugador sale de la celda hasta que la
## escena de regreso consume el dato con [method clear_cell_visit].
var _returning_from_cell: bool = false


## registra que el jugador va a entrar a la celda [param cell_id].
## [param return_scene] es la escena a la que volverá y [param return_pos] la
## posición global donde debe reaparecer. Lo invoca
## [method SceneManager.enter_cell].
func begin_cell_visit(cell_id: int, return_scene: String, return_pos: Vector2) -> void:
	_cell_id = cell_id
	_cell_return_scene = return_scene
	_cell_return_position = return_pos
	_returning_from_cell = false


## devuelve el número de la celda que debe mostrar el interior.
func get_cell_id() -> int:
	return _cell_id


## devuelve la ruta de la escena a la que se vuelve al salir de la
## celda. Es una cadena vacía si no hay visita registrada.
func get_cell_return_scene() -> String:
	return _cell_return_scene


## marca que el jugador está saliendo de la celda. Lo invoca
## [method SceneManager.exit_cell] justo antes de cambiar de escena.
func mark_returning_from_cell() -> void:
	_returning_from_cell = true


## indica si la escena actual acaba de cargarse porque el jugador salió
## de una celda. El nivel lo consulta en [code]_ready[/code] para colocar al
## jugador frente a la puerta en vez de en el punto de inicio.
func is_returning_from_cell() -> bool:
	return _returning_from_cell


## devuelve la posición global donde debe reaparecer el jugador al
## volver de la celda. Solo es válida si [method is_returning_from_cell] es
## [code]true[/code].
func get_cell_return_position() -> Vector2:
	return _cell_return_position


## da por terminada la visita a la celda y olvida sus datos. La escena
## de regreso debe invocarlo después de leer la posición de regreso.
func clear_cell_visit() -> void:
	_cell_id = 0
	_cell_return_scene = ""
	_cell_return_position = Vector2.ZERO
	_returning_from_cell = false
