extends Node2D

# Variables para guardar las coordenadas límite del mapa
var limite_izquierdo: float
var limite_derecho: float
var limite_superior: float
var limite_inferior: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Ajustes iniciales del jugador
	# Se usa el método del Player (en lugar de tocar la luz directamente) para
	# que, además de apagar la linterna, el personaje use la skin sin lámpara.
	$player.set_lantern_enabled(false)
	$player/Camera2D.zoom = Vector2(1.4, 1.4)
	
	# 2. Calcular los límites basados en el mapa
	var tilemap = $TileMap 
	var camera = $player/Camera2D 
	
	var map_rect = tilemap.get_used_rect()
	var tile_size = tilemap.tile_set.tile_size
	
	# Convertir a píxeles
	limite_izquierdo = map_rect.position.x * tile_size.x
	limite_superior = map_rect.position.y * tile_size.y
	limite_derecho = map_rect.end.x * tile_size.x
	limite_inferior = map_rect.end.y * tile_size.y
	
	# Aplicar límites a la cámara
	camera.limit_left = limite_izquierdo
	camera.limit_top = limite_superior
	camera.limit_right = limite_derecho
	camera.limit_bottom = limite_inferior

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Limitar matemáticamente la posición X e Y del jugador
	$player.position.x = clamp($player.position.x, limite_izquierdo, limite_derecho)
	$player.position.y = clamp($player.position.y, limite_superior, limite_inferior)
