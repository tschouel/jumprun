class_name FmodStartTrigger
extends Area2D

@export_group("FMOD Einstellungen")
## Ziehe hier die Node 'FmodEventEmitter2D' rein
@export var audio_controller: Node

func _ready() -> void:
	# Verhindert doppelten Signal-Fehler, falls im Editor schon verbunden
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if not audio_controller:
		audio_controller = get_tree().current_scene.find_child("FmodEventEmitter2D", true, false)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if audio_controller and audio_controller.has_method("set_go"):
			audio_controller.set_go(2.0)
			print("FmodStart durchfahren: Go auf 2 gesetzt!")
