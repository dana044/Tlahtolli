## Cuadro de diálogo con efecto de máquina de escribir.
## Recibe líneas {"speaker": "...", "text": "..."}, pausa el juego
## mientras está abierto y avisa cuando termina.
extends CanvasLayer

## Se emite al terminar la última línea.
signal dialog_finished

## Label con el nombre de quien habla.
@export var speaker_label: Label
## Label con el texto del diálogo.
@export var text_label: RichTextLabel
## Segundos por letra (menor = más rápido).
@export_range(0.005, 0.2, 0.005) var seconds_per_character: float = 0.03
## Acción que avanza el diálogo (Enter / Espacio).
@export var advance_action: StringName = &"ui_accept"
## Si es true, el juego se pausa durante el diálogo.
@export var pause_game: bool = true

var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _tween: Tween


func _ready() -> void:
	hide()


## Inicia un diálogo con la lista de líneas.
func start(new_lines: Array) -> void:
	if new_lines.is_empty():
		return
	_lines = new_lines
	_index = 0
	show()
	if pause_game:
		get_tree().paused = true
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	speaker_label.text = line.get("speaker", "")
	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	_typing = true
	if _tween:
		_tween.kill()
	# Que el efecto funcione aunque el juego esté en pausa.
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var total := text_label.get_total_character_count()
	_tween.tween_property(text_label, "visible_characters", total, seconds_per_character * total)
	_tween.finished.connect(func(): _typing = false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(advance_action):
		get_viewport().set_input_as_handled()
		if _typing:
			# Primer toque: mostrar todo el texto.
			if _tween:
				_tween.kill()
			text_label.visible_characters = -1
			_typing = false
		else:
			# Segundo toque: siguiente línea o cerrar.
			_index += 1
			if _index >= _lines.size():
				_close()
			else:
				_show_line()


func _close() -> void:
	hide()
	if pause_game:
		get_tree().paused = false
	dialog_finished.emit()
