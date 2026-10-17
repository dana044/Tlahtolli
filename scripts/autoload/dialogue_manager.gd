## Gestor global de diálogos (autoload "DialogueManager").
## Uso:
##     DialogueManager.play("res://data/dialogues/llorona.json", "llorona_atrapa")
##     await DialogueManager.dialogue_finished
extends Node

## Se emite cuando termina el diálogo actual.
signal dialogue_finished

## Escena del cuadro de diálogo.
@export var dialog_box_scene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")

## Referencia al cuadro de diálogo.
var dialog_box: CanvasLayer
## Bloque que se está reproduciendo (para desbloquear pistas del diario).
var _current_block: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_box = dialog_box_scene.instantiate()
	add_child(dialog_box)
	dialog_box.dialog_finished.connect(_on_dialog_finished)


## Reproduce un bloque de un archivo JSON.
func play(json_path: String, block_id: String = "") -> void:
	_current_block = block_id
	dialog_box.start(_load_lines(json_path, block_id))


## ¿Hay un diálogo abierto?
func is_active() -> bool:
	return dialog_box.visible


func _on_dialog_finished() -> void:
	Journal.unlock_from_dialogue(_current_block)
	dialogue_finished.emit()


func _load_lines(path: String, block_id: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: no se encontró " + path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		return data
	if data is Dictionary:
		if data.has(block_id) and data[block_id] is Array:
			return data[block_id]
		push_error("DialogueManager: no existe el bloque '%s' en %s" % [block_id, path])
		return []
	push_error("DialogueManager: formato inválido en " + path)
	return []
