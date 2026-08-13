extends Node2D

@export var level_limit_right: int = 100000 # Im Inspektor pro Level anpassbar

func _ready() -> void:
	# Sucht die Camera2D in der Szene und setzt das Limit
	var camera = $Player/Camera2D # Passe den Pfad zu deiner Kamera an
	if camera:
		camera.limit_right = level_limit_right
