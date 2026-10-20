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

## Distancia, en píxeles, a la que la Llorona aparece del jugador al recoger
## la muñeca.
@export var peace_appear_distance: float = 80.0

## Segundos de espera al cargar el nivel antes de iniciar la introducción.
## Deja terminar el fundido de entrada para que el diálogo no salga sobre negro.
@export var intro_delay: float = 0.8

## Solo para pruebas: si es true, desbloquea todas las pistas del diario al
## iniciar. Sirve al ejecutar este nivel directamente (F6), porque las pistas
## reales las desbloquea la abuelita en la intro. Déjalo en false al entregar.
@export var debug_unlock_all_clues: bool = false

## Si es true, imprime en la consola cada paso de la captura y la caza.
## Sirve para depurar; desactívalo al entregar.
@export var debug_log: bool = true

## Zona de paso hacia el nivel del Chaneque, en coordenadas globales (posición
## y tamaño). Es el hueco del borde derecho por el que el jugador puede salir
## del mapa; debe extenderse hacia fuera del mapa. Por defecto está a la
## altura de la casa (centro vertical en Y = 231). El nivel 3 hace entrar al
## jugador a esa misma altura (ver [code]entry_y[/code] en
## [code]level_3_chaneque.gd[/code]).
@export var exit_gate_rect: Rect2 = Rect2(1092, 191, 100, 80)

## Coordenada X a partir de la cual se cambia de nivel. Con el borde derecho
## del mapa (1152) el cambio ocurre cuando el centro del personaje llega al
## borde, es decir, cuando ya salió medio cuerpo.
@export var exit_trigger_x: float = 1152.0

## Duración del fundido a negro al salir hacia el nivel 3, en segundos. Con
## [code]0.0[/code] el corte es directo, lo que refuerza la sensación de que el
## personaje camina de un mapa a otro.
@export var exit_fade_time: float = 0.0


## Id del objeto de la muñeca en [code]items.json[/code].
const ITEM_DOLL: String = "muneca"

## Id del objeto del medallón de plata en [code]items.json[/code].
const ITEM_MEDALLION: String = "medallon"

## Bandera de [GameState] que indica que la Llorona ya recibió la muñeca.
const FLAG_QUEST_DONE: String = "llorona_en_paz"

## Archivo con los diálogos de este nivel.
const DIALOGUE_PATH: String = "res://data/dialogues/llorona.json"

## Escena del nivel 3 (el Chaneque), a la que lleva la salida.
const LEVEL_3_PATH: String = "res://scenes/levels/level_3_chaneque.tscn"

## Bandera de [GameState] que avisa al nivel 3 de que el jugador llega
## caminando desde este nivel. El nivel 3 la consume al iniciar. Debe coincidir
## con la constante del mismo nombre en [code]level_3_chaneque.gd[/code].
const FLAG_WALKING_INTO_LEVEL_3: String = "entrando_nivel_3"


@onready var player: Player = $Player
@onready var llorona: Llorona = $Llorona
@onready var spawn_point: Marker2D = $SpawnPoint

## Muñeca de trapo escondida en el mapa. Es [code]null[/code] si la escena no
## incluye el nodo [code]Muneca[/code] (o si la misión ya se completó).
@onready var doll: ItemPickup = get_node_or_null("Muneca")

## Pergamino con los mensajes de inicio. Es [code]null[/code] si el nivel
## no lo incluye.
@onready var scroll_message: ScrollMessage = get_node_or_null("ScrollMessage")
@onready var transition_icon: Sprite2D = $TransitionIcon



## Indica si hay una captura en curso. Evita que un segundo contacto inicie
## un respawn anidado.
var _respawning: bool = false

## Si es [code]true[/code], la Llorona ya no debe cazar al jugador (se
## recogió la muñeca o la misión terminó). Evita que un respawn en curso
## reanude la caza.
var _hunt_suspended: bool = false

## Indica si hay un diálogo o una entrega en curso. Evita que se disparen dos
## secuencias de misión a la vez.
var _quest_busy: bool = false

