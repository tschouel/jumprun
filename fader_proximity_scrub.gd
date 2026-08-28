extends Node

## Scrubbt durch eine Animation (z.B. 50 Frames) je nach Naehe des Fader-Werts
## zu einer Zielposition ("perfect_position") - wie ein Kalt/Warm-Anzeiger.
## Genau auf perfect_position = letzter Frame, je weiter weg (in BEIDE
## Richtungen gleich behandelt), desto niedriger der gezeigte Frame.

@export var fader: Fader
@export var sprite: AnimatedSprite2D
## Name der Animation im SpriteFrames, deren Frames durchgescrubbt werden.
@export var animation_name: String = "default"

@export_group("Zielposition")
## Fader-Wert (0..1), der als "perfekt getroffen" gilt - zeigt den letzten Frame
## (z.B. Frame 50 bei einer 50-Frame-Animation).
@export_range(0.0, 1.0) var perfect_position: float = 0.5
## Wie weit man von perfect_position entfernt sein darf, bis der niedrigste
## Frame (0) erreicht ist. Kleinere Range = praeziser/empfindlicher.
@export_range(0.01, 1.0) var distance_range: float = 0.3

func _ready() -> void:
	if sprite:
		sprite.stop()
		sprite.animation = animation_name
	if fader:
		fader.value_changed.connect(_on_fader_value_changed)
		call_deferred("_sync_initial_value")

func _sync_initial_value() -> void:
	if fader:
		_on_fader_value_changed(fader.get_value())

func _on_fader_value_changed(new_value: float) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return
	var distance: float = abs(new_value - perfect_position)
	var closeness: float = clamp(1.0 - (distance / distance_range), 0.0, 1.0)
	var frame_index: int = int(round(closeness * float(frame_count - 1)))
	frame_index = clamp(frame_index, 0, frame_count - 1)
	sprite.set_frame_and_progress(frame_index, 0.0)
