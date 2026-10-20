## Pantalla de cierre "Lo que aprendiste".
##
## Se muestra después de hablar con la abuelita: un fondo oscuro con un título y
## tres datos, uno por leyenda (La Mulata, La Llorona y El Chaneque). Se
## construye por completo con código, así que no necesita escena propia: basta
## con [code]LearnedScreen.new()[/code] y añadirla al árbol. Se cierra con la
## tecla de avanzar (Espacio o Enter) y emite [signal closed].
## [br][br]Los textos se leen de [code]res://data/messages.json[/code]
## ([code]aprendiste_titulo[/code], [code]aprendiste_mulata[/code],
## [code]aprendiste_llorona[/code] y [code]aprendiste_chaneque[/code]); si falta
## alguno se usa el de [constant DEFAULT_FACTS].
## [br][br]Ruta sugerida: [code]res://scripts/ui/lo_que_aprendiste.gd[/code].
class_name LearnedScreen
extends CanvasLayer


## Se emite cuando el jugador cierra la pantalla, ya con el fundido terminado.
signal closed


## Archivo con los textos.
const MESSAGES_PATH: String = "res://data/messages.json"

## Id del título en [constant MESSAGES_PATH].
const TITLE_ID: String = "aprendiste_titulo"

## Ids de los tres datos en [constant MESSAGES_PATH]: Mulata, Llorona, Chaneque.
const FACT_IDS: Array[String] = ["aprendiste_mulata", "aprendiste_llorona", "aprendiste_chaneque"]

## Título por defecto, si falta en el archivo de textos.
const DEFAULT_TITLE: String = "Lo que aprendiste"

## Encabezado de cada dato, en el mismo orden que [constant FACT_IDS].
const HEADINGS: Array[String] = ["La Mulata", "La Llorona", "El Chaneque"]

## Datos por defecto, en el mismo orden que [constant FACT_IDS].
const DEFAULT_FACTS: Array[String] = [
	"La Mulata dibujó su salida con carbón: el ingenio y el arte abren caminos donde parece que no los hay.",
	"El llanto de la Llorona nos recuerda que una historia dolorosa también merece ser escuchada con respeto.",
	"Los chaneques cuidan el monte: quien entra en la naturaleza debe hacerlo con respeto y gratitud.",
]

## Capa de dibujo. Queda sobre el juego y bajo el fundido de [SceneManager].
const SCREEN_LAYER: int = 60

## Ancho de la columna de texto, en píxeles.
const COLUMN_WIDTH: float = 760.0


## Segundos del fundido de entrada y de salida.
@export var fade_time: float = 1.0

## Segundos que deben pasar antes de poder cerrar la pantalla, para que el
## jugador no la cierre sin querer con la pulsación del diálogo anterior.
@export var min_seconds: float = 1.5

## Texto de la indicación para continuar.
@export var hint_text: String = "Espacio para continuar"

## Color de fondo.
@export var background_color: Color = Color(0.04, 0.03, 0.06, 1.0)

## Color del título y de los encabezados.
@export var accent_color: Color = Color(1.0, 0.85, 0.45)


## Contenedor de toda la pantalla. Es el que se desvanece.
var _root: Control

## Indicación de la tecla para continuar.
var _hint: Label

## Indica si ya se puede cerrar la pantalla.
var _can_close: bool = false

## Indica si la pantalla ya se está cerrando.
var _closing: bool = false


## Construye la pantalla y la muestra con un fundido.
func _ready() -> void:
	layer = SCREEN_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui(_load_texts())
	_play_intro()


## Cierra la pantalla con la tecla de avanzar, una vez pasado
## [member min_seconds].
## [param event] es el evento de entrada recibido.
func _unhandled_input(event: InputEvent) -> void:
	if not _can_close or _closing:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_close()


## Lee de [constant MESSAGES_PATH] el título y los tres datos. Devuelve un
## diccionario con las claves [code]title[/code] (String) y [code]facts[/code]
## (Array[String]); los textos que falten se sustituyen por los de respaldo.
func _load_texts() -> Dictionary:
	var title: String = DEFAULT_TITLE
	var facts: Array[String] = DEFAULT_FACTS.duplicate()

	var file: FileAccess = FileAccess.open(MESSAGES_PATH, FileAccess.READ)
	if file != null:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			title = data.get(TITLE_ID, title)
			for i in FACT_IDS.size():
				facts[i] = data.get(FACT_IDS[i], facts[i])
	else:
		push_warning("LearnedScreen: no se encontró " + MESSAGES_PATH)

	return {"title": title, "facts": facts}


## Crea los nodos de la interfaz: fondo, título, los tres datos y la indicación.
## [param texts] es el diccionario devuelto por [method _load_texts].
func _build_ui(texts: Dictionary) -> void:
	_root = Control.new()
	_root.modulate.a = 0.0
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background: ColorRect = ColorRect.new()
	background.color = background_color
	_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_make_label(texts["title"], 40, accent_color))
	column.add_child(_make_spacer(10.0))

	var facts: Array = texts["facts"]
	for i in FACT_IDS.size():
		column.add_child(_make_label(HEADINGS[i], 24, accent_color))
		column.add_child(_make_label(facts[i], 20, Color.WHITE))
		column.add_child(_make_spacer(8.0))

	_hint = _make_label(hint_text, 16, Color(1.0, 1.0, 1.0, 0.7))
	_hint.modulate.a = 0.0
	column.add_child(_hint)


## Crea una etiqueta centrada que ajusta el texto al ancho de la columna.
## [param text] es el texto, [param font_size] el tamaño de la letra y
## [param color] su color.
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Crea un espacio vacío vertical.
## [param height] es su alto, en píxeles.
func _make_spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


## Hace aparecer la pantalla con un fundido y, pasado [member min_seconds],
## muestra la indicación y permite cerrarla.
func _play_intro() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, fade_time)

	await get_tree().create_timer(min_seconds + fade_time).timeout
	_can_close = true
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.5)


## Desvanece la pantalla y emite [signal closed].
func _close() -> void:
	_closing = true
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, fade_time)
	await tween.finished
	closed.emit()