## Salida hacia el nivel del Chaneque (flecha guía y detección del cruce). Se
## crea por código en [method _setup_exit] y se activa al recibir el medallón.
var _exit: LevelExit

## Indica si ya se inició el cambio de nivel. Evita cambiarlo dos veces.
var _leaving: bool = false


func _ready() -> void:
	$Music.play()
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

	# Misión de la muñeca: al recogerla aparece la Llorona (ya sin hostilidad)
	# y al interactuar con ella se le entrega.
	llorona.interacted.connect(_on_llorona_interacted)
	if GameState.has_flag(FLAG_QUEST_DONE):
		# La misión ya se completó (por ejemplo, tras recargar el nivel): no
		# hay muñeca que buscar ni Llorona que cace.
		_hunt_suspended = true
		if doll != null:
			doll.queue_free()
	elif doll != null:
		doll.picked_up.connect(_on_doll_picked_up)

	if debug_unlock_all_clues:
		Journal.unlock_all()
	
	if transition_icon != null:
		transition_icon.scale = Vector2(0.5, 0.5)
		transition_icon.global_position = Vector2(exit_trigger_x - 100, exit_gate_rect.position.y -0)
		transition_icon.z_index = 50

	# La salida se crea siempre, también al recargar el nivel con la misión
	# ya completada (en ese caso queda abierta desde el inicio).
	_setup_exit()

	# Introducción del nivel: diálogo, pergamino y, al final, la caza.
	# Si la misión ya terminó, se omite.
	if not _hunt_suspended:
		_play_intro()


## Secuencia de entrada al nivel:
## 1. Diálogo del protagonista ("Ese llanto… viene de la casa.").
## 2. Pergamino con el aviso y la misión (no bloquea al jugador).
## 3. Comienza la caza de la Llorona.
## El jugador no puede moverse hasta que se cierra el diálogo.
func _play_intro() -> void:
	player.can_move = false

	# Deja terminar el fundido de entrada.
	await get_tree().create_timer(intro_delay).timeout

	# 1. Diálogo (pausa el juego hasta que el jugador lo cierra).
	await _play_dialogue("protagonista_pradera")
	player.can_move = true

	# 2. Pergamino. Sin await a propósito: los mensajes se muestran mientras el
	# jugador ya puede moverse.
	if scroll_message != null:
		scroll_message.play_configured_sequence()

	# 3. La caza empieza una vez cerrado el diálogo.
	if not _hunt_suspended:
		_log("Intro terminada: inicia la caza")
		llorona.start_hunting()


## Ejecuta la secuencia de captura: fundido de salida, regreso al checkpoint,
## fundido de entrada y reanudación de la caza.
## El orden es relevante: primero se detiene la Llorona y se bloquea al
## jugador para que nada se mueva durante el fundido; el teletransporte se
## realiza con la pantalla en negro para que no sea visible; por último se
## devuelve el control.
func _on_player_caught() -> void:
	if _respawning:
		_log("Captura ignorada: ya hay un respawn en curso")
		return
	_respawning = true
	_log("Capturado: inicia respawn")

	# 1. Detener la caza y bloquear el input.
	llorona.stop_hunting()
	player.can_move = false

	# 2. Esperar a que la pantalla esté completamente negra antes de mover
	# al jugador; hacerlo antes dejaría ver el teletransporte.
	await SceneManager.fade_out(fade_duration)
	_log("Fundido de salida terminado")

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
	_log("Respawn hecho: el jugador recupera el control")

	# 6. La aparición de la Llorona corre en paralelo (sin await). Así, si esa
	# animación tarda o nunca termina, no puede dejar bloqueada la reanudación
	# de la caza. Si la caza se reanuda demasiado pronto, sube hunt_resume_delay.
	# 6. Periodo de gracia antes de reanudar la caza.
	await get_tree().create_timer(hunt_resume_delay).timeout

	# Si mientras tanto se recogió la muñeca, la Llorona ya no es hostil.
	if not _hunt_suspended:
		_log("Reanudando caza")
		llorona.start_hunting()
	else:
		_log("Caza NO reanudada: _hunt_suspended es true")

	_respawning = false

	# 7. Periodo de gracia antes de reanudar la caza.
	await get_tree().create_timer(hunt_resume_delay).timeout

	# Si mientras tanto se recogió la muñeca, la Llorona ya no es hostil.
	if not _hunt_suspended:
		_log("Reanudando caza")
		llorona.start_hunting()
	else:
		_log("Caza NO reanudada: _hunt_suspended es true")

	_respawning = false


