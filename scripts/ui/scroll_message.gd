## Pergamino con mensajes que aparecen arriba a la derecha.
## Puede mostrar uno solo o una cadena (message_id + follow_up_ids).
## Respeta la pausa: con el juego pausado, el mensaje se congela y los
## siguientes no salen hasta reanudar.
class_name ScrollMessage
extends CanvasLayer

## Se emite cuando termina de mostrarse un mensaje.
signal message_finished
## Se emite cuando termina toda la cadena de mensajes.
signal sequence_finished

## Archivo con los textos: { "id": "texto" }.
@export_file("*.json") var messages_path: String = "res://data/messages.json"
## Primer mensaje que se muestra al entrar a la escena (vacío = ninguno).
@export var message_id: String = ""
## Mensajes que salen después del primero, en orden.
@export var follow_up_ids: Array[String] = []
## Si es true, la cadena empieza sola al cargar la escena. Si el nivel la
## lanza por código (play_configured_sequence), déjalo en false.
@export var show_on_ready: bool = true
## Segundos de espera antes del primer mensaje.
@export_range(0.0, 10.0, 0.1) var start_delay: float = 0.5
## Segundos que permanece visible cada mensaje.
@export_range(1.0, 30.0, 0.5) var display_seconds: float = 6.0
## Segundos que dura el fundido de entrada y salida.
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.4
## Segundos de pausa entre un mensaje y el siguiente.
@export_range(0.0, 5.0, 0.1) var gap_seconds: float = 0.6

## Pergamino completo (NinePatchRect). Asígnalo en el Inspector.
@export var banner: Control
## Label donde se escribe el texto. Asígnalo en el Inspector.
@export var message_label: Label

var _messages: Dictionary = {}
var _tween: Tween
var _token: int = 0   # Sirve para cancelar una cadena en curso.


func _ready() -> void:
	_load_messages()
	banner.modulate.a = 0.0
	banner.hide()
	if show_on_ready:
		# El 'false' hace que el temporizador se detenga con la pausa.
		await get_tree().create_timer(start_delay, false).timeout
		play_configured_sequence()


## Muestra message_id y luego los follow_up_ids, tal como están en el Inspector.
func play_configured_sequence() -> void:
	if message_id == "":
		return
	var ids: Array[String] = [message_id]
	ids.append_array(follow_up_ids)
	await show_sequence(ids)


## Muestra varios mensajes uno tras otro.
func show_sequence(ids: Array[String]) -> void:
	_token += 1
	var my_token := _token
	for id in ids:
		await show_message(id)
		if my_token != _token:
			return
		await get_tree().create_timer(gap_seconds, false).timeout
		if my_token != _token:
			return
	sequence_finished.emit()


## Muestra un mensaje. Si 'seconds' es negativo usa display_seconds.
func show_message(id: String, seconds: float = -1.0) -> void:
	if not _messages.has(id):
		push_warning("ScrollMessage: no existe el mensaje '%s'" % id)
		return
	message_label.text = _messages[id]
	var duration := display_seconds if seconds < 0.0 else seconds

	if _tween:
		_tween.kill()
	banner.show()
	# Tween normal: se detiene cuando el árbol está en pausa.
	_tween = create_tween()
	_tween.tween_property(banner, "modulate:a", 1.0, fade_seconds)
	_tween.tween_interval(duration)
	_tween.tween_property(banner, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(banner.hide)
	await _tween.finished
	message_finished.emit()


## Oculta todo de inmediato y cancela la cadena.
func hide_message() -> void:
	_token += 1
	if _tween:
		_tween.kill()
	banner.modulate.a = 0.0
	banner.hide()


func _load_messages() -> void:
	var file := FileAccess.open(messages_path, FileAccess.READ)
	if file == null:
		push_error("ScrollMessage: no se encontró " + messages_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		_messages = data
	else:
		push_error("ScrollMessage: formato inválido en " + messages_path)
