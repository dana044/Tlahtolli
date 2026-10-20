## Final.
##
## El jugador llega con la moneda, el medallón y el carboncillo y los entrega
## en el altar. Al hacerlo, el altar brilla, la oscuridad se disuelve, regresa
## la luz y se abre la salida hacia el pueblo, marcada con una flecha hacia la
## derecha. Es el director de la escena: el altar y la salida no se conocen
## entre sí.
extends Node2D


## Archivo con los diálogos del final.
const DIALOGUE_PATH: String = "res://data/dialogues/abuelita_final.json"

## Ids (en [code]items.json[/code]) de los tres regalos de las leyendas.
const OFFERINGS: Array[String] = ["moneda", "medallon", "carboncillo"]

## Mensaje que aparece en el pergamino al terminar la ofrenda.
const MSG_EFFECT: String = "ofrenda_efecto"

## Aviso cuando el jugador llega al altar sin los tres objetos.
const MSG_MISSING_OFFERINGS: String = "altar_faltan_ofrendas"

## Número de este nivel en el diario de pistas (muestra las cinco).
const JOURNAL_LEVEL: int = 3

## Bandera de [GameState] que marca la ofrenda como entregada.
const FLAG_ALTAR_DONE: String = "ofrenda_altar_completa"

## Bandera que avisa a la escena del pueblo de que el jugador llega
## caminando por la izquierda. Debe coincidir con la de [code]pueblo_fiesta.gd[/code].
const FLAG_WALKING_INTO_VILLAGE: String = "entrando_pueblo"


@export_group("Mapa")
## Región jugable, en coordenadas globales (posición y tamaño). Con
## [member use_tilemap_bounds] activado se ignora.
@export var map_bounds: Rect2 = Rect2(0, 0, 1152, 648)
## Si es true, los límites se calculan con las casillas pintadas del mapa.
## Útil si el tamaño de tu casilla no divide exactamente a 1152 × 648.
@export var use_tilemap_bounds: bool = false
## Nodo del mapa (TileMap, TileMapLayer o un nodo que contiene varias capas).
@export var tilemap: Node

@export_group("Escena y luz")
## Escena del pueblo, a la que lleva la salida.
@export_file("*.tscn") var village_scene: String = "res://scenes/levels/pueblo_fiesta.tscn"
## Indica si la linterna del jugador está encendida mientras hay oscuridad.
@export var lantern_enabled: bool = true
## Color con el que se oscurece el mapa al inicio.
@export var darkness_color: Color = Color("#3f3f53")
## Duración del regreso a la luz natural, en segundos.
@export var daylight_time: float = 2.5
## Escala de las imágenes de las ofrendas sobre el altar.
@export var offering_scale: float = 1.0

@export_group("Salida")
## Zona de paso hacia el pueblo, en coordenadas globales. Con un rectángulo
## vacío (valor por defecto) se calcula sola en el borde derecho del mapa.
@export var exit_gate_rect: Rect2 = Rect2()
## Alto de la zona de paso cuando se calcula sola, en píxeles.
@export var exit_gate_height: float = 108.0
## Coordenada X a partir de la cual se cambia de escena. Un valor negativo
## usa el borde derecho del mapa.
@export var exit_trigger_x: float = -1.0
## Brillo de la flecha. Con 1.0 se ve del color original, que es lo correcto
## porque la flecha aparece cuando la oscuridad ya se quitó.
@export var arrow_glow: float = 1.0
## Duración del fundido a negro al salir (0.0 = corte directo).
@export var exit_fade_time: float = 0.0

@export_group("Pruebas")
## Si es true, da al jugador los tres objetos al iniciar. Sirve para ejecutar
## esta escena sola (F6). Desactívalo al entregar.
@export var debug_give_items: bool = false


@onready var player: Player = $Player
@onready var start_point: Marker2D = $StartPoint
@onready var darkness: CanvasModulate = $Oscuridad
@onready var altar: AltarFinal = $AltarFinal

