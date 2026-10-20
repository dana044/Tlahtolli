## Nivel 1: la prisión de la Mulata de Córdoba.
##
## Actúa como director de la escena: coloca al jugador, delimita el mapa y
## conecta las hojas de acertijo, el pergamino de preguntas, el dibujo del
## barco y a la [Mulata]. Ninguno de ellos se conoce entre sí: este script es
## el único que los une mediante señales y decide qué ocurre en cada momento
## (diálogos, progreso, final y salida).
## [br][br]El progreso se guarda en [GameState] con banderas, así que no se
## pierde al recargar el nivel y un acertijo no puede resolverse dos veces
## para duplicar el avance. Las hojas pueden resolverse en cualquier orden.
## [br][br]las puertas de las celdas ([CeldaPuerta]) cambian a la escena
## de interior; al volver, este nivel se recarga con ese progreso intacto y
## coloca al jugador frente a la puerta por la que entró.
## [br][br]las hojas de acertijo ya no están en este mapa: están dentro
## de las celdas 3, 5 y 8 ([code]interior_celdas.gd[/code]), que resuelve el
## acertijo y guarda el progreso en [GameState]. Al volver, este nivel
## muestra con animación la parte del barco ganada y, si ya están las tres
## hojas, la Mulata invita a ir a la pared y aparecen las flechas
## ([method _play_pending_rewards]). El nodo [code]Hojas[/code] se conserva
## (vacío) por si se agrega alguna hoja suelta en el mapa.
## [br][br]Nodos que el nivel espera (los nombres deben coincidir):
## [codeblock]
## player (Player)            StartPoint (Marker2D)
## Mulata (Mulata)            BarcoPared (BoatDrawing)
## Hojas (Node2D, con hijos RiddlePaper)
## ZonaSalida (Area2D)        RiddlePanel (RiddlePanel)
## ScrollMessage (ScrollMessage)
## HUD (CanvasLayer) con ContadorLabel (Label) y Destello (ColorRect)
## InventoryBar (InventoryBar)  <- instancia de inventory_bar.tscn; se
## actualiza sola mediante las señales del autoload [Inventory]
## [/codeblock]
extends Node2D


## Región jugable del nivel, en coordenadas globales (posición y tamaño).
## Limita el movimiento del jugador y la cámara. Un tamaño de cero desactiva
## la restricción.
@export var map_bounds: Rect2 = Rect2(0, 0, 1152, 648)

## Indica si la linterna del jugador está encendida en este nivel.
@export var lantern_enabled: bool = true

## Si es [code]true[/code], el diálogo final comienza solo al resolver el
## último acertijo. Si es [code]false[/code] (por defecto), el jugador debe
## volver a hablar con la Mulata, así el final ocurre a la vista del jugador.
@export var finale_auto_start: bool = false

## Segundos que tarda el destello en llegar a su máximo.
@export var flash_in_time: float = 0.5

## Segundos que tarda el destello en apagarse.
@export var flash_out_time: float = 1.0

## Zona de paso hacia el nivel 2, en coordenadas globales (posición y
## tamaño). Es el hueco del borde derecho por el que el jugador puede salir
## del mapa; debe extenderse hacia fuera. Su centro vertical debe coincidir
## con la altura del punto de reaparición del nivel 2.
## [br]el paso ahora va de y = 129 a y = 217 (antes de 191 a 271), para
## que coincida con la salida real ([code]ZonaSalida[/code]).
@export var exit_gate_rect: Rect2 = Rect2(1092, 129, 100, 88)

## punto global al que apunta la flecha de salida: el centro de la
## zona de salida real ([code]ZonaSalida[/code]). Con [code]Vector2.ZERO[/code]
## la flecha usa el centro de [member exit_gate_rect]. Ojo: el jugador solo
## puede cruzar dentro de [member exit_gate_rect]; si la flecha queda fuera de
## su altura, ajusta ese rectángulo para que la incluya.
@export var exit_arrow_target: Vector2 = Vector2(1120, 172)

## Coordenada X a partir de la cual se cambia de nivel (el centro del
## personaje ya cruzó el borde derecho del mapa).
@export var exit_trigger_x: float = 1152.0

