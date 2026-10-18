## Pergamino con el acertijo y sus tres opciones de respuesta.
##
## Es una interfaz "tonta": solo muestra el acertijo, recibe la opción elegida
## y avisa con [signal answered] si fue correcta. No decide qué pasa después
## (diálogos, progreso del barco): eso lo hace el nivel.
## [br][br]Al elegir una opción el panel se bloquea solo (todas las opciones
## quedan deshabilitadas) para evitar entradas accidentales. El nivel lo
## desbloquea con [method unlock] tras un error, o lo cierra con
## [method close] tras un acierto. No se puede cerrar sin acertar.
## [br][br]Estructura de nodos esperada (los nombres deben coincidir):
## [codeblock]
## RiddlePanel (CanvasLayer)
## ├─ Dim (ColorRect)
## └─ Center (CenterContainer)
##    └─ Scroll (NinePatchRect)
##       └─ Margin (MarginContainer)
##          └─ VBox (VBoxContainer)
##             ├─ TitleLabel (Label)
##             ├─ RiddleLabel (Label)
##             ├─ Option1 (Button)
##             ├─ Option2 (Button)
##             └─ Option3 (Button)
## [/codeblock]
class_name RiddlePanel
extends CanvasLayer


## Se emite cuando el jugador elige una opción.
## [param riddle_id] es el id del acertijo abierto; [param is_correct] indica
## si la opción elegida era la respuesta correcta.
signal answered(riddle_id: String, is_correct: bool)


## Ruta (relativa a este nodo) del contenedor que guarda los textos y botones.
const VBOX_PATH: String = "Center/Scroll/Margin/VBox"

## Nombres de los botones de opción, en orden (A, B, C).
const OPTION_NAMES: Array[String] = ["Option1", "Option2", "Option3"]


## Etiqueta con el tema del acertijo (título del pergamino).
@onready var _title_label: Label = get_node(VBOX_PATH + "/TitleLabel")

## Etiqueta con el texto del acertijo.
@onready var _riddle_label: Label = get_node(VBOX_PATH + "/RiddleLabel")

## Botones de opción, en el mismo orden que las opciones del JSON.
var _buttons: Array[Button] = []

## Id del acertijo que se está mostrando.
var _riddle_id: String = ""

## Índice de la opción correcta del acertijo actual.
var _correct_index: int = -1

## Indica si las opciones están bloqueadas (no responden al jugador).
var _locked: bool = false


## Reúne los botones, conecta sus señales y deja el panel oculto.
func _ready() -> void:
	for option_name in OPTION_NAMES:
		var button: Button = get_node(VBOX_PATH + "/" + option_name) as Button
		_buttons.append(button)
		# bind() añade el índice de la opción a la señal pressed.
		button.pressed.connect(_on_option_pressed.bind(_buttons.size() - 1))
	hide()


## Muestra un acertijo y habilita sus opciones.
## [param riddle_id] es el id del acertijo; [param riddle] es su diccionario
## de [code]riddles.json[/code] (theme, text, options, correct).
func open(riddle_id: String, riddle: Dictionary) -> void:
	_riddle_id = riddle_id
	_correct_index = int(riddle.get("correct", -1))
	_title_label.text = String(riddle.get("theme", ""))
	_riddle_label.text = String(riddle.get("text", ""))

	var options: Array = riddle.get("options", [])
	for i in _buttons.size():
		var has_option: bool = i < options.size()
		_buttons[i].visible = has_option
		if has_option:
			# char(65) es "A": las opciones se rotulan A), B), C).
			_buttons[i].text = "%s) %s" % [char(65 + i), String(options[i])]

	show()
	unlock()


## Cierra el panel (tras un acierto).
func close() -> void:
	lock()
	hide()


## Deshabilita todas las opciones. Se llama sola al elegir una.
func lock() -> void:
	_locked = true
	for button in _buttons:
		button.disabled = true


## Vuelve a habilitar las opciones (tras un error) y devuelve el foco a la
## primera, para poder responder también con el teclado.
func unlock() -> void:
	_locked = false
	for button in _buttons:
		button.disabled = false
	if not _buttons.is_empty() and _buttons[0].visible:
		_buttons[0].grab_focus()


## Reacciona a la elección de una opción: bloquea el panel y avisa al nivel.
## [param index] es el índice (0, 1 o 2) de la opción elegida.
func _on_option_pressed(index: int) -> void:
	if _locked:
		return
	lock()
	answered.emit(_riddle_id, index == _correct_index)
