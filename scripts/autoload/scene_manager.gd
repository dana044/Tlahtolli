## Gestor de transiciones de fundido.
##
## Crea por código una capa de interfaz con un rectángulo a pantalla completa
## y lo anima con un [Tween]. Al ser infraestructura global, no requiere una
## escena propia y funciona en cualquier nivel.
extends Node

## Color del fundido.
const FADE_COLOR: Color = Color.BLACK

## Capa de dibujo del fundido. Un valor alto lo mantiene sobre cualquier HUD.
const FADE_LAYER: int = 100

## Capa de interfaz que contiene el rectángulo de fundido.
var _canvas_layer: CanvasLayer

## Rectángulo a pantalla completa que produce el fundido.
var _fade_rect: ColorRect

## Tween del fundido en curso. [code]null[/code] si no hay ninguno activo.
var _tween: Tween


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = FADE_LAYER
	add_child(_canvas_layer)

	_fade_rect = ColorRect.new()
	# Inicia transparente para no cubrir el juego al cargar.
	_fade_rect.color = Color(FADE_COLOR, 0.0)
	# El rectángulo cubre toda la pantalla; sin este filtro bloquearía los
	# clics destinados a la interfaz.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_fade_rect)


## Oscurece la pantalla hasta cubrirla por completo.
## Puede esperarse con [code]await[/code].
## [param duration] es la duración del fundido, en segundos.
func fade_out(duration: float) -> void:
	await _fade_to(1.0, duration)


## Aclara la pantalla hasta hacerla totalmente visible.
## Puede esperarse con [code]await[/code].
## [param duration] es la duración del fundido, en segundos.
func fade_in(duration: float) -> void:
	await _fade_to(0.0, duration)


## Anima la opacidad del rectángulo hacia [param target_alpha].
func _fade_to(target_alpha: float, duration: float) -> void:
	_kill_previous_tween()
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await _tween.finished


## Cancela el fundido en curso, si existe, para que nunca compitan dos a la
## vez. Prevalece el último solicitado.
func _kill_previous_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null
