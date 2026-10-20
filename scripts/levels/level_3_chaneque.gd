## Nivel 3: el Chaneque.
##
## Un bosque oscuro (CanvasModulate) iluminado solo por la linterna del
## jugador. Cada rama que se pisa hace ruido: enoja al Chaneque y atenúa la
## linterna. A la cuarta, la luz se apaga y el jugador regresa al checkpoint.
## Hay que juntar tres ofrendas (listón, cempasúchil y mandarina) y entregarlas
## en el altar; entonces la linterna recupera su luz completa (el bosque sigue
## oscuro), aparece el Chaneque y, al
## hablar con él, entrega la moneda de oro. Después se abre una salida en el
## borde derecho del mapa, a la altura del altar, señalada con flechas; al
## cruzarla termina el nivel.
## [br][br]Igual que en el nivel de la Llorona, este script es el director de
## la escena: Player, ramas, altar y Chaneque no se conocen entre sí; solo el
## nivel conecta sus señales.
## [br][br]Estructura de la escena esperada (ver [code]level_3_chaneque.tscn[/code]):
## [code]Player, StartPoint, Fondo, Oscuridad, Ramas, Ofrendas, Altar, Chaneque,
## ScrollMessage[/code].
extends Node2D


## Se emite cuando el jugador cruza la salida del borde derecho, ya con la
## moneda, y el nivel queda completo.
## Úsala para pasar al siguiente nivel o a la escena final.
signal level_completed


## Archivo con los diálogos del Chaneque.
const DIALOGUE_PATH: String = "res://data/dialogues/chaneque.json"

## Bloques de diálogo de las pisadas, en orden (1.ª, 2.ª y 3.ª que cuentan).
const NOISE_BLOCKS: Array[String] = ["chaneque_ruido", "chaneque_ruido_2", "chaneque_ruido_3"]

## Ids (en [code]items.json[/code]) de las ofrendas que pide el altar.
const OFFERINGS: Array[String] = ["liston", "cempasuchil", "mandarina"]

## Id de la recompensa del nivel.
const REWARD_ITEM: String = "moneda"

## Bandera de [GameState] que marca el nivel como completado.
const COMPLETED_FLAG: String = "chaneque_completo"

## Id (en [code]messages.json[/code]) del mensaje de bienvenida del nivel.
const MSG_INTRO: String = "chaneque_mensaje_inicio"

## Id (en [code]messages.json[/code]) del aviso cuando faltan ofrendas.
const MSG_MISSING_OFFERINGS: String = "altar_faltan_ofrendas"

## Prefijo de los mensajes de contexto de cada objeto en
## [code]messages.json[/code]: el id es este prefijo + el id del objeto
## (por ejemplo [code]item_liston[/code]).
const MSG_ITEM_PREFIX: String = "item_"

## Bandera de [GameState] que deja el nivel 2 al cruzar la salida: el jugador
## llega caminando desde la izquierda. Se consume (se apaga) al iniciar. Debe
## coincidir con [code]FLAG_WALKING_INTO_LEVEL_3[/code] de
## [code]level_2_llorona.gd[/code].
const FLAG_WALKING_IN: String = "entrando_nivel_3"

## Cuánto se extiende, en píxeles, la zona de paso de entrada hacia fuera del
## borde izquierdo del mapa.
const ENTRY_GAP_OUTSIDE: float = 60.0

## Margen extra, en píxeles, que la zona de paso de entrada se prolonga hacia
## dentro del mapa más allá del punto al que camina el jugador.
const ENTRY_GAP_INSIDE_MARGIN: float = 20.0

## Mitad del alto, en píxeles, de la zona de paso de entrada.
const ENTRY_GAP_HALF_HEIGHT: float = 40.0

## Cuánto se extiende, en píxeles, la zona de paso de la salida hacia fuera del
## borde derecho del mapa.
const EXIT_GAP_OUTSIDE: float = 60.0

## Cuánto se extiende, en píxeles, la zona de paso de la salida hacia dentro del
## mapa, antes del borde derecho.
const EXIT_GAP_INSIDE: float = 60.0

## Mitad del alto, en píxeles, de la zona de paso de la salida.
const EXIT_GAP_HALF_HEIGHT: float = 40.0

## Duración del fundido a negro al cruzar la salida, en segundos.
const EXIT_FADE_TIME: float = 0.7

