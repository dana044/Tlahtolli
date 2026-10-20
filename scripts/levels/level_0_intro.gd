## Nivel 0: introducción con la abuelita.
##
## El jugador camina hacia la abuelita y pulsa interactuar para escuchar la
## conversación completa (la neblina y las tres leyendas). Al terminar se abre
## la salida del borde derecho hacia el nivel 1. La conversación puede
## repetirse todas las veces que se quiera.
## [br][br]Igual que en los demás niveles, este script es el director de la
## escena: la abuelita y el jugador no se conocen entre sí; solo el nivel
## conecta sus señales.
extends Node2D


## Archivo con los diálogos de la abuelita.
const DIALOGUE_PATH: String = "res://data/dialogues/abuelita_intro.json"

## Bloques de [constant DIALOGUE_PATH] que se reproducen, en orden, como una
## sola conversación. Cada bloque desbloquea sus pistas del diario al
## terminar (lo hace el [DialogueManager] mediante [code]journal.json[/code]).
const ABUELITA_BLOCKS: Array[String] = [
	"abuelita_intro",
	"abuelita_mulata",
	"abuelita_llorona",
	"abuelita_chaneque",
	"abuelita_cierre",
]

## Bandera de [GameState] que indica que ya se escuchó la conversación
## completa. Mantiene abierta la salida si el nivel se recarga.
const FLAG_INTRO_DONE: String = "abuelita_intro_vista"

## Escena del nivel 1 (la Mulata), a la que lleva la salida.
const LEVEL_1_PATH: String = "res://scenes/levels/level_1_mulata.tscn"

## Bandera de [GameState] que avisa al nivel 1 de que el jugador llega
## caminando desde este nivel. El nivel 1 debe consumirla (apagarla) al
## iniciar, igual que hace el nivel 3 con [code]entrando_nivel_3[/code].
const FLAG_WALKING_INTO_LEVEL_1: String = "entrando_nivel_1"


## Zona de paso hacia el nivel 1, en coordenadas globales (posición y tamaño).
## Es el hueco del borde derecho por el que el jugador puede salir del mapa;
## debe extenderse hacia fuera del mapa. Por defecto está a la altura del
## camino de tierra (centro vertical en Y = 480): ajusta Y si tu camino está
## en otro lugar.
@export var exit_gate_rect: Rect2 = Rect2(1092, 440, 100, 80)

## Coordenada X a partir de la cual se cambia de nivel. Es un poco menor que
## el borde derecho del mapa (1152) porque este nivel ya impide que el
## jugador pase de ese borde.
@export var exit_trigger_x: float = 1140.0

## Duración del fundido a negro al salir hacia el nivel 1, en segundos. Con
## [code]0.0[/code] el corte es directo, como en la salida del nivel 2.
@export var exit_fade_time: float = 0.0

## Distancia máxima, en píxeles, a la que el jugador puede hablar con la
## abuelita. Este nivel dibuja a los personajes a escala 4, así que el valor
## por defecto del [Player] (56 px) es menor que la distancia a la que chocan
## sus colisiones y no se podría interactuar desde todos los lados.
@export var player_interact_range: float = 120.0


## Jugador del nivel.
@onready var player: Player = $player

## Abuelita con la que se habla.
@onready var abuela: Abuela = $Abuela


# Variables para guardar las coordenadas límite del mapa
var limite_izquierdo: float
var limite_derecho: float
var limite_superior: float
var limite_inferior: float

## Salida hacia el nivel 1 (flecha guía y detección del cruce). Se crea por
## código en [method _setup_exit] y se abre al terminar la conversación.
var _exit: LevelExit

## Indica si hay una conversación en curso. Evita que una segunda pulsación
## de interactuar encime otra secuencia.
var _talking: bool = false