## Duración del fundido a negro al salir, en segundos. Con [code]0.0[/code]
## el corte es directo. Si lo subes, el nivel 2 debe llamar a
## [code]SceneManager.fade_in()[/code] al iniciar, o la pantalla quedará negra.
@export var exit_fade_time: float = 0.0

## Si es true, imprime en la consola los pasos del nivel. Desactívalo al
## entregar.
@export var debug_log: bool = true

## punto al que guían las flechas una vez resueltas las tres hojas, en
## coordenadas globales: el lugar frente a la pared de piedra (arriba a la
## derecha) donde el jugador debe llegar para que ocurra el final. Ajústalo
## en el Inspector si el jugador no puede pisar ese punto del mapa.
## [br]ahora es la salida real ([code]ZonaSalida[/code], en
## (1120, 172)), no el punto de la pared (995, 275) que había antes; así las
## flechas apuntan a la salida. Si quieres volver al punto anterior, cambia
## este valor en el Inspector.
@export var finale_point: Vector2 = Vector2(1120, 172)

## distancia, en píxeles, a [member finale_point] a partir de la cual
## se considera que el jugador llegó a la pared y comienza el final.
@export var finale_radius: float = 48.0

## lugar, en coordenadas globales, donde la Mulata se coloca junto al
## dibujo de la pared durante el final. Por defecto es el sitio donde estaba
## en la escena antes de acompañar al jugador.
@export var mulata_finale_point: Vector2 = Vector2(995, 243)

## duración, en segundos, del fundido que aclara la pantalla al volver
## de una celda. Debe ser parecida al fundido con el que se entró (el de la
## propiedad [code]fade_time[/code] de [CeldaPuerta]).
@export var cell_fade_in_time: float = 0.4


## Archivo con los diálogos de la Mulata.
const DIALOGUE_PATH: String = "res://data/dialogues/mulata.json"

## Archivo con los acertijos.
const RIDDLES_PATH: String = "res://data/riddles.json"

## Escena del nivel 2 (la Llorona), a la que lleva la salida.
const LEVEL_2_PATH: String = "res://scenes/levels/level_2_llorona.tscn"

## Id del carboncillo en [code]items.json[/code].
const ITEM_CHARCOAL: String = "carboncillo"

## Bandera de [GameState]: el jugador ya escuchó el diálogo inicial.
const FLAG_INTRO_SEEN: String = "mulata_intro_vista"

## Bandera de [GameState]: el nivel está completo (carboncillo entregado).
const FLAG_LEVEL_DONE: String = "mulata_nivel_completo"

## Prefijo de las banderas de acertijos resueltos. Se le añade el id del
## acertijo (por ejemplo, [code]mulata_acertijo_riddle_1[/code]).
const FLAG_RIDDLE_PREFIX: String = "mulata_acertijo_"

## prefijo de las banderas de acertijos resueltos dentro de una celda
## cuya recompensa (parte del barco y diálogo) aún no se mostró. La marca
## [code]interior_celdas.gd[/code] y la consume [method _play_pending_rewards].
const FLAG_PENDING_PREFIX: String = "mulata_pendiente_"


@onready var player: Player = $player
@onready var start_point: Marker2D = $StartPoint
@onready var mulata: Mulata = $Mulata
@onready var boat: BoatDrawing = $BarcoPared
@onready var papers: Node2D = $Hojas
@onready var exit_zone: Area2D = $ZonaSalida
@onready var riddle_panel: RiddlePanel = $RiddlePanel
@onready var scroll_message: ScrollMessage = $ScrollMessage
@onready var counter_label: Label = $HUD/ContadorLabel
@onready var flash: ColorRect = $HUD/Destello
@onready var transition_icon: Sprite2D = $TransitionIcon


## Acertijos cargados de [code]riddles.json[/code]: { id: {theme, boat_part,
## text, options, correct, success} }.
var _riddles: Dictionary = {}

## Indica si hay una secuencia en curso (diálogo, pergamino, final). Evita
## que se disparen dos a la vez.
var _busy: bool = false

