## Menú de pausa. Se abre/cierra con Esc ("ui_cancel").
## Necesita Process Mode = Always.
extends CanvasLayer

## Escena del menú principal.
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main/main_menu.tscn"
## Acción que abre/cierra la pausa.
@export var toggle_action: StringName = &"ui_cancel"

## Botones (se asignan en el Inspector).
@export var resume_button: Button
@export var menu_button: Button
@export var quit_button: Button


func _ready() -> void:
	hide()
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(_go_to_main_menu)
	quit_button.pressed.connect(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		# No pausar si hay un diálogo abierto.
		if DialogueManager.is_active():
			return
		toggle()
		get_viewport().set_input_as_handled()


## Abre o cierra la pausa.
func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		resume_button.grab_focus()


func _go_to_main_menu() -> void:
	get_tree().paused = false
	hide()
	get_tree().change_scene_to_file(main_menu_scene)
