## La Mulata de Córdoba, personaje con el que se puede hablar.
##
## Hereda de [ItemPickup] solo para reutilizar el grupo
## [code]interactable[/code] (el que consulta [method Player._try_interact]) y
## el aviso con la imagen de la tecla E. No se "recoge": al interactuar solo
## emite [signal interacted] y el nivel decide qué diálogo reproducir.
## [br][br]NUEVO: además puede acompañar al jugador. Con [method start_following]
## recorre el mismo camino que él (como los compañeros de Pokémon), a una
## distancia fija y con su sprite de ocho direcciones. Atraviesa al jugador y
## cualquier obstáculo: se mueve por posición, sin física. Con
## [method walk_to] puede ir a un punto concreto (el final del nivel).
## [br]Sigue siendo interactuable con E mientras acompaña. Como siempre está
## cerca, [method interact] cede el turno a cualquier otro objeto interactuable
## (por ejemplo, una hoja) que esté al alcance del jugador.
class_name Mulata
extends ItemPickup


## Se emite cada vez que el jugador interactúa con la Mulata.
signal interacted

## NUEVO: se emite cuando la Mulata llega al destino de [method walk_to].
signal arrived


## NUEVO: separación, en píxeles, entre dos puntos consecutivos del rastro
## que deja el jugador. Valores bajos siguen el camino con más fidelidad.
const TRAIL_STEP: float = 3.0

## NUEVO: máximo de puntos del rastro. Evita que crezca sin límite si la
## Mulata se queda atrás por mucho tiempo.
const MAX_TRAIL_POINTS: int = 1024

## NUEVO: distancia, en píxeles, a la que [method walk_to] da por llegada a
## la Mulata. Es mayor que cero para no depender de la precisión decimal.
const ARRIVAL_DISTANCE: float = 1.0


@export_group("Seguimiento")

## NUEVO: distancia, medida a lo largo del camino recorrido, que la Mulata
## mantiene detrás del jugador, en píxeles.
@export var follow_distance: float = 28.0

## NUEVO: velocidad de la Mulata, en píxeles por segundo. Debe ser algo mayor
## que [member Player.speed] (140) para que pueda alcanzar al jugador.
@export var follow_speed: float = 150.0

## NUEVO: si la Mulata queda más lejos que esto (por ejemplo, tras una
## pausa), acelera para alcanzar al jugador. En píxeles de camino.
@export var catch_up_distance: float = 64.0

## NUEVO: multiplicador de [member follow_speed] mientras alcanza al jugador.
@export var catch_up_multiplier: float = 1.6


## NUEVO: nodo al que sigue (el jugador). [code]null[/code] si no sigue a nadie.
var _target: Node2D

## NUEVO: camino recorrido por el jugador que la Mulata aún no ha pisado, del
## punto más antiguo al más reciente.
var _trail: Array[Vector2] = []

## NUEVO: último punto del jugador guardado en [member _trail].
var _last_recorded: Vector2 = Vector2.ZERO

## NUEVO: indica si está siguiendo al jugador.
var _following: bool = false

## NUEVO: indica si camina hacia [member _walk_target] (ver [method walk_to]).
var _walking: bool = false

## NUEVO: destino, en coordenadas globales, de la caminata de [method walk_to].
var _walk_target: Vector2 = Vector2.ZERO

## NUEVO: sufijo de la dirección hacia la que mira (e, se, s, sw, w, nw, n, ne).
var _facing: String = "s"

## NUEVO: sprite animado con las ocho direcciones ([code]walk_<dirección>[/code]).
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


## NUEVO: prepara a la Mulata como compañera: desactiva sus colisiones para
## que atraviese al jugador y los muros.
## [br]Las colisiones se ponen con [method Object.set] porque este script
## hereda de [ItemPickup] (un [Node2D]), pero el nodo de la escena es un
## [CharacterBody2D] y esas propiedades existen en él.
## [br]Como camina pegada al jugador, el aviso de la tecla E queda casi
## siempre visible; si estorba, desactiva [code]Show Prompt[/code] en el
## Inspector.
func _ready() -> void:
	super()
	set(&"collision_layer", 0)
	set(&"collision_mask", 0)


## Lo invoca el [Player] al presionar E cerca. Avisa al nivel.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _collected:
		return

	# NUEVO: la Mulata siempre está cerca del jugador, así que sería la más
	# cercana y le ganaría a las hojas. Si hay otro objeto al alcance, la
	# interacción se le cede a ese objeto.
	var other: Node2D = _find_other_interactable(_by)
	if other != null:
		other.call("interact", _by)
		return

	interacted.emit()


## NUEVO: busca el objeto interactuable más cercano al jugador, distinto de la
## Mulata, que esté dentro de su alcance. Aplica el mismo criterio que
## [method Player._try_interact]: nodos visibles del grupo
## [code]interactable[/code] con el método [code]interact[/code].
## Devuelve [code]null[/code] si no hay ninguno.
## [param by] es el nodo que interactúa (el jugador).
func _find_other_interactable(by: Node2D) -> Node2D:
	# Alcance del jugador; 56 es su valor por defecto si no lo expone.
	var reach: float = 56.0
	var configured: Variant = by.get("interact_range")
	if configured != null:
		reach = float(configured)

	var closest: Node2D = null
	var closest_distance: float = reach
	for node in get_tree().get_nodes_in_group("interactable"):
		var candidate: Node2D = node as Node2D
		if candidate == null or candidate == self or not candidate.is_visible_in_tree():
			continue
		if not candidate.has_method("interact"):
			continue
		var distance: float = by.global_position.distance_to(candidate.global_position)
		if distance <= closest_distance:
			closest = candidate
			closest_distance = distance
	return closest


