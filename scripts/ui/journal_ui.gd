## Interfaz del diario de pistas. Se abre con J (acción "open_journal").
## Muestra las pistas desbloqueadas y avisa cuando llega una nueva.
extends CanvasLayer

## Tipografía del diario (título, entradas e indicaciones). Si está vacía,
## se usa la fuente por defecto del proyecto.
@export var journal_font: Font
## Color de la letra para todas las entradas del diario.
@export var font_color: Color = Color("3b2314")
## Panel completo del diario. Asígnalo en el Inspector.
@export var book: Control
## Contenedor donde se crean las entradas. Asígnalo en el Inspector.
@export var entries_box: VBoxContainer
## Aviso breve de "nueva pista". Asígnalo en el Inspector.
@export var toast_label: Label
## Acción que abre/cierra el diario.
@export var toggle_action: StringName = &"open_journal"
## Si es true, las pistas aún no descubiertas salen como "???".
@export var show_locked_entries: bool = true
## Título de una pista bloqueada.
@export var locked_title: String = "???"
## Texto de una pista bloqueada.
@export var locked_text: String = "Aún no conozco esta pista."
## Tamaños de letra.
@export_range(8, 48) var title_font_size: int = 22
@export_range(8, 32) var body_font_size: int = 16
## Segundos que se ve el aviso de nueva pista.
@export_range(1.0, 10.0, 0.5) var toast_seconds: float = 3.0

var _toast_tween: Tween


func _ready() -> void:
	_apply_font()
	book.hide()
	toast_label.hide()
	toast_label.modulate.a = 0.0
	Journal.clue_unlocked.connect(_on_clue_unlocked)

## Aplica la tipografía a todo el diario con un Theme. Un Theme asignado a
## 'book' se hereda por todos sus hijos, incluidas las entradas creadas
## por código, y también por TitleLabel y HintLabel.
func _apply_font() -> void:
	if journal_font == null:
		return
	var diary_theme := Theme.new()
	diary_theme.default_font = journal_font
	diary_theme.set_color("font_color", "Label", font_color)
	book.theme = diary_theme
	
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


## Dibuja de nuevo todas las entradas.
func _rebuild_entries() -> void:
	for child in entries_box.get_children():
		child.queue_free()
	for entry in Journal.entries:
		var unlocked := Journal.is_unlocked(entry.get("id", ""))
		if not unlocked and not show_locked_entries:
			continue
		if unlocked:
			_add_entry(entry.get("title", ""), entry.get("text", ""), false)
		else:
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


## Muestra el aviso "Nueva pista" con fundido.
func _on_clue_unlocked(_clue_id: String) -> void:
	toast_label.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(toast_seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast_label.hide)
