## Interfaz del diario de pistas. Se abre con la acción "open_journal" (Tab)
## o con el botón "?". Muestra solo las pistas del nivel actual, avisa cuando
## llega una nueva y muestra la misión en curso a la izquierda de la pantalla.
class_name JournalUI
extends CanvasLayer

## Panel completo del diario. Asígnalo en el Inspector.
@export var book: Control
## Contenedor donde se crean las entradas. Asígnalo en el Inspector.
@export var entries_box: VBoxContainer
## Aviso breve de "nueva pista". Asígnalo en el Inspector.
@export var toast_label: Label
## Acción que abre/cierra el diario.
@export var toggle_action: StringName = &"open_journal"

@export_group("Nivel")
## Nivel en el que está esta instancia del diario (1 = Mulata, 2 = Llorona,
## 3 = Chaneque). Solo se muestran las pistas cuyo "level" en journal.json
## sea menor o igual a este número. El script de cada nivel también puede
## fijarlo con set_level().
@export_range(1, 3) var current_level: int = 1
## Si es true, al entrar al nivel se desbloquean las pistas que le
## corresponden, sin importar si el jugador pasó por la intro. No muestra el
## aviso de "nueva pista".
@export var auto_unlock_level_clues: bool = false
## Si es true, las pistas del nivel aún no descubiertas salen como "???".
@export var show_locked_entries: bool = true
## Título de una pista bloqueada.
@export var locked_title: String = "???"
## Texto de una pista bloqueada.
@export var locked_text: String = "Aún no conozco esta pista."

@export_group("Botón de pistas (?)")
## Botón que abre el diario. Asígnalo en el Inspector.
@export var journal_button: TextureButton
## Contenedor que agrupa el botón y el aviso (el HBoxContainer).
@export var button_row: Control
## Tamaño del botón en píxeles (el mismo que el botón de pausa).
@export var journal_button_size: Vector2 = Vector2(70, 70)
## Separación respecto al borde izquierdo de la pantalla.
@export var journal_button_margin: int = 18
## Distancia desde el borde superior de la pantalla. 
@export var journal_button_top: int = 100

@export_group("Misión")
## Label donde se escribe la misión. Asígnalo en el Inspector.
@export var mission_label: Label
## Archivo con los textos de las misiones (el mismo de los mensajes).
@export_file("*.json") var messages_path: String = "res://data/messages.json"
## Id de la misión que se muestra al entrar al nivel (vacío = ninguna). El
## script del nivel puede cambiarla con set_mission().
@export var mission_id: String = ""
## Tamaño de letra de la misión.
@export_range(8, 64) var mission_font_size: int = 30
## Color de la letra de la misión.
@export var mission_color: Color = Color.WHITE
## Grosor del contorno negro que ayuda a leer sobre cualquier fondo.
@export_range(0, 12) var mission_outline_size: int = 6
## Ancho máximo del texto antes de saltar de línea, en píxeles.
@export var mission_width: float = 360.0
## Separación entre el botón "?" y la misión, en píxeles.
@export var mission_gap: int = 12

@export_group("Apariencia")
## Color de la letra para todas las entradas del diario.
@export var font_color: Color = Color("3b2314")
## Tipografía del diario. Si está vacía, usa la fuente por defecto del proyecto.
@export var journal_font: Font
## Tamaño de letra del título de cada pista.
@export_range(8, 48) var title_font_size: int = 22
## Tamaño de letra del texto de cada pista.
@export_range(8, 32) var body_font_size: int = 16
## Segundos que se ve el aviso de nueva pista.
@export_range(1.0, 10.0, 0.5) var toast_seconds: float = 3.0