## Qué tan cerca del borde derecho, en píxeles, debe estar el centro del jugador
## para contar como cruce. Es un margen de tolerancia por si el límite del mapa
## lo detiene un poco antes del borde.
const EXIT_TRIGGER_MARGIN: float = 24.0

## Mitad del alto, en píxeles, de la franja donde cuenta el cruce, centrada en
## la altura de la salida.
const EXIT_TRIGGER_HALF_HEIGHT: float = 60.0

## Escena a la que lleva la salida del nivel.
const NEXT_LEVEL_PATH: String = "res://scenes/levels/level_4_final.tscn"


## Región jugable del nivel, en coordenadas globales (posición y tamaño).
## Limita el movimiento del jugador y la cámara. Si se deja en cero, se
## calcula a partir de la imagen del nodo [code]Fondo[/code].
@export var map_bounds: Rect2 = Rect2()

## Indica si la linterna del jugador está encendida en este nivel.
@export var lantern_enabled: bool = true

## Color con el que se oscurece el mapa. Si se ve muy claro, prueba con uno
## más oscuro, por ejemplo [code]#2e2e3d[/code].
@export var darkness_color: Color = Color("#3f3f53")

## Intensidad de la linterna según el número de ruidos. El índice 0 es la
## luz completa; cada valor siguiente es una atenuación, y el último apaga
## la linterna. Con cinco valores: tres atenuaciones y a la cuarta se apaga.
@export var light_levels: Array[float] = [1.0, 0.85, 0.65, 0.45, 0.0]

## Duración de cada atenuación de la linterna, en segundos.
@export var light_fade_time: float = 0.5

## Segundos entre el crujido de la rama y el diálogo del Chaneque. Deja
## escuchar el ruido antes de que el juego se pause con el diálogo.
@export var noise_dialogue_delay: float = 0.5

## Segundos que se deja leer el mensaje de bienvenida antes de que se rompa
## la rama del tutorial.
@export var tutorial_delay: float = 3.0

## Escala de las imágenes de las ofrendas en el mapa.
@export var offering_scale: float = 1.0

## Duración del fundido de entrada al llegar desde el nivel 2, en segundos.
## Sirve para aclarar la pantalla si el nivel anterior usó fundido a negro; si
## no lo usó, no se nota.
@export var arrival_fade_time: float = 0.3

## Altura (coordenada Y) a la que el jugador entra por el borde izquierdo al
## llegar desde el nivel 2. Debe coincidir con el centro vertical de
## [code]exit_gate_rect[/code] del nivel 2 (a la altura de la casa) para que el
## paseo se sienta continuo.
@export var entry_y: float = 231.0

## Distancia, en píxeles, que el jugador camina hacia dentro del mapa al
## entrar, medida desde el borde izquierdo.
@export var entry_walk_distance: float = 80.0

## Ajuste vertical, en píxeles, de la salida respecto a la altura del altar.
## Con [code]0[/code] queda justo a la altura del origen del altar; si el
## origen del altar no está en su centro, sube o baja la salida con este valor.
@export var exit_y_offset: float = 0.0

## Si es [code]true[/code], dibuja la zona de paso de la salida (verde) y la
## línea de cruce (roja) para ajustarla a simple vista. Desactívalo al terminar.
@export var debug_exit: bool = false


## Jugador del nivel.
@onready var player: Player = $Player

## Punto de inicio y checkpoint del nivel.
@onready var start_point: Marker2D = $StartPoint

## Imagen de fondo del mapa; define los límites del mundo si no hay
## [member map_bounds].
@onready var background: Sprite2D = $Fondo

## Oscurecedor del mapa.
@onready var darkness: CanvasModulate = $Oscuridad

## Contenedor de todas las ramas (incluida la del tutorial).
@onready var branches_root: Node = $Ramas

## Rama que se rompe sola al inicio para enseñar la mecánica.
@onready var tutorial_branch: Branch = $Ramas/RamaTutorial

## Contenedor de los [Marker2D] donde aparecen las ofrendas. El nombre de cada
## marcador debe ser el id del objeto ([code]liston[/code], etc.).
@onready var offerings_root: Node = $Ofrendas

## Altar de la salida.
@onready var altar: Altar = $Altar

## Chaneque (oculto hasta entregar las ofrendas).
@onready var chaneque: Chaneque = $Chaneque

