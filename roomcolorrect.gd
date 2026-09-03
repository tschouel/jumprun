extends ColorRect

@export var target_color: Color = Color.WHITE
@export var inactive_color: Color = Color.GRAY
@export var transition_duration: float = 1.0

var _tween: Tween

func _ready() -> void:
	color = inactive_color

func fade_in() -> void:
	_start_tween(target_color)

func fade_out() -> void:
	_start_tween(inactive_color)

func _start_tween(to_color: Color) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", to_color, transition_duration)
