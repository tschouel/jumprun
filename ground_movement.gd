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
	if not sprite:
		# "Walk" ist ein direktes Kind von GroundMovement selbst
		sprite = get_node_or_null("Walk") as AnimatedSprite2D
	if not sprite and _player:
		sprite = _player.find_child("*Sprite*", true, false) as AnimatedSprite2D
func set_active(active: bool) -> void:
	is_active = active
	if not is_active:
		_play_stand_animation()
## Wird vom player.gd im Haupt-_physics_process aufgerufen
func process_movement(delta: float) -> void:
	if not _player:
		return
	# 1. Schwerkraft
	if not _player.is_on_floor():
		_player.velocity.y += gravity * delta
	# 2. Sprung
	# "jump" wird nur abgefragt, wenn diese Action im Input Map überhaupt existiert
	# (verhindert die "InputMap action doesn't exist"-Fehlerflut)
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up")
	if InputMap.has_action("jump"):
		jump_pressed = jump_pressed or Input.is_action_just_pressed("jump")
	if jump_pressed and _player.is_on_floor():
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
		# Spiegelt die Figur horizontal, sodass sie in Laufrichtung schaut
		if sprite:
			sprite.flip_h = (input_axis < 0.0)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, friction * delta)
	# 5. Animationssteuerung
	_update_animation(input_axis)
func _update_animation(input_axis: float) -> void:
	if not sprite:
		return
	var on_floor: bool = _player.is_on_floor()
	# Nur "moving", solange aktiv links/rechts gelaufen wird
	var is_moving: bool = input_axis != 0.0 and abs(_player.velocity.x) > 10.0
	if not on_floor:
		_play_animation("jump")
	elif is_moving:
		_play_animation("walking")
	else:
		_play_animation("stand")
func _play_stand_animation() -> void:
	_play_animation("stand")
func _play_animation(anim_name: String) -> void:
	if not sprite:
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
