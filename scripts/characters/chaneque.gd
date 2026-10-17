## @author Citlaly Morales Viveros (Cliente / Programadora XP)
##
## El Chaneque: guardián del monte.
##
## Durante el nivel es solo una voz; al final aparece, camina hacia el jugador
## y le entrega la moneda. Se mueve y se anima en ocho direcciones, igual que
## el [Player]: usa los mismos sufijos de dirección y espera animaciones
## [code]walk_<dirección>[/code] y, opcionalmente, [code]idle_<dirección>[/code].
## Si una animación no tiene fotogramas todavía, simplemente no se reproduce.
## [br][br]Se registra en el grupo [code]interactable[/code] y emite
## [signal interacted] cuando el jugador habla con él.
class_name Chaneque
extends CharacterBody2D


## Se emite cuando el jugador interactúa con el Chaneque.
signal interacted

## Se emite al llegar al destino de [method walk_to].
signal arrived


## Velocidad de desplazamiento, en píxeles por segundo.
@export var speed: float = 60.0


## Nodo [AnimatedSprite2D] que muestra al Chaneque.
@onready var sprite: AnimatedSprite2D = $Sprite2D

## Forma de colisión. Se desactiva mientras el Chaneque está oculto.
@onready var collision: CollisionShape2D = $CollisionShape2D

## Sufijo de la dirección hacia la que mira (ver [constant Player.DIRECTION_NAMES]).
var _facing: String = "s"

## Destino actual de [method walk_to], en coordenadas globales.
var _walk_target: Vector2 = Vector2.ZERO

## Distancia a la que se detiene del destino, en píxeles.
var _stop_distance: float = 4.0

## Indica si está caminando hacia [member _walk_target].
var _walking: bool = false


## Se registra como interactuable y fija el modo de movimiento top-down.
func _ready() -> void:
	add_to_group("interactable")
	# Modo flotante: vista top-down, sin suelo ni gravedad.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Avanza hacia el destino (si lo hay) y actualiza la animación.
## [param _delta] es el tiempo del paso de física (no se usa).
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO

	if _walking:
		var to_target: Vector2 = _walk_target - global_position
		if to_target.length() <= _stop_distance:
			_walking = false
			arrived.emit()
		else:
			direction = to_target.normalized()

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction)


## Lo invoca el [Player] al interactuar cerca. Avisa al nivel.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	interacted.emit()


## Camina hacia [param target] (coordenadas globales) y emite [signal arrived]
## al llegar. [param stop_distance] es la distancia, en píxeles, a la que se
## detiene del punto (útil para no empalmarse con el jugador).
func walk_to(target: Vector2, stop_distance: float = 4.0) -> void:
	_walk_target = target
	_stop_distance = stop_distance
	_walking = true


## Hace que el Chaneque mire hacia [param point] (coordenadas globales) sin
## moverse. La orientación se redondea a una de las ocho direcciones.
func face_towards(point: Vector2) -> void:
	var direction: Vector2 = point - global_position
	if direction == Vector2.ZERO:
		return
	_facing = _direction_suffix(direction)
	_update_animation(Vector2.ZERO)


## Oculta al Chaneque y desactiva su colisión, para que no estorbe mientras
## solo es una voz.
func hide_chaneque() -> void:
	visible = false
	_walking = false
	collision.set_deferred("disabled", true)


## Muestra al Chaneque con un fundido y reactiva su colisión.
## Puede esperarse con [code]await[/code].
## [param duration] es la duración del fundido, en segundos.
func appear(duration: float = 1.5) -> void:
	modulate.a = 0.0
	visible = true
	collision.set_deferred("disabled", false)

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished


## Permite o impide que el jugador interactúe con el Chaneque.
## [param value] es [code]false[/code] para dejarlo como simple decoración.
func set_interactable(value: bool) -> void:
	if value:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")


## Devuelve el sufijo de dirección (e, se, s, sw, w, nw, n, ne) más cercano
## al vector [param direction], con el mismo criterio que el [Player].
func _direction_suffix(direction: Vector2) -> String:
	var index: int = roundi(direction.angle() / (PI / 4.0))
	return Player.DIRECTION_NAMES[posmod(index, 8)]


## Selecciona la animación según la dirección de movimiento. Al detenerse
## conserva la última orientación.
## [param direction] es la dirección de movimiento; cero indica reposo.
func _update_animation(direction: Vector2) -> void:
	var moving: bool = direction != Vector2.ZERO
	if moving:
		_facing = _direction_suffix(direction)

	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return

	var animation_name: String = ("walk_" if moving else "idle_") + _facing
	if frames.has_animation(animation_name) and frames.get_frame_count(animation_name) > 0:
		sprite.play(animation_name)
	elif not moving:
		# Sin animación de reposo se congela la de caminar en su fotograma
		# actual, mirando hacia la última dirección.
		var walk_name: String = "walk_" + _facing
		if frames.has_animation(walk_name) and frames.get_frame_count(walk_name) > 0:
			sprite.play(walk_name)
			sprite.pause()
