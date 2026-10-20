## Pantalla de créditos. Se muestra al terminar el juego, sobre la portada del
## menú principal, con la música de fondo y un botón de salida.
## Los nombres se editan en el Inspector (lista "Entries"), sin tocar el código.
extends Control

## Qué hace el botón de salida.
enum ExitAction {
	BACK_TO_MENU, ## Regresa al menú principal.
}


@export_group("Salida")
## Qué ocurre al presionar el botón.
@export var exit_action: ExitAction = ExitAction.BACK_TO_MENU
## Escena del menú principal (para la opción BACK_TO_MENU).
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main/main_menu.tscn"

@export_group("Nodos de la escena")
## Contenedor donde se escriben los créditos. Asígnalo en el Inspector.
@export var content_box: VBoxContainer
## Botón de salida (Button, TextureButton o ImageButton). Asígnalo en el Inspector.
@export var exit_button: BaseButton
## Reproductor de la música. Asígnalo en el Inspector.
@export var music_player: AudioStreamPlayer

@export_group("Contenido")
## Título de la pantalla.
@export var title_text: String = "Créditos"
## Cada línea es "Rol|Nombre". Se muestran en este orden.
@export var entries: Array[String] = [
	"Dev principal|Citlaly Morales Viveros",
	"Dev soporte|Dana Carmona Santamaria",
	"Game Designer|Stephanie Elizdeth Hernández Prieto",
	"Diseño visual|Diego Rafael Jiménez Trujano",
	"Producción|Todos",
	"Música|ElevenLabs Music
	Epidemic Sound",
	"Asistencia|Claude",
]
## Texto final (vacío = ninguno).
@export var footer_text: String = "Gracias por jugar"

@export_group("Tipografía")
## Fuente de los textos. Vacía = la fuente por defecto del proyecto.
@export var font: Font
@export_range(8, 96) var title_size: int = 56
@export_range(8, 64) var role_size: int = 32
@export_range(8, 64) var name_size: int = 38
@export_range(8, 64) var footer_size: int = 32
@export var title_color: Color = Color("ffe9a8")
@export var role_color: Color = Color("e0b878")
@export var name_color: Color = Color.WHITE
## Grosor del contorno negro que ayuda a leer el texto sobre la portada.
@export_range(0, 12) var outline_size: int = 5
## Ancho máximo de cada línea antes de saltar de renglón, en píxeles.
@export var text_width: float = 700.0
## Separación vertical entre bloques, en píxeles.
@export var block_spacing: int = 14

@export_group("Animación")
## Velocidad a la que suben los créditos, en píxeles por segundo.
@export var scroll_speed: float = 65.0
## Segundos antes de que aparezca el primer bloque.
@export_range(0.0, 5.0, 0.1) var start_delay: float = 0.5
## Segundos que tarda en aparecer cada bloque.
@export_range(0.1, 3.0, 0.1) var fade_seconds: float = 0.7
## Segundos entre la aparición de un bloque y el siguiente.
@export_range(0.0, 2.0, 0.05) var block_delay: float = 0.3
## Segundos que se espera, con los créditos ya terminados, antes de
## volver solo al menú principal. Con 0 no vuelve solo.
@export_range(0.0, 15.0, 0.5) var auto_exit_delay: float = 3.0
## Segundos iniciales en los que se ignora Espacio, para que no se salte
## los créditos por la pulsación de la pantalla anterior.
@export_range(0.0, 3.0, 0.1) var skip_lock_seconds: float = 1.0

@export_group("Música")
## Música de los créditos. Si queda vacía se usa la del nodo AudioStreamPlayer.
@export var music: AudioStream
## Volumen final de la música, en dB.
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = 0.0
## Segundos que tarda la música en subir al empezar.
@export_range(0.0, 5.0, 0.1) var music_fade_in: float = 1.5

@export_group("Botón")
## Tamaño del botón de salida, en píxeles.
@export var button_size: Vector2 = Vector2(320, 80)
## Brillo con el que se resalta el botón seleccionado.
@export var highlight_color: Color = Color(1.3, 1.3, 1.3)


## Evita ejecutar la salida dos veces.
var _leaving: bool = false
## Indica si los créditos están subiendo.
var _scrolling: bool = false
## Segundos transcurridos desde que se abrió la pantalla.
var _alive: float = 0.0


func _ready() -> void:
	# Avisa con claridad qué campo falta en el Inspector.
	var missing: Array[String] = []
	if content_box == null: missing.append("Content Box")
	if exit_button == null: missing.append("Exit Button")
	if music_player == null: missing.append("Music Player")
	if not missing.is_empty():
		push_error("Credits: faltan por asignar en el Inspector: " + ", ".join(missing))
		return

	var blocks: Array[Control] = _build_content()
	_setup_exit_button()
	_start_music()
	_start_scroll(blocks)


#region Contenido

