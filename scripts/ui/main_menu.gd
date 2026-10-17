## Menú de inicio sin botones.
## Se avanza al primer nivel presionando una tecla (Espacio por defecto).
extends Control

## Primera escena del juego.
@export_file("*.tscn") var first_scene: String = "res://scenes/ui/test_ui.tscn"
## Tecla que inicia el juego.
@export var start_key: Key = KEY_SPACE
## Label inferior con la instrucción. Asígnalo en el Inspector.
@export var prompt_label: Label
## Si es true, el texto de la instrucción parpadea suavemente.
@export var blink_prompt: bool = true
## Segundos que dura cada parpadeo.
@export_range(0.2, 3.0, 0.1) var blink_seconds: float = 1.0

var _started: bool = false   # Evita cambiar de escena dos veces.


func _ready() -> void:
	if blink_prompt and prompt_label:
		_start_blink()


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == start_key:
		_started = true
		_go_to(first_scene)


## Hace que el texto suba y baje de opacidad en bucle.
func _start_blink() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(prompt_label, "modulate:a", 0.3, blink_seconds)
	tween.tween_property(prompt_label, "modulate:a", 1.0, blink_seconds)


## Cambia de escena solo si existe (evita errores mientras el equipo las termina).
func _go_to(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("Menú: la escena aún no existe -> " + path)
		_started = false
