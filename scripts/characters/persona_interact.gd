## Interacción de un habitante del pueblo (Persona1 … Persona8).
##
## Es un nodo que se añade como hijo de cada persona (el nivel lo hace por
## código), de modo que no hay que modificar las escenas de las personas. Se
## registra en el grupo [code]interactable[/code] (el que consulta
## [method Player._try_interact]) solo mientras está activo, muestra la tecla E
## cuando el jugador está cerca y emite [signal interacted]. No conoce los
## diálogos: el nivel decide qué dice cada persona (mismo patrón que [Abuela]).
## [br][br]Ruta sugerida: [code]res://scripts/characters/persona_interact.gd[/code].
class_name PersonaInteract
extends Node2D


## Se emite cuando el jugador interactúa con la persona.
## [param persona_id] es el número de la persona (1 a 8).
signal interacted(persona_id: int)


## Número de la persona (1 a 8). Lo asigna el nivel y sirve para elegir su
## diálogo.
@export var persona_id: int = 0

## Si es [code]true[/code], muestra la tecla E sobre la persona cuando el
## jugador está cerca. Desactívalo si la escena de la persona ya trae la suya.
@export var show_prompt: bool = true

## Posición de la tecla E respecto a la persona, en píxeles.
@export var prompt_offset: Vector2 = Vector2(0, -37)

## Escala de la tecla E.
@export var prompt_scale: Vector2 = Vector2(0.5, 0.5)

## Distancia máxima al jugador, en píxeles, para que aparezca la tecla E.
## Debe coincidir con [member Player.interact_range].
@export var prompt_distance: float = 56.0


## Tecla E sobre la persona. Es [code]null[/code] si [member show_prompt] es
## [code]false[/code].
var _prompt: InteractPrompt


## Compensa la escala de la persona para que la tecla E mantenga su tamaño, crea
## la tecla E y deja la interacción apagada hasta [method set_active].
func _ready() -> void:
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d != null and not is_zero_approx(parent_2d.scale.x) and not is_zero_approx(parent_2d.scale.y):
		scale = Vector2(1.0 / parent_2d.scale.x, 1.0 / parent_2d.scale.y)

	if show_prompt:
		_prompt = InteractPrompt.new()
		_prompt.name = "PromptE"
		_prompt.prompt_offset = prompt_offset
		_prompt.prompt_scale = prompt_scale
		_prompt.prompt_distance = prompt_distance
		add_child(_prompt)

	set_active(false)


## Activa o desactiva la interacción con la persona. Desactivada, el jugador no
## puede hablar con ella y no aparece la tecla E.
## [param active] es [code]true[/code] para poder hablar con ella.
func set_active(active: bool) -> void:
	if active:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")


## Punto de entrada de la interacción: lo invoca el [Player] cuando el jugador
## presiona [code]interact[/code] estando cerca. Emite [signal interacted].
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	interacted.emit(persona_id)
