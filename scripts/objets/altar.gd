## @author Citlaly Morales Viveros (Cliente / Programadora XP)
## Altar donde se entregan las ofrendas al Chaneque.
##
## Es un [StaticBody2D] sólido que el jugador no puede atravesar. Se registra
## en el grupo [code]interactable[/code] (el que consulta
## [method Player._try_interact]) y emite [signal interacted]; el nivel decide
## si el jugador trae las ofrendas completas. Mientras no exista la imagen
## [code]altar_chaneque.png[/code] se dibuja un rectángulo marcador.
class_name Altar
extends StaticBody2D


## Se emite cuando el jugador interactúa con el altar.
signal interacted


## Ruta por defecto de la imagen del altar.
const DEFAULT_TEXTURE: String = "res://assets/sprites/objects/altar_chaneque.png"


## Imagen del altar. Si está vacía se usa [constant DEFAULT_TEXTURE].
@export var texture: Texture2D

## Tamaño del rectángulo marcador mientras no hay imagen, en píxeles.
@export var placeholder_size: Vector2 = Vector2(48, 32)

## Posición de cada ofrenda sobre el altar, relativa al origen del altar, en
## píxeles. Ajústalas según el tamaño de tu imagen del altar.
@export var offering_offsets: Array[Vector2] = [Vector2(-14, -16), Vector2(0, -20), Vector2(14, -16)]

## Segundos entre la colocación de una ofrenda y la siguiente.
@export var offering_delay: float = 0.35


## Nodo [Sprite2D] que muestra el altar.
@onready var sprite: Sprite2D = $Sprite2D

## Indica si las ofrendas ya fueron entregadas.
var _delivered: bool = false


## Se registra como interactuable y carga la imagen si existe.
func _ready() -> void:
	add_to_group("interactable")

	if texture == null and ResourceLoader.exists(DEFAULT_TEXTURE):
		texture = load(DEFAULT_TEXTURE) as Texture2D
	sprite.texture = texture

	# Redibuja el marcador, que depende de si hay imagen o no.
	queue_redraw()


## Lo invoca el [Player] al interactuar cerca. Avisa al nivel.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _delivered:
		return
	interacted.emit()


## Marca las ofrendas como entregadas: el altar deja de ser interactuable.
func mark_delivered() -> void:
	_delivered = true
	remove_from_group("interactable")


## Coloca las ofrendas sobre el altar, una por una, con un pequeño efecto de
## aparición. Puede esperarse con [code]await[/code].
## [param textures] son las imágenes de las ofrendas, en el orden en que se
## colocan. [param item_scale] es su escala. Con [param animate] en
## [code]false[/code] aparecen de golpe y sin esperas (para restaurar el
## altar ya entregado).
func place_offerings(textures: Array[Texture2D], item_scale: float = 1.0, animate: bool = true) -> void:
	for i in textures.size():
		var item: Sprite2D = Sprite2D.new()
		item.texture = textures[i]
		# Si hay más ofrendas que posiciones, las sobrantes se apilan arriba.
		item.position = offering_offsets[i] if i < offering_offsets.size() else Vector2(0, -16)
		item.scale = Vector2.ONE * item_scale
		add_child(item)

		if animate:
			item.scale = Vector2.ZERO
			var tween: Tween = create_tween()
			tween.tween_property(item, "scale", Vector2.ONE * item_scale, 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await get_tree().create_timer(offering_delay).timeout

	if animate:
		await get_tree().create_timer(0.3).timeout


## Dibuja un rectángulo marcador cuando todavía no hay imagen del altar.
func _draw() -> void:
	if texture == null:
		draw_rect(Rect2(-placeholder_size / 2.0, placeholder_size), Color(0.45, 0.28, 0.15))
