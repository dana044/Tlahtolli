## Controlador de movimiento del jugador.
##
## Implementa desplazamiento top-down en ocho direcciones con aceleración y
## fricción configurables, animación direccional (norte, sur, este, oeste y
## diagonales), una cámara de seguimiento con suavizado y una linterna
## opcional. Admite limitar el área de movimiento y de visión a los bordes
## del mapa.
##
## Se espera una animación por cada una de las ocho direcciones, con estos
## nombres (sufijos: [code]e, se, s, sw, w, nw, n, ne[/code]):
## [br]- [code]walk_<dirección>[/code]: caminando (por ejemplo [code]walk_ne[/code]).
## [br]- [code]idle_<dirección>[/code]: quieto (opcional; si no existe, se
## congela la animación de caminar en su fotograma actual).
class_name Player
extends CharacterBody2D


## Se emite cuando una caminata automática iniciada con [method walk_to]
## llega a su destino.
signal auto_walk_finished


## Sufijos de dirección, ordenados por ángulo a partir del este y en sentido
## horario (el eje Y de Godot crece hacia abajo).
const DIRECTION_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Magnitud de entrada por debajo de la cual no se considera movimiento.
## Evita el parpadeo entre animaciones con entradas casi nulas del gamepad.
const DIRECTION_DEADZONE: float = 0.2

## Fracción mínima del radio de la linterna cuando se atenúa. Evita que
## [member PointLight2D.texture_scale] llegue a cero; la luz se anula con la
## energía, no con el tamaño.
const LANTERN_MIN_SCALE_FACTOR: float = 0.05

## Distancia, en píxeles, al destino a partir de la cual una caminata
## automática ([method walk_to]) se da por terminada. Debe ser mayor que lo
## que avanza el personaje en un paso de física para no pasarse de largo.
const AUTO_WALK_ARRIVAL: float = 4.0


#region Movimiento

## Velocidad máxima de desplazamiento, en píxeles por segundo.
## Rango habitual en juegos top-down: 120–160.
@export var speed: float = 140.0

## Tasa de aceleración hacia la velocidad máxima, en píxeles por segundo².
## Valores altos producen un arranque más inmediato.
@export var acceleration: float = 1400.0

## Tasa de desaceleración al no existir entrada, en píxeles por segundo².
## Valores altos producen una detención más abrupta.
@export var friction: float = 1400.0

## Indica si el jugador responde al input.
## Cuando es [code]false[/code] (capturas, cinemáticas), se ignora la entrada
## y el personaje se detiene aplicando la fricción. Normalmente lo controla
## el nivel o el GameManager, no el Inspector.
@export var can_move: bool = true

#endregion


#region Cámara

## Habilita el suavizado de posición de la cámara.
## Si está desactivado, la cámara se mantiene fija respecto al jugador.
@export var camera_smoothing_enabled: bool = true:
	set(value):
		camera_smoothing_enabled = value
		if camera:
			camera.position_smoothing_enabled = value

## Velocidad con la que la cámara alcanza la posición del jugador.
## Valores altos reducen el retardo de seguimiento.
@export_range(1.0, 20.0, 0.5) var camera_smoothing_speed: float = 5.0:
	set(value):
		camera_smoothing_speed = value
		if camera:
			camera.position_smoothing_speed = value

#endregion


#region Interacción

## Distancia máxima, en píxeles, a la que el jugador puede interactuar con un
## nodo del grupo [code]interactable[/code] (objetos recogibles, personajes
## con los que se puede hablar, etc.). Se mide desde el origen del jugador
## hasta el origen del objeto.
@export var interact_range: float = 56.0

#endregion


#region Límites del mapa

## Distancia, en píxeles, que el jugador se mantiene alejado del borde
## izquierdo y derecho del mapa. Evita que el sprite asome fuera de la
## pantalla (la cámara sí llega hasta el borde exacto).
@export var edge_margin_sides: float = 10.0

## Distancia mínima al borde superior del mapa, en píxeles. Es mayor porque
## el origen del personaje está en los pies y el sprite crece hacia arriba.
@export var edge_margin_top: float = 30.0

## Distancia mínima al borde inferior del mapa, en píxeles.
@export var edge_margin_bottom: float = 4.0

#endregion


## Nodo [AnimatedSprite2D] que representa visualmente al personaje.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Nodo [Camera2D] de seguimiento.
@onready var camera: Camera2D = $Camera2D

## Luz de la linterna. Es [code]null[/code] si la escena no incluye el nodo
## [code]LanternLight[/code].
@onready var lantern: PointLight2D = get_node_or_null("LanternLight")

## Radio original de la linterna ([member PointLight2D.texture_scale]),
## guardado en [method _ready]. Es la referencia del factor de intensidad.
var _lantern_base_scale: float = 1.0

## Energía original de la linterna ([member PointLight2D.energy]), guardada
## en [method _ready]. Es la referencia del factor de intensidad.
var _lantern_base_energy: float = 1.0

## Tween de atenuación de la linterna en curso. Se cancela si llega otro.
var _lantern_tween: Tween