## Salida hacia el nivel 2 (flecha guía y detección del cruce). Se crea por
## código en [method _setup_exit] y se abre al entregar el carboncillo.
var _exit: LevelExit

## Indica si ya se inició el cambio de nivel. Evita cambiarlo dos veces.
var _leaving: bool = false

## flechas que guían al jugador hasta la pared de piedra. Se crean por
## código en [method _setup_guide_arrows].
var _arrows: GuideArrows

## indica si las flechas están activas y el nivel espera a que el
## jugador llegue a [member finale_point].
var _guiding: bool = false

## indica si el nivel se cargó porque el jugador salió de una celda. En
## ese caso reaparece frente a la puerta y no se repite la introducción.
var _returning_from_cell: bool = false


func _ready() -> void:
	$Music.play() 
	# El jugador debe estar en su posición inicial antes de cualquier lógica.
	player.global_position = start_point.global_position
	player.set_lantern_enabled(lantern_enabled)

	# Los mismos límites del mapa se aplican al jugador y a la cámara.
	player.set_world_bounds(map_bounds)
	GameState.set_checkpoint(start_point.global_position)

	# si el jugador vuelve de una celda, reaparece donde estaba frente a
	# la puerta (en vez de en el punto de inicio) y la pantalla se aclara.
	_returning_from_cell = GameState.is_returning_from_cell()
	if _returning_from_cell:
		player.teleport_to(GameState.get_cell_return_position())
		GameState.clear_cell_visit()
		# Sin await: el nivel sigue cargándose mientras la pantalla se aclara.
		SceneManager.fade_in(cell_fade_in_time)

	# El destello parte invisible, aunque la escena lo deje distinto.
	flash.modulate.a = 0.0

	_riddles = _load_riddles()

	# Todas las conexiones se hacen aquí: no hay señales conectadas desde el
	# editor, de modo que todo el flujo del nivel se lee en este script.
	mulata.interacted.connect(_on_mulata_interacted)
	riddle_panel.answered.connect(_on_riddle_answered)
	exit_zone.body_entered.connect(_on_exit_zone_body_entered)
	
	if transition_icon != null:
		transition_icon.scale = Vector2(0.5, 0.5)
		transition_icon.global_position = Vector2(exit_trigger_x - 50, exit_gate_rect.position.y -10)
		transition_icon.z_index = 50

	_connect_papers()
	_restore_progress()
	_setup_exit()
	_update_counter()
	print("Interactuables: ", get_tree().get_nodes_in_group("interactable"))

	# las flechas guía, la Mulata acompañante y el mensaje de inicio.
	_setup_guide_arrows()
	_start_companion()
	_play_intro()
	# si el jugador resolvió un acertijo dentro de una celda, aquí se
	# muestra su recompensa al volver.
	_play_pending_rewards()


## Conecta cada hoja del nodo [code]Hojas[/code]. Las que ya estaban
## resueltas (por ejemplo, al recargar el nivel) se retiran del mapa.
## [br]Si una hoja no trae [member RiddlePaper.riddle_id] en el Inspector, se
## le asigna por su orden en el árbol (primera hoja = riddle_1, etc.).
func _connect_papers() -> void:
	var index: int = 0
	for child in papers.get_children():
		var paper: RiddlePaper = child as RiddlePaper
		if paper == null:
			continue
		index += 1
		if paper.riddle_id.is_empty():
			paper.riddle_id = "riddle_%d" % index
		if _is_solved(paper.riddle_id):
			paper.queue_free()
		else:
			paper.paper_read.connect(_on_paper_read)


## Restaura el aspecto del nivel según las banderas guardadas, sin animación:
## las partes del barco ya ganadas, o la escena vacía si el nivel terminó.
func _restore_progress() -> void:
	if GameState.has_flag(FLAG_LEVEL_DONE):
		# La Mulata ya se fue y el dibujo se desvaneció con ella.
		mulata.fade_away(0.0)
		boat.hide()
		return

	for id: String in _riddles.keys():
		# lo resuelto en una celda y aún pendiente se anima después.
		if _is_solved(id) and not GameState.has_flag(FLAG_PENDING_PREFIX + id):
			var riddle: Dictionary = _riddles[id]
			boat.show_part(String(riddle.get("boat_part", "")), false)