## Pergamino con mensajes (escena [code]scroll_message.tscn[/code]). Se usa
## por nombre de método porque su script no declara [code]class_name[/code].
@onready var scroll_message: CanvasLayer = $ScrollMessage


## Todas las ramas del nivel.
var _branches: Array[Branch] = []

## Cuántos ruidos han contado desde el último checkpoint (sin el tutorial).
var _noise_count: int = 0

## Indica si las ramas ya pueden afectar a la luz (después del tutorial y
## hasta entregar las ofrendas).
var _gameplay_active: bool = false

## Evita que dos eventos (pisadas, interacciones) se encimen.
var _busy: bool = false

## Indica que el nivel ya terminó.
var _finished: bool = false

## Salida del nivel por el borde derecho, a la altura del altar. Se crea por
## código y se abre al recibir la moneda.
var _exit: LevelExit

## Flechas animadas que guían al jugador hacia la salida.
var _guide_arrows: GuideArrows

## Evita procesar el cruce de la salida más de una vez.
var _exit_triggered: bool = false

## Indica si la salida ya está abierta.
var _exit_open: bool = false

## Coordenada X del borde derecho del mapa.
var _exit_right_edge: float = 0.0

## Coordenada Y, central, de la salida.
var _exit_y: float = 0.0

## Segundos acumulados para limitar los avisos de depuración.
var _debug_timer: float = 0.0


## Coloca al jugador, delimita el mapa, registra el checkpoint y arranca la
## secuencia inicial (o restaura el estado final si el nivel ya se completó).
func _ready() -> void:
	darkness.color = darkness_color
	chaneque.hide_chaneque()

	# El jugador debe estar en su posición inicial antes de que comience
	# cualquier otra lógica.
	player.global_position = start_point.global_position
	player.set_lantern_enabled(lantern_enabled)
	_setup_world_bounds()

	# El inicio del nivel es el único checkpoint.
	GameState.set_checkpoint(start_point.global_position)

	_setup_branches()
	_setup_exit()
	altar.interacted.connect(_on_altar_interacted)
	chaneque.interacted.connect(_on_chaneque_interacted)

	# Si el nivel ya se completó (por ejemplo, tras recargarlo), no hay
	# tutorial, ofrendas ni oscuridad que volver a vivir.
	if GameState.has_flag(COMPLETED_FLAG):
		_apply_completed_state()
		return

	_spawn_offerings()

	# Si el jugador viene del nivel de la Llorona, entra caminando por la
	# izquierda antes de que comience la secuencia inicial.
	if GameState.has_flag(FLAG_WALKING_IN):
		GameState.set_flag(FLAG_WALKING_IN, false)
		await _walk_in_from_left()

	_start_level()


#region Inicio y tutorial

## Entrada desde el nivel 2: el jugador aparece con medio cuerpo fuera del
## borde izquierdo, a la altura [member entry_y], y camina solo
## [member entry_walk_distance] píxeles hacia dentro, como si continuara el
## paseo del mapa anterior. Se abre una zona de paso en el borde para que el
## límite del mapa no lo detenga. Puede esperarse con [code]await[/code]:
## termina cuando el jugador llega a su destino.
func _walk_in_from_left() -> void:
	_lock_player(true)

	var left_edge: float = _world_left_edge()
	var destination: Vector2 = Vector2(left_edge + entry_walk_distance, entry_y)
	player.set_edge_gap(Rect2(
			left_edge - ENTRY_GAP_OUTSIDE, entry_y - ENTRY_GAP_HALF_HEIGHT,
			ENTRY_GAP_OUTSIDE + entry_walk_distance + ENTRY_GAP_INSIDE_MARGIN,
			ENTRY_GAP_HALF_HEIGHT * 2.0))

	# El centro del personaje queda justo en el borde: medio cuerpo visible.
	player.teleport_to(Vector2(left_edge, entry_y))
	SceneManager.fade_in(arrival_fade_time)

	await player.walk_to(destination)
	player.clear_edge_gap()


