## Estado global que persiste entre escenas.
##
## Por ahora solo almacena el checkpoint del jugador. Es deliberadamente
## mínimo y no contiene lógica de juego: los niveles deciden cuándo guardar
## y cuándo leer. Puede ampliarse más adelante con inventario y progreso.
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