## Crea la salida hacia el nivel 2 con [member exit_gate_rect] y
## [member exit_trigger_x]. Queda cerrada hasta entregar el carboncillo; si el
## nivel ya estaba completo, queda abierta sin animación.
func _setup_exit() -> void:
	_exit = LevelExit.new()
	_exit.name = "SalidaNivel2"
	_exit.gate_rect = exit_gate_rect
	_exit.trigger_x = exit_trigger_x
	# la flecha apunta a la salida real, no al centro del hueco.
	_exit.arrow_target = exit_arrow_target
	add_child(_exit)
	_exit.player_crossed.connect(_on_exit_crossed)
	# deja en la consola dónde queda la flecha de salida, para comprobar
	# que se está usando esta versión del script.
	_log("Salida: flecha en %s, destino %s, zona de paso %s"
			% [exit_arrow_target + _exit.arrow_offset, exit_arrow_target, exit_gate_rect])

	if GameState.has_flag(FLAG_LEVEL_DONE):
		_exit.enable(false)
	
	if transition_icon != null:
		transition_icon.visible = true


## crea por código las flechas que guían hacia la pared de piedra. Van
## dentro de su propia [CanvasLayer] para que la oscuridad del nivel
## ([code]Oscuridad[/code]) no las apague. Si ya estaban resueltas las tres
## hojas pero el nivel no se completó (por ejemplo, al recargar), se
## reactivan.
func _setup_guide_arrows() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CapaFlechasGuia"
	add_child(layer)

	_arrows = GuideArrows.new()
	_arrows.name = "FlechasPared"
	layer.add_child(_arrows)

	# si queda una recompensa pendiente, las flechas salen cuando
	# termina (ver [method _play_pending_rewards]).
	if _all_solved() and not GameState.has_flag(FLAG_LEVEL_DONE) \
			and not _has_pending_rewards():
		_start_guide_to_wall()


## hace que la Mulata acompañe al jugador desde el inicio. Si el nivel
## ya estaba completo no hace nada: ella ya se fue.
func _start_companion() -> void:
	if GameState.has_flag(FLAG_LEVEL_DONE):
		return
	# al volver de una celda la Mulata aparece junto al jugador, en vez
	# de cruzar todo el mapa desde su lugar original.
	if _returning_from_cell:
		mulata.global_position = player.global_position + Vector2(-16.0, 0.0)
	mulata.start_following(player)


## secuencia de inicio del nivel, literalmente al comenzar. Si es la
## primera vez: bloquea al jugador, muestra el mensaje de inicio del
## [ScrollMessage], después el diálogo [code]mulata_inicio[/code] y por último
## la misión. Si ya la vio (por ejemplo, al recargar), solo muestra los
## mensajes del pergamino, sin bloquear.
## [br]No espera la señal ni el [Tween] del [ScrollMessage]: si otro mensaje
## lo interrumpe, ese [Tween] se cancela y la espera no terminaría nunca,
## dejando al jugador bloqueado. En su lugar espera un tiempo equivalente a
## lo que dura el mensaje.
## [br]Funciona con [code]Show On Ready[/code] activo (el [ScrollMessage] se
## lanza solo) o desactivado (lo lanza el nivel).
func _play_intro() -> void:
	if GameState.has_flag(FLAG_LEVEL_DONE):
		return

	# al volver de una celda no se repiten los mensajes del pergamino.
	# (Si el [ScrollMessage] tiene [code]Show On Ready[/code] activo, se lanza
	# solo y este script no puede detenerlo: desactívalo en el Inspector.)
	if _returning_from_cell:
		return

	var launches_itself: bool = scroll_message.show_on_ready

	if GameState.has_flag(FLAG_INTRO_SEEN):
		if not launches_itself:
			scroll_message.play_configured_sequence()
		return

	_busy = true
	player.can_move = false
	_log("Introducción: inicio")

	# Un fotograma de espera para que toda la escena esté lista.
	await get_tree().process_frame

	# Tiempo que tarda en verse y desvanecerse el mensaje de inicio.
	var banner_wait: float = 0.0
	if not scroll_message.message_id.is_empty():
		banner_wait = scroll_message.display_seconds + scroll_message.fade_seconds * 2.0
		if launches_itself:
			banner_wait += scroll_message.start_delay
		else:
			# Sin await: ver la documentación de esta función.
			scroll_message.show_message(scroll_message.message_id)

	await get_tree().create_timer(banner_wait).timeout

	_log("Introducción: diálogo de la Mulata")
	await _play_dialogue("mulata_inicio")
	GameState.set_flag(FLAG_INTRO_SEEN)
	_log("Introducción: terminada")

	# La misión sale al terminar el diálogo (sin await: no bloquea).
	if not launches_itself:
		scroll_message.show_sequence(scroll_message.follow_up_ids)
	_release_player()


