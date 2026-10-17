## Barra superior del inventario.
## Crea N cajitas vacías y las llena con los iconos de los objetos.
extends CanvasLayer

## Escena de una cajita (inventory_slot.tscn).
@export var slot_scene: PackedScene
## Contenedor donde se colocan las cajitas.
@export var slots_container: HBoxContainer
## Cuántas cajitas se muestran (vacías o llenas).
@export_range(1, 12) var max_slots: int = 6
## Tamaño en píxeles de cada cajita.
@export var slot_size: Vector2 = Vector2(70, 70)

var _slots: Array[InventorySlot] = []


func _ready() -> void:
	_build_slots()
	Inventory.item_added.connect(_refresh)
	Inventory.item_removed.connect(_refresh)
	_refresh()


func _build_slots() -> void:
	for i in max_slots:
		var slot := slot_scene.instantiate() as InventorySlot
		slot.custom_minimum_size = slot_size
		slots_container.add_child(slot)
		_slots.append(slot)


func _refresh(_id: String = "") -> void:
	for i in _slots.size():
		if i < Inventory.items.size():
			_slots[i].set_item(Inventory.get_item_icon(Inventory.items[i]))
		else:
			_slots[i].clear()
