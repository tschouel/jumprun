extends Node2D

var player: CharacterBody2D
var base_scale: Vector2 = Vector2.ONE

# Werden beim Betreten direkt von der DrivingZone überschrieben:
var boost_force: float = 350.0
var boost_duration: float = 1.5
var can_boost: bool = true

@export_group("Fahrphysik")
@export var drive_speed: float = 450.0

@export_group("Juice (Squash & Stretch)")
@export var boost_squash_intensity: float = 0.3
@export var squash_recovery_speed: float = 6.0

var is_active: bool = false
var _is_boosting: bool = false
var _is_transforming: bool = false

func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	var driving_sprite = _get_driving_sprite()
	if driving_sprite:
		base_scale = driving_sprite.scale
		if not driving_sprite.animation_finished.is_connected(_on_driving_sprite_animation_finished):
			driving_sprite.animation_finished.connect(_on_driving_sprite_animation_finished)

func set_active(active: bool) -> void:
	is_active = active
	_is_boosting = false
	
	var driving_sprite = _get_driving_sprite()
	if driving_sprite:
		driving_sprite.visible = active
		if active:
			_is_transforming = true
			if driving_sprite.sprite_frames and driving_sprite.sprite_frames.has_animation("FastCarTrans"):
				driving_sprite.play("FastCarTrans")
			else:
				_is_transforming = false
				_play_default_animation()
		else:
			driving_sprite.stop()
			_is_transforming = false

func _unhandled_input(event: InputEvent) -> void:
	if not player or not player.is_driving_active or _is_boosting or _is_transforming or not can_boost:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			_trigger_boost()

func process_movement(delta: float) -> void:
	if not player or not player.is_driving_active:
		return

	var driving_sprite = _get_driving_sprite()
	if driving_sprite and not driving_sprite.visible:
		driving_sprite.visible = true

	# Standard-Zielgeschwindigkeit holen
	var target_speed = drive_speed
	if "forward_speed" in player and player.forward_speed > 0.0:
		target_speed = player.forward_speed

	# WÄHREND DES BOOSTS: Volle Boost-Geschwindigkeit konstant halten
	if _is_boosting:
		target_speed += boost_force
		player.velocity.x = target_speed  # Sofortige & durchgehende Höchstgeschwindigkeit
	else:
		# Nach dem Boost: Sanftes Zurückbremsen auf Normaltempo
		player.velocity.x = move_toward(player.velocity.x, target_speed, 1200.0 * delta)

	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	else:
		player.velocity.y = 0.0

	_apply_juice_effects(delta)

# E-Boost Methode
func _trigger_boost() -> void:
	if not player:
		return
		
	_is_boosting = true
	
	var driving_sprite = _get_driving_sprite()
	if driving_sprite:
		driving_sprite.visible = true
		
		if driving_sprite.sprite_frames and driving_sprite.sprite_frames.has_animation("boost"):
			driving_sprite.play("boost")
		elif driving_sprite.sprite_frames and driving_sprite.sprite_frames.has_animation("FastCarBoost"):
			driving_sprite.play("FastCarBoost")

	# Warten bis die eingestellte Boost-Dauer vollständig abgelaufen ist
	await get_tree().create_timer(boost_duration).timeout
	_end_boost()

func _end_boost() -> void:
	_is_boosting = false
	if player and player.is_driving_active:
		_play_default_animation()

func _play_default_animation() -> void:
	var driving_sprite = _get_driving_sprite()
	if driving_sprite:
		driving_sprite.visible = true
		if driving_sprite.sprite_frames:
			if driving_sprite.sprite_frames.has_animation("FastCarDrive"):
				driving_sprite.play("FastCarDrive")
			elif driving_sprite.sprite_frames.has_animation("default"):
				driving_sprite.play("default")
			elif driving_sprite.sprite_frames.has_animation("drive"):
				driving_sprite.play("drive")

func _on_driving_sprite_animation_finished() -> void:
	var driving_sprite = _get_driving_sprite()
	if not driving_sprite or not player or not player.is_driving_active:
		return

	if _is_transforming and driving_sprite.animation == "FastCarTrans":
		_is_transforming = false
		_play_default_animation()

func _apply_juice_effects(delta: float) -> void:
	var driving_sprite = _get_driving_sprite()
	if not driving_sprite or base_scale == Vector2.ZERO:
		return

	if _is_boosting:
		var target_boost_scale = Vector2(base_scale.x * (1.0 + boost_squash_intensity), base_scale.y * (1.0 - boost_squash_intensity))
		driving_sprite.scale = driving_sprite.scale.lerp(target_boost_scale, 12.0 * delta)
	else:
		driving_sprite.scale = driving_sprite.scale.lerp(base_scale, squash_recovery_speed * delta)

func _get_driving_sprite() -> AnimatedSprite2D:
	var sprite = get_node_or_null("DrivingSprite") as AnimatedSprite2D
	if not sprite and player:
		sprite = player.get_node_or_null("DrivingSprite") as AnimatedSprite2D
	return sprite
