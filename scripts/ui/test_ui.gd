## Prueba SOLO para Dana. No se sube a Git.
extends Node

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: Inventory.add_item("mandarina")
			KEY_R: Inventory.add_item("liston")
			KEY_T: Inventory.add_item("flor")
			KEY_Y: Inventory.add_item("medallon")
			KEY_U: Inventory.add_item("moneda")
			KEY_I: Inventory.add_item("muneca")
			KEY_O: Inventory.remove_item("mandarina")
			KEY_C: DialogueManager.play("res://data/dialogues/abuelita_intro.json", "abuelita_intro")
			KEY_P: DialogueManager.play("res://data/dialogues/abuelita_intro.json")
