## Interior de la prisión: todas las celdas en una sola escena.
##
## Cada celda es un nodo hijo de [code]Celdas[/code] (instancia de
## [code]celda.tscn[/code]) llamado [code]celda_N[/code]. Este script lee en
## [GameState] cuál celda corresponde a la puerta por la que entró el
## jugador, muestra solo esa, lo coloca en su [code]StartPoint[/code] y limita
## movimiento y cámara a su interior. Las demás celdas quedan ocultas y
## desactivadas, no eliminadas, así que se puede entrar a cualquiera cuantas
## veces se quiera.
## [br][br]Nodos que la escena espera (los nombres deben coincidir):
## [codeblock]
## player (Player)             Celdas (instancia de celda.tscn)
## PuertaSalida (CeldaSalida)  Oscuridad (CanvasModulate)
## [/codeblock]
## [br]Cada [code]celda_N[/code] debe tener [code]Limites/StartPoint[/code]
## (donde aparece el jugador) y las paredes [code]Limites/pared_derecha[/code]
## y [code]Limites/pared_abajo[/code], de las que se calcula su tamaño.
## [br][br]el [code]StartPoint[/code] puede estar directamente bajo la
## celda o dentro de [code]Limites[/code] (ver [method _find_marker]). Antes,
## si estaba fuera de [code]Limites[/code] no se encontraba y tanto el
## jugador como la puerta de salida caían en el centro de la celda. Además,
## esta escena ahora ambienta la celda activa con camas, estantes y cadenas
## ([method _decorate_cell]), coloca dentro de ella su hoja de acertijo (solo
## en las celdas de [constant RIDDLE_CELLS]) y una hoja señuelo
## ([DecoyPaper]), y resuelve los acertijos con su propio [RiddlePanel].
## [br][br]Nodos nuevos que la escena espera: [code]RiddlePanel[/code]
## ([RiddlePanel]) y [code]ScrollMessage[/code] ([ScrollMessage]).
extends Node2D


## Si la linterna del jugador está encendida dentro de las celdas.
@export var lantern_enabled: bool = true

## Duración, en segundos, del fundido que aclara la pantalla al entrar. Debe
## ser parecida al fundido de [member CeldaPuerta.fade_time].
@export var fade_in_time: float = 0.4

## Posición de [code]PuertaSalida[/code] respecto al [code]StartPoint[/code]
## de la celda. El punto de inicio queda cerca de la pared inferior, así que
## por defecto la puerta se coloca justo en esa pared.
@export var exit_offset: Vector2 = Vector2(0.0, 11.0)

## Color del piso provisional. Se oscurece con el [CanvasModulate] de la
## escena.
@export var placeholder_floor_color: Color = Color(0.45, 0.4, 0.38)

## Color del contorno provisional.
@export var placeholder_wall_color: Color = Color(0.2, 0.17, 0.16)

## Si es [code]true[/code], imprime en la consola los pasos del interior.
## Desactívalo al entregar.
@export var debug_log: bool = true


## Tamaño de una celda, en píxeles, si no se encuentran sus paredes.
const DEFAULT_CELL_SIZE: Vector2 = Vector2(245.0, 128.0)

## Grosor del contorno provisional, en píxeles.
const PLACEHOLDER_OUTLINE_WIDTH: float = 2.0

## escena del estante. Su origen está en la base, centrado.
const SHELF_SCENE: PackedScene = preload("res://scenes/objects/estante.tscn")

## escena de la cama. Su origen está en el centro de la imagen.
const BED_SCENE: PackedScene = preload("res://scenes/objects/cama.tscn")

## escena de la hoja de acertijo ([RiddlePaper]).
const PAPER_SCENE: PackedScene = preload("res://scenes/objects/hoja.tscn")

## imagen de la cadena (16x8, sin colisión). Se carga al entrar, no al
## compilar, para que el script funcione aunque la imagen aún no exista; si
## falta, solo se omiten las cadenas y se avisa en la consola.
const CHAIN_TEXTURE_PATH: String = "res://assets/sprites/objects/cadena.png"

