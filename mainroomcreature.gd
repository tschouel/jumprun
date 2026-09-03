extends AnimatedSprite2D

@export var off_animation: String = ""
@export var start_animation: String = ""
@export var idle_animation: String = ""
@export var end_animation: String = ""
@export var end_animation_reverse: bool = false

func _ready() -> void:
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

## Normalfall (skip_off = false, wie bisher): falls eine Off-Animation
## gesetzt ist, wird die zuerst abgespielt und erst wenn SIE fertig ist,
## springt _on_animation_finished() automatisch weiter zur Start-Animation.
##
## play_start(true): startet SOFORT die Start-Animation, egal was gerade
## laeuft (auch wenn Off gerade mittendrin ist) - genau der Sofort-Trigger,
## den du wolltest, ohne auf das Ende von Off zu warten.
func play_start(skip_off: bool = false) -> void:
	if not skip_off and off_animation != "":
		play(off_animation)
	elif start_animation != "":
		play(start_animation)

func play_end() -> void:
	if end_animation == "":
		return
	if end_animation_reverse:
		play(end_animation, -1.0, true)
	else:
		play(end_animation)

func _on_animation_finished() -> void:
	if animation == off_animation and start_animation != "":
		play(start_animation)
	elif animation == start_animation and idle_animation != "":
		play(idle_animation)
