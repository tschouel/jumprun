class_name FlyingMovement
extends Node

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D
var base_scale: Vector2 = Vector2.ONE

@export_group("Flugphysik")
@export var fly_max_speed: float = 380.0
@export var fly_acceleration: float = 600.0
@export var fly_friction: float = 1.5
@export var fly_gravity: float = 30.0
@export var fly_boost_force: float = 450.0
@export var fly_up_speed_factor: float = 0.5

@export_group("Animation Tempo")
@export var fly_anim_base_speed: float = 2.8
@export var fly_anim_fast_speed: float = 6.0

@export_group("Juice (Tilt / Squash)")
@export var max_tilt_angle: float = 12.0
@export var tilt_speed: float = 8.0
@export var boost_squash_intensity: float = 0.25
@export var squash_recovery_speed: float = 10.0

var _boost_triggered_last_frame: bool = false

func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	var flying_sprite = player.get_node_or_null("FlyingSprite") as AnimatedSprite2D
	if flying_sprite:
		base_scale = flying_sprite.scale
		if not flying_sprite.animation_finished.is_connected(_on_flying_sprite_animation_finished):
			flying_sprite.animation_finished.connect(_on_flying_sprite_animation_finished)

func process_movement(delta: float) -> void:
	if not player or not player.is_flying_active:
		return

	# --- SICHTBARKEIT & SPRITE-AUSTAUSCH ERZWINGEN ---
	var flying_sprite = player.get_node_or_null("FlyingSprite") as AnimatedSprite2D
	if flying_sprite:
		player.show_only_sprite(flying_sprite)
	# ------------------------------------------------

	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var is_pressing_left: bool = Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left") or input_vector.x < -0.1
	var is_pressing_right: bool = Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right") or input_vector.x > 0.1
	var is_pressing_up: bool = Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up") or input_vector.y < -0.1

	# 1. Spiegelung
	if is_pressing_left:
		_set_sprites_flip(true)
	elif is_pressing_right:
		_set_sprites_flip(false)

	# 2. Animations-Tempo
	if flying_sprite and flying_sprite.animation == "default":
		var is_accelerating: bool = is_pressing_left or is_pressing_right or is_pressing_up
		flying_sprite.speed_scale = fly_anim_fast_speed if is_accelerating else fly_anim_base_speed

	# 3. Bewegung
	if input_vector != Vector2.ZERO:
		if input_vector.y < 0:
			input_vector.y *= fly_up_speed_factor
		player.velocity = player.velocity.move_toward(input_vector * fly_max_speed, fly_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, fly_friction * fly_max_speed * delta)
		if player.velocity.y < 0:
			player.velocity.y = move_toward(player.velocity.y, 0.0, fly_friction * fly_max_speed * delta)

	# 4. Boost (Taste E)
	if Input.is_physical_key_pressed(KEY_E) and not _boost_triggered_last_frame:
		player.velocity.y = -fly_boost_force
		_boost_triggered_last_frame = true
		
		if flying_sprite:
			flying_sprite.speed_scale = 4.0
			flying_sprite.play("boost")
			flying_sprite.frame = 0
			flying_sprite.scale = Vector2(base_scale.x * (1.0 + boost_squash_intensity), base_scale.y * (1.0 - boost_squash_intensity))
		
	elif not Input.is_physical_key_pressed(KEY_E):
		_boost_triggered_last_frame = false

	# 5. Schwerkraft
	if input_vector.y <= 0:
		player.velocity.y += fly_gravity * delta

	# 6. Juice Effects (Tilt & Squash)
	_apply_juice_effects(delta)

func _apply_juice_effects(delta: float) -> void:
	var flying_sprite = player.get_node_or_null("FlyingSprite") as AnimatedSprite2D
	if not flying_sprite:
		return

	# 1. Tilt (Neigung)
	var target_tilt_factor = player.velocity.x / fly_max_speed
	var target_rotation = deg_to_rad(target_tilt_factor * max_tilt_angle)
	
	flying_sprite.rotation = lerp_angle(flying_sprite.rotation, target_rotation, tilt_speed * delta)
	
	# 2. Squash/Stretch Rückfederung
	if base_scale != Vector2.ZERO:
		flying_sprite.scale = flying_sprite.scale.lerp(base_scale, squash_recovery_speed * delta)

func _set_sprites_flip(flip: bool) -> void:
	var flying_sprite = player.get_node_or_null("FlyingSprite")
	if flying_sprite and "flip_h" in flying_sprite:
		flying_sprite.flip_h = flip
		
	var main_sprite = player._get_main_sprite_node()
	if main_sprite and "flip_h" in main_sprite:
		main_sprite.flip_h = flip

func _on_flying_sprite_animation_finished() -> void:
	var flying_sprite = player.get_node_or_null("FlyingSprite") as AnimatedSprite2D
	if player.is_flying_active and flying_sprite and flying_sprite.animation == "boost":
		flying_sprite.play("default")