## Región del mundo a la que se restringen el jugador y la cámara, en
## coordenadas globales. Un área nula indica que no hay restricción.
var _world_bounds: Rect2 = Rect2()

## Sufijo de la dirección hacia la que se orientó el personaje por última
## vez. Se conserva al detenerse para mostrar la animación de reposo
## correspondiente.
var _facing: String = "s"

## Indica si el personaje camina solo hacia [member _auto_target] (por
## ejemplo, al entrar a un nivel). Mientras es [code]true[/code] se ignora el
## input del jugador.
var _auto_walking: bool = false

## Destino, en coordenadas globales, de la caminata automática en curso.
var _auto_target: Vector2 = Vector2.ZERO

## Zona del borde del mapa donde NO se aplica el límite de
## [member _world_bounds], en coordenadas globales. Permite que el personaje salga
## (o entre) del mapa por un hueco concreto, por ejemplo la salida hacia otro
## nivel. Un área nula indica que no hay ninguna zona de paso.
var _edge_gap: Rect2 = Rect2()


## Registra al jugador en el grupo [code]player[/code], sincroniza los valores
## exportados con los nodos hijos y configura el modo de movimiento.
## La sincronización es necesaria porque los setters de las propiedades
## exportadas se ejecutan antes de que [member camera] esté disponible.
func _ready() -> void:
	# Otros nodos (como la Llorona) localizan al jugador mediante este grupo.
	add_to_group("player")

	# El modo flotante es el adecuado para vista top-down: no existe suelo ni
	# gravedad. El modo por defecto (grounded) está pensado para plataformas.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	camera.position_smoothing_enabled = camera_smoothing_enabled
	camera.position_smoothing_speed = camera_smoothing_speed

	# Se recuerdan los valores de la linterna tal como se diseñaron en la
	# escena, para poder atenuarla y restaurarla después.
	if lantern:
		_lantern_base_scale = lantern.texture_scale
		_lantern_base_energy = lantern.energy


## Actualiza el movimiento del personaje en cada paso de física.
## [param delta] corresponde al tiempo transcurrido desde el paso anterior,
## en segundos.
func _physics_process(delta: float) -> void:
	# Sin permiso de movimiento la dirección es cero, por lo que la fricción
	# detiene al personaje de forma gradual en lugar de congelarlo de golpe.
	var direction: Vector2 = Vector2.ZERO
	if _auto_walking:
		# La caminata automática tiene prioridad sobre el input: el personaje
		# avanza hacia su destino sin importar el valor de can_move.
		direction = _auto_walk_direction()
	elif can_move:
		# El vector devuelto está normalizado, por lo que el movimiento
		# diagonal no excede la velocidad máxima. Aplica además la zona
		# muerta del gamepad.
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Se aplica aceleración cuando existe entrada y fricción cuando no.
	var moving: bool = direction.length() > DIRECTION_DEADZONE
	var rate: float = acceleration if moving else friction
	velocity = velocity.move_toward(direction * speed, rate * delta)

	move_and_slide()

	# Impide que el jugador salga del mapa. La posición es la del centro del
	# personaje, por lo que en el borde puede asomar la mitad del sprite.
	if _world_bounds.has_area():
		# Se reduce el área con los márgenes para que el sprite completo
		# quede dentro de lo que muestra la cámara.
		var walkable: Rect2 = _world_bounds.grow_individual(
				-edge_margin_sides, -edge_margin_top, -edge_margin_sides, -edge_margin_bottom)
		# Dentro de la zona de paso del borde no se recorta la posición, de modo
		# que el personaje pueda cruzar el límite del mapa (ver set_edge_gap).
		if not _edge_gap.has_point(global_position):
			global_position = global_position.clamp(walkable.position, walkable.end)

	_update_animation(direction, moving)

	if can_move and Input.is_action_just_pressed("interact"):
		_try_interact()


## Selecciona la animación según la dirección de entrada.
## La dirección se redondea al sector de 45° más cercano, lo que cubre las
## ocho orientaciones. Al detenerse se conserva la última orientación para
## reproducir la animación de reposo correspondiente.
## [param direction] es el vector de entrada; magnitud nula indica reposo.
## [param moving] indica si la entrada supera la zona muerta.
func _update_animation(direction: Vector2, moving: bool) -> void:
	if moving:
		var index: int = roundi(direction.angle() / (PI / 4.0))
		_facing = DIRECTION_NAMES[posmod(index, 8)]

	var animation_name: String = ("walk_" if moving else "idle_") + _facing
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return

	if frames.has_animation(animation_name):
		# Reproducir la animación que ya está activa no la reinicia.
		sprite.play(animation_name)
	elif not moving:
		# Sin animación de reposo, se congela la animación de caminar
		# en el fotograma actual.
		sprite.pause()


## Restringe al jugador y a la cámara a la región [param bounds], en
## coordenadas globales. Con la cámara limitada, el espacio exterior al mapa
## no llega a mostrarse. Un área nula elimina la restricción de movimiento
## y deja la cámara sin límites.
## [br]Si el mapa es más pequeño que la pantalla, la cámara no puede cubrir
## todo el espacio y se mostrará algo de fondo vacío.
func set_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds

	if bounds.has_area():
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.end.x)
		camera.limit_bottom = int(bounds.end.y)
		# Evita tirones cuando la cámara llega a un límite con el suavizado
		# activado.
		camera.limit_smoothed = true
	else:
		# Valores por defecto de Camera2D (sin límite práctico).
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000