## activa las flechas hacia [member finale_point] y deja al nivel
## esperando la llegada del jugador (ver [method _check_finale_arrival]).
func _start_guide_to_wall() -> void:
	_guiding = true
	_arrows.activate(player, finale_point)
	_log("Flechas hacia la pared activadas")
	# deja en la consola hacia dónde apuntan las flechas.
	_log("Destino de las flechas: %s" % finale_point)


## comprueba si el jugador llegó a la pared de piedra. Al llegar lo
## bloquea, apaga las flechas, la Mulata camina hasta el dibujo y comienza el
## final del nivel. Se llama en cada paso de física.
func _check_finale_arrival() -> void:
	if not _guiding or _busy or _leaving:
		return
	if player.global_position.distance_to(finale_point) > finale_radius:
		return

	# Las banderas se marcan antes de cualquier await para no repetir el final.
	_guiding = false
	_busy = true
	player.can_move = false
	_arrows.deactivate()
	_log("El jugador llegó a la pared")

	await mulata.walk_to(mulata_finale_point)
	await _play_finale()
	_release_player()


## indica si hay acertijos resueltos dentro de una celda cuya
## recompensa aún no se mostró.
func _has_pending_rewards() -> bool:
	for id: String in _riddles.keys():
		if GameState.has_flag(FLAG_PENDING_PREFIX + id):
			return true
	return false


## muestra, al volver de una celda, la recompensa de los acertijos
## resueltos allí: la parte del barco aparece en la pared con su animación y,
## si ya están las tres hojas, la Mulata invita al jugador a ir a la pared y
## se encienden las flechas (lo mismo que antes ocurría al resolver el
## acertijo en el mapa). Mientras dura, el jugador no puede moverse.
func _play_pending_rewards() -> void:
	if not _has_pending_rewards():
		return

	_busy = true
	player.can_move = false

	# Se espera a que la pantalla termine de aclararse y a que la escena esté
	# lista, para que el jugador vea aparecer el dibujo.
	await get_tree().create_timer(cell_fade_in_time + 0.1).timeout

	for id: String in _riddles.keys():
		if not GameState.has_flag(FLAG_PENDING_PREFIX + id):
			continue
		# La bandera se limpia antes del await para no repetir la animación.
		GameState.set_flag(FLAG_PENDING_PREFIX + id, false)
		var riddle: Dictionary = _riddles[id]
		_log("Recompensa pendiente: " + id)
		await boat.show_part(String(riddle.get("boat_part", "")))

	if _all_solved() and not GameState.has_flag(FLAG_LEVEL_DONE):
		await _play_dialogue("mulata_hacia_pared")
		_start_guide_to_wall()

	_release_player()


## El jugador leyó una hoja: abre el pergamino con su acertijo. El jugador no
## puede moverse mientras el pergamino está abierto.
## [param riddle_id] es el id del acertijo de la hoja.
func _on_paper_read(riddle_id: String) -> void:
	if _busy or _is_solved(riddle_id) or not _riddles.has(riddle_id):
		push_warning("Level1: hoja ignorada (%s)" % riddle_id)
		return
	_busy = true
	player.can_move = false
	_log("Hoja leída: " + riddle_id)
	riddle_panel.open(riddle_id, _riddles[riddle_id])


