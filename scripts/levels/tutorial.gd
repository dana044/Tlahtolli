## Escena de tutorial. Enseña los controles paso a paso, mostrando la imagen
## de cada tecla solo cuando toca:
##   1. W, A, S, D: se iluminan al usarse; al probar las cuatro, pasa al siguiente.
##   2. Esc: abrir y cerrar el menú de pausa.
##   3. Tab: abrir y cerrar el diario de pistas.
##   4. E: recoger un objeto.
##   5. Final: Enter para volver al menú.
extends Node2D

## Pasos del tutorial, en orden.
enum Step { MOVE, PAUSE, JOURNAL, INTERACT, DONE }

## Acciones de movimiento del Mapa de entrada (las mismas que usa el Player).
const MOVE_ACTIONS: Array[String] = ["move_up", "move_left", "move_down", "move_right"]


@export_group("Escenas")
## Escena a la que se vuelve al terminar el tutorial.
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main/main_menu.tscn"

@export_group("Nodos de la escena")
## Fondo de pasto (Sprite2D). Define los límites del mapa.
@export var background: Sprite2D
## Jugador de la escena.
@export var player: Player
## Objeto que se recoge en el paso de la tecla E (la muñeca).
@export var pickup: Node2D
## Menú de pausa de la escena (se lee su variable "is_open").
@export var pause_menu: CanvasLayer

@export_group("Imágenes de teclas")
@export var tex_w: Texture2D
@export var tex_a: Texture2D
@export var tex_s: Texture2D
@export var tex_d: Texture2D
@export var tex_esc: Texture2D
@export var tex_tab: Texture2D
@export var tex_e: Texture2D = preload("res://assets/sprites/ui/teclaE.png")
## Tamaño de cada tecla en pantalla.
@export var key_size: Vector2 = Vector2(64, 64)
## Separación entre teclas.
@export var key_spacing: int = 6
## Si es true, las teclas se dibujan con filtro "nearest" (pixel art nítido).
@export var pixel_art: bool = true
## Color de una tecla de movimiento que aún no se ha usado.
@export var key_idle_color: Color = Color(1, 1, 1, 0.55)
## Color de una tecla de movimiento que ya se usó.
@export var key_pressed_color: Color = Color(0.7, 1.0, 0.7, 1.0)

@export_group("Textos")
@export var text_move: String = "Muévete con W, A, S y D"
@export var text_pause: String = "Presiona Esc para abrir la pausa. Vuelve a presionarla para continuar"
@export var text_journal: String = "Presiona Tab para ver tu diario de pistas. Vuelve a presionarla para cerrarlo"
@export var text_interact: String = "Acércate al objeto y presiona E para recogerlo"
@export var text_done: String = "¡Listo! Ya sabes cómo jugar"
@export var text_done_hint: String = "Presiona Enter para volver al menú"

@export_group("Tipografía de los textos")
## Fuente de los textos. Vacía = la fuente por defecto del proyecto.
@export var label_font: Font
@export_range(8, 64) var label_font_size: int = 24
## Contorno negro para que se lea sobre el pasto.
@export_range(0, 12) var label_outline_size: int = 5
## Ancho máximo de los textos antes de saltar de línea.
@export var text_width: float = 600.0

@export_group("Escenario y avisos")
## Si es true, el jugador lleva la linterna encendida.
@export var lantern_enabled: bool = false
## Dónde aparece el objeto respecto al jugador.
@export var pickup_offset: Vector2 = Vector2(140, 0)
## Separación de los avisos respecto al borde inferior de la pantalla.
@export var hud_bottom_margin: int = 48
## Segundos de cada fundido entre pasos.
@export_range(0.05, 1.5, 0.05) var fade_seconds: float = 0.3
## Segundos que se ve el paso completado antes de pasar al siguiente.
@export_range(0.0, 3.0, 0.1) var done_hold_seconds: float = 0.7


var _step: Step = Step.MOVE
var _transitioning: bool = false

var _hud: CanvasLayer
var _margin: MarginContainer
var _step_boxes: Dictionary = {}   # Step -> Control
var _move_keys: Dictionary = {}    # acción -> tecla (Control)
var _move_done: Dictionary = {}    # acción -> bool

