## Altar antiguo del final.
##
## Es un [StaticBody2D] sólido que el jugador no puede atravesar. Se registra
## en el grupo [code]interactable[/code] (el que consulta
## [method Player._try_interact]) y emite [signal interacted]; el nivel decide
## si el jugador trae los tres objetos. Al entregarlos, los muestra sobre el
## altar y puede encender un brillo cálido que anuncia el regreso de la luz.
## [br]Su origen debe estar en la base del altar.
class_name AltarFinal
extends StaticBody2D


## Se emite cuando el jugador interactúa con el altar.
signal interacted


## Ruta por defecto de la imagen del altar.
const DEFAULT_TEXTURE: String = "res://assets/sprites/objects/altar_final.png"

## Lado, en píxeles, de la textura radial del brillo.
const GLOW_TEXTURE_SIZE: int = 256


## Imagen del altar. Si está vacía se usa [constant DEFAULT_TEXTURE] (si existe).
@export var texture: Texture2D

## Si es [code]true[/code] y no hay imagen, dibuja un rectángulo marcador.
## Desactívalo si el altar está dibujado en el TileMap.
@export var show_placeholder: bool = true

## Tamaño del rectángulo marcador, en píxeles.
@export var placeholder_size: Vector2 = Vector2(96, 48)

## Posición de cada objeto sobre el altar, relativa a su origen, en píxeles.
## El orden es el de entrega: moneda, medallón y carboncillo.
@export var offering_offsets: Array[Vector2] = [Vector2(-28, -50), Vector2(0, -56), Vector2(28, -50)]

## Segundos entre la colocación de un objeto y el siguiente.
@export var offering_delay: float = 0.5

@export_group("Brillo")
## Si es [code]true[/code], al entregar los objetos el altar se ilumina.
@export var glow_enabled: bool = true
## Color de la luz del altar.
@export var glow_color: Color = Color(1.0, 0.82, 0.5)
## Intensidad máxima de la luz.
@export_range(0.1, 4.0, 0.1) var glow_energy: float = 1.4
## Tamaño de la luz. Con 1.0 el radio es de unos 128 px.
@export_range(0.2, 8.0, 0.1) var glow_scale: float = 1.8
## Posición de la luz respecto al origen del altar.
@export var glow_offset: Vector2 = Vector2(0, -30)
## Segundos que tarda el brillo en encenderse y en apagarse.
@export var glow_fade_time: float = 1.2


## Imagen del altar. Es [code]null[/code] si la escena no incluye el nodo.
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

## Indica si los objetos ya fueron entregados.
var _delivered: bool = false

## Luz del brillo (se crea por código al encenderla).
var _glow: PointLight2D


## Se registra como interactuable y carga la imagen si existe.
func _ready() -> void:
	add_to_group("interactable")

	if texture == null and ResourceLoader.exists(DEFAULT_TEXTURE):
		texture = load(DEFAULT_TEXTURE) as Texture2D
	if sprite != null and texture != null:
		sprite.texture = texture

	# Redibuja el marcador, que depende de si hay imagen o no.
	queue_redraw()


## Lo invoca el [Player] al interactuar cerca. Avisa al nivel.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _delivered:
		return
	interacted.emit()


## Marca los objetos como entregados: el altar deja de ser interactuable.
func mark_delivered() -> void:
	_delivered = true
	remove_from_group("interactable")


## Coloca los objetos sobre el altar, uno por uno, con un efecto de aparición.
## Puede esperarse con [code]await[/code].
## [param textures] son las imágenes, en el orden de colocación.
## [param item_scale] es su escala. Con [param animate] en [code]false[/code]
## aparecen de golpe y sin esperas (para restaurar el altar ya entregado).
func place_offerings(textures: Array[Texture2D], item_scale: float = 1.0, animate: bool = true) -> void:
	for i in textures.size():
		var item: Sprite2D = Sprite2D.new()
		item.texture = textures[i]
		# Si hay más objetos que posiciones, los sobrantes se apilan arriba.
		item.position = offering_offsets[i] if i < offering_offsets.size() else Vector2(0, -36)
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


## Enciende el brillo del altar con un fundido. Puede esperarse con
## [code]await[/code]. No hace nada si [member glow_enabled] es [code]false[/code]
## o si ya está encendido.
func light_up() -> void:
	if not glow_enabled or _glow != null:
		return

	_glow = PointLight2D.new()
	_glow.color = glow_color
	_glow.energy = 0.0
	_glow.texture_scale = glow_scale
	_glow.position = glow_offset
	add_child(_glow)

	# La textura se asigna un fotograma después, cuando la luz ya está
	# registrada en el renderizador.
	await get_tree().process_frame
	if _glow == null:
		return
	_glow.texture = _build_glow_texture()

	var tween: Tween = create_tween()
	tween.tween_property(_glow, "energy", glow_energy, glow_fade_time)
	await tween.finished


## Apaga el brillo con un fundido y lo elimina. Se usa cuando ya regresó la
## luz natural. Puede esperarse con [code]await[/code].
func fade_glow() -> void:
	if _glow == null:
		return
	var light: PointLight2D = _glow
	_glow = null
	var tween: Tween = create_tween()
	tween.tween_property(light, "energy", 0.0, glow_fade_time)
	await tween.finished
	light.queue_free()


## Genera la textura de la luz: un círculo que se desvanece hacia el borde.
func _build_glow_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))

	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = GLOW_TEXTURE_SIZE
	tex.height = GLOW_TEXTURE_SIZE
	return tex


## Dibuja un rectángulo marcador cuando no hay imagen del altar.
func _draw() -> void:
	if texture == null and show_placeholder:
		draw_rect(Rect2(Vector2(-placeholder_size.x / 2.0, -placeholder_size.y), placeholder_size),
				Color(0.45, 0.28, 0.15))
