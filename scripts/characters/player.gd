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


## Sufijos de dirección, ordenados por ángulo a partir del este y en sentido
## horario (el eje Y de Godot crece hacia abajo).
const DIRECTION_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Magnitud de entrada por debajo de la cual no se considera movimiento.
## Evita el parpadeo entre animaciones con entradas casi nulas del gamepad.
const DIRECTION_DEADZONE: float = 0.2


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


## Nodo [AnimatedSprite2D] que representa visualmente al personaje.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Nodo [Camera2D] de seguimiento.
@onready var camera: Camera2D = $Camera2D

## Luz de la linterna. Es [code]null[/code] si la escena no incluye el nodo
## [code]LanternLight[/code].
@onready var lantern: PointLight2D = get_node_or_null("LanternLight")

## Región del mundo a la que se restringen el jugador y la cámara, en
## coordenadas globales. Un área nula indica que no hay restricción.
var _world_bounds: Rect2 = Rect2()

## Sufijo de la dirección hacia la que se orientó el personaje por última
## vez. Se conserva al detenerse para mostrar la animación de reposo
## correspondiente.
var _facing: String = "s"


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


## Actualiza el movimiento del personaje en cada paso de física.
## [param delta] corresponde al tiempo transcurrido desde el paso anterior,
## en segundos.
func _physics_process(delta: float) -> void:
	# Sin permiso de movimiento la dirección es cero, por lo que la fricción
	# detiene al personaje de forma gradual en lugar de congelarlo de golpe.
	var direction: Vector2 = Vector2.ZERO
	if can_move:
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
		global_position = global_position.clamp(_world_bounds.position, _world_bounds.end)

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


## Punto de extensión para la interacción con objetos del entorno.
## Su implementación prevista se basa en un [Area2D] que detecte los
## objetos interactuables al alcance mediante señales.
func _try_interact() -> void:
	pass