## archivo con los acertijos. Debe coincidir con el de
## [code]level_1_mulata.gd[/code].
const RIDDLES_PATH: String = "res://data/riddles.json"

## archivo con los diálogos de la Mulata. Debe coincidir con el de
## [code]level_1_mulata.gd[/code].
const DIALOGUE_PATH: String = "res://data/dialogues/mulata.json"

## bloque del diálogo que se reproduce al fallar un acertijo.
const ERROR_DIALOGUE_KEY: String = "mulata_error"

## prefijo de las banderas de acertijos resueltos. Debe coincidir con
## [code]FLAG_RIDDLE_PREFIX[/code] de [code]level_1_mulata.gd[/code].
const FLAG_RIDDLE_PREFIX: String = "mulata_acertijo_"

## prefijo de las banderas de acertijos resueltos dentro de una celda
## cuya recompensa (la parte del barco) aún no se mostró. Debe coincidir con
## [code]FLAG_PENDING_PREFIX[/code] de [code]level_1_mulata.gd[/code], que las
## consume al volver al nivel.
const FLAG_PENDING_PREFIX: String = "mulata_pendiente_"

## prefijo de las claves de los mensajes señuelo en
## [code]messages.json[/code]. Se le añade el número de la celda
## (por ejemplo, [code]celda_nota_3[/code]).
const NOTE_MESSAGE_PREFIX: String = "celda_nota_"

## celdas que guardan una hoja de acertijo, y qué acertijo de
## [code]riddles.json[/code] hay en cada una: { número de celda: id }.
const RIDDLE_CELLS: Dictionary = {
	3: "riddle_1",
	5: "riddle_2",
	8: "riddle_3",
}

## acomodo de cada celda. Las posiciones son locales a la celda: el
## (0, 0) es la esquina superior izquierda de su piso, que mide 245x128, con
## la puerta al centro de la pared inferior. Se dejó libre el pasillo
## x 95-150, y 56-128, que es por donde entra el jugador.
## [br]Claves de cada celda (todas opcionales):
## [codeblock]
## camas     Array[Vector2]  centro de cada cama
## estantes  Array[Vector2]  base (pies) de cada estante
## cadenas   Array[Vector2]  centro de cada cadena (sin colisión)
## acertijo  Vector2         hoja de acertijo (solo celdas de RIDDLE_CELLS)
## nota      Vector2         hoja señuelo
## [/codeblock]
const CELL_LAYOUTS: Dictionary = {
	1: {
		"camas": [Vector2(22, 18), Vector2(22, 50), Vector2(22, 82)],
		"estantes": [Vector2(112, 14), Vector2(144, 14), Vector2(176, 14), Vector2(208, 14)],
		"cadenas": [Vector2(54, 24), Vector2(54, 56), Vector2(54, 88)],
		"nota": Vector2(200, 92),
	},
	2: {
		"camas": [],
		"estantes": [
			Vector2(16, 14), Vector2(48, 14), Vector2(80, 14), Vector2(112, 14),
			Vector2(144, 14), Vector2(176, 14), Vector2(208, 14),
			Vector2(16, 65), Vector2(48, 65), Vector2(208, 118),
		],
		"cadenas": [Vector2(196, 56), Vector2(196, 84)],
		"nota": Vector2(170, 92),
	},
	3: {
		"camas": [Vector2(22, 100)],
		"estantes": [Vector2(16, 14), Vector2(176, 14), Vector2(208, 14)],
		"cadenas": [Vector2(60, 102), Vector2(224, 60)],
		"acertijo": Vector2(190, 70),
		"nota": Vector2(60, 56),
	},
	4: {
		"camas": [Vector2(222, 18), Vector2(222, 50)],
		"estantes": [Vector2(16, 14), Vector2(48, 14), Vector2(80, 14), Vector2(16, 65)],
		"cadenas": [Vector2(190, 26), Vector2(190, 58)],
		"nota": Vector2(60, 95),
	},
	5: {
		"camas": [Vector2(22, 18), Vector2(222, 18)],
		"estantes": [Vector2(80, 14), Vector2(112, 14), Vector2(144, 14), Vector2(176, 14)],
		"cadenas": [Vector2(22, 52), Vector2(222, 52)],
		"acertijo": Vector2(60, 90),
		"nota": Vector2(190, 90),
	},
	6: {
		"camas": [Vector2(123, 22)],
		"estantes": [
			Vector2(16, 14), Vector2(48, 14), Vector2(176, 14), Vector2(208, 14),
			Vector2(208, 65),
		],
		"cadenas": [Vector2(85, 30), Vector2(161, 30)],
		"nota": Vector2(50, 85),
	},
	7: {
		"camas": [Vector2(22, 66), Vector2(22, 98)],
		"estantes": [Vector2(176, 14), Vector2(208, 14), Vector2(208, 65)],
		"cadenas": [Vector2(60, 70), Vector2(60, 102)],
		"nota": Vector2(175, 92),
	},
	8: {
		"camas": [Vector2(222, 66), Vector2(222, 98)],
		"estantes": [Vector2(16, 14), Vector2(48, 14), Vector2(80, 14), Vector2(16, 65)],
		"cadenas": [Vector2(190, 70), Vector2(190, 102)],
		"acertijo": Vector2(70, 92),
		"nota": Vector2(170, 40),
	},
}