## Indica si ya se inició el cambio de nivel. Evita cambiarlo dos veces.
var _leaving: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Music.play()
	# 1. Ajustes iniciales del jugador
	# Se usa el método del Player (en lugar de tocar la luz directamente) para
	# que, además de apagar la linterna, el personaje use la skin sin lámpara.
	$player.set_lantern_enabled(false)
	$player/Camera2D.zoom = Vector2(1.4, 1.4)
	
	# 2. Calcular los límites basados en el mapa
	var tilemap = $TileMap 
	var camera = $player/Camera2D 
		
	var map_rect = tilemap.get_used_rect()
	var tile_size = tilemap.tile_set.tile_size
	
	# Velocidad del jugador
	if player:
		player.speed = 290.0
	
	# Convertir a píxeles
	limite_izquierdo = map_rect.position.x * tile_size.x
	limite_superior = map_rect.position.y * tile_size.y
	limite_derecho = map_rect.end.x * tile_size.x
	limite_inferior = map_rect.end.y * tile_size.y
	
	# Aplicar límites a la cámara
	camera.limit_left = limite_izquierdo
	camera.limit_top = limite_superior
	camera.limit_right = limite_derecho
	camera.limit_bottom = limite_inferior
	
	# 3. Abuelita y salida
	# El rango de interacción se amplía para la escala de este nivel.
	player.interact_range = player_interact_range
	abuela.interacted.connect(_on_abuela_interacted)
	
	
	
	# La salida se crea siempre; si la conversación ya se escuchó (por ejemplo,
	# al recargar el nivel) queda abierta desde el inicio.
	_setup_exit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Limitar matemáticamente la posición X e Y del jugador
	$player.position.x = clamp($player.position.x, limite_izquierdo, limite_derecho)
	$player.position.y = clamp($player.position.y, limite_superior, limite_inferior)


## Se ejecuta cuando el jugador interactúa con la abuelita. Reproduce todos
## los bloques de [constant ABUELITA_BLOCKS] como una sola conversación y,
## la primera vez, abre la salida hacia el nivel 1. Si el jugador vuelve a
## hablar con ella, la conversación se repite completa. El jugador no puede
## moverse mientras dura.
func _on_abuela_interacted() -> void:
	if _talking or _leaving:
		return
	_talking = true
	player.can_move = false

	for block_id in ABUELITA_BLOCKS:
		await _play_dialogue(block_id)
		# Se espera un fotograma antes del siguiente bloque: la misma pulsación
		# que cierra un cuadro no debe cerrar también el siguiente.
		await get_tree().process_frame

	# La salida solo se abre (con animación) la primera vez.
	var first_time: bool = not GameState.has_flag(FLAG_INTRO_DONE)
	GameState.set_flag(FLAG_INTRO_DONE)
	if first_time and _exit != null:
		_exit.enable()

	player.can_move = true
	_talking = false


## Crea la salida hacia el nivel 1 con los valores de [member exit_gate_rect]
## y [member exit_trigger_x]. Si la conversación ya se había escuchado, la
## deja abierta sin animación.
func _setup_exit() -> void:
	_exit = LevelExit.new()
	_exit.name = "SalidaMulata"
	_exit.gate_rect = exit_gate_rect
	_exit.trigger_x = exit_trigger_x
	add_child(_exit)
	_exit.player_crossed.connect(_on_exit_crossed)

	if GameState.has_flag(FLAG_INTRO_DONE):
		_exit.enable(false)


## El jugador cruzó la salida. Marca que el nivel 1 debe hacerlo entrar
## caminando por la izquierda y cambia de escena. El inventario, el diario y
## las banderas viajan solos porque viven en autoloads.
func _on_exit_crossed() -> void:
	if _leaving:
		return
	_leaving = true
	player.can_move = false

	GameState.set_flag(FLAG_WALKING_INTO_LEVEL_1)

	if exit_fade_time > 0.0:
		await SceneManager.fade_out(exit_fade_time)

	var error: Error = get_tree().change_scene_to_file(LEVEL_1_PATH)
	if error != OK:
		# Sin escena a la que ir (el nivel 1 aún no existe), se devuelve el
		# control para no dejar bloqueado al jugador.
		push_error("Level0: no se pudo cargar " + LEVEL_1_PATH)
		GameState.set_flag(FLAG_WALKING_INTO_LEVEL_1, false)
		player.can_move = true
		_leaving = false


## Reproduce el bloque [param key] de [constant DIALOGUE_PATH] con el cuadro
## de diálogo del juego y espera a que el jugador lo cierre. Puede esperarse
## con [code]await[/code].
## [br]Mientras el cuadro está abierto el juego queda en pausa (lo gestiona el
## [DialogueManager]) y las líneas avanzan con Enter / Espacio.
func _play_dialogue(key: String) -> void:
	DialogueManager.play(DIALOGUE_PATH, key)

	# Si el bloque no existe o está vacío, el cuadro no se abre y nunca se
	# emite la señal de fin; se sale para no dejar al jugador bloqueado.
	if not DialogueManager.is_active():
		return

	await DialogueManager.dialogue_finished