## NUEVO: la Mulata empieza a acompañar al jugador. Se coloca justo detrás de
## él y conserva la interacción con E.
## [param target] es el nodo al que seguirá (el jugador).
func start_following(target: Node2D) -> void:
	_target = target
	_walking = false
	_following = true

	# Parte detrás del jugador y con el rastro sembrado en su posición actual.
	global_position = target.global_position + Vector2(-follow_distance, 0.0)
	_trail.clear()
	_trail.append(target.global_position)
	_last_recorded = target.global_position
	_update_facing(Vector2.RIGHT)


## NUEVO: la Mulata deja de seguir al jugador y olvida el rastro.
func stop_following() -> void:
	_following = false
	_trail.clear()


## NUEVO: la Mulata camina en línea recta hasta [param destination], sin
## colisiones y dejando de seguir al jugador. Puede esperarse con
## [code]await[/code]: termina al llegar (ver [signal arrived]).
## [param destination] es el destino en coordenadas globales.
func walk_to(destination: Vector2) -> void:
	stop_following()
	_walk_target = destination
	_walking = true
	await arrived


## NUEVO: mueve a la Mulata en cada paso de física, siguiendo al jugador o
## caminando a su destino. Con el juego en pausa (diálogos) no se ejecuta.
## [param delta] es el tiempo transcurrido desde el paso anterior, en segundos.
func _physics_process(delta: float) -> void:
	if _walking:
		_step_walk(delta)
	elif _following and is_instance_valid(_target):
		_step_follow(delta)


## NUEVO: un paso de seguimiento. Guarda el camino del jugador y recorre ese
## mismo camino hasta quedar a [member follow_distance] de él; si ya está a
## esa distancia, se queda quieta.
## [param delta] es el tiempo del paso de física, en segundos.
func _step_follow(delta: float) -> void:
	# 1. Se guarda el rastro del jugador cada TRAIL_STEP píxeles.
	var player_pos: Vector2 = _target.global_position
	if player_pos.distance_to(_last_recorded) >= TRAIL_STEP:
		_trail.append(player_pos)
		_last_recorded = player_pos
		if _trail.size() > MAX_TRAIL_POINTS:
			_trail.pop_front()

	# 2. Camino que le sobra respecto a la distancia que debe mantener.
	var remaining: float = _remaining_path()
	var excess: float = remaining - follow_distance
	if excess <= 0.0:
		return

	var speed: float = follow_speed
	if remaining > catch_up_distance:
		speed *= catch_up_multiplier
	# Nunca avanza más que el sobrante: así no se pasa de la distancia ideal.
	var budget: float = minf(speed * delta, excess)

	# 3. Avanza por el rastro, punto por punto, aprovechando todo el paso.
	var start_pos: Vector2 = global_position
	while budget > 0.0 and not _trail.is_empty():
		var point: Vector2 = _trail[0]
		var distance: float = global_position.distance_to(point)
		if distance <= budget:
			global_position = point
			budget -= distance
			_trail.pop_front()
		else:
			global_position = global_position.move_toward(point, budget)
			budget = 0.0

	# 4. Mira hacia donde se movió en este paso.
	var moved: Vector2 = global_position - start_pos
	if moved.length_squared() > 0.0001:
		_update_facing(moved)


## NUEVO: un paso de la caminata de [method walk_to]. Al llegar, emite
## [signal arrived].
## [param delta] es el tiempo del paso de física, en segundos.
func _step_walk(delta: float) -> void:
	var to_target: Vector2 = _walk_target - global_position
	var step: float = follow_speed * delta
	if to_target.length() <= maxf(step, ARRIVAL_DISTANCE):
		global_position = _walk_target
		_walking = false
		arrived.emit()
		return

	_update_facing(to_target)
	global_position += to_target.normalized() * step


## NUEVO: longitud del camino que separa a la Mulata del último punto del
## rastro: de su posición al primer punto pendiente y de ahí al más reciente.
## Devuelve [code]0.0[/code] si no hay rastro.
func _remaining_path() -> float:
	if _trail.is_empty():
		return 0.0
	var length: float = global_position.distance_to(_trail[0])
	for i in range(_trail.size() - 1):
		length += _trail[i].distance_to(_trail[i + 1])
	return length


## NUEVO: orienta el sprite hacia [param direction] usando las ocho
## animaciones [code]walk_<dirección>[/code]. Usa los mismos sufijos y el
## mismo redondeo a sectores de 45° que el [Player].
## [param direction] es el vector de movimiento (no hace falta normalizarlo).
func _update_facing(direction: Vector2) -> void:
	var index: int = roundi(direction.angle() / (PI / 4.0))
	_facing = Player.DIRECTION_NAMES[posmod(index, 8)]

	var animation_name: String = "walk_" + _facing
	if _sprite.sprite_frames.has_animation(animation_name) and _sprite.animation != animation_name:
		_sprite.play(animation_name)


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
	# NUEVO: una vez desvanecida ya no debe seguir al jugador ni moverse.
	stop_following()

	if duration <= 0.0:
		hide()
		return

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	hide()
