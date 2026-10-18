## Cuadro de diálogo con efecto de máquina de escribir.
## Recibe líneas {"speaker": "...", "text": "..."}, pausa el juego mientras
## está abierto y avisa cuando termina. Cada línea pasa sola tras unos
## segundos, o de inmediato con la tecla de avance (Espacio).
extends CanvasLayer

## Se emite al terminar la última línea.
signal dialog_finished

## Label con el nombre de quien habla.
@export var speaker_label: Label
## Label con el texto del diálogo.
@export var text_label: RichTextLabel
## Label opcional con la indicación de la tecla (puede quedar vacío).
@export var hint_label: Label
## Texto de la indicación.
@export var hint_text: String = "Espacio para continuar"
## Segundos por letra (menor = más rápido).
@export_range(0.005, 0.2, 0.005) var seconds_per_character: float = 0.03
## Segundos que espera, con la línea ya escrita, antes de pasar a la
## siguiente por sí sola. Con 0 nunca avanza sola.
@export_range(0.0, 15.0, 0.5) var auto_advance_seconds: float = 3.0
## Acción que avanza el diálogo. "ui_accept" incluye Espacio y Enter.
@export var advance_action: StringName = &"ui_accept"
## Si es true, el juego se pausa durante el diálogo.
@export var pause_game: bool = true

var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _tween: Tween
var _auto_token: int = 0   # Invalida temporizadores de avance automático viejos.


func _ready() -> void:
	hide()
	if hint_label != null:
		hint_label.hide()


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
	_auto_token += 1
	var line: Dictionary = _lines[_index]
	speaker_label.text = line.get("speaker", "")
	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	if hint_label != null:
		hint_label.hide()
	_typing = true

	if _tween:
		_tween.kill()
	# Que el efecto funcione aunque el juego esté en pausa.
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var total := text_label.get_total_character_count()
	_tween.tween_property(text_label, "visible_characters", total, seconds_per_character * total)
	_tween.finished.connect(_on_line_finished)


## La línea ya se escribió completa: muestra la indicación y arranca la cuenta
## regresiva del avance automático.
func _on_line_finished() -> void:
	_typing = false
	if hint_label != null:
		hint_label.text = hint_text
		hint_label.show()
	_start_auto_advance()


func _start_auto_advance() -> void:
	if auto_advance_seconds <= 0.0:
		return
	_auto_token += 1
	var my_token := _auto_token
	# Este temporizador sí corre con el juego pausado (el diálogo lo pausa).
	await get_tree().create_timer(auto_advance_seconds).timeout
	# Si el jugador ya avanzó, o el cuadro se cerró, no hace nada.
	if my_token != _auto_token or not visible or _typing:
		return
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(advance_action):
		get_viewport().set_input_as_handled()
		if _typing:
			# Primer toque: mostrar todo el texto de golpe.
			if _tween:
				_tween.kill()
			text_label.visible_characters = -1
			_on_line_finished()
		else:
			# Segundo toque: siguiente línea o cerrar.
			_advance()


## Pasa a la siguiente línea o cierra el diálogo.
func _advance() -> void:
	_auto_token += 1
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	_auto_token += 1
	hide()
	if hint_label != null:
		hint_label.hide()
	if pause_game:
		get_tree().paused = false
	dialog_finished.emit()
