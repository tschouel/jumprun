@tool
class_name AnimationTempoSync
extends Node

## Berechnet automatisch die Abspielgeschwindigkeit (speed_scale) einer
## AnimatedSprite2D-Animation, sodass EIN kompletter Loop exakt einem
## musikalischen Notenwert bei einem bestimmten Tempo entspricht - z.B.
## "Viertel bei 90 bpm" = die Animation durchlaeuft ihre Frames in genau
## 60/90 = 0.667 Sekunden, unabhaengig davon, wie viele Frames sie hat oder
## welche Basis-FPS in der SpriteFrames-Resource eingetragen ist.
##
## WICHTIG: es wird NICHT die SpriteFrames-Resource selbst veraendert (die
## koennte von mehreren Sprites gemeinsam genutzt werden!) - stattdessen
## wird nur sprite.speed_scale gesetzt, ein rein lokaler Multiplikator, der
## ausschliesslich DIESE Node betrifft.
##
## @tool: die Geschwindigkeit wird sofort im Editor neu berechnet, wenn du
## note_value, bpm, frame_count, animation_name oder sprite aenderst - kein
## Play noetig. Im Editor selbst siehst du zwar keine laufende Animation,
## aber speed_scale ist beim naechsten Play sofort korrekt gesetzt.
##
## Setup: dieses Skript als Kind-Node UNTER die betreffende AnimatedSprite2D
## haengen (sprite bleibt dann leer, wird automatisch der Parent) ODER
## sprite im Inspector explizit zuweisen. animation_name leer lassen, um
## die aktuell gesetzte/erste Animation zu verwenden. frame_count nur
## ausfuellen, wenn du die Bildanzahl manuell vorgeben willst - 0
## (Standard) liest sie automatisch aus der SpriteFrames-Resource aus.

enum NoteValue { GANZE, HALBE, VIERTEL, ACHTEL, SECHZEHNTEL }
const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]

@export var sprite: AnimatedSprite2D:
	set(value):
		sprite = value
		apply_tempo()

## Leer lassen = die aktuell gesetzte/erste Animation von sprite verwenden.
@export var animation_name: String = "":
	set(value):
		animation_name = value
		apply_tempo()

## 0 = Bildanzahl automatisch aus der SpriteFrames-Resource auslesen. Nur
## ausfuellen, wenn du sie manuell vorgeben willst.
@export var frame_count: int = 0:
	set(value):
		frame_count = value
		apply_tempo()

@export var note_value: NoteValue = NoteValue.VIERTEL:
	set(value):
		note_value = value
		apply_tempo()

@export var bpm: float = 90.0:
	set(value):
		bpm = value
		apply_tempo()


func _ready() -> void:
	if not sprite:
		sprite = get_parent() as AnimatedSprite2D
	apply_tempo()


## Berechnet speed_scale so, dass EIN Loop der Animation exakt
## NOTE_FRACTIONS[note_value] * 4.0 * (60.0 / bpm) Sekunden dauert, und
## setzt sie auf sprite.speed_scale. Kann jederzeit manuell erneut
## aufgerufen werden (z.B. nach einem Tempo-Wechsel zur Laufzeit).
func apply_tempo() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	var anim: String = animation_name if animation_name != "" else sprite.animation
	if anim == "" or not sprite.sprite_frames.has_animation(anim):
		return

	var actual_frame_count: int = frame_count if frame_count > 0 else sprite.sprite_frames.get_frame_count(anim)
	if actual_frame_count <= 0 or bpm <= 0.0:
		return

	var loop_duration: float = NOTE_FRACTIONS[note_value] * 4.0 * (60.0 / bpm)
	if loop_duration <= 0.0:
		return

	var base_fps: float = sprite.sprite_frames.get_animation_speed(anim)
	if base_fps <= 0.0:
		return

	var desired_fps: float = actual_frame_count / loop_duration
	sprite.speed_scale = desired_fps / base_fps
