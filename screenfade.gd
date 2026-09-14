class_name ScreenFade
extends CanvasLayer
## Einfache, wiederverwendbare Fade-to-Black Komponente.
##
## SETUP IM EDITOR:
## - Dieses Skript auf eine CanvasLayer-Node legen.
## - Ein ColorRect als Kind-Node hinzufügen, Name "ColorRect".
##   - Layout > Anchors Preset: "Full Rect" (deckt den ganzen Bildschirm ab)
##   - Color: Schwarz, Alpha = 0 (wird hier in _ready() ohnehin gesetzt)
##   - Mouse Filter: Ignore (damit der Rect keine Klicks/Inputs blockiert,
##     ausser waehrend er sichtbar ist - siehe _rect.mouse_filter unten)
## - layer wird in _ready() auf 100 gesetzt, damit der Fade ueber allem
##   anderen liegt (HUD, Spielwelt, etc.).

@export var fade_color: Color = Color.BLACK

@onready var _rect: ColorRect = $ColorRect


func _ready() -> void:
	layer = 100
	_rect.color = fade_color
	_rect.color.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Blendet auf Schwarz (Alpha 0 -> 1) über die angegebene Dauer.
## Per "await" aufrufen, um auf das Ende zu warten:
##   await screen_fade.fade_out(1.5)
func fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished


## Blendet von Schwarz zurück (Alpha 1 -> 0) über die angegebene Dauer.
func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, duration)
	await tween.finished