## Secuencia inicial: mensaje de bienvenida, rama del tutorial y diálogo.
## La primera atenuación de la luz es solo una demostración: no cuenta en el
## contador de ruidos y la linterna se recupera al terminar.
func _start_level() -> void:
	_lock_player(true)
	player.set_lantern_intensity(light_levels[0], 0.0)

	# Mensaje de bienvenida y tiempo para leerlo.
	_show_message(MSG_INTRO)
	await get_tree().create_timer(tutorial_delay).timeout

	# Se rompe una rama "sin querer" y el Chaneque se enoja.
	tutorial_branch.break_branch()
	player.set_lantern_intensity(light_levels[1], light_fade_time)
	await get_tree().create_timer(0.8).timeout
	await _play_dialogue("chaneque_rama")

	# La luz vuelve: el tutorial no cuenta.
	player.set_lantern_intensity(light_levels[0], 1.0)
	await get_tree().create_timer(1.0).timeout

	_lock_player(false)
	_gameplay_active = true


## Deja el nivel como queda al terminarlo: oscuridad original, altar entregado,
## Chaneque sin interacción y ramas inactivas.
func _apply_completed_state() -> void:
	_finished = true
	player.set_lantern_intensity(light_levels[0], 0.0)
	altar.mark_delivered()
	altar.place_offerings(_offering_icons(), offering_scale, false)
	chaneque.set_interactable(false)
	for branch in _branches:
		branch.set_active(false)
	_open_exit(false)

#endregion


#region Ramas y luz

## Conecta todas las ramas del contenedor [member branches_root].
func _setup_branches() -> void:
	for child in branches_root.get_children():
		if child is Branch:
			_branches.append(child)
			child.broken.connect(_on_branch_broken)


## Reacciona a una rama rota: atenúa la linterna, hace hablar al Chaneque y,
## si la luz se apaga, regresa al jugador al checkpoint.
## [param branch] es la rama que se rompió.
func _on_branch_broken(branch: Branch) -> void:
	# La rama del tutorial no cuenta; tampoco las que se rompen mientras
	# ya hay otro evento en curso (evita bajar la luz dos veces por pisada).
	if branch.is_tutorial or not _gameplay_active or _busy:
		return
	_busy = true

	_noise_count += 1
	var level_index: int = mini(_noise_count, light_levels.size() - 1)
	player.set_lantern_intensity(light_levels[level_index], light_fade_time)

	if _noise_count >= light_levels.size() - 1:
		await _blackout()
	else:
		_lock_player(true)
		await get_tree().create_timer(noise_dialogue_delay).timeout
		var block_index: int = mini(_noise_count - 1, NOISE_BLOCKS.size() - 1)
		await _play_dialogue(NOISE_BLOCKS[block_index])
		_lock_player(false)

	_busy = false


## La linterna se apagó: fundido a negro, regreso al checkpoint, ramas
## reparadas y luz completa. Las ofrendas ya recogidas se conservan.
func _blackout() -> void:
	_lock_player(true)
	await get_tree().create_timer(0.7).timeout
	await SceneManager.fade_out(0.7)

	for branch in _branches:
		branch.repair()
	_noise_count = 0

	player.teleport_to(GameState.get_checkpoint())
	player.set_lantern_intensity(light_levels[0], 0.0)

	await get_tree().create_timer(0.3).timeout
	await SceneManager.fade_in(0.7)
	_lock_player(false)

#endregion


#region Ofrendas y altar

## Convierte cada [Marker2D] de [member offerings_root] en un [ItemPickup]
## con el icono del objeto. Al recogerlo se agrega al inventario y desaparece
## del mapa (lo hace [ItemPickup]).
func _spawn_offerings() -> void:
	for marker in offerings_root.get_children():
		if not marker is Marker2D:
			continue

		var item_id: String = String(marker.name)
		if Inventory.get_item_data(item_id).is_empty():
			push_warning("Level3: el marcador '%s' no es un id de items.json" % item_id)
			continue

		var pickup: ItemPickup = ItemPickup.new()
		pickup.item_id = item_id
		pickup.position = marker.position

		var icon: Sprite2D = Sprite2D.new()
		icon.texture = Inventory.get_item_icon(item_id)
		icon.scale = Vector2.ONE * offering_scale
		pickup.add_child(icon)

		pickup.picked_up.connect(_on_offering_picked)
		offerings_root.add_child(pickup)


## Muestra la frase de contexto cultural del objeto recién recogido.
## [param item_id] es el id del objeto recogido.
func _on_offering_picked(item_id: String) -> void:
	_show_message(MSG_ITEM_PREFIX + item_id)


## Devuelve las imágenes de las tres ofrendas, en el orden de [constant OFFERINGS].
func _offering_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for item_id in OFFERINGS:
		icons.append(Inventory.get_item_icon(item_id))
	return icons


