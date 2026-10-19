## Piso de piedra de la prisión.
##
## [TileMapLayer] que rellena el mapa con los tres mosaicos del [TileSet]
## ([code]tileset_piedra.tres[/code]), mezclándolos con distinta probabilidad
## para que el suelo no se vea repetitivo.
## [br][br]Solo rellena si la capa está vacía: si pintas celdas a mano en el
## editor, se respeta tu diseño y no se sobrescribe. Para volver al relleno
## automático, borra las celdas pintadas.
class_name StoneFloor
extends TileMapLayer


## Tamaño del relleno, en celdas (no en píxeles). Con tiles de 32 px,
## 36 x 21 cubre los 1152 x 648 px del mapa.
@export var fill_size: Vector2i = Vector2i(36, 21)

## Probabilidad relativa de cada mosaico, en el orden de las fuentes del
## [TileSet] (MosaicoPiedra1, 2 y 3). No hace falta que sumen 1.
@export var weights: Array[float] = [0.6, 0.25, 0.15]

## Semilla del azar. Con la misma semilla el piso queda igual en cada
## partida; cámbiala para obtener otra distribución.
@export var random_seed: int = 7

## Si es [code]true[/code], rellena el mapa al iniciar (solo si está vacío).
@export var autofill: bool = true


func _ready() -> void:
	if autofill and get_used_cells().is_empty():
		fill()


## Rellena [member fill_size] celdas desde el origen, eligiendo el mosaico de
## cada una según [member weights].
func fill() -> void:
	if tile_set == null or tile_set.get_source_count() == 0:
		push_warning("StoneFloor: la capa no tiene TileSet.")
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed

	for y: int in fill_size.y:
		for x: int in fill_size.x:
			set_cell(Vector2i(x, y), _pick_source(rng), Vector2i.ZERO)


## Elige al azar el id de una fuente del [TileSet], ponderado por
## [member weights]. [param rng] es el generador con la semilla del piso.
func _pick_source(rng: RandomNumberGenerator) -> int:
	var count: int = tile_set.get_source_count()
	var total: float = 0.0
	for i: int in count:
		total += _weight_of(i)
	if total <= 0.0:
		return tile_set.get_source_id(0)

	var roll: float = rng.randf() * total
	for i: int in count:
		roll -= _weight_of(i)
		if roll <= 0.0:
			return tile_set.get_source_id(i)
	return tile_set.get_source_id(count - 1)


## Peso del mosaico en la posición [param index]; 1.0 si no tiene uno asignado.
func _weight_of(index: int) -> float:
	return weights[index] if index < weights.size() else 1.0
