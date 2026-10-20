## Puerta de una celda, vista desde el exterior de la prisión.
##
## Se registra en el grupo [code]interactable[/code], que es el que consulta
## [method Player._try_interact]. Al pulsar la tecla E cerca de ella, el
## jugador entra a la celda [member celda_id]: el [SceneManager] guarda el
## punto de regreso en [GameState], funde a negro y carga el interior, que
## contiene todas las celdas en una sola escena.
## [br][br]Va como script raíz de [code]celda_externa_abierta.tscn[/code]. El
## [member celda_id] se ajusta en el Inspector de cada instancia dentro del
## nivel. Las puertas cerradas ([code]celda_externa_cerrada.tscn[/code]) no
## llevan este script, así que no se pueden abrir.
## [br][br]El aviso de la tecla E lo muestra el nodo hijo [InteractPrompt].
class_name CeldaPuerta
extends CharacterBody2D


## Número de la celda a la que lleva esta puerta. Debe coincidir con el
## sufijo del nodo [code]celda_N[/code] de [code]celda.tscn[/code]
## (1 a 8). Cada puerta debe tener un número distinto.
@export_range(1, 8) var celda_id: int = 1

## Duración, en segundos, del fundido a negro al entrar. Con cero el corte
## es directo.
@export var fade_time: float = 0.4


## Evita iniciar la entrada dos veces (por ejemplo, con E pulsada de nuevo
## durante el fundido).
var _entering: bool = false


## Registra la puerta como interactuable.
func _ready() -> void:
	add_to_group("interactable")
	if has_node("InteractPrompt"):
		$InteractPrompt.scale = Vector2(0.5, 0.5)

## Entra a la celda. Lo invoca el [Player] al interactuar cerca.
## [br]El jugador reaparecerá al volver exactamente donde está ahora, que es
## un lugar libre frente a la puerta.
## [param by] es el nodo que interactúa (el [Player]).
func interact(by: Node2D) -> void:
	if _entering:
		return
	_entering = true

	# El jugador no debe moverse durante el fundido.
	var player: Player = by as Player
	if player != null:
		player.can_move = false

	var scene_path: String = get_tree().current_scene.scene_file_path
	var error: Error = await SceneManager.enter_cell(
			celda_id, scene_path, by.global_position, fade_time)

	# Si el cambio de escena falló, se devuelve el control para no dejar
	# bloqueado al jugador. Con éxito esta escena se libera sola.
	if error != OK:
		if player != null:
			player.can_move = true
		_entering = false
