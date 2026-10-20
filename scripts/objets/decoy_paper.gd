## Hoja señuelo de las celdas de la prisión.
##
## Hereda de [ItemPickup] para reutilizar el grupo [code]interactable[/code]
## y el aviso con la imagen de la tecla E. Se ve igual que una hoja de
## acertijo ([RiddlePaper]), pero solo muestra un mensaje corto, sin acertijo
## ni progreso: su única función es confundir al jugador.
## [br][br]A diferencia de [RiddlePaper], no desaparece al leerse: puede
## volver a leerse las veces que se quiera. El script del interior
## ([code]interior_celdas.gd[/code]) escucha [signal note_read] y muestra el
## texto en el [ScrollMessage].
## [br][br]Si no tiene un [Sprite2D] hijo, crea uno con
## [member icon_texture] para que pueda crearse solo por código.
class_name DecoyPaper
extends ItemPickup


## Se emite cada vez que el jugador lee la hoja.
## [param message_id] es la clave del mensaje en [code]data/messages.json[/code].
signal note_read(message_id: String)


## Clave del mensaje en [code]data/messages.json[/code] (por ejemplo,
## [code]celda_nota_1[/code]).
@export var message_id: String = ""

## Imagen de la hoja. Es la misma de las hojas de acertijo, para que el
## jugador no pueda distinguirlas a simple vista.
@export var icon_texture: Texture2D = preload("res://assets/sprites/ui/icons/icon_hoja.png")

## Posición de la imagen respecto al origen de la hoja. Coincide con la de
## [code]hoja.tscn[/code].
@export var icon_offset: Vector2 = Vector2(0, -8)


## Prepara el aviso de la tecla E (lo hace [ItemPickup]) y, si hace falta,
## crea la imagen de la hoja.
func _ready() -> void:
	super()
	if get_node_or_null("Sprite2D") == null and icon_texture != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = icon_texture
		sprite.position = icon_offset
		add_child(sprite)


## Lee la hoja. Lo invoca el [Player] al interactuar cerca.
## [br]No se marca como recogida ni se libera: la hoja se queda en la celda.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if message_id.is_empty():
		return
	note_read.emit(message_id)
