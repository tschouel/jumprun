extends Node

## Scrubbt durch eine Animation (z.B. 50 Frames) je nach Naehe zur
## perfect_position - kommt vom zentralen ClosenessSource (fader_closeness.gd),
## nicht mehr direkt vom Fader. 0 = state_a/unangenehm -> niedrigster Frame,
## 1 = perfect -> letzter Frame.
##
## Wiederverwendbar: dasselbe Skript einfach mehrfach an verschiedene
## AnimatedSprite2D haengen (z.B. eine "on top" und eine andere) und jeweils
## denselben (oder einen anderen) closeness_source zuweisen - keine
## Code-Duplizierung noetig.

@export var closeness_source: ClosenessSource
@export var sprite: AnimatedSprite2D
## Name der Animation im SpriteFrames, deren Frames durchgescrubbt werden.
@export var animation_name: String = "default"

func _ready() -> void:
	if sprite:
		sprite.stop()
		sprite.animation = animation_name
	if closeness_source:
		closeness_source.closeness_changed.connect(_on_closeness_changed)

func _on_closeness_changed(closeness: float) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return
	var frame_index: int = int(round(closeness * float(frame_count - 1)))
	frame_index = clamp(frame_index, 0, frame_count - 1)
	sprite.set_frame_and_progress(frame_index, 0.0)
