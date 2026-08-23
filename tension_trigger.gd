extends Area2D
## Zone direkt beim Stimmschluessel: Spieler steht rein, drueckt E,
## Saite wird um eine Stufe gespannt (bis max_tension erreicht ist).
##
## SETUP: Diesen Node (Area2D + CollisionShape2D) beim Stimmschluessel-Ende
## der Saite platzieren, dieses Skript drauf, dann im Inspector "String Node"
## auf den MusicString-Root-Node ziehen (oder es findet ihn automatisch,
## falls dieser Trigger irgendwo als Kind/Geschwister im selben Saiten-
## Szenenbaum sitzt - siehe _ready() unten).
##
## ARM (optional): "Hand Grip" im Inspector auf einen Marker2D am Griffpunkt
## des Stimmschluessels ziehen (z.B. ein neuer Marker2D-Kind-Node direkt am
## Stimmschluessel-Sprite). Sobald der Spieler in der Zone E drueckt, wird -
## falls der Player irgendwo in seiner eigenen Szene einen Node mit dem
## Scene Unique Name "%SimpleArm" hat (siehe SimpleArm.gd) - dessen
## reach_and_retract(hand_grip) aufgerufen: kurze Greif-Animation, die zum
## Griffpunkt auffaehrt und sich danach wieder zurueckzieht. Ohne %SimpleArm
## passiert einfach nichts (kein Fehler).

@export var string_node: MusicString
@export var hand_grip: Node2D

var _player_inside: CharacterBody2D = null

func _ready() -> void:
	if not string_node:
		string_node = _find_music_string_ancestor()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _find_music_string_ancestor() -> MusicString:
	var n: Node = get_parent()
	while n:
		if n is MusicString:
			return n
		n = n.get_parent()
	return null

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_inside = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not string_node:
		return
	var pressed: bool = event.is_action_pressed("ui_accept")  # Fallback, falls "interact" nicht existiert
	if InputMap.has_action("interact"):
		pressed = event.is_action_pressed("interact")
	elif InputMap.has_action("e"):
		pressed = event.is_action_pressed("e")
	if pressed:
		string_node.request_tension_increase()
		if hand_grip:
			var arm: Node = _player_inside.get_node_or_null("%SimpleArm")
			if arm and arm.has_method("reach_and_retract"):
				arm.reach_and_retract(hand_grip)
