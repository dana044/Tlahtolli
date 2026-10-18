## Hoja de acertijo del Nivel 1 ("La Mulata de Córdoba").
##
## Hereda de [ItemPickup] para reutilizar el grupo [code]interactable[/code]
## y el aviso con la imagen de la tecla E. A diferencia de una hoja normal,
## no entrega nada al [Inventory]: al interactuar solo emite
## [signal paper_read] con el id del acertijo y desaparece. El nivel decide
## qué hacer (abrir el pergamino, contar la hoja, etc.).
## [br][br]Una hoja solo puede leerse una vez: tras interactuar se retira del
## grupo [code]interactable[/code] y se libera, así que no puede contarse ni
## repetirse por accidente.
class_name RiddlePaper
extends ItemPickup


## Se emite una sola vez, cuando el jugador lee la hoja.
## [param riddle_id] es el id del acertijo en [code]riddles.json[/code].
signal paper_read(riddle_id: String)


## Id del acertijo en [code]data/riddles.json[/code] (por ejemplo,
## [code]riddle_1[/code]). Se configura en el Inspector de cada hoja.
@export var riddle_id: String = ""


## Lee la hoja. Lo invoca el [Player] al interactuar cerca.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _collected or riddle_id.is_empty():
		return

	# Se marca primero para que ni el aviso ni una segunda pulsación de E
	# puedan volver a activarla.
	_collected = true
	remove_from_group("interactable")

	paper_read.emit(riddle_id)

	# La hoja ya fue leída: desaparece del suelo.
	queue_free()
