## Una cajita del inventario: el marco es la textura del propio nodo
## y encima se dibuja el icono del objeto.
class_name InventorySlot
extends TextureRect

## Nodo hijo donde se dibuja el icono. Se asigna en el Inspector.
@export var icon_rect: TextureRect


## Muestra un objeto en la cajita (null la deja vacía).
@warning_ignore("shadowed_variable_base_class")
func set_item(texture: Texture2D) -> void:
	icon_rect.texture = texture
	icon_rect.visible = texture != null


## Deja la cajita vacía.
func clear() -> void:
	set_item(null)
