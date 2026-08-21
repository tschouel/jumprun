extends Node2D
class_name Lift
## Lift, der dauerhaft zwischen eingefahrener und ausgefahrener Position
## hin- und herfährt.
##
## Der Sprite (AccLiftAnim) läuft komplett eigenständig im Loop - das wird
## direkt im SpriteFrames-Panel eingestellt (Loop-Icon bei der 130-Frame-
## Animation aktivieren), kein Umweg über den AnimationPlayer nötig.
##
## Der AnimationPlayer (AccliftAn) kümmert sich NUR noch um die Position
## der Plattform (AccLift) - über einen einzigen Property-Track, dessen
## Länge exakt zur Sprite-Animation passt (130 Frames / FPS = Sekunden),
## damit Collider und Optik synchron bleiben.
##
## Setup: Node-Struktur siehe Anleitung. AccLiftAnim (Sprite), AccLift
## (Platform/Collider-Body) und AccliftAn (AnimationPlayer) müssen als
## "Scene Unique Name" markiert sein (%-Symbol in der Szenenübersicht),
## damit dieses Script bei jeder Kopie automatisch die richtigen Nodes
## findet - keine manuelle Zuweisung im Inspector nötig.

@export var autoplay: bool = true
## Optionaler Zeitversatz in Sekunden, damit mehrere Lift-Instanzen im
## selben Level phasenverschoben laufen statt exakt synchron.
@export var start_offset: float = 0.0
@export var animation_name: String = "cycle"

func _ready() -> void:
	if not autoplay:
		return
	# Sprite startet seine eigene (im SpriteFrames-Panel geloopte) Animation.
	var sprite := %AccLiftAnim as AnimatedSprite2D
	sprite.play()  # spielt die aktuell im Inspector gesetzte Default-Animation

	# AnimationPlayer bewegt parallel dazu die Plattform.
	var anim_player := %AccliftAn as AnimationPlayer
	if not anim_player.has_animation(animation_name):
		push_warning("Lift: Animation '%s' nicht im AnimationPlayer gefunden." % animation_name)
		return
	anim_player.play(animation_name)

	if start_offset > 0.0:
		anim_player.seek(start_offset, true)
		# Hinweis: Der Sprite selbst läuft unabhängig weiter und wird hier
		# nicht mitverschoben - für den ersten Test einfach start_offset
		# bei 0.0 belassen, das können wir später verfeinern.
