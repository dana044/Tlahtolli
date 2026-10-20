extends Area2D

@onready var flame: AnimatedSprite2D = $Antorcha

func _ready() -> void:
	flame.play()
