class_name TuningPeg
extends Node2D

## Autonomer Stimmschluessel-Mechanismus: Spieler steht in interaction_zone,
## druecken engage_key (Standard F) "greift" den Peg (blockiert nur die
## Spielerbewegung, keine Armanimation). Danach drehen increase_key/
## decrease_key (Standard rechts/links) die Stufe hoch/runter - jeder
## erfolgreiche Dreh-Tastendruck loest turn_animation_name ab, ausserdem die
## Handgreif-Animation (falls hand_grip gesetzt). Ist schon bei num_steps
## bzw. 0 angekommen, spielt stattdessen stuck_animation_name (reines
## Feedback, level aendert sich dabei nicht) - Handgreif-Animation laeuft
## trotzdem, wie beim echten Dreh-Versuch.
##
## Was das Erreichen einer Stufe konkret bewirkt (Saite spannen, Gewicht
## fallen lassen, Tuer oeffnen ...) ist NICHT Teil dieses Skripts - dafuer
## einfach level_changed abonnieren.
##
## Setup: sprite (AnimatedSprite2D, mit den beiden Animationen
## turn_animation_name/stuck_animation_name als Kind anlegen), interaction_zone
## (Area2D + CollisionShape2D als Kind), optional hand_grip (Marker2D/Node2D
## am Griffpunkt) - alles als Kinder dieser Szene. player wird pro Instanz im
## Inspector zugewiesen.

signal engaged
signal disengaged
signal level_changed(new_level: int)

@export_group("Peg-Aufbau")
@export var sprite: AnimatedSprite2D
@export var interaction_zone: Area2D
@export var num_steps: int = 4
@export var start_level: int = 0
@export var turn_animation_name: String = "turn"
@export var stuck_animation_name: String = "stuck"

@export_group("Steuerung")
@export var engage_key: Key = KEY_F
@export var increase_key: Key = KEY_RIGHT
@export var decrease_key: Key = KEY_LEFT

@export_group("Spieler-Kopplung")
@export var player: CharacterBody2D
@export var freeze_player_while_engaged: bool = true

@export_group("Arm-Animation")
@export var hand_grip: Node2D

@export_group("Kamera")
@export var camera_offset_x: float = 0.0
@export var camera_offset_y: float = 0.0
@export var camera_zoom_enabled: bool = false
@export var camera_zoom_target: Vector2 = Vector2(0.6, 0.6)
@export var camera_transition_duration: float = 0.0
@export var camera_transition_curve: Curve

var level: int = 0

var _player_in_zone: bool = false
var _is_engaged: bool = false
var _is_turning: bool = false
var _active_anim_name: String = ""
var _pending_delta: int = 0
var _ground_movement: Node = null

func _ready() -> void:
	level = clampi(start_level, 0, num_steps)

	if player:
		_ground_movement = player.get_node_or_null("GroundMovement")

	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

func is_at_max() -> bool:
	return level >= num_steps

func is_at_min() -> bool:
	return level <= 0

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		if _is_engaged:
			_disengage()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.physical_keycode == engage_key:
		if _is_engaged:
			_disengage()
		else:
			_engage()
		return

	if not _is_engaged:
		return

	if event.physical_keycode == increase_key:
		_request_turn(1)
	elif event.physical_keycode == decrease_key:
		_request_turn(-1)

func _engage() -> void:
	_is_engaged = true
	engaged.emit()
	if freeze_player_while_engaged and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	_apply_camera_offset(true)
	_apply_camera_zoom(true)

func _disengage() -> void:
	_is_engaged = false
	disengaged.emit()
	if freeze_player_while_engaged and player:
		player.set_physics_process(true)
	_apply_camera_offset(false)
	_apply_camera_zoom(false)

func _request_turn(delta: int) -> void:
	if _is_turning:
		return
	var at_limit: bool = (delta > 0 and is_at_max()) or (delta < 0 and is_at_min())
	_is_turning = true
	_pending_delta = 0 if at_limit else delta
	_active_anim_name = stuck_animation_name if at_limit else turn_animation_name

	if hand_grip and player:
		var arm: Node = player.get_node_or_null("%SimpleArm")
		if arm and arm.has_method("reach_and_retract"):
			arm.reach_and_retract(hand_grip)

	if sprite:
		if delta < 0 and not at_limit:
			sprite.play_backwards(_active_anim_name)
		else:
			sprite.play(_active_anim_name)
	else:
		_on_animation_finished()

func _on_animation_finished() -> void:
	if sprite and sprite.animation != _active_anim_name:
		return
	_is_turning = false
	if _pending_delta != 0:
		level = clampi(level + _pending_delta, 0, num_steps)
		level_changed.emit(level)
	_pending_delta = 0

func _apply_camera_offset(activate: bool) -> void:
	if camera_offset_x == 0.0 and camera_offset_y == 0.0:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_offset_override"):
			_ground_movement.set_camera_offset_override(Vector2(camera_offset_x, camera_offset_y), camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_offset_override"):
			_ground_movement.clear_camera_offset_override(camera_transition_duration, camera_transition_curve)

func _apply_camera_zoom(activate: bool) -> void:
	if not camera_zoom_enabled:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_zoom_override"):
			_ground_movement.set_camera_zoom_override(camera_zoom_target, camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_zoom_override"):
			_ground_movement.clear_camera_zoom_override(camera_transition_duration, camera_transition_curve)