## Indica si el jugador trae las tres ofrendas.
func _has_all_offerings() -> bool:
	for item_id in OFFERINGS:
		if not Inventory.has_item(item_id):
			return false
	return true


## El jugador interactuó con el altar. Con las tres ofrendas las entrega,
## la linterna recupera su luz y aparece el Chaneque. La oscuridad del mapa
## se mantiene.
func _on_altar_interacted() -> void:
	if _busy or _finished:
		return

	if not _has_all_offerings():
		_show_message(MSG_MISSING_OFFERINGS)
		return

	_busy = true
	_gameplay_active = false
	_lock_player(true)

	# Las ofrendas salen del inventario y se colocan sobre el altar.
	var icons: Array[Texture2D] = _offering_icons()
	for item_id in OFFERINGS:
		Inventory.remove_item(item_id)
	altar.mark_delivered()
	for branch in _branches:
		branch.set_active(false)
	await altar.place_offerings(icons, offering_scale)

	# La linterna vuelve a su intensidad inicial; el mapa sigue oscuro.
	player.set_lantern_intensity(light_levels[0], 0.5)
	await get_tree().create_timer(0.5).timeout

	# El Chaneque aparece, mira al jugador y se le acerca.
	chaneque.face_towards(player.global_position)
	await chaneque.appear()
	chaneque.walk_to(player.global_position, 40.0)

	_lock_player(false)
	_busy = false


## El jugador habló con el Chaneque: diálogo final y moneda de oro.
func _on_chaneque_interacted() -> void:
	if _busy or _finished:
		return
	_busy = true
	_lock_player(true)

	await _play_dialogue("chaneque_altar")

	Inventory.add_item(REWARD_ITEM)
	_show_message(MSG_ITEM_PREFIX + REWARD_ITEM)

	GameState.set_flag(COMPLETED_FLAG)
	chaneque.set_interactable(false)
	_finished = true

	_lock_player(false)
	_busy = false

	# El nivel se da por terminado cuando el jugador cruza la salida.
	_open_exit(true)

#endregion


#region Salida

## Crea la salida del nivel y las flechas guía, ambas cerradas. La salida es
## una zona de paso en el borde derecho del mapa, centrada en la altura del
## altar. Se abren con [method _open_exit].
func _setup_exit() -> void:
	var right_edge: float = _world_right_edge()
	var exit_y: float = altar.global_position.y + exit_y_offset
	_exit_right_edge = right_edge
	_exit_y = exit_y

	_exit = LevelExit.new()
	_exit.gate_rect = Rect2(
			right_edge - EXIT_GAP_INSIDE, exit_y - EXIT_GAP_HALF_HEIGHT,
			EXIT_GAP_INSIDE + EXIT_GAP_OUTSIDE, EXIT_GAP_HALF_HEIGHT * 2.0)
	_exit.trigger_x = right_edge
	_exit.arrow_target = Vector2(right_edge, exit_y)
	_exit.debug_draw = debug_exit
	add_child(_exit)
	_exit.player_crossed.connect(_on_exit_crossed)

	# Las flechas van en una CanvasLayer para que la oscuridad no las apague.
	var arrows_layer: CanvasLayer = CanvasLayer.new()
	add_child(arrows_layer)
	_guide_arrows = GuideArrows.new()
	arrows_layer.add_child(_guide_arrows)


## Abre la salida: aparece la flecha del borde y las flechas guía parten del
## jugador hacia ella.
## [param animated] indica si la flecha aparece con fundido
## ([code]true[/code]) o de golpe ([code]false[/code], al recargar el nivel).
func _open_exit(animated: bool) -> void:
	_exit.enable(animated)
	_exit_open = true
	print("Level3: salida abierta. gate_rect=", _exit.gate_rect, " trigger_x=", _exit.trigger_x)
	_guide_arrows.activate(player, _exit.arrow_target)