## Pergamino con mensajes. Es [code]null[/code] si la escena no lo incluye.
@onready var scroll_message: ScrollMessage = get_node_or_null("ScrollMessage")

## Diario del nivel. Es [code]null[/code] si la escena no lo incluye.
@onready var journal_ui: JournalUI = get_node_or_null("JournalUI")


## Límites del mundo realmente usados (de [member map_bounds] o del mapa).
var _world_rect: Rect2 = Rect2()

## Salida hacia el pueblo (flecha guía y detección del cruce). Se crea por
## código y se abre al terminar la ofrenda.
var _exit: LevelExit

## Evita que dos interacciones se encimen.
var _busy: bool = false

## Indica que la ofrenda ya se entregó.
var _completed: bool = false

## Indica si ya se inició el cambio de escena.
var _leaving: bool = false


func _ready() -> void:
	darkness.color = darkness_color

	player.global_position = start_point.global_position
	player.set_lantern_enabled(lantern_enabled)
	_setup_world_bounds()

	_setup_journal()

	if debug_give_items:
		for item_id in OFFERINGS:
			Inventory.add_item(item_id)

	altar.interacted.connect(_on_altar_interacted)
	_setup_exit()

	# Si la ofrenda ya se entregó (por ejemplo, al recargar la escena), se deja
	# el estado final: luz natural, objetos en el altar y salida abierta.
	if GameState.has_flag(FLAG_ALTAR_DONE):
		_apply_completed_state()


#region Mapa

## Delimita el mundo para el jugador y la cámara.
func _setup_world_bounds() -> void:
	_world_rect = map_bounds
	if use_tilemap_bounds:
		var from_tiles: Rect2 = _tilemap_pixel_rect()
		if from_tiles.has_area():
			_world_rect = from_tiles
		else:
			push_warning("OfrendaFinal: no se pudo leer el mapa; se usa 'map_bounds'.")
	player.set_world_bounds(_world_rect)


## Calcula, en píxeles globales, el área cubierta por las casillas pintadas de
## [member tilemap] y de todas sus capas. Devuelve un rectángulo vacío si no
## hay mapa o no tiene casillas.
func _tilemap_pixel_rect() -> Rect2:
	if tilemap == null:
		return Rect2()

	var nodes: Array[Node] = [tilemap]
	nodes.append_array(tilemap.find_children("*", "", true, false))

	var result: Rect2 = Rect2()
	var found: bool = false
	for node in nodes:
		var node_2d: Node2D = node as Node2D
		if node_2d == null or not node_2d.has_method("get_used_rect"):
			continue
		var tile_set: TileSet = node_2d.get("tile_set") as TileSet
		if tile_set == null:
			continue
		var used: Rect2i = node_2d.call("get_used_rect")
		if used.size == Vector2i.ZERO:
			continue

		var tile_size: Vector2 = Vector2(tile_set.tile_size)
		var top_left: Vector2 = node_2d.to_global(Vector2(used.position) * tile_size)
		var size: Vector2 = Vector2(used.size) * tile_size * node_2d.global_scale.abs()
		var rect: Rect2 = Rect2(top_left, size)
		result = rect if not found else result.merge(rect)
		found = true

	return result

#endregion


#region Ofrenda

## El jugador interactuó con el altar. Con los tres objetos los entrega,
## ilumina el altar, regresa la luz y abre la salida. Sin ellos, avisa.
func _on_altar_interacted() -> void:
	if _busy or _completed:
		return

	if not _has_all_offerings():
		_show_message(MSG_MISSING_OFFERINGS)
		return

	_busy = true
	player.can_move = false

	await _play_dialogue("ofrenda_inicio")

	# Los objetos salen del inventario y se colocan sobre el altar.
	var icons: Array[Texture2D] = _offering_icons()
	for item_id in OFFERINGS:
		Inventory.remove_item(item_id)
	altar.mark_delivered()
	await altar.place_offerings(icons, offering_scale)

	# El altar brilla y, poco después, la oscuridad se disuelve.
	_show_message(MSG_EFFECT)
	await altar.light_up()
	await _restore_daylight()
	altar.fade_glow()

	_completed = true
	GameState.set_flag(FLAG_ALTAR_DONE)

	# Se abre el camino: aparece la flecha hacia la derecha.
	_exit.enable()

	player.can_move = true
	_busy = false


