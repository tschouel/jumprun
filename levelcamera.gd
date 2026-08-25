extends Node
## Kamera-Setup pro Hauptszene/Level.
## Node irgendwo in die Szene legen, Camera- und Positions-Werte im Inspector setzen.
@export var camera: Camera2D
@export var start_position: Vector2 = Vector2.ZERO
@export var zoom: float = 1.0
func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_2d()
	if not camera:
		push_warning("LevelCamera: Keine Camera2D gefunden - bitte im Inspector manuell zuweisen.")
		return
	camera.global_position = start_position
	camera.zoom = Vector2(zoom, zoom)
	camera.make_current()
