extends AnimatedSprite2D

## Im Inspector pro Instanz individuell setzen, z.B. 0, 4, 8
@export var start_frame: int = 0
## Wenn true, wird start_frame ignoriert und zufällig gestartet
@export var randomize_start: bool = false

func _ready() -> void:
	play()
	var frame_count := sprite_frames.get_frame_count(animation)
	if randomize_start:
		frame = randi() % frame_count
	else:
		frame = start_frame % frame_count
