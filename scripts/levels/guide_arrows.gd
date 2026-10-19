## Flechas animadas que guían al jugador hacia un punto del mapa.
##
## Dibuja una fila de chevrones que parten del jugador y señalan hacia el
## destino, avanzando suavemente en esa dirección. Solo se dibujan los
## primeros [member max_length] píxeles, que es lo que la cámara alcanza a
## mostrar, y se desvanecen en los extremos para no aparecer ni desaparecer de
## golpe. Dejan de dibujarse al llegar cerca del destino.
## [br][br]Debe colocarse dentro de una [CanvasLayer]: así la oscuridad del
## nivel (un [CanvasModulate]) no las apaga y siempre se ven. Por eso las
## posiciones del mundo se convierten a pantalla con la transformación del
## canvas del viewport (incluye el desplazamiento y el zoom de la cámara).
## [br][br]Uso:
## [codeblock]
## var arrows := GuideArrows.new()
## capa_canvas.add_child(arrows)
## arrows.activate(player, Vector2(995, 275))
## # ...
## arrows.deactivate()
## [/codeblock]
class_name GuideArrows
extends Node2D


## Color de las flechas.
@export var arrow_color: Color = Color(1.0, 0.85, 0.45, 0.95)

## Tamaño de cada flecha, en píxeles de pantalla.
@export var arrow_size: float = 14.0

## Grosor del trazo de las flechas, en píxeles de pantalla.
@export var line_width: float = 4.0

## Separación entre flechas, medida en el mundo, en píxeles.
@export var spacing: float = 26.0

## Velocidad a la que avanzan las flechas hacia el destino, en píxeles del
## mundo por segundo.
@export var march_speed: float = 24.0

## Longitud máxima de la fila de flechas, en píxeles del mundo, contada desde
## el jugador.
@export var max_length: float = 110.0

## Distancia al jugador, en píxeles del mundo, a partir de la cual aparece la
## primera flecha. Evita dibujarlas encima del personaje.
@export var start_offset: float = 20.0

## Distancia al destino, en píxeles del mundo, a partir de la cual dejan de
## dibujarse.
@export var hide_radius: float = 20.0


## Nodo desde el que parten las flechas (el jugador).
var _origin: Node2D

## Destino de las flechas, en coordenadas globales.
var _target: Vector2 = Vector2.ZERO

## Indica si las flechas están encendidas.
var _active: bool = false

## Tiempo acumulado, en segundos. Mueve la animación de avance.
var _time: float = 0.0


## Las flechas parten apagadas: sin [method activate] no consumen proceso.
func _ready() -> void:
	set_process(false)


## Enciende las flechas.
## [param origin] es el nodo desde el que parten (el jugador);
## [param target] es el destino, en coordenadas globales.
func activate(origin: Node2D, target: Vector2) -> void:
	_origin = origin
	_target = target
	_active = true
	set_process(true)
	queue_redraw()


## Apaga las flechas y las borra de la pantalla.
func deactivate() -> void:
	_active = false
	set_process(false)
	queue_redraw()


## Avanza la animación y pide redibujar en cada fotograma.
## [param delta] es el tiempo transcurrido desde el fotograma anterior, en
## segundos.
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Dibuja la fila de flechas entre el jugador y el destino.
func _draw() -> void:
	if not _active or not is_instance_valid(_origin):
		return

	var start: Vector2 = _origin.global_position
	var to_target: Vector2 = _target - start
	var distance: float = to_target.length()

	# Longitud de la fila: se corta cerca del destino y a max_length.
	var usable: float = minf(distance - hide_radius, max_length)
	if usable <= start_offset:
		return

	var world_dir: Vector2 = to_target / distance
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var screen_dir: Vector2 = canvas.basis_xform(world_dir).normalized()
	var perpendicular: Vector2 = screen_dir.orthogonal()

	# La fase desplaza toda la fila hacia el destino y se repite cada
	# [member spacing] píxeles, de modo que el movimiento parece continuo.
	var phase: float = fmod(_time * march_speed, spacing)
	var travelled: float = start_offset + phase

	while travelled < usable:
		# 0 en los extremos de la fila y 1 en el centro: desvanece los bordes.
		var t: float = (travelled - start_offset) / (usable - start_offset)
		var color: Color = arrow_color
		color.a *= sin(PI * t)

		var screen_pos: Vector2 = canvas * (start + world_dir * travelled)
		var tip: Vector2 = screen_pos + screen_dir * arrow_size
		var wing_a: Vector2 = screen_pos - screen_dir * arrow_size * 0.3 + perpendicular * arrow_size
		var wing_b: Vector2 = screen_pos - screen_dir * arrow_size * 0.3 - perpendicular * arrow_size
		draw_polyline(PackedVector2Array([wing_a, tip, wing_b]), color, line_width, true)

		travelled += spacing