@onready var player: Player = $player
@onready var cells: Node2D = $Celdas
@onready var exit_door: CeldaSalida = $PuertaSalida

## pergamino con el acertijo de la hoja que el jugador lee.
@onready var riddle_panel: RiddlePanel = $RiddlePanel

## pergamino con los mensajes cortos (hojas señuelo y éxito de los
## acertijos).
@onready var scroll_message: ScrollMessage = $ScrollMessage


## Región de la celda activa, en coordenadas globales.
var _cell_rect: Rect2 = Rect2()

## acertijos cargados de [code]riddles.json[/code]: { id: {theme,
## boat_part, text, options, correct, success} }.
var _riddles: Dictionary = {}

## indica si hay un acertijo abierto. Evita leer otra hoja mientras
## tanto.
var _busy: bool = false


## Prepara la celda pedida en [GameState]: oculta las demás, coloca al jugador
## y a la puerta de salida, delimita el mapa y aclara la pantalla.
func _ready() -> void:
	var active: Node2D = _find_active_cell()
	if active == null:
		push_error("InteriorCeldas: la escena no tiene ninguna celda.")
		return

	_show_only(active)
	_cell_rect = _get_cell_rect(active)

	# el StartPoint se busca también fuera de Limites (celda_1 y celda_2
	# lo tienen ahí); antes, al no encontrarlo, se usaba el centro de la celda.
	var start: Marker2D = _find_marker(active, "StartPoint")
	var start_pos: Vector2 = start.global_position if start != null else _cell_rect.get_center()

	# El jugador debe estar en su sitio antes de fijar los límites.
	player.teleport_to(start_pos)
	player.set_lantern_enabled(lantern_enabled)
	player.set_world_bounds(_cell_rect)
	_frame_camera(_cell_rect)

	# la puerta se coloca en el hueco de la pared (o en el marcador
	# opcional PuntoSalida de la celda), no en el centro.
	exit_door.global_position = _get_exit_position(active, start_pos)

	# ambientación, hojas y resolución de acertijos de la celda activa.
	_riddles = _load_riddles()
	riddle_panel.answered.connect(_on_riddle_answered)
	_decorate_cell(active)

	queue_redraw()
	_log("Celda activa: " + String(active.name))

	# Sin await: el interior sigue cargándose mientras la pantalla se aclara.
	SceneManager.fade_in(fade_in_time)


