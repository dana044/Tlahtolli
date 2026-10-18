## Menú de pausa. Se abre con el botón de la esquina o con Esc ("ui_cancel").
## Necesita Process Mode = Always en el nodo raíz.
extends CanvasLayer

## Escena del menú principal.
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main/main_menu.tscn"
## Acción que abre/cierra la pausa.
@export var toggle_action: StringName = &"ui_cancel"
## Brillo con el que se resalta el botón seleccionado.
@export var highlight_color: Color = Color(1.3, 1.3, 1.3)

@export_group("Botón de pausa (esquina)")
## Botón que siempre está en pantalla. Asígnalo en el Inspector.
@export var pause_button: TextureButton
## Tamaño del botón en píxeles.
@export var pause_button_size: Vector2 = Vector2(56, 56)
## Separación respecto a la esquina superior izquierda.
@export var pause_button_margin: int = 12

@export_group("Menú de pausa")
## Panel completo del menú (el nodo Control). Asígnalo en el Inspector.
@export var overlay: Control
## Botones del menú (cualquier tipo de botón). Asígnalos en el Inspector.
@export var resume_button: BaseButton
@export var menu_button: BaseButton
@export var quit_button: BaseButton
## Tamaño de cada botón del menú. Súbelo para hacerlos más grandes.
@export var menu_button_size: Vector2 = Vector2(360, 90)
## Tamaño de letra de los botones (0 = respeta el de cada ImageButton).
@export_range(0, 96) var menu_font_size: int = 0
## Separación vertical entre los botones.
@export var menu_button_spacing: int = 20

## true mientras el menú está abierto.
var is_open: bool = false


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if overlay == null: missing.append("Overlay")
	if pause_button == null: missing.append("Pause Button")
	if resume_button == null: missing.append("Resume Button")
	if menu_button == null: missing.append("Menu Button")
	if quit_button == null: missing.append("Quit Button")
	if not missing.is_empty():
		push_error("PauseMenu: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	overlay.hide()
	_setup_pause_button()
	_setup_menu_buttons()

	pause_button.pressed.connect(_on_pause_button_pressed)
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(_go_to_main_menu)
	quit_button.pressed.connect(get_tree().quit)


## Coloca el botón de pausa en la esquina superior izquierda.
func _setup_pause_button() -> void:
	# Sin foco, para que Espacio/Enter (que avanzan diálogos) no lo activen.
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.ignore_texture_size = true
	pause_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_button.custom_minimum_size = pause_button_size
	pause_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, pause_button_margin)


## Aplica tamaño, letra y resalte a los botones del menú.
func _setup_menu_buttons() -> void:
	for button in [resume_button, menu_button, quit_button]:
		button.custom_minimum_size = menu_button_size
		if menu_font_size > 0 and button is ImageButton:
			(button as ImageButton).font_size = menu_font_size
		button.focus_entered.connect(func(): button.modulate = highlight_color)
		button.focus_exited.connect(func(): button.modulate = Color.WHITE)
		button.mouse_entered.connect(button.grab_focus)

	var box := resume_button.get_parent()
	if box is BoxContainer:
		box.add_theme_constant_override("separation", menu_button_spacing)


## El botón de la esquina solo se ve cuando el juego está corriendo: se oculta
## con la pausa abierta, durante un diálogo y con el diario abierto.
func _process(_delta: float) -> void:
	if pause_button == null:
		return
	pause_button.visible = not (
		get_tree().paused or DialogueManager.is_active() or Journal.is_open)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(toggle_action):
		return
	# Con el menú abierto, Esc siempre lo cierra. Cerrado, no se abre si hay
	# un diálogo o el diario en pantalla.
	if not is_open and (DialogueManager.is_active() or Journal.is_open):
		return
	toggle()
	get_viewport().set_input_as_handled()


func _on_pause_button_pressed() -> void:
	if is_open or DialogueManager.is_active() or Journal.is_open:
		return
	toggle()


## Abre o cierra el menú de pausa.
func toggle() -> void:
	is_open = not is_open
	overlay.visible = is_open
	get_tree().paused = is_open
	if is_open:
		resume_button.grab_focus()


func _go_to_main_menu() -> void:
	is_open = false
	overlay.hide()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