## El jugador eligió una opción del pergamino.
## [param riddle_id] es el acertijo respondido; [param is_correct] indica si
## acertó. Un error no pierde progreso: se avisa y se permite reintentar.
func _on_riddle_answered(riddle_id: String, is_correct: bool) -> void:
	if not is_correct:
		_log("Respuesta incorrecta en " + riddle_id)
		# Las opciones siguen bloqueadas mientras se muestra el mensaje.
		await _play_dialogue("mulata_error")
		riddle_panel.unlock()
		return

	riddle_panel.close()

	# Un acertijo ya resuelto no suma progreso por segunda vez.
	if _is_solved(riddle_id):
		_release_player()
		return

	GameState.set_flag(FLAG_RIDDLE_PREFIX + riddle_id)
	_update_counter()
	_log("Acertijo resuelto: " + riddle_id)

	var riddle: Dictionary = _riddles.get(riddle_id, {})
	var success: String = String(riddle.get("success", ""))
	if not success.is_empty():
		# Sin await: el mensaje se muestra mientras el dibujo avanza.
		scroll_message.show_text(success)

	# La parte del barco la define el JSON, no el orden de las hojas.
	await boat.show_part(String(riddle.get("boat_part", "")))

	if _all_solved() and finale_auto_start:
		await _play_finale()
	elif _all_solved():
		# con las tres hojas resueltas, la Mulata invita al jugador a
		# ir a la pared y aparecen las flechas que lo guían hasta allá.
		await _play_dialogue("mulata_hacia_pared")
		_start_guide_to_wall()

	_release_player()


## El jugador interactuó con la Mulata. Según el progreso: diálogo inicial,
## recordatorio de que faltan hojas o final del nivel.
func _on_mulata_interacted() -> void:
	if _busy or GameState.has_flag(FLAG_LEVEL_DONE):
		return
	_busy = true
	player.can_move = false

	if _all_solved():
		# el final ocurre junto a la pared de piedra, no donde esté la
		# Mulata (ahora siempre está junto al jugador). Si el jugador le habla
		# con las tres hojas resueltas, ella lo invita otra vez a ir allá y se
		# reactivan las flechas.
		await _play_dialogue("mulata_hacia_pared")
		_start_guide_to_wall()
	elif not GameState.has_flag(FLAG_INTRO_SEEN):
		await _play_dialogue("mulata_inicio")
		GameState.set_flag(FLAG_INTRO_SEEN)
	else:
		await _play_dialogue("mulata_hoja_incompleta")

	_release_player()


## El jugador entró en la zona de salida. Si aún faltan hojas, la Mulata se
## lo recuerda. Solo reacciona al [Player]: otros cuerpos se ignoran.
## [param body] es el cuerpo que entró en la zona.
func _on_exit_zone_body_entered(body: Node2D) -> void:
	if not body is Player or _busy or _all_solved():
		return
	_busy = true
	player.can_move = false
	_log("Intento de salir sin las tres hojas")

	await _play_dialogue("mulata_hoja_incompleta")

	_release_player()


## Final del nivel: diálogo, barco completo, destello, carboncillo, guardado
## y apertura de la salida. No devuelve el control: lo hace quien lo invoca.
func _play_finale() -> void:
	if GameState.has_flag(FLAG_LEVEL_DONE):
		return

	await _play_dialogue("mulata_final")

	# Con las tres respuestas correctas el barco ya está completo; esto solo
	# garantiza que ninguna parte quede sin mostrar.
	boat.show_complete()

	await _play_culmination()

	Inventory.add_item(ITEM_CHARCOAL)
	GameState.set_flag(FLAG_LEVEL_DONE)
	_log("Nivel completo: carboncillo entregado")

	# La descripción del objeto sale de items.json.
	var context: String = String(Inventory.get_item_data(ITEM_CHARCOAL).get("context", ""))
	if not context.is_empty():
		scroll_message.show_text(context)

	# Con el carboncillo en mano se abre el camino hacia el nivel 2.
	_exit.enable()


