## Final.
##
## El jugador llega con la moneda, el medallón y el carboncillo y los entrega
## en el altar. Al hacerlo, el altar brilla, la oscuridad se disuelve, regresa
## la luz y se abre la salida hacia el pueblo, marcada con una flecha hacia la
## derecha. Es el director de la escena: el altar y la salida no se conocen
## entre sí.
##
## el pueblo ya está dentro de este mapa (al noreste). Al terminar la
## ofrenda se apaga la linterna del jugador (y su skin pasa a la versión sin
## lámpara), aparecen flechas guía hacia el pueblo, los habitantes
## (Persona1 … Persona8) y la abuelita se vuelven interactuables, y al
## terminar de hablar con la abuelita se muestra "Lo que aprendiste" y, después,
## los créditos.
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

## Bloque de [constant DIALOGUE_PATH] con las líneas de la abuelita al
## final del juego.
const DIALOGUE_ABUELITA_FINAL: String = "abuelita_final"

## Prefijo de los bloques de diálogo de los habitantes del pueblo en
## [constant DIALOGUE_PATH]. Se completa con el número de la persona:
## [code]persona_1[/code] … [code]persona_8[/code].
const PERSONA_BLOCK_PREFIX: String = "persona_"

## Cantidad de habitantes del pueblo (nodos [code]Persona1[/code] …
## [code]Persona8[/code] de la escena).
const PERSONA_COUNT: int = 8

## Capa de dibujo de las flechas guía. Queda por encima del mapa y por
## debajo de los cuadros de diálogo.
const ARROWS_LAYER: int = 5

## Escena a la que se va si la de créditos todavía no existe, para no
## dejar al jugador atrapado en el final.
const FALLBACK_SCENE: String = "res://scenes/main/main_menu.tscn"

## Duración, en segundos, del fundido a negro hacia los créditos.
const CREDITS_FADE_TIME: float = 1.0

## Id (en [code]messages.json[/code]) de la misión que aparece al terminar
## la ofrenda: hablar con la abuelita.
const MSG_MISSION_ABUELA: String = "final_mision2"

## Archivo con los textos de los mensajes y las misiones.
const MESSAGES_PATH: String = "res://data/messages.json"


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
## Si es true, el mapa empieza a oscuras (se ignora que el nodo
## [code]Oscuridad[/code] esté oculto en el editor). Se disuelve al terminar la
## ofrenda. Con false el mapa empieza con luz natural.
@export var start_in_darkness: bool = true

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
## Si es true, además de las flechas se crea la salida por el borde
## derecho hacia [member village_scene] (comportamiento anterior). Con false
## (valor por defecto) el pueblo ya está dentro de este mapa y solo se muestran
## las flechas guía de [member village_arrow_target].
@export var use_exit_to_village_scene: bool = false

@export_group("Pueblo y créditos")
## Punto del pueblo, en coordenadas globales, hacia el que apuntan las
## flechas guía al terminar la ofrenda. Ajústalo en el Inspector.
@export var village_arrow_target: Vector2 = Vector2(800, 215)
## Distancia al pueblo, en píxeles, a partir de la cual se apagan las
## flechas guía.
@export var arrows_stop_distance: float = 90.0
## Escena de créditos que se muestra al terminar de hablar con la
## abuelita. Cámbiala cuando tu compañero/a entregue la suya.
@export_file("*.tscn") var credits_scene: String = "res://scenes/main/creditos.tscn"
## Si es true, antes de los créditos se muestra la pantalla de cierre
## "Lo que aprendiste" (tres datos, uno por leyenda).
@export var show_learned_screen: bool = true

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

## Abuelita del pueblo. Es [code]null[/code] si la escena no la incluye.
@onready var abuela: Abuela = get_node_or_null("Abuelita")


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

## Flechas guía hacia el pueblo. Se crean por código y se encienden al
## terminar la ofrenda.
var _arrows: GuideArrows

## Nodos de interacción de los habitantes (Persona1 … Persona8).
var _personas: Array[PersonaInteract] = []

## Indica si ya empezó el cierre (diálogo final, pantalla de cierre y
## créditos). Evita que se repita.
var _ending: bool = false