## Detecta el cruce de la salida por su cuenta, sin depender de [LevelExit]:
## basta con que el jugador llegue al borde derecho dentro de la franja de la
## salida. Con [member debug_exit] imprime cada segundo dónde está el jugador.
## [param delta] es el tiempo transcurrido desde el paso anterior, en segundos.
func _physics_process(delta: float) -> void:
	if not _exit_open or _exit_triggered:
		return

	var pos: Vector2 = player.global_position

	if debug_exit:
		_debug_timer += delta
		if _debug_timer >= 1.0:
			_debug_timer = 0.0
			print("Level3 debug: jugador=", pos, " borde_x=", _exit_right_edge,
					" salida_y=", _exit_y)

	var near_edge: bool = pos.x >= _exit_right_edge - EXIT_TRIGGER_MARGIN
	var in_strip: bool = absf(pos.y - _exit_y) <= EXIT_TRIGGER_HALF_HEIGHT
	if near_edge and in_strip:
		_on_exit_crossed()


## El jugador cruzó la salida: apaga las flechas, hace un fundido a negro y
## da el nivel por completado y pasa al nivel final.
func _on_exit_crossed() -> void:
	if _exit_triggered:
		return
	_exit_triggered = true

	print("Level3: el jugador cruzó la salida; cargando ", NEXT_LEVEL_PATH)
	_guide_arrows.deactivate()
	_lock_player(true)
	await SceneManager.fade_out(EXIT_FADE_TIME)
	level_completed.emit()

	if not ResourceLoader.exists(NEXT_LEVEL_PATH):
		push_error("Level3: no existe la escena '%s'." % NEXT_LEVEL_PATH)
		# Red de seguridad: se aclara la pantalla y se libera al jugador para
		# que no se quede atrapado en negro.
		await SceneManager.fade_in(EXIT_FADE_TIME)
		_lock_player(false)
		return

	var error: Error = get_tree().change_scene_to_file(NEXT_LEVEL_PATH)
	if error != OK:
		push_error("Level3: no se pudo cargar '%s' (error %d)." % [NEXT_LEVEL_PATH, error])
		await SceneManager.fade_in(EXIT_FADE_TIME)
		_lock_player(false)

#endregion


#region Utilidades

## Delimita el mundo para el jugador y la cámara. Usa [member map_bounds] si
## tiene área; si no, calcula la región a partir de la imagen de fondo. Sin
## ninguna de las dos no se restringe nada.
func _setup_world_bounds() -> void:
	if map_bounds.has_area():
		player.set_world_bounds(map_bounds)
		return
	if background.texture == null:
		return
	var rect: Rect2 = background.get_rect()
	var top_left: Vector2 = background.to_global(rect.position)
	var size: Vector2 = rect.size * background.global_scale.abs()
	player.set_world_bounds(Rect2(top_left, size))


## Devuelve la coordenada X del borde izquierdo del mapa: la de
## [member map_bounds] si tiene área o, si no, la de la imagen de fondo.
func _world_left_edge() -> float:
	if map_bounds.has_area():
		return map_bounds.position.x
	return background.global_position.x


## Devuelve la coordenada X del borde derecho del mapa: la de
## [member map_bounds] si tiene área o, si no, la de la imagen de fondo.
func _world_right_edge() -> float:
	if map_bounds.has_area():
		return map_bounds.end.x
	if background.texture == null:
		return background.global_position.x
	var rect: Rect2 = background.get_rect()
	return background.to_global(rect.position).x + rect.size.x * absf(background.global_scale.x)


## Reproduce el bloque [param block_id] de [constant DIALOGUE_PATH] con el
## cuadro de diálogo del juego y espera a que el jugador lo cierre. Puede
## esperarse con [code]await[/code].
## [br]Mientras el cuadro está abierto el juego queda en pausa (lo gestiona el
## [DialogueManager]) y las líneas avanzan con Enter / Espacio.
func _play_dialogue(block_id: String) -> void:
	DialogueManager.play(DIALOGUE_PATH, block_id)

	# Si el bloque no existe o está vacío, el cuadro no se abre y nunca se
	# emite la señal de fin; se sale para no dejar al jugador bloqueado.
	if not DialogueManager.is_active():
		return

	await DialogueManager.dialogue_finished


## Bloquea o libera el movimiento del jugador.
## [param locked] es [code]true[/code] para bloquearlo.
func _lock_player(locked: bool) -> void:
	player.can_move = not locked


## Muestra un mensaje del pergamino ([code]messages.json[/code]) sin esperar
## a que desaparezca.
## [param message_id] es el id del mensaje (por ejemplo
## [code]chaneque_mensaje_inicio[/code] o [code]item_liston[/code]).
func _show_message(message_id: String) -> void:
	scroll_message.call("show_message", message_id)

#endregion
