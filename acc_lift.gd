extends Node2D
class_name Lift
## Lift, der dauerhaft zwischen eingefahrener und ausgefahrener Position
## hin- und herfährt.
##
## Sowohl das Sprite-Frame (AccLiftSprite:frame) als auch die Plattform-
## Position (AccLift:position) stecken als Property-Tracks in EINER
## AnimationPlayer-Animation ("lift") - dadurch bleiben beide zu jedem
## Zeitpunkt exakt synchron, und man kann im Editor durch Scrubben der
## Zeitleiste direkt sehen, wo der Sprite gerade steht, um die Position-
## Keyframes passend zu setzen.
##
## WICHTIG (das war der Bug): Die "Autoplay"-Eigenschaft direkt am
## AnimationPlayer-Node (AccliftAn, oben im Animation-Panel als Dropdown)
## MUSS auf "[none]" stehen. Dieses Script hier ist die EINZIGE Stelle,
## die play() aufrufen soll - läuft die native Autoplay-Eigenschaft
## zusätzlich, wird die Animation doppelt gestartet bzw. zwei
## unabhängige Quellen konkurrieren um denselben Node-Zustand, was zu
## Ruckeln/Überblendungen (halbtransparente Frames) führen kann.
##
## Genauso: AccLiftSprite (der AnimatedSprite2D) darf selbst KEINE eigene
## Autoplay-Animation gesetzt haben (im SpriteFrames-Panel unten, kleines
## Play-Symbol neben einer Animation) - sonst läuft der Sprite nach
## eigenem, unabhängigem Takt weiter, komplett losgelöst davon, was der
## AnimationPlayer vorgibt. Zur Sicherheit stoppt dieses Script den
## Sprite trotzdem explizit selbst, bevor die eigentliche Animation
## gestartet wird - so kann er nie parallel weiterlaufen, egal was im
## Inspector eingestellt ist.
##
## Setup: AccLiftSprite (Sprite), AccLift (Platform/Collider-Body) und
## AccliftAn (AnimationPlayer) müssen als "Scene Unique Name" markiert
## sein (%-Symbol in der Szenenübersicht - Rechtsklick auf den Node →
## "Access as Unique Name"), damit dieses Script bei jeder Kopie/Instanz
## automatisch die richtigen Nodes findet, ganz ohne manuelle Zuweisung
## im Inspector.

@export var autoplay: bool = true

## Optionaler Zeitversatz in Sekunden, damit mehrere Lift-Instanzen im
## selben Level phasenverschoben laufen statt exakt synchron.
@export var start_offset: float = 0.0

@export var animation_name: String = "lift"

func _ready() -> void:
	if not autoplay:
		return

	var anim_player := %AccliftAn as AnimationPlayer
	if not anim_player:
		push_warning("Lift: 'AccliftAn' (AnimationPlayer) nicht gefunden - ist die Node als Scene Unique Name (%) markiert und heisst sie exakt 'AccliftAn'?")
		return
	if not anim_player.has_animation(animation_name):
		push_warning("Lift: Animation '%s' nicht im AnimationPlayer gefunden." % animation_name)
		return

	# Sicherheitsnetz: Falls AccLiftSprite (versehentlich, z.B. übrig
	# von früherem Testen) eine eigene Autoplay-Animation am Laufen hat,
	# hier explizit stoppen - damit garantiert NUR der AnimationPlayer
	# über frame/position bestimmt, nie zwei Quellen gleichzeitig.
	var sprite := %AccLiftSprite as AnimatedSprite2D
	if sprite and sprite.is_playing():
		sprite.stop()

	anim_player.play(animation_name)
	if start_offset > 0.0:
		anim_player.seek(start_offset, true)