func _ready() -> void:
	darkness.color = darkness_color

	# el mapa empieza a oscuras aunque en el editor se haya ocultado el
	# nodo para trabajar cómodamente.
	darkness.visible = start_in_darkness

	player.global_position = start_point.global_position
	player.set_lantern_enabled(lantern_enabled)
	_setup_world_bounds()

	_setup_journal()

	if debug_give_items:
		for item_id in OFFERINGS:
			Inventory.add_item(item_id)

	altar.interacted.connect(_on_altar_interacted)
	_setup_exit()

	# pergamino, flechas, habitantes y abuelita del pueblo.
	_fix_scroll_message()
	_setup_arrows()
	_setup_personas()
	_setup_abuela()

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
	if _exit != null:
		_exit.enable()

	# aparecen las flechas hacia el pueblo, y los habitantes y la
	# abuelita ya pueden hablar.
	_open_village()

	player.can_move = true
	_busy = false


## Quita la oscuridad del mapa con un fundido hasta la luz natural.
func _restore_daylight() -> void:
	# la linterna del jugador se atenúa a la vez que regresa la luz.
	player.set_lantern_intensity(0.0, daylight_time)

	var tween: Tween = create_tween()
	tween.tween_property(darkness, "color", Color.WHITE, daylight_time)
	await tween.finished

	# Sin CanvasModulate el mapa queda con su luz natural.
	darkness.visible = false

	# la luz del jugador se cancela y su skin cambia a la versión sin
	# lámpara ([method Player.set_lantern_enabled] hace ambas cosas).
	player.set_lantern_enabled(false)


## Deja la escena como queda al terminar la ofrenda.
func _apply_completed_state() -> void:
	_completed = true
	darkness.visible = false
	altar.mark_delivered()
	altar.place_offerings(_offering_icons(), offering_scale, false)
	if _exit != null:
		_exit.enable(false)

	# sin linterna ni skin con lámpara, pergamino inicial fuera y pueblo
	# abierto (flechas, habitantes y abuelita).
	player.set_lantern_enabled(false)
	if scroll_message != null:
		scroll_message.message_id = ""
	_open_village()


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
	# con el pueblo dentro del mapa no hace falta la salida por el borde.
	if not use_exit_to_village_scene:
		return

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


#region Pueblo y final

## Corrige el pergamino de la escena. Acepta el nodo aunque se llame
## [code]ScrollMessaje[/code] (como está en el .tscn) y lo hace visible: con
## [code]visible = false[/code] en la [CanvasLayer] ningún mensaje se vería.
func _fix_scroll_message() -> void:
	if scroll_message == null:
		scroll_message = get_node_or_null("ScrollMessaje") as ScrollMessage
	if scroll_message == null:
		push_warning("OfrendaFinal: no hay un nodo 'ScrollMessage'; no habrá mensajes.")
		return
	scroll_message.visible = true


## Crea la capa y las flechas guía hacia el pueblo. Quedan apagadas hasta
## que termina la ofrenda ([method _open_village]). Van en una [CanvasLayer]
## para que la oscuridad del nivel no las apague.
func _setup_arrows() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CapaFlechas"
	layer.layer = ARROWS_LAYER
	add_child(layer)

	_arrows = GuideArrows.new()
	_arrows.name = "FlechasPueblo"
	layer.add_child(_arrows)

	# Solo se procesa la distancia al pueblo mientras las flechas están activas.
	set_process(false)


## Añade a cada [code]PersonaN[/code] un nodo [PersonaInteract] que la
## vuelve interactuable sin tocar su escena. Quedan inactivas hasta que termina
## la ofrenda.
func _setup_personas() -> void:
	for i in range(1, PERSONA_COUNT + 1):
		var persona: Node2D = get_node_or_null("Persona%d" % i) as Node2D
		if persona == null:
			push_warning("OfrendaFinal: no se encontró el nodo 'Persona%d'." % i)
			continue

		var interaction: PersonaInteract = PersonaInteract.new()
		interaction.name = "Interaccion"
		interaction.persona_id = i
		persona.add_child(interaction)
		interaction.interacted.connect(_on_persona_interacted)
		_personas.append(interaction)


## Conecta la abuelita. Hasta terminar la ofrenda no se puede hablar
## con ella.
func _setup_abuela() -> void:
	if abuela == null:
		push_warning("OfrendaFinal: no hay un nodo 'Abuelita'; no habrá cierre.")
		return
	abuela.interacted.connect(_on_abuela_interacted)
	_set_abuela_active(false)


