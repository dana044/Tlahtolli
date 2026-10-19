## Interfaz del diario de pistas. Se abre con la acción "open_journal" (Tab)
## o con el botón "?". Muestra solo las pistas que corresponden al nivel
## actual y avisa cuando llega una nueva.
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
## sea menor o igual a este número. Se cambia en el Inspector de cada nivel.
@export_range(1, 3) var current_level: int = 1
## Si es true, al entrar al nivel se desbloquean las pistas que le
## corresponden, sin importar si el jugador pasó por la intro. Sirve para
## probar un nivel suelto con F6 o como respaldo. No muestra el aviso.
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
## Contenedor que agrupa el botón y el aviso (el HBoxContainer). Asígnalo en
## el Inspector: es el que se coloca a la izquierda, a media altura.
@export var button_row: Control
## Tamaño del botón en píxeles.
@export var journal_button_size: Vector2 = Vector2(70, 70)
## Separación respecto al borde izquierdo de la pantalla.
@export var journal_button_margin: int = 12

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


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if book == null: missing.append("Book")
	if entries_box == null: missing.append("Entries Box")
	if toast_label == null: missing.append("Toast Label")
	if not missing.is_empty():
		push_error("JournalUI: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	_setup_journal_button()
	_apply_theme()
	book.hide()
	toast_label.hide()
	toast_label.modulate.a = 0.0

	# Va antes de conectar la señal, para que no salga el aviso de "nueva pista".
	if auto_unlock_level_clues:
		for entry in Journal.entries:
			if _is_in_current_level(entry):
				Journal.unlock(entry["id"])

	Journal.clue_unlocked.connect(_on_clue_unlocked)


## Coloca el botón "?" en el borde izquierdo, a media altura, con el tamaño
## indicado en journal_button_size.
func _setup_journal_button() -> void:
	if journal_button == null:
		return
	# Sin foco, para que Espacio/Enter (que avanzan diálogos) no lo activen.
	journal_button.focus_mode = Control.FOCUS_NONE
	journal_button.ignore_texture_size = true
	journal_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	journal_button.custom_minimum_size = journal_button_size
	# Evita que el contenedor estire el botón más allá de su tamaño.
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	journal_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	journal_button.pressed.connect(open)

## El botón solo se ve con el juego corriendo (no en pausa, diálogo ni diario).
func _process(_delta: float) -> void:
	if journal_button == null:
		return
	journal_button.visible = not get_tree().paused


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


## Aplica color de letra y, si hay, la tipografía a todo el diario con un
## Theme heredado por los hijos. El color se aplica siempre, tenga o no fuente.
func _apply_theme() -> void:
	var diary_theme := Theme.new()
	if journal_font != null:
		diary_theme.default_font = journal_font
	diary_theme.set_color("font_color", "Label", font_color)
	book.theme = diary_theme


## ¿Esta pista corresponde al nivel actual?
func _is_in_current_level(entry: Dictionary) -> bool:
	return int(entry.get("level", 1)) <= current_level


## Busca una pista por id. Devuelve {} si no existe.
func _find_entry(id: String) -> Dictionary:
	for entry in Journal.entries:
		if entry.get("id", "") == id:
			return entry
	return {}


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