## Enciende o apaga la linterna. Cada nivel decide su estado inicial.
## No tiene efecto si la escena no incluye el nodo [code]LanternLight[/code].
func set_lantern_enabled(enabled: bool) -> void:
	if lantern:
		lantern.visible = enabled


## Atenúa o restaura la linterna de forma gradual.
## [param factor] es la intensidad relativa a la original: [code]1.0[/code]
## deja la luz como se diseñó en la escena y [code]0.0[/code] la apaga por
## completo (energía cero). Se reducen a la vez el radio y la energía.
## [param duration] es la duración de la transición, en segundos; con un
## valor menor o igual a cero el cambio es instantáneo.
## [br]No tiene efecto si la escena no incluye el nodo
## [code]LanternLight[/code].
func set_lantern_intensity(factor: float, duration: float = 0.4) -> void:
	if lantern == null:
		return

	factor = clampf(factor, 0.0, 1.0)
	var target_scale: float = _lantern_base_scale * maxf(factor, LANTERN_MIN_SCALE_FACTOR)
	var target_energy: float = _lantern_base_energy * factor

	# Una atenuación nueva sustituye a la anterior para que nunca compitan.
	if is_instance_valid(_lantern_tween):
		_lantern_tween.kill()

	if duration <= 0.0:
		lantern.texture_scale = target_scale
		lantern.energy = target_energy
		return

	_lantern_tween = create_tween().set_parallel(true)
	_lantern_tween.tween_property(lantern, "texture_scale", target_scale, duration)
	_lantern_tween.tween_property(lantern, "energy", target_energy, duration)


## Coloca al jugador en [param pos] (coordenadas globales) sin que la cámara
## "viaje" hasta allí. Se usa para regresar al último checkpoint.
## También detiene cualquier velocidad que llevara el personaje.
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	# Sin esto, el suavizado haría que la cámara cruzara el mapa deslizándose.
	camera.reset_smoothing()


## Hace que el personaje camine solo hasta [param target], con la misma
## animación y velocidad que si el jugador lo moviera. Se ignora el input
## mientras dura. Puede esperarse con [code]await[/code]: termina al llegar.
## [br]Si el trayecto sale del mapa, debe abrirse antes una zona de paso con
## [method set_edge_gap]; de lo contrario el límite del mapa lo detendría.
## [param target] es el destino en coordenadas globales.
func walk_to(target: Vector2) -> void:
	_auto_target = target
	_auto_walking = true
	await auto_walk_finished


## Calcula la dirección de la caminata automática y la termina al llegar.
## Devuelve el vector unitario hacia el destino, o [constant Vector2.ZERO]
## si ya se alcanzó (en ese caso emite [signal auto_walk_finished]).
func _auto_walk_direction() -> Vector2:
	var to_target: Vector2 = _auto_target - global_position
	if to_target.length() <= AUTO_WALK_ARRIVAL:
		_auto_walking = false
		auto_walk_finished.emit()
		return Vector2.ZERO
	return to_target.normalized()


## Abre un hueco en el límite del mapa por el que el personaje puede salir o
## entrar. Mientras el personaje esté dentro de [param gap] no se aplica el
## recorte de [method set_world_bounds]; fuera de él, el límite sigue vigente.
## [param gap] es la zona de paso, en coordenadas globales. Debe extenderse
## hacia fuera del mapa para que el personaje pueda cruzar el borde.
func set_edge_gap(gap: Rect2) -> void:
	_edge_gap = gap


## Cierra la zona de paso abierta con [method set_edge_gap]; el límite del
## mapa vuelve a aplicarse en todo su perímetro.
func clear_edge_gap() -> void:
	_edge_gap = Rect2()


## Punto de extensión para la interacción con objetos del entorno.
## Su implementación prevista se basa en un [Area2D] que detecte los
## objetos interactuables al alcance mediante señales.
## [br][br]Implementación actual: en lugar de un [Area2D], se recorre el grupo
## [code]interactable[/code] y se elige el nodo visible más cercano dentro de
## [member interact_range] que tenga el método [code]interact(by)[/code]. Así
## cualquier objeto o personaje se vuelve interactuable con solo añadirse al
## grupo e implementar ese método, sin tocar el Player.
func _try_interact() -> void:
	var closest: Node2D = null
	var closest_distance: float = interact_range

	for node in get_tree().get_nodes_in_group("interactable"):
		var candidate := node as Node2D
		# Se ignoran nodos ocultos (por ejemplo, la Llorona cuando no está
		# en escena) y los que no saben reaccionar a la interacción.
		if candidate == null or not candidate.is_visible_in_tree():
			continue
		if not candidate.has_method("interact"):
			continue

		var distance: float = global_position.distance_to(candidate.global_position)
		if distance <= closest_distance:
			closest = candidate
			closest_distance = distance

	if closest != null:
		closest.call("interact", self)
