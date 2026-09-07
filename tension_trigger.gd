extends Area2D
## Zone direkt beim Stimmschluessel: Spieler steht rein, drueckt zuerst
## engage_key (Standard F), um den Stimmschluessel "anzufassen" - das
## BLOCKIERT NUR die Spielerbewegung (ueber ground_module.set_animation_override,
## siehe groundmovement.gd), loest aber selbst KEINE Armanimation aus. Erst
## danach reagieren increase_key/decrease_key (Standard rechts/links), um die
## Saite tatsaechlich zu spannen bzw. zu lockern - UND jeder erfolgreiche
## Dreh-Tastendruck loest dabei die Handgreif-Animation aus (falls hand_grip
## gesetzt ist). Erneutes Druecken von engage_key (oder Verlassen der Zone)
## laesst wieder los und gibt die Bewegung frei.
##
## SETUP: Diesen Node (Area2D + CollisionShape2D) beim Stimmschluessel-Ende
## der Saite platzieren, dieses Skript drauf, dann im Inspector "String Node"
## auf den MusicString- oder StringWall-Root-Node ziehen (oder es findet ihn
## automatisch, falls dieser Trigger irgendwo als Kind/Geschwister im
## selben Saiten-Szenenbaum sitzt - siehe _ready() unten).
##
## Funktioniert mit MusicString.gd (hat increase UND decrease) genauso wie
## mit StringWall.gd (hat nur increase - decrease wird dort automatisch per
## has_method() ignoriert).
##
## ARM (optional): "Hand Grip" im Inspector auf einen Marker2D am Griffpunkt
## des Stimmschluessels ziehen. Bei JEDEM erfolgreichen Dreh-Tastendruck
## (links ODER rechts, waehrend angefasst) wird - falls der Player irgendwo
## in seiner eigenen Szene einen Node mit dem Scene Unique Name "%SimpleArm"
## hat (siehe SimpleArm.gd) - dessen reach_and_retract(hand_grip) aufgerufen.
## Ohne %SimpleArm passiert einfach nichts (kein Fehler). Das reine Angreifen
## (engage_key) selbst loest KEINE Armanimation aus.

signal engaged
signal disengaged

@export var string_node: Node
@export var hand_grip: Node2D

@export_group("Bedienung")
## Taste zum Angreifen/Loslassen des Stimmschluessels - blockiert NUR die
## Bewegung, keine Armanimation.
@export var engage_key: Key = KEY_F
## Taste zum Anspannen - wirkt nur, waehrend der Stimmschluessel angefasst
## ist. Loest bei Erfolg die Handgreif-Animation aus.
@export var increase_key: Key = KEY_RIGHT
## Taste zum Lockern - wirkt nur, waehrend der Stimmschluessel angefasst ist.
## Wird ignoriert, falls string_node keine request_tension_decrease()-Methode
## hat (z.B. bei StringWall.gd). Loest bei Erfolg die Handgreif-Animation aus.
@export var decrease_key: Key = KEY_LEFT

var _player_inside: CharacterBody2D = null
var _is_engaged: bool = false

func _ready() -> void:
	if not string_node:
		string_node = _find_string_ancestor()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _find_string_ancestor() -> Node:
	var n: Node = get_parent()
	while n:
		if n.has_method("request_tension_increase"):
			return n
		n = n.get_parent()
	return null

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_inside = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		if _is_engaged:
			_disengage()
		_player_inside = null

func _unhandled_key_input(event: InputEvent) -> void:
	if not _player_inside or not string_node:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == engage_key:
		if _is_engaged:
			_disengage()
		else:
			_engage()
		get_viewport().set_input_as_handled()
		return

	if not _is_engaged:
		return

	if event.keycode == increase_key:
		if string_node.request_tension_increase():
			_try_hand_grip()
		get_viewport().set_input_as_handled()
	elif event.keycode == decrease_key:
		if string_node.has_method("request_tension_decrease"):
			if string_node.request_tension_decrease():
				_try_hand_grip()
			get_viewport().set_input_as_handled()

## Nur Bewegungssperre + Signal - KEINE Armanimation.
func _engage() -> void:
	_is_engaged = true
	engaged.emit()
	if _player_inside and "movement_locked" in _player_inside:
		_player_inside.movement_locked = true
	_lock_player_movement(true)

func _disengage() -> void:
	_is_engaged = false
	disengaged.emit()
	_lock_player_movement(false)

## Blockiert bzw. entsperrt die Spielerbewegung ueber das dafuer vorgesehene
## Override-System in groundmovement.gd (set_animation_override /
## clear_animation_override).
func _lock_player_movement(lock: bool) -> void:
	if not _player_inside:
		return
	var ground_module: Node = _player_inside.get("ground_module")
	if not ground_module:
		return
	if lock:
		ground_module.set_animation_override("stand")
	else:
		ground_module.clear_animation_override()

func _try_hand_grip() -> void:
	if not hand_grip or not _player_inside:
		return
	var arm: Node = _player_inside.get_node_or_null("%SimpleArm")
	if arm and arm.has_method("reach_and_retract"):
		arm.reach_and_retract(hand_grip)
