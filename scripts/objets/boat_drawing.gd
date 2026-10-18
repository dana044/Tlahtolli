## Dibujo del barco que la Mulata traza en la pared con carboncillo.
##
## El barco se compone de tres partes independientes (casco, mástil y vela)
## que aparecen con un fundido, en el orden en que el nivel lo pida. Así el
## dibujo avanza según los acertijos resueltos, sin depender del orden en que
## se leyeron las hojas.
## [br][br]Mientras no existan las imágenes definitivas, cada parte se dibuja
## por código con trazos de carboncillo. Para usar arte propio, asigna una
## textura a [member hull_texture], [member mast_texture] o
## [member sail_texture]: cada una es una capa del mismo tamaño, centrada en
## el origen de este nodo. Escala el nodo para ajustar el tamaño en pantalla.
class_name BoatDrawing
extends Node2D


## Id de la parte "casco". Coincide con [code]boat_part[/code] de riddles.json.
const PART_HULL: String = "casco"

## Id de la parte "mástil". Coincide con [code]boat_part[/code] de riddles.json.
const PART_MAST: String = "mástil"

## Id de la parte "vela". Coincide con [code]boat_part[/code] de riddles.json.
const PART_SAIL: String = "vela"

## Todas las partes que forman el barco completo.
const PARTS: Array[String] = [PART_HULL, PART_MAST, PART_SAIL]

## Contorno del casco (trapecio), en píxeles locales.
const HULL_POINTS: Array[Vector2] = [
	Vector2(-32, 0), Vector2(32, 0), Vector2(23, 12), Vector2(-23, 12),
]

## Base del mástil, en píxeles locales (sobre el centro del casco).
const MAST_BASE: Vector2 = Vector2(0, 0)

## Punta del mástil, en píxeles locales.
const MAST_TOP: Vector2 = Vector2(0, -52)

## Contorno de la vela (triángulo), en píxeles locales.
const SAIL_POINTS: Array[Vector2] = [
	Vector2(3, -50), Vector2(30, -14), Vector2(3, -14),
]


## Color de los trazos provisionales (carboncillo).
@export var charcoal_color: Color = Color(0.1, 0.09, 0.09)

## Grosor de los trazos provisionales, en píxeles.
@export var line_width: float = 2.0

## Segundos que tarda en aparecer una parte del barco.
@export_range(0.1, 5.0, 0.1) var reveal_seconds: float = 1.2

@export_group("Arte definitivo (opcional)")

## Capa del casco. Si está vacía se dibuja el casco provisional.
@export var hull_texture: Texture2D

## Capa del mástil. Si está vacía se dibuja el mástil provisional.
@export var mast_texture: Texture2D

## Capa de la vela. Si está vacía se dibuja la vela provisional.
@export var sail_texture: Texture2D


## Opacidad actual de cada parte (0 = oculta, 1 = totalmente visible).
## Clave: id de la parte; valor: opacidad.
var _alpha: Dictionary = {PART_HULL: 0.0, PART_MAST: 0.0, PART_SAIL: 0.0}


## Hace aparecer la parte [param part] del barco.
## Puede esperarse con [code]await[/code]. Si la parte ya estaba visible no
## hace nada, de modo que un acertijo no puede duplicar el progreso.
## [param part] es el id de la parte (ver [constant PARTS]).
## [param animate] indica si aparece con fundido ([code]true[/code]) o de
## golpe ([code]false[/code]), por ejemplo al recargar un nivel con progreso.
func show_part(part: String, animate: bool = true) -> void:
	if not _alpha.has(part):
		push_warning("BoatDrawing: la parte '%s' no existe." % part)
		return
	if float(_alpha[part]) >= 1.0:
		return

	if not animate:
		_set_part_alpha(1.0, part)
		return

	var tween: Tween = create_tween()
	tween.tween_method(_set_part_alpha.bind(part), float(_alpha[part]), 1.0, reveal_seconds)
	await tween.finished


## Muestra de golpe todas las partes que aún no estén visibles. Sirve para
## garantizar el barco completo en el final del nivel.
func show_complete() -> void:
	for part in PARTS:
		show_part(part, false)


## Indica si las tres partes del barco ya son totalmente visibles.
func is_complete() -> bool:
	for part in PARTS:
		if float(_alpha[part]) < 1.0:
			return false
	return true


## Actualiza la opacidad de una parte y redibuja. También es la función que
## anima el [Tween] de [method show_part].
## [param value] es la nueva opacidad; [param part] es el id de la parte.
func _set_part_alpha(value: float, part: String) -> void:
	_alpha[part] = value
	queue_redraw()


## Dibuja las partes visibles, con arte definitivo si existe o con trazos
## provisionales si no.
func _draw() -> void:
	var hull_alpha: float = _alpha[PART_HULL]
	if hull_alpha > 0.0:
		if hull_texture != null:
			_draw_layer(hull_texture, hull_alpha)
		else:
			_draw_shape(HULL_POINTS, hull_alpha, 0.5)

	var mast_alpha: float = _alpha[PART_MAST]
	if mast_alpha > 0.0:
		if mast_texture != null:
			_draw_layer(mast_texture, mast_alpha)
		else:
			var mast_color: Color = charcoal_color
			mast_color.a = mast_alpha
			draw_line(MAST_BASE, MAST_TOP, mast_color, line_width * 1.5)

	var sail_alpha: float = _alpha[PART_SAIL]
	if sail_alpha > 0.0:
		if sail_texture != null:
			_draw_layer(sail_texture, sail_alpha)
		else:
			_draw_shape(SAIL_POINTS, sail_alpha, 0.3)


## Dibuja una capa de arte definitivo centrada en el origen del nodo.
## [param texture] es la imagen; [param alpha] su opacidad.
func _draw_layer(texture: Texture2D, alpha: float) -> void:
	draw_texture(texture, -texture.get_size() / 2.0, Color(1.0, 1.0, 1.0, alpha))


## Dibuja un polígono provisional: relleno suave y contorno de carboncillo.
## [param points] es el contorno; [param alpha] la opacidad del trazo;
## [param fill_ratio] la proporción de [param alpha] que usa el relleno.
func _draw_shape(points: Array[Vector2], alpha: float, fill_ratio: float) -> void:
	var polygon: PackedVector2Array = PackedVector2Array(points)

	var fill: Color = charcoal_color
	fill.a = alpha * fill_ratio
	draw_colored_polygon(polygon, fill)

	var outline: Color = charcoal_color
	outline.a = alpha
	# El contorno se cierra repitiendo el primer punto.
	polygon.append(polygon[0])
	draw_polyline(polygon, outline, line_width)
