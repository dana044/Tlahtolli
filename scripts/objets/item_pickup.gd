## Objeto del mundo que el jugador recoge con la acción [code]interact[/code].
##
## Al interactuar, agrega [member item_id] al [Inventory] y desaparece de la
## escena. Se registra en el grupo [code]interactable[/code], que es el que
## consulta [method Player._try_interact]. Es genérico: sirve para la muñeca y
## para cualquier objeto futuro (flor, mandarina, moneda...) con solo cambiar
## el id en el Inspector.
##
## Además muestra sobre el objeto la imagen de la tecla E cuando el jugador
## está lo bastante cerca para interactuar.
class_name ItemPickup
extends Node2D


## Se emite justo después de agregar el objeto al inventario.
## [param item_id] es el id del objeto recogido.
signal picked_up(item_id: String)


## Id del objeto en [code]data/items.json[/code] (por ejemplo, [code]muneca[/code]).
@export var item_id: String = ""

@export_group("Aviso de interacción")

## Si es [code]true[/code], muestra la imagen de la tecla cuando el jugador
## está cerca.
@export var show_prompt: bool = true

## Imagen que se muestra sobre el objeto (la tecla E).
@export var prompt_texture: Texture2D = preload("res://assets/sprites/ui/teclaE.png")

## Distancia máxima al jugador, en píxeles, para que aparezca la imagen.
## Debe coincidir con el alcance de interacción del [Player] (el que usa
## [method Player._try_interact]); si la imagen sale pero no deja recoger,
## reduce este valor.
@export var prompt_distance: float = 40.0

## Posición de la imagen respecto al objeto. Queda centrada sobre este punto.
@export var prompt_offset: Vector2 = Vector2(0, -24)

## Escala de la imagen en pantalla (1 = tamaño original). No se ve afectada
## por la escala del objeto.
@export var prompt_scale: Vector2 = Vector2.ONE

## Si es [code]true[/code], la imagen se dibuja con filtro "nearest" para que
## el pixel art se vea nítido.
@export var prompt_pixel_art: bool = true

## Si es [code]true[/code], la imagen sube y baja suavemente para llamar la
## atención.
@export var prompt_bobbing: bool = true

## Cuántos píxeles sube y baja la imagen cuando [member prompt_bobbing] está activo.
@export_range(0.0, 10.0, 0.5) var prompt_bob_amount: float = 2.0

## Segundos que dura el fundido de entrada y salida.
@export_range(0.05, 1.0, 0.05) var prompt_fade_seconds: float = 0.2


## Evita recoger el objeto dos veces en el mismo fotograma.
var _collected: bool = false

## Sprite del aviso (se crea por código).
var _prompt: Sprite2D

## Jugador de la escena, buscado una sola vez.
var _player: Player

## Indica si el aviso está visible (o apareciendo) en este momento.
var _prompt_shown: bool = false

var _fade_tween: Tween
var _bob_tween: Tween


## Registra el objeto como interactuable y prepara el aviso.
func _ready() -> void:
	add_to_group("interactable")
	if show_prompt and prompt_texture != null:
		_build_prompt()


## Comprueba cada fotograma si el jugador está cerca para mostrar u ocultar
## el aviso.
func _process(_delta: float) -> void:
	if _prompt == null or _collected:
		return
	if _player == null:
		_player = _find_player()
		if _player == null:
			return

	# El aviso también se oculta mientras el jugador no puede moverse
	# (diálogos y secuencias de misión).
	var near: bool = (
		_player.can_move
		and global_position.distance_to(_player.global_position) <= prompt_distance
	)
	if near != _prompt_shown:
		_set_prompt_visible(near)


## Recoge el objeto. Lo invoca el [Player] al interactuar cerca.
## [param _by] es el nodo que interactúa (no se usa por ahora).
func interact(_by: Node2D) -> void:
	if _collected or item_id.is_empty():
		return
	_collected = true
	remove_from_group("interactable")

	Inventory.add_item(item_id)
	picked_up.emit(item_id)

	# Desaparece de la pantalla (y con él su aviso); ahora vive en el inventario.
	queue_free()


## Crea el Sprite2D del aviso como hijo del objeto, oculto al inicio.
func _build_prompt() -> void:
	_prompt = Sprite2D.new()
	_prompt.texture = prompt_texture
	_prompt.z_index = 10   # Por encima del sprite del objeto y del jugador.
	_prompt.position = prompt_offset
	if prompt_pixel_art:
		_prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# La escala inversa mantiene el tamaño de la imagen aunque el objeto
	# esté escalado.
	var inverse := Vector2.ONE
	if not is_zero_approx(scale.x) and not is_zero_approx(scale.y):
		inverse = Vector2(1.0 / scale.x, 1.0 / scale.y)
	_prompt.scale = prompt_scale * inverse

	_prompt.modulate.a = 0.0
	_prompt.hide()
	add_child(_prompt)


## Muestra u oculta el aviso con un fundido.
func _set_prompt_visible(value: bool) -> void:
	_prompt_shown = value
	if _fade_tween:
		_fade_tween.kill()
	if value:
		_prompt.show()
		_start_bobbing()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_prompt, "modulate:a", 1.0 if value else 0.0, prompt_fade_seconds)
	if not value:
		_fade_tween.tween_callback(_stop_prompt)


## Oculta el sprite y detiene la animación de subida y bajada.
func _stop_prompt() -> void:
	_prompt.hide()
	if _bob_tween:
		_bob_tween.kill()
	_prompt.position = prompt_offset


## Hace que la imagen suba y baje en bucle.
func _start_bobbing() -> void:
	if not prompt_bobbing or prompt_bob_amount <= 0.0:
		return
	if _bob_tween:
		_bob_tween.kill()
	_prompt.position = prompt_offset
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_prompt, "position:y", prompt_offset.y - prompt_bob_amount, 0.5)\
		.set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_prompt, "position:y", prompt_offset.y + prompt_bob_amount, 0.5)\
		.set_trans(Tween.TRANS_SINE)


## Busca al [Player] en la escena actual. Devuelve [code]null[/code] si aún
## no existe.
func _find_player() -> Player:
	var root := get_tree().current_scene
	if root == null:
		return null
	for node in root.find_children("*", "", true, false):
		if node is Player:
			return node
	return null
