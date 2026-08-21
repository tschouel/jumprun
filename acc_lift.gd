extends Node2D
class_name Lift
## Lift, der dauerhaft zwischen eingefahrener und ausgefahrener Position
## hin- und herfährt.
##
## Sowohl das Sprite-Frame (AccLiftAnim:frame) als auch die Plattform-
## Position (AccLift:position) stecken als Property-Tracks in EINER
## AnimationPlayer-Animation ("lift") - dadurch bleiben beide zu jedem
## Zeitpunkt exakt synchron, und man kann im Editor durch Scrubben der
## Zeitleiste direkt sehen, wo der Sprite gerade steht, um die Position-
## Keyframes passend zu setzen.
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
	anim_player.play(animation_name)
	if start_offset > 0.0:
		anim_player.seek(start_offset, true)
