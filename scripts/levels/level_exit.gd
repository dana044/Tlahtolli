## Salida de un nivel por un hueco del borde del mapa, con flecha guía.
##
## Al activarla con [method enable], aparece una flecha que late señalando el
## hueco y el [Player] puede atravesar el borde del mapa por esa zona. Cuando el
## centro del personaje (la mitad de su cuerpo) rebasa [member trigger_x] se
## emite [signal player_crossed]; el nivel decide qué hacer (cambiar de escena,
## fundido, etc.).
## [br][br]Es un nodo sin escena propia: el nivel lo crea por código con
## [code]LevelExit.new()[/code], asigna [member gate_rect] y [member trigger_x]
## y lo añade como hijo antes de llamar a [method enable]. La flecha se dibuja
## con [method _draw], por lo que no necesita ninguna imagen.
class_name LevelExit
extends Node2D


## Se emite una sola vez, cuando el jugador cruza [member trigger_x] dentro de
## la zona de paso.
signal player_crossed


## Contorno de la flecha, apuntando a la derecha y centrado en su origen.
const ARROW_SHAPE: Array[Vector2] = [
	Vector2(-18, -5), Vector2(2, -5), Vector2(2, -11), Vector2(18, 0),
	Vector2(2, 11), Vector2(2, 5), Vector2(-18, 5),
]

## Color de relleno de la flecha.
const ARROW_FILL: Color = Color(1.0, 0.9, 0.5)

## Color del borde de la flecha, que la separa del pasto.
const ARROW_OUTLINE: Color = Color(0.0, 0.0, 0.0)

## Grosor del borde de la flecha, en píxeles.
const ARROW_OUTLINE_WIDTH: float = 2.0

## Capa de dibujo de la flecha. Un valor alto la mantiene sobre árboles y
## arbustos, sin importar su orden por profundidad (Y-sort).
const ARROW_Z_INDEX: int = 100


## Zona de paso, en coordenadas globales (posición y tamaño). Es el hueco por el
## que el jugador puede salir del mapa, por lo que debe extenderse hacia fuera
## del borde. También define la altura a la que se coloca la flecha.
@export var gate_rect: Rect2 = Rect2()

## Coordenada X, global, a partir de la cual se considera que el jugador cruzó.
## Con el borde derecho del mapa, cruza cuando el centro del personaje llega al
## borde, es decir, cuando ya salió medio cuerpo.
@export var trigger_x: float = 0.0

## Desplazamiento de la flecha respecto al punto formado por [member trigger_x]
## y el centro vertical de [member gate_rect]. Un valor negativo en X la deja
## antes del borde.
@export var arrow_offset: Vector2 = Vector2(-55.0, 0.0)

## punto global al que apunta la flecha (por ejemplo, el centro de la
## zona de salida real). La flecha se coloca en este punto más
## [member arrow_offset]. Con [constant Vector2.ZERO] (por defecto) se usa el
## comportamiento anterior: [member trigger_x] y el centro vertical de
## [member gate_rect].
@export var arrow_target: Vector2 = Vector2.ZERO

## Multiplicador de brillo de la flecha. Compensa el [CanvasModulate] oscuro de
## los niveles, que apagaría una flecha del color original. Con [code]1.0[/code]
## se ve tal cual; en un nivel oscuro funcionan valores de 3.0 a 4.0.
@export var arrow_glow: float = 3.5

## Distancia, en píxeles, que la flecha avanza y retrocede al latir.
@export var arrow_bob_amplitude: float = 6.0

## Velocidad del latido de la flecha, en radianes por segundo.
@export var arrow_bob_speed: float = 4.0

## Duración del fundido con el que aparece la flecha, en segundos.
@export var arrow_fade_time: float = 0.8

## Si es [code]true[/code], dibuja la zona de paso ([member gate_rect], en
## verde) y la línea de cruce ([member trigger_x], en rojo) para poder ajustar
## la salida a simple vista. Desactívalo en la versión final.
@export var debug_draw: bool = false


## Indica si la salida está abierta (flecha visible y paso permitido).
var _enabled: bool = false

## Indica si el jugador ya cruzó. Evita emitir [signal player_crossed] más de
## una vez.
var _crossed: bool = false