## Efecto de culminación de la leyenda (provisional, sin imágenes nuevas): un
## destello blanco cubre la pantalla y, en su punto más alto, la Mulata y el
## barco desaparecen. Puede esperarse con [code]await[/code].
func _play_culmination() -> void:
	var tween_in: Tween = create_tween()
	tween_in.tween_property(flash, "modulate:a", 1.0, flash_in_time)
	await tween_in.finished

	# Con la pantalla en blanco nadie ve el cambio.
	mulata.fade_away(0.0)
	boat.hide()

	var tween_out: Tween = create_tween()
	tween_out.tween_property(flash, "modulate:a", 0.0, flash_out_time)
	await tween_out.finished


## El jugador cruzó la salida (ya pasó medio cuerpo): cambia al nivel 2. El
## inventario y las banderas viajan solos porque viven en autoloads.
func _on_exit_crossed() -> void:
	if _leaving:
		return
	_leaving = true
	player.can_move = false

	if exit_fade_time > 0.0:
		await SceneManager.fade_out(exit_fade_time)

	var error: Error = get_tree().change_scene_to_file(LEVEL_2_PATH)
	if error != OK:
		# Sin escena a la que ir, se devuelve el control para no dejar
		# bloqueado al jugador.
		push_error("Level1: no se pudo cargar " + LEVEL_2_PATH)
		if exit_fade_time > 0.0:
			SceneManager.fade_in(exit_fade_time)
		player.can_move = true
		_leaving = false


## Devuelve el control al jugador y libera el nivel para la siguiente
## secuencia.
func _release_player() -> void:
	player.can_move = true
	_busy = false


## Reproduce el bloque [param key] de [constant DIALOGUE_PATH] y espera a que
## el jugador lo cierre. Puede esperarse con [code]await[/code].
## [br]Mientras el cuadro está abierto el juego queda en pausa (lo gestiona el
## [DialogueManager]) y las líneas avanzan con Enter / Espacio.
func _play_dialogue(key: String) -> void:
	DialogueManager.play(DIALOGUE_PATH, key)

	# Si el bloque no existe o está vacío, el cuadro no se abre y nunca se
	# emite la señal de fin; se sale para no dejar al jugador bloqueado.
	if not DialogueManager.is_active():
		return

	await DialogueManager.dialogue_finished


## Indica si el acertijo [param riddle_id] ya fue resuelto.
func _is_solved(riddle_id: String) -> bool:
	return GameState.has_flag(FLAG_RIDDLE_PREFIX + riddle_id)


## Cuenta los acertijos resueltos.
func _solved_count() -> int:
	var count: int = 0
	for id: String in _riddles.keys():
		if _is_solved(id):
			count += 1
	return count


## Indica si todos los acertijos del archivo están resueltos.
func _all_solved() -> bool:
	return not _riddles.is_empty() and _solved_count() == _riddles.size()


## Actualiza el contador de hojas resueltas (X/N) del HUD.
func _update_counter() -> void:
	counter_label.text = "Hojas: %d/%d" % [_solved_count(), _riddles.size()]


## Carga [code]riddles.json[/code]. Devuelve un diccionario vacío si el
## archivo falta o tiene un formato inválido.
func _load_riddles() -> Dictionary:
	var file: FileAccess = FileAccess.open(RIDDLES_PATH, FileAccess.READ)
	if file == null:
		push_error("Level1: no se encontró " + RIDDLES_PATH)
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		return data
	push_error("Level1: formato inválido en " + RIDDLES_PATH)
	return {}


## Imprime un mensaje de depuración si [member debug_log] está activo.
func _log(message: String) -> void:
	if debug_log:
		print("[Nivel1] ", message)

func _physics_process(_delta: float) -> void:
	# detecta la llegada del jugador a la pared de piedra.
	_check_finale_arrival()

	if Input.is_action_just_pressed("interact"):
		print("E pulsada. can_move=", player.can_move)
		for n in get_tree().get_nodes_in_group("interactable"):
			print("  ", n.name, " script=", n.get_script().resource_path, " riddle_id=", n.get("riddle_id"))