## Crea los textos y devuelve los bloques en el orden en que aparecerán.
func _build_content() -> Array[Control]:
	for child in content_box.get_children():
		child.queue_free()
	content_box.add_theme_constant_override("separation", block_spacing)

	var blocks: Array[Control] = []
	blocks.append(_make_label(title_text, title_size, title_color))

	for line in entries:
		var parts: PackedStringArray = line.split("|", true, 1)
		var pair := VBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if parts.size() == 2:
			pair.add_child(_make_label(parts[0].strip_edges(), role_size, role_color))
			pair.add_child(_make_label(parts[1].strip_edges(), name_size, name_color))
		else:
			# Sin "|" se muestra solo como nombre.
			pair.add_child(_make_label(line.strip_edges(), name_size, name_color))
		blocks.append(pair)

	if footer_text != "":
		blocks.append(_make_label(footer_text, footer_size, title_color))

	for block in blocks:
		block.modulate.a = 1.0 # Ahora el texto es completamente visible desde el inicio
		content_box.add_child(block)
	return blocks


## Texto centrado con la tipografía configurada.
## Texto centrado con la tipografía configurada.
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(text_width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline_size)
	return label


## Inicia el movimiento de los créditos hacia arriba y, al final, el botón.
func _start_scroll(_blocks: Array[Control]) -> void:
	exit_button.modulate.a = 0.0

	# Esperamos un fotograma para que Godot calcule el ancho correcto de la pantalla
	await get_tree().process_frame
	
	# top_level = true hace que el contenedor ignore las restricciones de su
	# padre (ContentMargin) para que podamos moverlo hacia arriba libremente
	content_box.top_level = true
	content_box.position.y = get_viewport_rect().size.y
	content_box.position.x = (get_viewport_rect().size.x - content_box.size.x) / 2.0

	await get_tree().create_timer(start_delay).timeout
	_scrolling = true


func _process(delta: float) -> void:
	# cuenta el tiempo para el bloqueo inicial de Espacio.
	_alive += delta

	if _scrolling:
		content_box.position.y -= scroll_speed * delta

		# Se detiene cuando el último texto pasa del centro de la pantalla
		if content_box.position.y + content_box.size.y < get_viewport_rect().size.y * 0.6:
			_scrolling = false
			var tween: Tween = create_tween()
			tween.tween_property(exit_button, "modulate:a", 1.0, fade_seconds)
			# al terminar los créditos, vuelve solo al menú.
			_exit_after_delay()

#endregion


#region Botón y música

## Da tamaño, resalte y acción al botón de salida.
func _setup_exit_button() -> void:
	exit_button.custom_minimum_size = button_size
	exit_button.focus_entered.connect(func(): exit_button.modulate = highlight_color)
	exit_button.focus_exited.connect(func(): exit_button.modulate = Color.WHITE)
	exit_button.mouse_entered.connect(exit_button.grab_focus)
	exit_button.pressed.connect(_on_exit_pressed)
	# Permite activarlo con Enter o Espacio desde el inicio.
	exit_button.grab_focus()


## Espera [member auto_exit_delay] segundos y sale al menú principal. Si
## el jugador ya salió antes (botón o Espacio), no hace nada.
func _exit_after_delay() -> void:
	if auto_exit_delay <= 0.0:
		return
	await get_tree().create_timer(auto_exit_delay).timeout
	_on_exit_pressed()


## Con Espacio (o Enter) se salta lo que falte de los créditos y se
## vuelve al menú principal.
## [param event] es el evento de entrada recibido.
func _unhandled_input(event: InputEvent) -> void:
	if _alive < skip_lock_seconds:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()


## Sale de los créditos: limpia la partida, baja la música y ejecuta la acción.
func _on_exit_pressed() -> void:
	if _leaving:
		return
	_leaving = true

	# Una partida nueva no debe heredar objetos ni pistas de esta.
	Inventory.clear()
	Journal.clear()

	if music_player.playing:
		var tween: Tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.6)
		await tween.finished

	match exit_action:
		ExitAction.BACK_TO_MENU:
			if ResourceLoader.exists(main_menu_scene):
				get_tree().change_scene_to_file(main_menu_scene)
			else:
				push_warning("Credits: no existe " + main_menu_scene)
				_leaving = false


## Empieza la música con un fundido de entrada. Se repite al terminar, aunque
## el archivo de audio no esté configurado para repetirse.
func _start_music() -> void:
	if music != null:
		music_player.stream = music
	if music_player.stream == null:
		push_warning("Credits: no hay música asignada (campo 'Music' o 'Stream' del reproductor).")
		return

	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)
	music_player.volume_db = -40.0
	music_player.play()
	create_tween().tween_property(music_player, "volume_db", music_volume_db, music_fade_in)


func _on_music_finished() -> void:
	if not _leaving:
		music_player.play()

#endregion	
