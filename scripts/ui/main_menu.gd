## Menú principal con portada y tres botones: Jugar, Tutorial y Ajustes.
extends Control

## Primera escena del juego (la intro con la abuelita).
@export_file("*.tscn") var first_scene: String = "res://scenes/levels/level_0_intro.tscn"
## Escena del tutorial.
@export_file("*.tscn") var tutorial_scene: String = "res://scenes/main/tutorial.tscn"
## Escena de ajustes. Vacía = el botón aún no hace nada.
@export_file("*.tscn") var settings_scene: String = ""

## Botones (se asignan en el Inspector). Sirve Button, TextureButton o ImageButton.
@export var play_button: BaseButton
@export var tutorial_button: BaseButton
@export var settings_button: BaseButton

## Tamaño de cada botón en píxeles.
@export var button_size: Vector2 = Vector2(320, 80)
## Separación vertical entre botones.
@export var button_spacing: int = 16
## Brillo con el que se resalta el botón seleccionado.
@export var highlight_color: Color = Color(1.3, 1.3, 1.3)

var _busy: bool = false   # Evita cambiar de escena dos veces.


func _ready() -> void:
	$Music.play()
	
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if play_button == null: missing.append("Play Button")
	if tutorial_button == null: missing.append("Tutorial Button")
	if settings_button == null: missing.append("Settings Button")
	if not missing.is_empty():
		push_error("MainMenu: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	for button in [play_button, tutorial_button, settings_button]:
		button.custom_minimum_size = button_size
		button.focus_entered.connect(func(): button.modulate = highlight_color)
		button.focus_exited.connect(func(): button.modulate = Color.WHITE)
		button.mouse_entered.connect(button.grab_focus)

	var box := play_button.get_parent()
	if box is BoxContainer:
		box.add_theme_constant_override("separation", button_spacing)

	play_button.pressed.connect(func(): _start(first_scene))
	tutorial_button.pressed.connect(func(): _start(tutorial_scene))
	settings_button.pressed.connect(_on_settings_pressed)

	# Permite navegar con las flechas y Enter/Espacio desde el inicio.
	play_button.grab_focus()


## Empieza una partida nueva o el tutorial: borra lo que quedó de antes
## (objetos y pistas) para que nada pase de una partida a otra.
func _start(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_warning("Menú: la escena aún no existe -> " + path)
		return
	_busy = true
	Inventory.clear()
	Journal.clear()
	get_tree().change_scene_to_file(path)


## Por ahora no hace nada. Cuando exista la escena de ajustes, escribe su
## ruta en "Settings Scene" en el Inspector.
func _on_settings_pressed() -> void:
	if settings_scene == "" or not ResourceLoader.exists(settings_scene):
		return
	get_tree().change_scene_to_file(settings_scene)