var _toast_tween: Tween
var _messages: Dictionary = {}
## true mientras hay una misión que mostrar.
var _mission_active: bool = false
## true durante un desbloqueo masivo, para no mostrar avisos de "nueva pista".
var _silent_unlock: bool = false


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if book == null: missing.append("Book")
	if entries_box == null: missing.append("Entries Box")
	if toast_label == null: missing.append("Toast Label")
	if not missing.is_empty():
		push_error("JournalUI: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	_load_messages()
	_setup_journal_button()
	_setup_mission_label()
	set_mission(mission_id)
	_apply_theme()

	book.hide()
	toast_label.hide()
	toast_label.modulate.a = 0.0

	if auto_unlock_level_clues:
		_unlock_level_clues()

	Journal.clue_unlocked.connect(_on_clue_unlocked)


#region Nivel y pistas

## Fija el nivel del diario desde el script del nivel. Con
## [param unlock_clues] en true también desbloquea, sin avisos, todas las
## pistas que corresponden a ese nivel o a los anteriores.
func set_level(level: int, unlock_clues: bool = false) -> void:
	current_level = clampi(level, 1, 3)
	if unlock_clues:
		_unlock_level_clues()


## Desbloquea las pistas del nivel actual sin mostrar el aviso.
func _unlock_level_clues() -> void:
	if Journal.entries.is_empty():
		push_warning("JournalUI: Journal.entries está vacío; revisa data/journal.json.")
		return
	_silent_unlock = true
	for entry in Journal.entries:
		if _is_in_current_level(entry):
			Journal.unlock(entry["id"])
	_silent_unlock = false


## ¿Esta pista corresponde al nivel actual?
func _is_in_current_level(entry: Dictionary) -> bool:
	return int(entry.get("level", 1)) <= current_level


## Busca una pista por id. Devuelve {} si no existe.
func _find_entry(id: String) -> Dictionary:
	for entry in Journal.entries:
		if entry.get("id", "") == id:
			return entry
	return {}

#endregion


#region Botón "?"

## Coloca el botón "?" en la esquina superior izquierda, justo debajo del
## botón de pausa.
func _setup_journal_button() -> void:
	if journal_button == null:
		return
	# Sin foco, para que Espacio/Enter (que avanzan diálogos) no lo activen.
	journal_button.focus_mode = Control.FOCUS_NONE
	journal_button.ignore_texture_size = true
	journal_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	journal_button.custom_minimum_size = journal_button_size
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	journal_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	journal_button.pressed.connect(open)

	if button_row != null:
		button_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button_row.position = Vector2(journal_button_margin, journal_button_top)

## El botón y la misión solo se ven con el juego corriendo (no durante la
## pausa, los diálogos ni con el diario abierto).
func _process(_delta: float) -> void:
	var running: bool = not get_tree().paused
	if journal_button != null:
		journal_button.visible = running
	if mission_label != null:
		mission_label.visible = running and _mission_active

#endregion


#region Misión

## Da estilo y posición al texto de la misión: esquina superior izquierda,
## debajo del botón "?".
func _setup_mission_label() -> void:
	if mission_label == null:
		return
	mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if journal_font != null:
		mission_label.add_theme_font_override("font", journal_font)
	mission_label.add_theme_font_size_override("font_size", mission_font_size)
	mission_label.add_theme_color_override("font_color", mission_color)
	mission_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mission_label.add_theme_constant_override("outline_size", mission_outline_size)

	# Anclada arriba a la izquierda; crece hacia abajo.
	mission_label.anchor_left = 0.0
	mission_label.anchor_right = 0.0
	mission_label.anchor_top = 0.0
	mission_label.anchor_bottom = 0.0
	mission_label.offset_left = journal_button_margin
	mission_label.offset_right = journal_button_margin + mission_width
	mission_label.offset_top = journal_button_top + journal_button_size.y + mission_gap
	mission_label.offset_bottom = mission_label.offset_top
	mission_label.grow_vertical = Control.GROW_DIRECTION_END


## Muestra la misión con ese id (de messages.json). Con un id vacío o que no
## existe, oculta el texto. La llama el script del nivel cuando la misión cambia.
func set_mission(id: String) -> void:
	if mission_label == null:
		return
	if id == "" or not _messages.has(id):
		if id != "":
			push_warning("JournalUI: no existe la misión '%s' en messages.json" % id)
		_mission_active = false
		mission_label.hide()
		return
	mission_label.text = _messages[id]
	_mission_active = true
	mission_label.show()


func _load_messages() -> void:
	var file := FileAccess.open(messages_path, FileAccess.READ)
	if file == null:
		push_error("JournalUI: no se encontró " + messages_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		_messages = data

#endregion


#region Abrir y cerrar

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		if book.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif book.visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Abre el diario (no si el juego ya está pausado por un diálogo o la pausa).
func open() -> void:
	if get_tree().paused:
		return
	_rebuild_entries()
	book.show()
	get_tree().paused = true
	Journal.is_open = true


func close() -> void:
	book.hide()
	get_tree().paused = false
	Journal.is_open = false

#endregion


#region Dibujo de las entradas

## Aplica color de letra y, si hay, la tipografía a todo el diario con un
## Theme heredado por los hijos.
func _apply_theme() -> void:
	var diary_theme := Theme.new()
	if journal_font != null:
		diary_theme.default_font = journal_font
	diary_theme.set_color("font_color", "Label", font_color)
	book.theme = diary_theme


## Dibuja de nuevo las entradas del nivel actual.
func _rebuild_entries() -> void:
	for child in entries_box.get_children():
		child.queue_free()
	for entry in Journal.entries:
		if not _is_in_current_level(entry):
			continue
		var unlocked := Journal.is_unlocked(entry.get("id", ""))
		if unlocked:
			_add_entry(entry.get("title", ""), entry.get("text", ""), false)
		elif show_locked_entries:
			_add_entry(locked_title, locked_text, true)


func _add_entry(title_text: String, body_text: String, locked: bool) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", title_font_size)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", body_font_size)

	box.add_child(title)
	box.add_child(body)
	box.add_child(HSeparator.new())
	if locked:
		box.modulate.a = 0.5
	entries_box.add_child(box)


## Muestra el aviso "Nueva pista" (solo si la pista pertenece a este nivel).
func _on_clue_unlocked(clue_id: String) -> void:
	if _silent_unlock:
		return
	var entry := _find_entry(clue_id)
	if entry.is_empty() or not _is_in_current_level(entry):
		return
	toast_label.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(toast_seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast_label.hide)

#endregion
