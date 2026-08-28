class_name TuningPeg
extends Node2D

@export_group("Peg-Aufbau")
@export var sprite: AnimatedSprite2D
@export var interaction_zone: Area2D
@export var turn_animation_name: String = "turn"
@export_range(0.0, 1.0) var turn_step: float = 0.25

@export_group("Steuerung")
@export var toggle_key: Key = KEY_E

@export_group("Spieler-Kopplung")
@export var player: CharacterBody2D
@export var freeze_player_while_turning: bool = true

@export_group("Arm-Animation")
@export var hand_grip: Node2D

@export_group("Seil & Gewicht")
@export var weight: RigidBody2D
@export_range(0.0, 1.0) var release_threshold: float = 1.0

@export_group("Seil-Visual")
@export var rope_start_point: Node2D
@export var rope_end_point: Node2D
@export var rope_line: Line2D
@export var rope_sag: float = 30.0
@export var rope_segments: int = 16

signal value_changed(new_value: float)
signal weight_released

var value: float = 0.0
var _player_in_zone: bool = false
var _is_turning: bool = false
var _rope_released: bool = false

func _ready() -> void:
	if interaction_zone:
		interaction_zone.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_player_in_zone = true
		)
		interaction_zone.body_exited.connect(func(b):
			if b.is_in_group("player"):
				_player_in_zone = false
		)

	if weight:
		weight.freeze = true

	if sprite:
		sprite.animation_finished.connect(_on_turn_finished)

	_update_rope_visual()

func _process(_delta: float) -> void:
	if not _rope_released:
		_update_rope_visual()

func _update_rope_visual() -> void:
	if not (rope_line and rope_start_point and rope_end_point):
		return

	rope_line.global_position = rope_start_point.global_position
	var end_local: Vector2 = rope_line.to_local(rope_end_point.global_position)

	var points: PackedVector2Array = PackedVector2Array()
	for i in range(rope_segments + 1):
		var t: float = float(i) / float(rope_segments)
		var p: Vector2 = Vector2.ZERO.lerp(end_local, t)
		p.y += rope_sag * 4.0 * t * (1.0 - t)
		points.append(p)

	rope_line.points = points

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if _rope_released:
		return
	if event is InputEventKey and event.physical_keycode == toggle_key and event.pressed and not event.echo:
		_request_turn()

func _request_turn() -> void:
	if _is_turning:
		return
	_is_turning = true

	if freeze_player_while_turning and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

	if hand_grip and player:
		var arm: Node = player.get_node_or_null("%SimpleArm")
		if arm and arm.has_method("reach_and_retract"):
			arm.reach_and_retract(hand_grip)

	if sprite:
		sprite.play(turn_animation_name)

func _on_turn_finished() -> void:
	if sprite.animation != turn_animation_name:
		return

	_is_turning = false
	if freeze_player_while_turning and player:
		player.set_physics_process(true)

	value = clamp(value + turn_step, 0.0, 1.0)
	value_changed.emit(value)

	if not _rope_released and value >= release_threshold:
		_release_weight()

func _release_weight() -> void:
	_rope_released = true
	if weight:
		weight.freeze = false
	if rope_line:
		rope_line.visible = false
	weight_released.emit()
