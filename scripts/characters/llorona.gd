## Enemigo que acecha mediante teletransportes y persigue al jugador de cerca.
##
## Si entra en contacto con el jugador, emite [signal caught_player] y se
## retira hasta que el nivel decida cómo continuar.
##
## Se espera una animación por cada una de las ocho direcciones, con estos
## nombres (sufijos: [code]n, ne, e, se, s, sw, w, nw[/code]):
class_name Llorona
extends Area2D


## Se emite cuando la Llorona entra en contacto con el jugador.
## Debe conectarse desde el nivel o el GameManager para aplicar la consecuencia.
signal caught_player


## Estados de comportamiento de la Llorona.
enum State {
	INACTIVE, ## Sin actividad: invisible y sin detección.
	STALKING, ## Acecho mediante teletransportes periódicos.
	CHASING, ## Persecución directa al jugador.
}


#region Parámetros de teletransporte

## Tiempo medio entre teletransportes, en segundos.
@export var teleport_interval: float = 6.0

## Variación máxima, en segundos, aplicada a [member teleport_interval].
## Ejemplo: 6.0 ± 2.0 produce intervalos entre 4 y 8 segundos.
@export var interval_variation: float = 2.0

## Distancia mínima al jugador para reaparecer, en píxeles.
## Conviene que sea mayor que [member detection_radius] para que la Llorona
## no aparezca ya persiguiendo.
@export var min_distance: float = 140.0

## Distancia máxima al jugador para reaparecer, en píxeles.
## Valores menores incrementan la presión sobre el jugador.
@export var max_distance: float = 250.0

## Número máximo de posiciones candidatas evaluadas por ciclo.
## Si ninguna es válida, la Llorona no reaparece hasta el siguiente ciclo.
@export var max_attempts: int = 12

#endregion


#region Parámetros de persecución

## Velocidad de persecución, en píxeles por segundo.
## Un valor inferior a la velocidad del jugador permite escapar de ella.
@export var chase_speed: float = 90.0

## Distancia al jugador, en píxeles, por debajo de la cual comienza la
## persecución.
@export var detection_radius: float = 110.0

## Distancia al jugador, en píxeles, por encima de la cual la Llorona pierde
## el rastro. Debe ser mayor que [member detection_radius] para evitar que
## alterne de estado constantemente en el límite.
@export var lose_radius: float = 220.0

## Si es [code]true[/code], la persecución se limita a las ocho direcciones
## (N, NE, E, SE, S, SO, O, NO), igual que el jugador. Si es [code]false[/code],
## se mueve en línea recta hacia él con cualquier ángulo.
@export var snap_to_eight_directions: bool = true

#endregion


#region Restricciones de aparición

## Capas físicas que se consideran obstáculo (paredes, árboles, estructuras).
## La Llorona no reaparecerá en posiciones que se superpongan con ellas.
@export_flags_2d_physics var obstacle_mask: int = 1

## Región del mundo, en coordenadas globales, donde se permite aparecer.
## Si el área es cero (valor por defecto), no se aplica ninguna restricción.
@export var spawn_bounds: Rect2 = Rect2()

#endregion


## Duración mínima permitida entre teletransportes, en segundos.
const MIN_WAIT: float = 1.0

## Sufijos de dirección, ordenados por ángulo a partir del este y en sentido
## horario (el eje Y de Godot crece hacia abajo).
const DIRECTION_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Temporizador que controla el intervalo entre teletransportes.
@onready var timer: Timer = $Timer

## Representación visual animada de la Llorona.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Reproductor del sonido de llanto.
@onready var cry_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

## Forma de colisión utilizada para validar posiciones de aparición.
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Referencia al jugador. Puede ser [code]null[/code] hasta que este se inicialice.
var player: Node2D = null

## Estado actual de comportamiento.
var _state: State = State.INACTIVE

## Sufijo de la dirección hacia la que mira actualmente.
var _facing: String = "s"


func _ready() -> void:
	# El orden de inicialización entre nodos no está garantizado, por lo que
	# la referencia al jugador también se reintenta bajo demanda.
	_try_find_player()

	body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = true
	# Las consultas al espacio físico deben realizarse durante el paso de física.
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS

	# Estado inicial: inactiva hasta que se invoque start_hunting().
	visible = false
	set_deferred("monitoring", false)


## Evalúa la detección y la persecución en cada paso de física.
## [param delta] es el tiempo transcurrido desde el paso anterior, en segundos.
func _physics_process(delta: float) -> void:
	match _state:
		State.STALKING:
			# Solo puede detectar al jugador mientras está en escena.
			if visible:
				# Permanece quieta, observando al jugador.
				_play_directional("idle", player.global_position - global_position)
				if _distance_to_player() <= detection_radius:
					_start_chasing()
		State.CHASING:
			_chase(delta)


## Inicia la caza: la Llorona comenzará a acechar cerca del jugador.
## No tiene efecto si la caza ya está activa o si no existe un jugador.
func start_hunting() -> void:
	if _state != State.INACTIVE:
		return

	_try_find_player()
	if not is_instance_valid(player):
		push_warning("Llorona: no hay ningún nodo en el grupo 'player'; la caza no se iniciará.")
		return

	_state = State.STALKING
	_schedule_next_teleport()


