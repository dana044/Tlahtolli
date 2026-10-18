## La Mulata de Córdoba, personaje con el que se puede hablar.
##
## Hereda de [ItemPickup] solo para reutilizar el grupo
## [code]interactable[/code] (el que consulta [method Player._try_interact]) y
## el aviso con la imagen de la tecla E. No se "recoge": al interactuar solo
## emite [signal interacted] y el nivel decide qué diálogo reproducir.
class_name Mulata
extends ItemPickup


## Se emite cada vez que el jugador interactúa con la Mulata.
signal interacted


## Lo invoca el [Player] al presionar E cerca. Avisa al nivel.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _collected:
		return
	interacted.emit()


## Hace desaparecer a la Mulata (final de la leyenda): deja de ser
## interactuable, oculta su aviso y se desvanece. Puede esperarse con
## [code]await[/code].
## [param duration] es la duración del desvanecimiento, en segundos; con un
## valor menor o igual a cero desaparece al instante (por ejemplo, al recargar
## un nivel ya completado).
func fade_away(duration: float = 1.0) -> void:
	# _collected oculta el aviso de la tecla (ver ItemPickup._process).
	_collected = true
	remove_from_group("interactable")

	if duration <= 0.0:
		hide()
		return

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	hide()