## Jugador que debe cruzar. Puede ser [code]null[/code] hasta que se registre.
var _player: Player = null

## Desplazamiento horizontal actual del latido de la flecha, en píxeles.
var _bob: float = 0.0


## Deja la salida cerrada: flecha invisible y sin procesamiento hasta que se
## invoque [method enable].
func _ready() -> void:
	z_index = ARROW_Z_INDEX
	z_as_relative = false
	modulate = Color(arrow_glow, arrow_glow, arrow_glow, 0.0)
	set_process(false)
	set_physics_process(false)


## Anima el latido de la flecha y la redibuja.
## [param _delta] es el tiempo transcurrido desde el cuadro anterior, en
## segundos (no se usa: el latido depende del reloj global).
func _process(_delta: float) -> void:
	_bob = sin(Time.get_ticks_msec() / 1000.0 * arrow_bob_speed) * arrow_bob_amplitude
	queue_redraw()


## Detecta el cruce: el centro del jugador debe haber rebasado
## [member trigger_x] estando dentro de [member gate_rect].
## [param _delta] es el tiempo transcurrido desde el paso anterior (no se usa).
func _physics_process(_delta: float) -> void:
	if _crossed:
		return

	if not is_instance_valid(_player):
		_find_player()
		return

	var pos: Vector2 = _player.global_position
	if pos.x >= trigger_x and gate_rect.has_point(pos):
		_crossed = true
		player_crossed.emit()


## Dibuja la flecha guía en su posición actual.
func _draw() -> void:
	var center: Vector2 = to_local(_arrow_anchor()) + Vector2(_bob, 0.0)

	var points: PackedVector2Array = PackedVector2Array()
	for point in ARROW_SHAPE:
		points.append(center + point)
	draw_colored_polygon(points, ARROW_FILL)

	# El contorno se cierra repitiendo el primer punto.
	points.append(points[0])
	draw_polyline(points, ARROW_OUTLINE, ARROW_OUTLINE_WIDTH)

	if debug_draw:
		draw_rect(Rect2(to_local(gate_rect.position), gate_rect.size), Color(0.0, 1.0, 0.0, 0.25))
		draw_line(to_local(Vector2(trigger_x, gate_rect.position.y)),
				to_local(Vector2(trigger_x, gate_rect.end.y)), Color(1.0, 0.0, 0.0), 2.0)


## Abre la salida: muestra la flecha y permite al jugador atravesar el borde
## del mapa por [member gate_rect]. No tiene efecto si ya estaba abierta.
## [param animated] indica si la flecha aparece con fundido
## ([code]true[/code]) o de golpe ([code]false[/code]), por ejemplo al
## recargar un nivel cuya misión ya se completó.
func enable(animated: bool = true) -> void:
	if _enabled:
		return
	_enabled = true
	_crossed = false

	_find_player()
	if is_instance_valid(_player):
		_player.set_edge_gap(gate_rect)
	else:
		push_warning("LevelExit: no hay ningún nodo en el grupo 'player'; no se abrirá el paso.")

	set_process(true)
	set_physics_process(true)

	if animated:
		modulate = Color(arrow_glow, arrow_glow, arrow_glow, 0.0)
		create_tween().tween_property(self, "modulate:a", 1.0, arrow_fade_time)
	else:
		modulate = Color(arrow_glow, arrow_glow, arrow_glow, 1.0)


## Cierra la salida: oculta la flecha y devuelve el límite del mapa a todo su
## perímetro. No tiene efecto si ya estaba cerrada.
func disable() -> void:
	if not _enabled:
		return
	_enabled = false

	if is_instance_valid(_player):
		_player.clear_edge_gap()

	set_process(false)
	set_physics_process(false)
	modulate.a = 0.0


## Devuelve el punto global donde se centra la flecha, sin contar el latido.
## [br]si [member arrow_target] está definido, la flecha se coloca ahí
## en vez de usar [member trigger_x] y el centro de [member gate_rect].
func _arrow_anchor() -> Vector2:
	if arrow_target != Vector2.ZERO:
		return arrow_target + arrow_offset
	return Vector2(trigger_x, gate_rect.get_center().y) + arrow_offset


## Actualiza la referencia al jugador (grupo [code]player[/code]) si aún no
## es válida.
func _find_player() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
