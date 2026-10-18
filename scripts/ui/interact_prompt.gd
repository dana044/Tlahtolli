## Imagen de la tecla E que aparece sobre un objeto interactuable cuando el
## jugador está cerca. Se coloca como hijo del objeto (Llorona, altar...).
## Se oculta durante la pausa, los diálogos y las secuencias de misión.
class_name InteractPrompt
extends Sprite2D

## Imagen que se muestra (la tecla E).
@export var prompt_texture: Texture2D = preload("res://assets/sprites/ui/teclaE.png")
## Distancia máxima al jugador, en píxeles, para que aparezca. Debe coincidir
## con el alcance de interacción del jugador.
@export var prompt_distance: float = 60.0
## Posición de la imagen respecto al objeto (centrada sobre ese punto).
@export var prompt_offset: Vector2 = Vector2(0, -32)
## Escala de la imagen (1 = tamaño original). No la afecta la escala del objeto.
@export var prompt_scale: Vector2 = Vector2.ONE
## Si es true, se dibuja con filtro "nearest" para pixel art nítido.
@export var pixel_art: bool = true
## Si es true, la imagen sube y baja suavemente.
@export var bobbing: bool = true
## Cuántos píxeles sube y baja.
@export_range(0.0, 10.0, 0.5) var bob_amount: float = 2.0
## Segundos del fundido de entrada y salida.
@export_range(0.05, 1.0, 0.05) var fade_seconds: float = 0.2
## Si es true, solo aparece mientras el objeto padre está en el grupo
## "interactable" (la Llorona solo entra en él cuando está en paz).
@export var require_interactable_group: bool = true
## Si no está vacía, solo aparece cuando el jugador tiene al menos uno de estos
## objetos del inventario (por ejemplo, el altar del Chaneque).
@export var required_items: Array[String] = []

var _host: Node2D
var _player: Player
var _shown: bool = false
var _fade_tween: Tween
var _bob_tween: Tween


func _ready() -> void:
	# Siempre activo, para poder ocultarse cuando el juego se pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_host = get_parent() as Node2D
	if _host == null:
		push_warning("InteractPrompt: debe ser hijo de un nodo 2D.")
		set_process(false)
		return

	texture = prompt_texture
	z_index = 10
	position = prompt_offset
	if pixel_art:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# La escala inversa mantiene el tamaño aunque el objeto esté escalado.
	var inverse := Vector2.ONE
	if not is_zero_approx(_host.scale.x) and not is_zero_approx(_host.scale.y):
		inverse = Vector2(1.0 / _host.scale.x, 1.0 / _host.scale.y)
	scale = prompt_scale * inverse

	modulate.a = 0.0
	hide()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var should_show := _should_show()
	if should_show != _shown:
		_set_shown(should_show)


func _should_show() -> bool:
	if get_tree().paused or not _player.can_move:
		return false
	if require_interactable_group and not _host.is_in_group("interactable"):
		return false
	if not required_items.is_empty():
		var has_any := false
		for id in required_items:
			if Inventory.has_item(id):
				has_any = true
				break
		if not has_any:
			return false
	return _host.global_position.distance_to(_player.global_position) <= prompt_distance


func _set_shown(value: bool) -> void:
	_shown = value
	if _fade_tween:
		_fade_tween.kill()
	if value:
		show()
		_start_bobbing()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0 if value else 0.0, fade_seconds)
	if not value:
		_fade_tween.tween_callback(_stop)


func _stop() -> void:
	hide()
	if _bob_tween:
		_bob_tween.kill()
	position = prompt_offset


func _start_bobbing() -> void:
	if not bobbing or bob_amount <= 0.0:
		return
	if _bob_tween:
		_bob_tween.kill()
	position = prompt_offset
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", prompt_offset.y - bob_amount, 0.5)\
		.set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(self, "position:y", prompt_offset.y + bob_amount, 0.5)\
		.set_trans(Tween.TRANS_SINE)