## Devuelve el nodo [code]celda_N[/code] que corresponde a
## [method GameState.get_cell_id]. Si no existe (por ejemplo, al probar esta
## escena directamente con F6), usa la primera celda y avisa.
func _find_active_cell() -> Node2D:
	var id: int = GameState.get_cell_id()
	var cell: Node2D = cells.get_node_or_null("celda_%d" % id) as Node2D
	if cell != null:
		return cell

	push_warning("InteriorCeldas: no existe celda_%d; se muestra la primera." % id)
	for child in cells.get_children():
		var first: Node2D = child as Node2D
		if first != null:
			return first
	return null


## Muestra y activa solo [param active]; oculta y desactiva las demás para que
## no se vean ni estorben desde las celdas vecinas.
## [param active] es la celda que debe quedar visible.
func _show_only(active: Node2D) -> void:
	for child in cells.get_children():
		var cell: Node2D = child as Node2D
		if cell == null:
			continue
		var is_active: bool = cell == active
		cell.visible = is_active
		cell.process_mode = Node.PROCESS_MODE_INHERIT if is_active \
				else Node.PROCESS_MODE_DISABLED


## Calcula la región de [param cell] en coordenadas globales a partir de la
## posición de sus paredes derecha e inferior. Si faltan, usa
## [constant DEFAULT_CELL_SIZE].
## [param cell] es el nodo [code]celda_N[/code].
func _get_cell_rect(cell: Node2D) -> Rect2:
	var right: Node2D = cell.get_node_or_null("Limites/pared_derecha") as Node2D
	var bottom: Node2D = cell.get_node_or_null("Limites/pared_abajo") as Node2D
	if right == null or bottom == null:
		push_warning("InteriorCeldas: %s no tiene paredes; se usa el tamaño por defecto."
				% cell.name)
		return Rect2(cell.global_position, DEFAULT_CELL_SIZE)

	var size: Vector2 = Vector2(
			right.global_position.x - cell.global_position.x,
			bottom.global_position.y - cell.global_position.y)
	return Rect2(cell.global_position, size)


## Centra la cámara en la celda. [method Player.set_world_bounds] limita la
## cámara a la celda, pero con el zoom del jugador la pantalla es más grande
## que ella y se vería descentrada con espacio vacío a un solo lado. Aquí se
## amplía el límite de la cámara (no el del jugador) hasta el tamaño de la
## pantalla, centrado en la celda.
## [param rect] es la región de la celda, en coordenadas globales.
func _frame_camera(rect: Rect2) -> void:
	var view: Vector2 = get_viewport_rect().size / player.camera.zoom
	var framed: Rect2 = rect
	if view.x > rect.size.x:
		framed.position.x = rect.get_center().x - view.x / 2.0
		framed.size.x = view.x
	if view.y > rect.size.y:
		framed.position.y = rect.get_center().y - view.y / 2.0
		framed.size.y = view.y

	player.camera.limit_left = int(framed.position.x)
	player.camera.limit_top = int(framed.position.y)
	player.camera.limit_right = int(framed.end.x)
	player.camera.limit_bottom = int(framed.end.y)


## Imprime un mensaje de depuración si [member debug_log] está activo.
func _log(message: String) -> void:
	if debug_log:
		print("[Interior] ", message)


## busca el marcador [param marker_name] de [param cell]. Lo busca
## primero dentro de [code]Limites[/code] y, si no está, directamente bajo la
## celda. Devuelve [code]null[/code] si no existe en ninguno de los dos sitios.
## [param cell] es el nodo [code]celda_N[/code].
## [param marker_name] es el nombre del [Marker2D] (por ejemplo,
## [code]StartPoint[/code]).
func _find_marker(cell: Node2D, marker_name: String) -> Marker2D:
	var marker: Marker2D = cell.get_node_or_null("Limites/" + marker_name) as Marker2D
	if marker == null:
		marker = cell.get_node_or_null(marker_name) as Marker2D
	return marker


