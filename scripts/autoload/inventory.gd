## Inventario global del jugador (autoload "Inventory").
extends Node

## Se emite al agregar un objeto.
signal item_added(item_id: String)
## Se emite al quitar un objeto.
signal item_removed(item_id: String)

## Ruta del catálogo de objetos.
@export_file("*.json") var catalog_path: String = "res://data/items.json"

## Ids de los objetos que el jugador tiene ahora.
var items: Array[String] = []
## Catálogo cargado del JSON: { id: {name, icon, context} }.
var catalog: Dictionary = {}
## Caché de texturas.
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_load_catalog()


func _load_catalog() -> void:
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		push_error("Inventory: no se encontró " + catalog_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		catalog = data
	else:
		push_error("Inventory: items.json tiene formato inválido.")


## Datos de un objeto (name, icon, context) o {} si no existe.
func get_item_data(id: String) -> Dictionary:
	return catalog.get(id, {})


## Icono del objeto, o null si falta la imagen.
func get_item_icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var path: String = get_item_data(id).get("icon", "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Inventory: falta el icono de '%s' (%s)" % [id, path])
		return null
	var tex: Texture2D = load(path)
	_icon_cache[id] = tex
	return tex


func add_item(id: String) -> void:
	if id not in items:
		items.append(id)
		item_added.emit(id)


func remove_item(id: String) -> void:
	if id in items:
		items.erase(id)
		item_removed.emit(id)


func has_item(id: String) -> bool:
	return id in items


func clear() -> void:
	var old := items.duplicate()
	items.clear()
	for id in old:
		item_removed.emit(id)
