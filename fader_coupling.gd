extends Node

## Koppelt zwei Fader ueber 3 Trigger-Zonen, wie ein Cassetten-Reel-Mechanismus:
## Trigger 1 = gleiche Richtung, Trigger 2 = entkoppelt, Trigger 3 = Gegenrichtung.
## Spieler laeuft in eine der drei Zonen -> Modus wechselt sofort.
##
## Wichtig: es wird nicht der ABSOLUTWERT des oberen Faders auf den unteren
## uebertragen, sondern nur das BEWEGUNGS-DELTA seit dem letzten Frame -
## sonst wuerde der untere Fader beim Umschalten des Modus immer hart auf
## einen neuen Wert "springen". So bleibt seine Position wirklich das Ergebnis
## des ganzen Wegs, den der Spieler gegangen ist - das eigentliche Raetsel.
##
## Setup: oben und unten je einen Fader-Node in die Szene setzen (gleiche
## Fader.gd-Klasse). Der UNTERE Fader bekommt im Inspector KEINE
## interaction_zone - dadurch ist er automatisch nicht direkt greifbar
## (regelt Fader.gd schon selbst), sondern bewegt sich nur ueber dieses
## Skript hier. Dieses Skript selbst an einen beliebigen Node haengen,
## top_fader/bottom_fader zuweisen, und die drei Area2D-Trigger-Zonen
## irgendwo in der Szene platzieren und hier reinziehen.

enum CouplingMode { SAME_DIRECTION, DECOUPLED, OPPOSITE_DIRECTION }

@export var top_fader: Fader
@export var bottom_fader: Fader
@export var initial_mode: CouplingMode = CouplingMode.SAME_DIRECTION

@export_group("Trigger-Zonen")
@export var same_direction_trigger: Area2D
@export var decoupled_trigger: Area2D
@export var opposite_direction_trigger: Area2D

var _mode: int = CouplingMode.SAME_DIRECTION
var _last_top_value: float = 0.0

func _ready() -> void:
	_mode = initial_mode
	if same_direction_trigger:
		same_direction_trigger.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_mode = CouplingMode.SAME_DIRECTION
		)
	if decoupled_trigger:
		decoupled_trigger.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_mode = CouplingMode.DECOUPLED
		)
	if opposite_direction_trigger:
		opposite_direction_trigger.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_mode = CouplingMode.OPPOSITE_DIRECTION
		)
	if top_fader:
		top_fader.value_changed.connect(_on_top_value_changed)
		call_deferred("_sync_initial_top_value")

func _sync_initial_top_value() -> void:
	if top_fader:
		_last_top_value = top_fader.get_value()

func _on_top_value_changed(new_value: float) -> void:
	var delta: float = new_value - _last_top_value
	_last_top_value = new_value
	if not bottom_fader or _mode == CouplingMode.DECOUPLED:
		return
	var multiplier: float = 1.0 if _mode == CouplingMode.SAME_DIRECTION else -1.0
	bottom_fader.set_value(bottom_fader.get_value() + delta * multiplier)