## calcula dónde va la puerta de salida. Si la celda tiene un
## [Marker2D] llamado [code]PuntoSalida[/code] (en [code]Limites[/code] o bajo
## la celda), la puerta se coloca ahí; sirve para afinar a mano el hueco de la
## puerta de una celda en particular. Si no, se usa [param start_pos] más
## [member exit_offset].
## [param cell] es el nodo [code]celda_N[/code]; [param start_pos] es el punto
## de aparición del jugador, en coordenadas globales.
func _get_exit_position(cell: Node2D, start_pos: Vector2) -> Vector2:
	var marker: Marker2D = _find_marker(cell, "PuntoSalida")
	if marker != null:
		return marker.global_position
	return start_pos + exit_offset


## ambienta la celda [param cell]: camas, estantes y cadenas, la hoja
## de acertijo (si le corresponde y aún no está resuelta) y la hoja señuelo,
## según [constant CELL_LAYOUTS]. Los objetos se agregan a esta escena, no a
## la celda, para que se ordenen por altura (y-sort) junto al jugador.
## [param cell] es el nodo [code]celda_N[/code] activo.
func _decorate_cell(cell: Node2D) -> void:
	# El número sale del nombre del nodo, así también funciona al probar la
	# escena con F6 (cuando GameState no tiene ninguna celda registrada).
	var cell_id: int = int(String(cell.name).trim_prefix("celda_"))
	var layout: Dictionary = CELL_LAYOUTS.get(cell_id, {})
	if layout.is_empty():
		push_warning("InteriorCeldas: no hay acomodo para la celda %d." % cell_id)
		return

	var origin: Vector2 = cell.global_position
	for pos: Vector2 in layout.get("camas", []):
		_spawn_scene(BED_SCENE, origin + pos)
	for pos: Vector2 in layout.get("estantes", []):
		_spawn_scene(SHELF_SCENE, origin + pos)
	_spawn_chains(origin, layout.get("cadenas", []))
	_spawn_papers(origin, cell_id, layout)


## instancia [param scene] en [param global_pos] como hijo de esta
## escena.
## [param scene] es la escena a instanciar; [param global_pos] es la posición
## global de su origen.
func _spawn_scene(scene: PackedScene, global_pos: Vector2) -> Node2D:
	var node: Node2D = scene.instantiate() as Node2D
	add_child(node)
	node.global_position = global_pos
	return node


## coloca las cadenas, que son solo decoración (sin colisión). Si la
## imagen no existe todavía, las omite y avisa.
## [param origin] es la esquina superior izquierda de la celda, en coordenadas
## globales; [param positions] son los centros de las cadenas, locales a la
## celda.
func _spawn_chains(origin: Vector2, positions: Array) -> void:
	if positions.is_empty():
		return
	if not ResourceLoader.exists(CHAIN_TEXTURE_PATH):
		push_warning("InteriorCeldas: no existe %s; se omiten las cadenas." % CHAIN_TEXTURE_PATH)
		return

	var texture: Texture2D = load(CHAIN_TEXTURE_PATH) as Texture2D
	for pos: Vector2 in positions:
		var chain: Sprite2D = Sprite2D.new()
		chain.name = "Cadena"
		chain.texture = texture
		# Pixel art nítido, como el resto de objetos.
		chain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(chain)
		chain.global_position = origin + pos


## coloca las hojas de la celda. La de acertijo solo existe si la
## celda está en [constant RIDDLE_CELLS] y su acertijo no se resolvió; la
## señuelo ([DecoyPaper]) siempre está.
## [param origin] es la esquina superior izquierda de la celda, en coordenadas
## globales; [param cell_id] es el número de la celda; [param layout] es su
## entrada de [constant CELL_LAYOUTS].
func _spawn_papers(origin: Vector2, cell_id: int, layout: Dictionary) -> void:
	var riddle_id: String = String(RIDDLE_CELLS.get(cell_id, ""))
	if not riddle_id.is_empty() and layout.has("acertijo"):
		if _riddles.has(riddle_id) and not _is_solved(riddle_id):
			var paper: RiddlePaper = PAPER_SCENE.instantiate() as RiddlePaper
			paper.riddle_id = riddle_id
			paper.paper_read.connect(_on_paper_read)
			add_child(paper)
			paper.global_position = origin + (layout["acertijo"] as Vector2)

	if layout.has("nota"):
		var decoy: DecoyPaper = DecoyPaper.new()
		decoy.message_id = NOTE_MESSAGE_PREFIX + str(cell_id)
		decoy.note_read.connect(_on_note_read)
		add_child(decoy)
		decoy.global_position = origin + (layout["nota"] as Vector2)


