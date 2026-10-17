## Gestor global de diálogos (autoload "DialogueManager").
## Uso:
##     DialogueManager.play("res://data/dialogues/llorona.json")
##     await DialogueManager.dialogue_finished
extends Node

## Se emite cuando termina el diálogo actual.
signal dialogue_finished

## Escena del cuadro de diálogo.
@export var dialog_box_scene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")

## Referencia al cuadro de diálogo.
var dialog_box: CanvasLayer


func _ready() -> void:
	# Siempre activo, incluso con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_box = dialog_box_scene.instantiate()
	add_child(dialog_box)
	dialog_box.dialog_finished.connect(func(): dialogue_finished.emit())


## Reproduce un bloque de un archivo JSON.
## Si el archivo es una lista simple, no hace falta el id del bloque.
func play(json_path: String, block_id: String = "") -> void:
	dialog_box.start(_load_lines(json_path, block_id))


## Diálogo abierto
func is_active() -> bool:
	return dialog_box.visible


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
