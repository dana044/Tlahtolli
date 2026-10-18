## Menú de pausa. Se abre/cierra con Esc ("ui_cancel").
## Necesita Process Mode = Always en el nodo raíz.
extends CanvasLayer

## Escena del menú principal.
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main/main_menu.tscn"
## Acción que abre/cierra la pausa.
@export var toggle_action: StringName = &"ui_cancel"
## Brillo con el que se resalta el botón seleccionado.
@export var highlight_color: Color = Color(1.3, 1.3, 1.3)

## Botones del menú (cualquier tipo de botón). Asígnalos en el Inspector.
@export var resume_button: BaseButton
@export var menu_button: BaseButton
@export var quit_button: BaseButton

## true mientras el menú está abierto.
var is_open: bool = false


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if resume_button == null: missing.append("Resume Button")
	if menu_button == null: missing.append("Menu Button")
	if quit_button == null: missing.append("Quit Button")
	if not missing.is_empty():
		push_error("PauseMenu: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	hide()
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(_go_to_main_menu)
	quit_button.pressed.connect(get_tree().quit)

	for button in [resume_button, menu_button, quit_button]:
		_setup_highlight(button)


## Ilumina el botón al enfocarlo con teclado o pasar el mouse.
func _setup_highlight(button: BaseButton) -> void:
	button.focus_entered.connect(func(): button.modulate = highlight_color)
	button.focus_exited.connect(func(): button.modulate = Color.WHITE)
	button.mouse_entered.connect(button.grab_focus)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(toggle_action):
		return
	# Con el menú abierto, Esc siempre lo cierra. Cerrado, no se abre si hay
	# un diálogo o el diario en pantalla.
	if not is_open and (DialogueManager.is_active() or Journal.is_open):
		return
	toggle()
	get_viewport().set_input_as_handled()


## Abre o cierra el menú de pausa.
func toggle() -> void:
	is_open = not is_open
	visible = is_open
	get_tree().paused = is_open
	if is_open:
		resume_button.grab_focus()


func _go_to_main_menu() -> void:
	is_open = false
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
