class_name GroundMovement
extends Node2D

@export_group("Geschwindigkeit & Beschleunigung")
## Maximale Laufgeschwindigkeit
@export var speed: float = 350.0
## Beschleunigung beim Anlaufen
@export var acceleration: float = 3000.0
## Hohe Reibung beim Bremsen (verhindert Schlittschuhlaufen)
@export var friction: float = 4500.0

@export_group("Sprung & Schwerkraft")
@export var jump_velocity: float = -550.0
@export var gravity: float = 1400.0

@export_group("Referenzen")
@export var sprite: AnimatedSprite2D

var is_active: bool = false
var _player: CharacterBody2D = null

func setup(player: CharacterBody2D) -> void:
	_player = player
	if not sprite and _player:
		sprite = _player.find_child("*Sprite*", true, false) as AnimatedSprite2D

func set_active(active: bool) -> void:
	is_active = active
	if not is_active:
		_set_idle_frame()

## Wird vom player.gd im Haupt-_physics_process aufgerufen
func process_movement(delta: float) -> void:
	if not _player:
		return

	# 1. Schwerkraft
	if not _player.is_on_floor():
		_player.velocity.y += gravity * delta

	# 2. Sprung
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("jump")) and _player.is_on_floor():
		_player.velocity.y = jump_velocity

	# 3. Horizontaler Input
	var input_axis: float = Input.get_axis("ui_left", "ui_right")
	if input_axis == 0.0:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_axis += 1.0

	# 4. Knackiges Beschleunigen & Sofort-Stopp
	if input_axis != 0.0:
		_player.velocity.x = move_toward(_player.velocity.x, input_axis * speed, acceleration * delta)
		if sprite:
			sprite.flip_h = (input_axis < 0.0)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, friction * delta)

	# 5. Animationssteuerung
	_update_animation(input_axis)

func _update_animation(input_axis: float) -> void:
	if not sprite:
		return

	var is_moving: bool = abs(_player.velocity.x) > 10.0 and input_axis != 0.0
	var on_floor: bool = _player.is_on_floor()

	if on_floor and is_moving:
		if sprite.animation != "walking" or not sprite.is_playing():
			sprite.play("walking")
	else:
		_set_idle_frame()

func _set_idle_frame() -> void:
	if not sprite:
		return

	if sprite.is_playing() and sprite.animation == "walking":
		sprite.stop()

	sprite.animation = "walking"
	sprite.frame = 0
