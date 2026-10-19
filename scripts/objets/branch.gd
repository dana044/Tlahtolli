## Rama del suelo que se rompe al ser pisada por el jugador.
##
## Es un [Area2D] que detecta al nodo del grupo [code]player[/code]. Al
## pisarla cambia a la imagen de rama rota, reproduce un crujido y emite
## [signal broken] una sola vez; el nivel decide qué consecuencia tiene (por
## ejemplo, atenuar la linterna). La rama no sabe nada de luces ni de diálogos.
## [br][br]Las imágenes y el sonido se pueden asignar en el Inspector; si se
## dejan vacíos se buscan en las rutas por defecto definidas abajo.
class_name Branch
extends Area2D


## Se emite una sola vez, justo cuando la rama se rompe.
## [param branch] es la rama que se rompió.
signal broken(branch: Branch)


## Ruta por defecto de la imagen de la rama intacta.
const DEFAULT_INTACT_TEXTURE: String = "res://assets/sprites/objects/rama.png"

## Ruta por defecto de la imagen de la rama rota.
const DEFAULT_BROKEN_TEXTURE: String = "res://assets/sprites/objects/rama_rota.png"

## Carpeta donde se busca el sonido de la rama al romperse.
const SFX_DIR: String = "res://assets/audio/sfx/"

## Nombres de archivo (sin extensión) que se prueban, en orden, dentro de
## [constant SFX_DIR].
const BREAK_SOUND_NAMES: Array[String] = ["rama_rota", "rama", "crujido", "branch_break"]

## Extensiones de audio que se prueban para cada nombre.
const BREAK_SOUND_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]


## Indica que es la rama del tutorial del inicio del nivel. No se rompe al
## pisarla (el nivel la rompe por código con [method break_branch]).
@export var is_tutorial: bool = false

## Imagen de la rama intacta. Si está vacía se usa [constant DEFAULT_INTACT_TEXTURE].
@export var intact_texture: Texture2D

## Imagen de la rama rota. Si está vacía se usa [constant DEFAULT_BROKEN_TEXTURE].
@export var broken_texture: Texture2D

## Sonido del crujido. Si está vacío se busca en [constant SFX_DIR] y, si no
## hay ningún archivo, se usa un crujido provisional generado por código para
## que la rama nunca se rompa en silencio.
@export var break_sound: AudioStream


## Nodo [Sprite2D] que muestra la rama.
@onready var sprite: Sprite2D = $Sprite2D

## Reproductor del crujido.
@onready var sound: AudioStreamPlayer2D = $BreakSound

## Crujido provisional, generado una sola vez y compartido por todas las ramas.
static var _placeholder_crack: AudioStreamWAV

## Indica si ya se avisó de que faltaba el archivo de sonido (un solo aviso).
static var _warned_no_sound: bool = false

## Indica si la rama ya está rota. Evita que se rompa dos veces.
var _is_broken: bool = false


## Carga los recursos por defecto, muestra la rama intacta y se conecta a la
## detección de cuerpos.
func _ready() -> void:
	if intact_texture == null:
		intact_texture = _load_if_exists(DEFAULT_INTACT_TEXTURE) as Texture2D
	if broken_texture == null:
		broken_texture = _load_if_exists(DEFAULT_BROKEN_TEXTURE) as Texture2D
	if break_sound == null:
		break_sound = _find_break_sound()

	sprite.texture = intact_texture
	sound.stream = break_sound

	# El crujido debe sonar en el momento exacto de la pisada aunque el juego
	# se pause enseguida (por ejemplo, al abrirse el diálogo del Chaneque). Si
	# no, el audio se congelaría y terminaría de sonar hasta cerrar el diálogo.
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)

	# La rama del tutorial la rompe el nivel por código; así no se activa
	# sola si el jugador aparece encima de ella.
	if is_tutorial:
		monitoring = false


## Rompe la rama: cambia la imagen, reproduce el crujido y emite
## [signal broken]. Si ya estaba rota, no hace nada.
func break_branch() -> void:
	if _is_broken:
		return
	_is_broken = true

	if broken_texture != null:
		sprite.texture = broken_texture

	if sound.stream != null:
		# Un tono ligeramente distinto en cada rama evita que el sonido
		# se sienta repetitivo.
		sound.pitch_scale = randf_range(0.9, 1.1)
		sound.play()

	# Este método puede ejecutarse dentro de una señal de física, donde no se
	# permite modificar el monitoreo de forma directa.
	set_deferred("monitoring", false)
	broken.emit(self)


## Devuelve la rama a su estado intacto para que pueda volver a romperse.
## Lo usa el nivel al regresar al jugador a un checkpoint. La rama del
## tutorial se queda rota.
func repair() -> void:
	if is_tutorial:
		return
	_is_broken = false
	sprite.texture = intact_texture
	set_deferred("monitoring", true)


## Activa o desactiva la detección de pisadas de una rama que sigue intacta.
## [param active] es [code]false[/code] para que deje de romperse (por
## ejemplo, cuando el nivel ya terminó).
func set_active(active: bool) -> void:
	if _is_broken or is_tutorial:
		return
	set_deferred("monitoring", active)


## Rompe la rama si quien entró es el jugador.
## [param body] es el cuerpo que entró en el área.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		break_branch()


## Carga el recurso de [param path] si existe; en caso contrario avisa en la
## consola y devuelve [code]null[/code], para que el juego no se detenga por
## una imagen o sonido que aún no están en el proyecto.
func _load_if_exists(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Branch: no se encontró el recurso " + path)
	return null


## Busca el sonido de la rama en [constant SFX_DIR] probando los nombres y
## extensiones definidos arriba. Si no encuentra ninguno, avisa una vez en la
## consola y devuelve un crujido provisional.
func _find_break_sound() -> AudioStream:
	for sound_name in BREAK_SOUND_NAMES:
		for extension in BREAK_SOUND_EXTENSIONS:
			var path: String = "%s%s.%s" % [SFX_DIR, sound_name, extension]
			if ResourceLoader.exists(path):
				return load(path) as AudioStream

	if not _warned_no_sound:
		_warned_no_sound = true
	return _get_placeholder_crack()


## Devuelve un crujido provisional: dos chasquidos cortos de ruido que se
## apagan rápido. Se genera la primera vez y se reutiliza después.
func _get_placeholder_crack() -> AudioStreamWAV:
	if _placeholder_crack != null:
		return _placeholder_crack

	var mix_rate: int = 22050
	var sample_count: int = int(mix_rate * 0.3)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	var smoothed: float = 0.0
	for i in sample_count:
		var t: float = float(i) / mix_rate
		# Primer chasquido al inicio y un segundo, más suave, a los 80 ms.
		var envelope: float = exp(-t * 40.0)
		if t >= 0.08:
			envelope += 0.7 * exp(-(t - 0.08) * 50.0)
		# Un filtro simple le quita agudez al ruido para que suene a madera.
		smoothed = lerpf(smoothed, randf_range(-1.0, 1.0), 0.6)
		var value: int = clampi(int(smoothed * envelope * 0.8 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	_placeholder_crack = wav
	return wav