## el jugador leyó una hoja señuelo: muestra su mensaje corto. Se
## ignora mientras hay un acertijo abierto.
## [param message_id] es la clave del mensaje en [code]messages.json[/code].
func _on_note_read(message_id: String) -> void:
	if _busy:
		return
	# Sin await: el mensaje se desvanece solo.
	scroll_message.show_message(message_id)


## el jugador leyó una hoja de acertijo: abre el pergamino. El jugador
## no puede moverse mientras está abierto.
## [param riddle_id] es el id del acertijo de la hoja.
func _on_paper_read(riddle_id: String) -> void:
	if _busy or _is_solved(riddle_id) or not _riddles.has(riddle_id):
		push_warning("InteriorCeldas: hoja ignorada (%s)" % riddle_id)
		return
	_busy = true
	player.can_move = false
	_log("Hoja leída: " + riddle_id)
	riddle_panel.open(riddle_id, _riddles[riddle_id])


## el jugador eligió una opción del pergamino. Un error no pierde
## progreso: la Mulata avisa y se permite reintentar. Un acierto guarda el
## progreso en [GameState]; la parte del barco se muestra al volver al nivel
## (ver [code]_play_pending_rewards[/code] en [code]level_1_mulata.gd[/code]).
## [param riddle_id] es el acertijo respondido; [param is_correct] indica si
## acertó.
func _on_riddle_answered(riddle_id: String, is_correct: bool) -> void:
	if not is_correct:
		_log("Respuesta incorrecta en " + riddle_id)
		# Las opciones siguen bloqueadas mientras se muestra el diálogo.
		await _play_dialogue(ERROR_DIALOGUE_KEY)
		riddle_panel.unlock()
		return

	riddle_panel.close()

	# Un acertijo ya resuelto no suma progreso por segunda vez.
	if not _is_solved(riddle_id):
		GameState.set_flag(FLAG_RIDDLE_PREFIX + riddle_id)
		GameState.set_flag(FLAG_PENDING_PREFIX + riddle_id)
		_log("Acertijo resuelto: " + riddle_id)

		var riddle: Dictionary = _riddles.get(riddle_id, {})
		var success: String = String(riddle.get("success", ""))
		if not success.is_empty():
			# Sin await: el mensaje se desvanece solo.
			scroll_message.show_text(success)

	player.can_move = true
	_busy = false


## reproduce el bloque [param key] de [constant DIALOGUE_PATH] y espera
## a que el jugador lo cierre. Si el bloque no existe, no espera nada para no
## dejar bloqueado al jugador.
## [param key] es el nombre del bloque en el archivo de diálogos.
func _play_dialogue(key: String) -> void:
	DialogueManager.play(DIALOGUE_PATH, key)
	if not DialogueManager.is_active():
		return
	await DialogueManager.dialogue_finished


## indica si el acertijo [param riddle_id] ya fue resuelto.
func _is_solved(riddle_id: String) -> bool:
	return GameState.has_flag(FLAG_RIDDLE_PREFIX + riddle_id)


## carga [constant RIDDLES_PATH]. Devuelve un diccionario vacío si el
## archivo falta o tiene un formato inválido.
func _load_riddles() -> Dictionary:
	var file: FileAccess = FileAccess.open(RIDDLES_PATH, FileAccess.READ)
	if file == null:
		push_error("InteriorCeldas: no se encontró " + RIDDLES_PATH)
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		return data
	push_error("InteriorCeldas: formato inválido en " + RIDDLES_PATH)
	return {}
