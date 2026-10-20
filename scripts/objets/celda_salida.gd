## Puerta por la que el jugador sale de una celda y regresa al exterior.
##
## Es un nodo interactuable (grupo [code]interactable[/code]): al pulsar la
## tecla E cerca de ella llama a [method SceneManager.exit_cell]. El script
## del interior ([code]interior_celdas.gd[/code]) la coloca junto a la entrada
## de la celda activa. El aviso de la tecla E lo muestra el nodo hijo
## [InteractPrompt].
class_name CeldaSalida
extends Node2D


## Duración, en segundos, del fundido a negro al salir. Con cero el corte
## es directo.
@export var fade_time: float = 0.4

## Si es [code]true[/code], dibuja un rectángulo provisional que marca la
## puerta. Desactívalo cuando la puerta tenga su propio sprite.
@export var draw_placeholder: bool = true

## Color del rectángulo provisional.
@export var placeholder_color: Color = Color(0.35, 0.22, 0.12)


## Evita iniciar la salida dos veces durante el fundido.
var _leaving: bool = false


## Registra la puerta como interactuable.
func _ready() -> void:
	add_to_group("interactable")


## Dibuja el marcador provisional de la puerta: el origen del nodo queda en
## el centro de su borde inferior, como en las puertas del exterior.
func _draw() -> void:
	if draw_placeholder:
		draw_rect(Rect2(-16.0, -28.0, 32.0, 28.0), placeholder_color)


## Sale de la celda. Lo invoca el [Player] al interactuar cerca.
## [param by] es el nodo que interactúa (el [Player]).
func interact(by: Node2D) -> void:
	if _leaving:
		return
	_leaving = true

	# El jugador no debe moverse durante el fundido.
	var player: Player = by as Player
	if player != null:
		player.can_move = false

	var error: Error = await SceneManager.exit_cell(fade_time)

	# Si no se pudo salir, se devuelve el control al jugador.
	if error != OK:
		if player != null:
			player.can_move = true
		_leaving = false
