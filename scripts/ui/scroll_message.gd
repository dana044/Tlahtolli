## Pergamino con un mensaje que aparece arriba a la derecha.
## Cada nivel instancia esta escena y escribe el id del mensaje en el Inspector.
## También se puede llamar desde código: $ScrollMessage.show_message("otro_id")
extends CanvasLayer

## Archivo con los textos: { "id": "texto" }.
@export_file("*.json") var messages_path: String = "res://data/messages.json"
## Id del mensaje que se muestra al entrar a la escena (dejar vacío para no mostrar ninguno).
@export var message_id: String = ""
## Si es true, el mensaje aparece solo al cargar la escena.
@export var show_on_ready: bool = true
## Segundos de espera antes de mostrarlo al entrar.
@export_range(0.0, 10.0, 0.1) var start_delay: float = 0.5
## Segundos que permanece visible.
@export_range(1.0, 30.0, 0.5) var display_seconds: float = 6.0
## Segundos que tardan el fundido de entrada y salida.
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.4

## Pergamino completo (NinePatchRect). Asígnalo en el Inspector.
@export var banner: Control
## Label donde se escribe el texto. Asígnalo en el Inspector.
@export var message_label: Label

var _messages: Dictionary = {}
var _tween: Tween


func _ready() -> void:
	_load_messages()
	banner.modulate.a = 0.0
	banner.hide()
	if show_on_ready and message_id != "":
		await get_tree().create_timer(start_delay).timeout
		show_message(message_id)


## Muestra el mensaje con ese id. Si 'seconds' es negativo usa display_seconds.
func show_message(id: String, seconds: float = -1.0) -> void:
	if not _messages.has(id):
		push_warning("ScrollMessage: no existe el mensaje '%s'" % id)
		return
	message_label.text = _messages[id]
	var duration := display_seconds if seconds < 0.0 else seconds

	if _tween:
		_tween.kill()
	banner.show()
	# TWEEN_PAUSE_PROCESS: funciona aunque el juego esté en pausa.
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(banner, "modulate:a", 1.0, fade_seconds)
	_tween.tween_interval(duration)
	_tween.tween_property(banner, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(banner.hide)


## Oculta el mensaje de inmediato.
func hide_message() -> void:
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
