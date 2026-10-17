## Nivel 2: la pradera de la Llorona.
##
## Actúa como director de la escena: coloca al jugador, delimita el mapa,
## registra el checkpoint inicial, inicia la caza y gestiona las consecuencias
## de una captura. Player y Llorona no se conocen entre sí; este script es el
## único que conecta [signal Llorona.caught_player] con el castigo.
extends Node2D


## Región jugable del nivel, en coordenadas globales (posición y tamaño).
## Limita el movimiento del jugador y la cámara, y restringe dónde puede
## aparecer la Llorona. Un tamaño de cero desactiva la restricción.
@export var map_bounds: Rect2 = Rect2()

## Indica si la linterna del jugador está encendida en este nivel.
@export var lantern_enabled: bool = true

## Duración de la pantalla completamente negra entre el fundido de salida y
## el de entrada, en segundos. Permite que el teletransporte ocurra fuera de
## la vista del jugador. Valores de 0.5 a 1.0 añaden un momento de tensión.
@export var respawn_blackout: float = 0.4

## Duración de cada fundido (salida y entrada), en segundos.
@export var fade_duration: float = 0.6

## Segundos de gracia tras el respawn antes de que la Llorona reanude la caza.
@export var hunt_resume_delay: float = 1.0

## Indica si hay una captura en curso. Evita que un segundo contacto inicie
## un respawn anidado.
var _respawning: bool = false

@onready var player: Player = $Player
@onready var llorona: Llorona = $Llorona
@onready var spawn_point: Marker2D = $SpawnPoint


func _ready() -> void:
	# El jugador debe estar en su posición inicial antes de que comience
	# cualquier otra lógica, incluida la caza.
	player.global_position = spawn_point.global_position
	player.set_lantern_enabled(lantern_enabled)

	# Los mismos límites del mapa se aplican al jugador, a la cámara y a la
	# aparición de la Llorona.
	player.set_world_bounds(map_bounds)
	llorona.spawn_bounds = map_bounds

	# Checkpoint inicial: todo respawn regresa aquí hasta que existan
	# checkpoints intermedios.
	GameState.set_checkpoint(spawn_point.global_position)

	# La conexión se realiza en el nivel, no en la Llorona ni en el Player,
	# de modo que cambiar la consecuencia de la captura (vidas, jumpscare)
	# solo requiere editar este script.
	llorona.caught_player.connect(_on_player_caught)

	# Inicio inmediato de la caza. Más adelante puede delegarse en un Area2D
	# de entrada que invoque start_hunting() al ser atravesado.
	llorona.start_hunting()


## Ejecuta la secuencia de captura: fundido de salida, regreso al checkpoint,
## fundido de entrada y reanudación de la caza.
## El orden es relevante: primero se detiene la Llorona y se bloquea al
## jugador para que nada se mueva durante el fundido; el teletransporte se
## realiza con la pantalla en negro para que no sea visible; por último se
## devuelve el control.
func _on_player_caught() -> void:
	if _respawning:
		return
	_respawning = true

	# 1. Detener la caza y bloquear el input.
	llorona.stop_hunting()
	player.can_move = false

	# 2. Esperar a que la pantalla esté completamente negra antes de mover
	# al jugador; hacerlo antes dejaría ver el teletransporte.
	await SceneManager.fade_out(fade_duration)

	# 3. Reubicar al jugador en el checkpoint y anular su velocidad residual.
	player.global_position = GameState.get_checkpoint()
	player.velocity = Vector2.ZERO

	# 4. Mantener la pantalla en negro un instante antes de mostrar la escena.
	await get_tree().create_timer(respawn_blackout).timeout

	# 5. Iniciar el fundido de entrada sin esperar a que termine: el jugador
	# recupera el control en cuanto empieza a ver, para que el respawn no se
	# sienta lento.
	SceneManager.fade_in(fade_duration)
	player.can_move = true

	# 6. Periodo de gracia antes de reanudar la caza.
	await get_tree().create_timer(hunt_resume_delay).timeout
	llorona.start_hunting()

	_respawning = false
