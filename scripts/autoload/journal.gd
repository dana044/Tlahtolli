## Estado del diario de pistas (autoload "Journal").
## Guarda qué pistas se desbloquearon y crea la tecla para abrirlo.
extends Node

## Se emite al desbloquear una pista nueva.
signal clue_unlocked(clue_id: String)

## Archivo con las pistas.
@export_file("*.json") var journal_path: String = "res://data/journal.json"
## Nombre de la acción de entrada que abre el diario.
@export var open_action: StringName = &"open_journal"
## Tecla por defecto de esa acción.
@export var open_key: Key = KEY_TAB

## Todas las pistas del juego, en orden: [{id, unlocked_by, title, text}].
var entries: Array = []
## Ids de las pistas ya desbloqueadas.
var unlocked: Array[String] = []
## true mientras el diario está abierto (lo usa el menú de pausa).
var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_entries()
	_ensure_action()


## Desbloquea una pista por su id.
func unlock(id: String) -> void:
	if id in unlocked:
		return
	unlocked.append(id)
	clue_unlocked.emit(id)


## Desbloquea las pistas asociadas a un bloque de diálogo terminado.
func unlock_from_dialogue(block_id: String) -> void:
	if block_id == "":
		return
	for entry in entries:
		if entry.get("unlocked_by", "") == block_id:
			unlock(entry["id"])


func is_unlocked(id: String) -> bool:
	return id in unlocked


## Desbloquea todo (solo para pruebas).
func unlock_all() -> void:
	for entry in entries:
		unlock(entry["id"])


## Borra el progreso (al empezar una partida nueva).
func clear() -> void:
	unlocked.clear()
	is_open = false


func _load_entries() -> void:
	var file := FileAccess.open(journal_path, FileAccess.READ)
	if file == null:
		push_error("Journal: no se encontró " + journal_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		entries = data
	else:
		push_error("Journal: formato inválido en " + journal_path)


## Crea la acción "open_journal" con la tecla J si no existe.
func _ensure_action() -> void:
	if InputMap.has_action(open_action):
		return
	InputMap.add_action(open_action)
	var ev := InputEventKey.new()
	ev.physical_keycode = open_key
	InputMap.action_add_event(open_action, ev)