## Detiene la caza, oculta a la Llorona y silencia el llanto.
func stop_hunting() -> void:
	_state = State.INACTIVE
	timer.stop()
	visible = false
	cry_player.stop()
	# Se difiere porque puede invocarse durante el procesamiento de colisiones.
	set_deferred("monitoring", false)


## Pasa a perseguir al jugador y suspende los teletransportes.
func _start_chasing() -> void:
	_state = State.CHASING
	timer.stop()


## Deja de perseguir, retoma el acecho y programa el siguiente teletransporte.
func _stop_chasing() -> void:
	_state = State.STALKING
	_schedule_next_teleport()


## Avanza hacia el jugador. Si este se aleja más de [member lose_radius],
## pierde el rastro.
func _chase(delta: float) -> void:
	if not is_instance_valid(player):
		_stop_chasing()
		return

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > maxf(lose_radius, detection_radius):
		_stop_chasing()
		return

	var direction: Vector2 = to_player.normalized()
	if snap_to_eight_directions:
		direction = _snap_to_eight_directions(direction)

	global_position += direction * chase_speed * delta
	_play_directional("walk", direction)


## Devuelve el vector unitario de la dirección cardinal u ordinal más cercana
## a [param direction]. Los ángulos se redondean a múltiplos de 45°, por lo
## que el resultado siempre es una de las ocho direcciones posibles.
func _snap_to_eight_directions(direction: Vector2) -> Vector2:
	var snapped_angle: float = snappedf(direction.angle(), PI / 4.0)
	return Vector2.from_angle(snapped_angle)


## Devuelve el sufijo de dirección ([code]n[/code], [code]ne[/code], ...)
## correspondiente a [param direction].
func _direction_name(direction: Vector2) -> String:
	var index: int = roundi(direction.angle() / (PI / 4.0))
	return DIRECTION_NAMES[posmod(index, 8)]


## Reproduce la animación [param prefix] ([code]walk[/code] o [code]idle[/code])
## correspondiente a la dirección [param direction].
## Si no existe la animación solicitada no hace nada. En el caso de
## [code]idle[/code], recurre al primer fotograma de la animación
## [code]walk[/code] de la misma dirección.
func _play_directional(prefix: String, direction: Vector2) -> void:
	if direction == Vector2.ZERO or sprite.sprite_frames == null:
		return

	_facing = _direction_name(direction)
	var frames: SpriteFrames = sprite.sprite_frames
	var animation_name: String = "%s_%s" % [prefix, _facing]

	if frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
	elif prefix == "idle":
		var fallback_name: String = "walk_%s" % _facing
		if frames.has_animation(fallback_name):
			sprite.animation = fallback_name
			sprite.frame = 0
			sprite.pause()


## Devuelve la distancia al jugador, en píxeles.
## Devuelve [constant INF] si no hay un jugador válido.
func _distance_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


## Programa el siguiente teletransporte aplicando la variación aleatoria.
func _schedule_next_teleport() -> void:
	var wait: float = randf_range(
		teleport_interval - interval_variation,
		teleport_interval + interval_variation
	)
	timer.start(maxf(MIN_WAIT, wait))


## Se ejecuta al agotarse el temporizador: reubica a la Llorona y programa
## el siguiente ciclo. Solo actúa durante el acecho.
func _on_timer_timeout() -> void:
	if _state != State.STALKING:
		return
	_teleport_near_player()
	_schedule_next_teleport()


## Reubica a la Llorona en una posición válida alrededor del jugador.
## Evalúa hasta [member max_attempts] candidatos; si ninguno es válido,
## conserva su estado actual hasta el siguiente ciclo.
func _teleport_near_player() -> void:
	_try_find_player()
	if not is_instance_valid(player):
		return

	for _attempt in max_attempts:
		# Ángulo uniforme sobre el círculo completo y distancia dentro del
		# anillo [min_distance, max_distance] centrado en el jugador.
		var direction: Vector2 = Vector2.from_angle(randf() * TAU)
		var distance: float = randf_range(min_distance, max_distance)
		var candidate: Vector2 = player.global_position + direction * distance

		if not _is_valid_spawn(candidate):
			continue

		global_position = candidate
		_play_directional("idle", player.global_position - global_position)
		visible = true
		# Se difiere porque modificar monitoring durante el procesamiento de
		# colisiones genera el error "Can't change this state while flushing queries".
		set_deferred("monitoring", true)

		if cry_player.stream and not cry_player.playing:
			cry_player.play()
		return


## Indica si una posición es válida para la aparición.
## Una posición es válida si está dentro de [member spawn_bounds] (cuando se
## ha definido) y la forma de colisión completa no se superpone con ningún
## obstáculo de [member obstacle_mask].
func _is_valid_spawn(pos: Vector2) -> bool:
	if spawn_bounds.has_area() and not spawn_bounds.has_point(pos):
		return false

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = collision_shape.shape
	params.transform = Transform2D(0.0, pos + collision_shape.position)
	params.collision_mask = obstacle_mask
	# Solo los cuerpos sólidos se consideran obstáculo.
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	return space.intersect_shape(params, 1).is_empty()


## Gestiona el contacto con un cuerpo. Solo el jugador activa la captura.
func _on_body_entered(body: Node2D) -> void:
	if _state == State.INACTIVE:
		return
	if body.is_in_group("player"):
		caught_player.emit()
		# Tras la captura, la Llorona se retira hasta que el nivel decida
		# cómo continuar.
		stop_hunting()


## Actualiza la referencia al jugador si aún no es válida.
func _try_find_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
