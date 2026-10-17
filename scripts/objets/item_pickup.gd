## Objeto del mundo que el jugador recoge con la acción [code]interact[/code].
##
## Al interactuar, agrega [member item_id] al [Inventory] y desaparece de la
## escena. Se registra en el grupo [code]interactable[/code], que es el que
## consulta [method Player._try_interact]. Es genérico: sirve para la muñeca y
## para cualquier objeto futuro (flor, mandarina, moneda...) con solo cambiar
## el id en el Inspector.
class_name ItemPickup
extends Node2D


## Se emite justo después de agregar el objeto al inventario.
## [param item_id] es el id del objeto recogido.
signal picked_up(item_id: String)


## Id del objeto en [code]data/items.json[/code] (por ejemplo, [code]muneca[/code]).
@export var item_id: String = ""

## Evita recoger el objeto dos veces en el mismo fotograma.
var _collected: bool = false


## Registra el objeto como interactuable.
func _ready() -> void:
	add_to_group("interactable")


## Recoge el objeto. Lo invoca el [Player] al interactuar cerca.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _collected or item_id.is_empty():
		return
	_collected = true
	remove_from_group("interactable")

	Inventory.add_item(item_id)
	picked_up.emit(item_id)

	# Desaparece de la pantalla; ahora vive en el inventario.
	queue_free()
