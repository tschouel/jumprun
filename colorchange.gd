extends Node

## Faerbt den Hintergrund je nach Naehe zur perfect_position - kommt vom
## zentralen ClosenessSource (fader_closeness.gd), nicht mehr direkt vom
## Fader-Rohwert. 0 = state_a/unangenehm, 1 = perfect.
## Bevorzugt eine Gradient-Resource (beliebig viele Farbstufen, im Inspector
## visuell bearbeitbar) - falls keine gesetzt ist, wird stattdessen einfach
## zwischen color_from (state_a) und color_to (perfect) interpoliert.

@export var closeness_source: ClosenessSource
@export var color_rect: ColorRect

@export_group("Farbverlauf")
## Optional: Gradient-Resource mit beliebig vielen Farbstufen. Hat Vorrang, falls gesetzt.
@export var gradient: Gradient
## Wird nur genutzt, wenn kein gradient gesetzt ist (closeness 0.0 / state_a)
@export var color_from: Color = Color.BLACK
## Wird nur genutzt, wenn kein gradient gesetzt ist (closeness 1.0 / perfect)
@export var color_to: Color = Color.WHITE

func _ready() -> void:
	if closeness_source:
		closeness_source.closeness_changed.connect(_on_closeness_changed)

func _on_closeness_changed(closeness: float) -> void:
	if not color_rect:
		return
	if gradient:
		color_rect.color = gradient.sample(closeness)
	else:
		color_rect.color = color_from.lerp(color_to, closeness)