## Activa o desactiva la interacción con la abuelita y la tecla E que
## lleva sobre la cabeza.
## [param active] es [code]true[/code] para poder hablar con ella.
func _set_abuela_active(active: bool) -> void:
	if active:
		abuela.add_to_group("interactable")
	else:
		abuela.remove_from_group("interactable")

	var prompt: Node2D = abuela.get_node_or_null("PromptE") as Node2D
	if prompt != null:
		prompt.visible = active


## Muestra la misión "Habla con la abuela" en el diario y en el
## pergamino. Su texto es el de [constant MSG_MISSION_ABUELA] en
## [constant MESSAGES_PATH].
func _show_abuela_mission() -> void:
	if journal_ui != null:
		journal_ui.set_mission(_message_text(MSG_MISSION_ABUELA))
	_show_message(MSG_MISSION_ABUELA)


## Devuelve el texto del mensaje [param message_id] de
## [constant MESSAGES_PATH], o una cadena vacía si no existe.
func _message_text(message_id: String) -> String:
	var file: FileAccess = FileAccess.open(MESSAGES_PATH, FileAccess.READ)
	if file == null:
		push_warning("OfrendaFinal: no se encontró " + MESSAGES_PATH)
		return ""
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		return data.get(message_id, "")
	return ""


## Abre el pueblo: enciende las flechas guía y permite hablar con los
## habitantes y con la abuelita. Se invoca al terminar la ofrenda (o al
## recargar la escena con la ofrenda ya entregada).
func _open_village() -> void:
	# nueva misión en el diario y en el pergamino.
	_show_abuela_mission()
	for persona in _personas:
		persona.set_active(true)
	if abuela != null:
		_set_abuela_active(true)
	if _arrows != null:
		_arrows.activate(player, village_arrow_target)
		set_process(true)


## Apaga las flechas cuando el jugador ya llegó al pueblo.
## [param _delta] es el tiempo transcurrido desde el fotograma anterior (no se usa).
func _process(_delta: float) -> void:
	if _arrows == null or not is_instance_valid(player):
		set_process(false)
		return
	if player.global_position.distance_to(village_arrow_target) <= arrows_stop_distance:
		_arrows.deactivate()
		set_process(false)


## El jugador habló con un habitante: reproduce su agradecimiento.
## [param persona_id] es el número de la persona (1 a 8).
func _on_persona_interacted(persona_id: int) -> void:
	if _busy or _ending:
		return
	_busy = true
	player.can_move = false

	await _play_dialogue("%s%d" % [PERSONA_BLOCK_PREFIX, persona_id])

	player.can_move = true
	_busy = false


## El jugador habló con la abuelita. Reproduce sus líneas finales,
## muestra "Lo que aprendiste" (si está activado) y pasa a los créditos.
func _on_abuela_interacted() -> void:
	if _busy or not _completed or _ending:
		return
	_busy = true
	_ending = true
	player.can_move = false

	# la misión se cumple al hablar con ella.
	if journal_ui != null:
		journal_ui.set_mission("")

	await _play_dialogue(DIALOGUE_ABUELITA_FINAL)

	if show_learned_screen:
		await _show_learned_screen()

	await _go_to_credits()


## Muestra la pantalla de cierre "Lo que aprendiste" y espera a que el
## jugador la cierre.
func _show_learned_screen() -> void:
	var screen: LearnedScreen = LearnedScreen.new()
	add_child(screen)
	await screen.closed
	screen.queue_free()


## Funde a negro y cambia a [member credits_scene]. Si esa escena aún no
## existe, usa [constant FALLBACK_SCENE]. El fundido de regreso lo hace este
## mismo método a través de [SceneManager], así la escena de créditos no tiene
## que llamar a [code]fade_in[/code].
func _go_to_credits() -> void:
	var target: String = credits_scene
	if target.is_empty() or not ResourceLoader.exists(target):
		push_warning("OfrendaFinal: no existe la escena de créditos ('%s'); se usa '%s'."
				% [target, FALLBACK_SCENE])
		target = FALLBACK_SCENE

	await SceneManager.fade_out(CREDITS_FADE_TIME)

	var error: Error = get_tree().change_scene_to_file(target)
	if error != OK:
		push_error("OfrendaFinal: no se pudo cargar " + target)
		await SceneManager.fade_in(CREDITS_FADE_TIME)
		player.can_move = true
		_busy = false
		_ending = false
		return

	# Sin await: el fundido de regreso sigue aunque este nivel ya se haya liberado.
	SceneManager.fade_in(CREDITS_FADE_TIME)

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