var _pause_seen_open: bool = false
var _journal_seen_open: bool = false


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if background == null: missing.append("Background")
	if player == null: missing.append("Player")
	if pickup == null: missing.append("Pickup")
	if pause_menu == null: missing.append("Pause Menu")
	if not missing.is_empty():
		push_error("Tutorial: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	_setup_stage()
	_build_hud()

	Inventory.item_added.connect(_on_item_added)
	# process_frame se emite en cada fotograma, incluso con el juego en pausa:
	# así se detecta cuándo se abre y se cierra el menú o el diario.
	get_tree().process_frame.connect(_poll)

	_show_step(Step.MOVE)


#region Escenario

## Centra al jugador en el fondo, limita el mapa y esconde el objeto hasta
## el paso de la tecla E.
func _setup_stage() -> void:
	var bounds := Rect2()
	if background.texture != null:
		bounds = background.get_global_transform() * background.get_rect()
	if bounds.has_area():
		player.global_position = bounds.get_center()
		player.set_world_bounds(bounds)
	player.set_lantern_enabled(lantern_enabled)

	pickup.global_position = player.global_position + pickup_offset
	# Oculto, el Player no puede interactuar con él.
	pickup.hide()

#endregion


#region Construcción de los avisos

## Crea todos los avisos (uno por paso). Solo se muestra el del paso actual.
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 4   # Debajo del diálogo (5), el diario (9) y la pausa (10).
	add_child(_hud)

	_margin = MarginContainer.new()
	_hud.add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_theme_constant_override("margin_bottom", hud_bottom_margin)

	_step_boxes[Step.MOVE] = _make_move_box()
	_step_boxes[Step.PAUSE] = _make_single_key_box(tex_esc, "Esc", text_pause)
	_step_boxes[Step.JOURNAL] = _make_single_key_box(tex_tab, "Tab", text_journal)
	_step_boxes[Step.INTERACT] = _make_single_key_box(tex_e, "E", text_interact)
	_step_boxes[Step.DONE] = _make_done_box()


## Contenedor vacío de un paso, oculto y pegado abajo al centro.
func _new_step_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	box.modulate.a = 0.0
	box.hide()
	_margin.add_child(box)
	return box


## Paso 1: W arriba y A, S, D abajo, con el texto debajo.
func _make_move_box() -> Control:
	var box := _new_step_box()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", key_spacing)
	grid.add_theme_constant_override("v_separation", key_spacing)
	grid.add_child(_make_spacer())
	grid.add_child(_make_move_key("move_up", tex_w, "W"))
	grid.add_child(_make_spacer())
	grid.add_child(_make_move_key("move_left", tex_a, "A"))
	grid.add_child(_make_move_key("move_down", tex_s, "S"))
	grid.add_child(_make_move_key("move_right", tex_d, "D"))
	box.add_child(grid)
	box.add_child(_make_label(text_move))
	return box


## Pasos 2 a 4: una sola tecla con su texto debajo.
func _make_single_key_box(texture: Texture2D, fallback: String, text: String) -> Control:
	var box := _new_step_box()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_make_key(texture, fallback))
	box.add_child(row)
	box.add_child(_make_label(text))
	return box


## Paso final: mensaje y la indicación para salir.
func _make_done_box() -> Control:
	var box := _new_step_box()
	box.add_child(_make_label(text_done))
	box.add_child(_make_label(text_done_hint))
	return box


## Tecla de movimiento: empieza atenuada y se registra para iluminarse.
func _make_move_key(action: String, texture: Texture2D, fallback: String) -> Control:
	var key := _make_key(texture, fallback)
	key.modulate = key_idle_color
	_move_keys[action] = key
	_move_done[action] = false
	return key


## Imagen de una tecla. Si falta la textura, dibuja una cajita con la letra.
func _make_key(texture: Texture2D, fallback: String) -> Control:
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.custom_minimum_size = key_size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if pixel_art:
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return rect

	var panel := PanelContainer.new()
	panel.custom_minimum_size = key_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_label(fallback)
	label.custom_minimum_size = Vector2.ZERO
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


## Espacio vacío del tamaño de una tecla (para la cruz de WASD).
func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = key_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Texto centrado con la tipografía configurada.
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(text_width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label_font != null:
		label.add_theme_font_override("font", label_font)
	label.add_theme_font_size_override("font_size", label_font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", label_outline_size)
	return label

#endregion


#region Avance de los pasos

## Muestra el aviso de [param step] con un fundido de entrada.
func _show_step(step: Step) -> void:
	_step = step
	if step == Step.INTERACT and is_instance_valid(pickup):
		pickup.show()

	var box: Control = _step_boxes[step]
	box.modulate.a = 0.0
	box.show()
	create_tween().tween_property(box, "modulate:a", 1.0, fade_seconds)


## Da por completado el paso actual: lo tiñe de verde, lo desvanece y muestra
## el siguiente.
func _complete_step() -> void:
	if _transitioning or _step == Step.DONE:
		return
	_transitioning = true

	var finished: Control = _step_boxes[_step]
	finished.modulate = Color(0.75, 1.0, 0.75, 1.0)
	var next_step: Step = (_step + 1) as Step

	var tween := create_tween()
	tween.tween_interval(done_hold_seconds)
	tween.tween_property(finished, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(func():
		finished.hide()
		_transitioning = false
		_show_step(next_step))


## Revisa en cada fotograma si se cumplió el paso actual.
func _poll() -> void:
	if not is_inside_tree() or _transitioning:
		return
	match _step:
		Step.MOVE:
			# Con el juego en pausa no cuenta lo que se presione.
			if not get_tree().paused:
				_poll_movement()
		Step.PAUSE:
			# Se completa al abrir y volver a cerrar el menú de pausa.
			if bool(pause_menu.get("is_open")):
				_pause_seen_open = true
			elif _pause_seen_open:
				_complete_step()
		Step.JOURNAL:
			# Se completa al abrir y volver a cerrar el diario.
			if Journal.is_open:
				_journal_seen_open = true
			elif _journal_seen_open:
				_complete_step()


## Ilumina cada tecla de movimiento al usarla; al probar las cuatro, avanza.
func _poll_movement() -> void:
	for action in MOVE_ACTIONS:
		if not _move_done[action] and Input.is_action_pressed(action):
			_move_done[action] = true
			(_move_keys[action] as Control).modulate = key_pressed_color
	if not _move_done.values().has(false):
		_complete_step()


## Al recoger cualquier objeto durante el paso de la tecla E, avanza.
func _on_item_added(_item_id: String) -> void:
	if _step == Step.INTERACT:
		_complete_step()


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.DONE and not _transitioning and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_exit_tutorial()


## Borra lo recogido en el tutorial y vuelve al menú principal.
func _exit_tutorial() -> void:
	Inventory.clear()
	Journal.clear()
	if ResourceLoader.exists(main_menu_scene):
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		push_warning("Tutorial: no existe " + main_menu_scene)

## Al salir de la escena se desconecta la revisión por fotograma.
func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.process_frame.is_connected(_poll):
		tree.process_frame.disconnect(_poll)
#endregion
