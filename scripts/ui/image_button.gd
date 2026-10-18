## Botón con una imagen de fondo y un texto configurable encima.
## Sirve para todos los botones del juego: se cambia el texto, la fuente y
## el tamaño de letra en el Inspector de cada instancia.
## Es @tool para que el texto se vea también en el editor.
@tool
class_name ImageButton
extends TextureButton

## Texto que se muestra sobre la imagen.
@export var label_text: String = "Botón":
	set(value):
		label_text = value
		_apply_style()

## Tipografía del texto. Si está vacía, usa la fuente por defecto del proyecto.
@export var font: Font:
	set(value):
		font = value
		_apply_style()

## Tamaño de letra.
@export_range(6, 96) var font_size: int = 24:
	set(value):
		font_size = value
		_apply_style()

## Color del texto.
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		_apply_style()

## Color del contorno del texto.
@export var outline_color: Color = Color.BLACK:
	set(value):
		outline_color = value
		_apply_style()

## Grosor del contorno (0 = sin contorno).
@export_range(0, 12) var outline_size: int = 0:
	set(value):
		outline_size = value
		_apply_style()

## Desplazamiento del texto respecto al centro, en píxeles. Sirve para
## corregir imágenes cuyo centro visual no coincide con el centro del archivo.
@export var text_offset: Vector2 = Vector2.ZERO:
	set(value):
		text_offset = value
		_apply_style()

## Cuánto baja el texto, en píxeles, mientras el botón está presionado.
@export var pressed_text_offset: Vector2 = Vector2(0, 2)

## Label donde se dibuja el texto (se crea por código).
var _label: Label


func _ready() -> void:
	# La imagen respeta el tamaño mínimo del botón y mantiene su proporción.
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Para que los clics pasen al botón y no se queden en el texto.
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_style()

	if not Engine.is_editor_hint():
		button_down.connect(func(): _apply_style(pressed_text_offset))
		button_up.connect(func(): _apply_style())


## Aplica texto, fuente, tamaño, color y posición al Label.
## [param extra_offset] se suma al desplazamiento (efecto de presionado).
func _apply_style(extra_offset: Vector2 = Vector2.ZERO) -> void:
	if _label == null:
		return
	_label.text = label_text

	if font != null:
		_label.add_theme_font_override("font", font)
	else:
		_label.remove_theme_font_override("font")
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", font_color)
	_label.add_theme_color_override("font_outline_color", outline_color)
	_label.add_theme_constant_override("outline_size", outline_size)

	var total := text_offset + extra_offset
	_label.offset_left = total.x
	_label.offset_right = total.x
	_label.offset_top = total.y
	_label.offset_bottom = total.y