## Quita la oscuridad del mapa con un fundido hasta la luz natural.
func _restore_daylight() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(darkness, "color", Color.WHITE, daylight_time)
	await tween.finished

	# Sin CanvasModulate el mapa queda con su luz natural.
	darkness.visible = false


## Deja la escena como queda al terminar la ofrenda.
func _apply_completed_state() -> void:
	_completed = true
	darkness.visible = false
	altar.mark_delivered()
	altar.place_offerings(_offering_icons(), offering_scale, false)
	_exit.enable(false)


## Indica si el jugador trae los tres objetos.
func _has_all_offerings() -> bool:
	for item_id in OFFERINGS:
		if not Inventory.has_item(item_id):
			return false
	return true


## Devuelve las imágenes de los tres objetos, en el orden de [constant OFFERINGS].
func _offering_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for item_id in OFFERINGS:
		icons.append(Inventory.get_item_icon(item_id))
	return icons

#endregion


#region Salida hacia el pueblo

## Crea la salida con la zona de paso y la línea de cruce en el borde derecho
## del mapa. Queda cerrada hasta terminar la ofrenda.
func _setup_exit() -> void:
	var trigger_x: float = exit_trigger_x if exit_trigger_x >= 0.0 else _world_rect.end.x

	var gate: Rect2 = exit_gate_rect
	if not gate.has_area():
		# Sale desde un poco antes del borde hasta bien afuera, centrada en Y.
		gate = Rect2(
				_world_rect.end.x - 60.0,
				_world_rect.get_center().y - exit_gate_height / 2.0,
				160.0, exit_gate_height)

	_exit = LevelExit.new()
	_exit.name = "SalidaPueblo"
	_exit.gate_rect = gate
	_exit.trigger_x = trigger_x
	_exit.arrow_glow = arrow_glow
	add_child(_exit)
	_exit.player_crossed.connect(_on_exit_crossed)


## El jugador cruzó la salida: marca que entra caminando al pueblo y cambia
## de escena. El inventario y las banderas viajan solos (son autoloads).
func _on_exit_crossed() -> void:
	if _leaving:
		return
	_leaving = true
	player.can_move = false

	GameState.set_flag(FLAG_WALKING_INTO_VILLAGE)

	if exit_fade_time > 0.0:
		await SceneManager.fade_out(exit_fade_time)

	var error: Error = get_tree().change_scene_to_file(village_scene)
	if error != OK:
		push_error("OfrendaFinal: no se pudo cargar " + village_scene)
		GameState.set_flag(FLAG_WALKING_INTO_VILLAGE, false)
		player.can_move = true
		_leaving = false

#endregion


#region Utilidades

## Le dice al diario en qué nivel está y oculta la misión (no hay ninguna).
func _setup_journal() -> void:
	if journal_ui == null:
		push_warning("OfrendaFinal: no hay un nodo 'JournalUI'; no habrá pistas.")
		return
	journal_ui.set_level(JOURNAL_LEVEL, true)
	journal_ui.set_mission("")


## Reproduce el bloque [param block_id] de [constant DIALOGUE_PATH] y espera a
## que el jugador lo cierre.
func _play_dialogue(block_id: String) -> void:
	DialogueManager.play(DIALOGUE_PATH, block_id)

	# Si el bloque no existe, el cuadro no se abre; se sale para no dejar
	# bloqueado al jugador.
	if not DialogueManager.is_active():
		return

	await DialogueManager.dialogue_finished


## Muestra un mensaje del pergamino sin esperar a que desaparezca.
func _show_message(message_id: String) -> void:
	if scroll_message != null:
		scroll_message.show_message(message_id)

#endregion
