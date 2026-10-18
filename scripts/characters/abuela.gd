## Abuelita del pueblo: personaje con el que se puede hablar.
##
## No conoce los diálogos ni lo que ocurre después de hablar con ella: solo se
## registra como interactuable y avisa con [signal interacted] cuando el
## jugador pulsa la tecla de interactuar estando cerca. El nivel decide qué
## diálogos se reproducen y qué se desbloquea (mismo patrón que [Llorona]).
## [br][br]Ruta sugerida: [code]res://scripts/characters/abuela.gd[/code].
class_name Abuela
extends CharacterBody2D


## Se emite cuando el jugador interactúa con la abuelita. A diferencia de la
## Llorona, no depende de ningún estado: puede emitirse todas las veces que
## se quiera, de modo que la conversación se pueda repetir.
signal interacted


## Registra a la abuelita en el grupo [code]interactable[/code], que es el que
## recorre el [Player] para saber con qué puede interactuar.
func _ready() -> void:
	add_to_group("interactable")


## Punto de entrada de la interacción: lo invoca el [Player] cuando el jugador
## presiona [code]interact[/code] estando dentro de su
## [member Player.interact_range]. Emite [signal interacted].
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	interacted.emit()