## Reacciona al recoger la muñeca: detiene la caza, muestra el diálogo del
## hallazgo y hace aparecer a la Llorona, ya sin hostilidad, delante del
## jugador. El jugador no puede moverse mientras dura la secuencia.
## [param _item_id] es el id del objeto recogido (no se usa por ahora).
func _on_doll_picked_up(_item_id: String) -> void:
	if _quest_busy:
		return
	_quest_busy = true

	# Desde este momento la Llorona deja de cazar, incluso si había un
	# respawn en curso (ver _on_player_caught).
	_hunt_suspended = true
	llorona.stop_hunting()
	player.can_move = false

	await _play_dialogue("muneca_encontrada")
	await llorona.appear_before_player(peace_appear_distance)

	player.can_move = true
	_quest_busy = false


## Se ejecuta cuando el jugador interactúa con la Llorona pacífica. Si lleva
## la muñeca, reproduce el diálogo de agradecimiento, cambia la muñeca por el
## medallón de plata, registra la misión como completada y despide a la
## Llorona.
func _on_llorona_interacted() -> void:
	if _quest_busy or not Inventory.has_item(ITEM_DOLL):
		return
	_quest_busy = true
	player.can_move = false

	await _play_dialogue("llorona_ofrenda")

	# Entrega: sale la muñeca, entra el medallón.
	Inventory.remove_item(ITEM_DOLL)
	Inventory.add_item(ITEM_MEDALLION)
	GameState.set_flag(FLAG_QUEST_DONE)

	await llorona.disappear()

	# Con el medallón en mano se abre el camino hacia el nivel del Chaneque.
	if _exit != null:
		_exit.enable()

	player.can_move = true
	_quest_busy = false


## Crea la salida hacia el nivel del Chaneque con los valores de
## [member exit_gate_rect] y [member exit_trigger_x]. Si la misión ya estaba
## completada (por ejemplo, al recargar el nivel), la deja abierta sin animación.
func _setup_exit() -> void:
	_exit = LevelExit.new()
	_exit.name = "SalidaChaneque"
	_exit.gate_rect = exit_gate_rect
	_exit.trigger_x = exit_trigger_x
	add_child(_exit)
	_exit.player_crossed.connect(_on_exit_crossed)

	if GameState.has_flag(FLAG_QUEST_DONE):
		_exit.enable(false)


## El jugador cruzó la salida (ya pasó medio cuerpo). Marca que el nivel 3
## debe hacerlo entrar caminando por la izquierda y cambia de escena. El
## inventario y las banderas viajan solos porque viven en autoloads
## ([Inventory] y [GameState]).
func _on_exit_crossed() -> void:
	if _leaving:
		return
	_leaving = true
	player.can_move = false

	GameState.set_flag(FLAG_WALKING_INTO_LEVEL_3)

	if exit_fade_time > 0.0:
		await SceneManager.fade_out(exit_fade_time)

	var error: Error = get_tree().change_scene_to_file(LEVEL_3_PATH)
	if error != OK:
		# Sin escena a la que ir, se devuelve el control para no dejar bloqueado
		# al jugador.
		push_error("Level2: no se pudo cargar " + LEVEL_3_PATH)
		GameState.set_flag(FLAG_WALKING_INTO_LEVEL_3, false)
		player.can_move = true
		_leaving = false
	
	if transition_icon != null:
		transition_icon.visible = true


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


## Imprime un mensaje de depuración si [member debug_log] está activo.
func _log(message: String) -> void:
	if debug_log:
		print("[Nivel2] ", message)
