class_name BalloonFlyingZone
extends GameZone

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export_group("FMOD Einstellungen")
## Das FmodEventEmitter2D Node aus der Szene oder vom Player
@export var zone_emitter: Node2D
@export var fmod_sparkle_param: String = "sparkle"
@export var sparkle_duration: float = 0.15

var active_player: CharacterBody2D = null

var _fmod_timer: float = 0.0
const FMOD_UPDATE_INTERVAL: float = 0.15

var _boost_triggered_last_frame: bool = false
var _sparkle_timer: float = 0.0

# Parameter-Tracking um unnötige/doppelte C++ Calls zu vermeiden
var _last_x: float = -1.0
var _last_y: float = -1.0
var _send_toggle: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if active_player != null:
		return

	var player = body as CharacterBody2D
	if not player:
		return

	active_player = player
	
	if "is_flying_active" in active_player:
		active_player.is_flying_active = true

	if not zone_emitter and "music_emitter" in active_player:
		zone_emitter = active_player.music_emitter

func _on_body_exited(body: Node2D) -> void:
	if body == active_player:
		if is_instance_valid(active_player) and "is_flying_active" in active_player:
			active_player.is_flying_active = false

		_reset_sparkle()
		active_player = null
		_last_x = -1.0
		_last_y = -1.0

func _process(delta: float) -> void:
	if not is_instance_valid(active_player):
		return

	_handle_sparkle_input(delta)

	_fmod_timer += delta
	if _fmod_timer >= FMOD_UPDATE_INTERVAL:
		_fmod_timer -= FMOD_UPDATE_INTERVAL
		_send_position_to_fmod()

func _set_fmod_param(param_name: String, value: float) -> void:
	if not is_instance_valid(zone_emitter):
		return

	if zone_emitter.has_method("set_parameter"):
		zone_emitter.set_parameter(param_name, value)
		print("[DEBUG FMOD Direct] ", param_name, " = ", "%.2f" % value)

func _handle_sparkle_input(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_E) and not _boost_triggered_last_frame:
		_boost_triggered_last_frame = true
		_sparkle_timer = sparkle_duration
		_set_fmod_param(fmod_sparkle_param, 1.0)
	elif not Input.is_physical_key_pressed(KEY_E):
		_boost_triggered_last_frame = false

	if _sparkle_timer > 0.0:
		_sparkle_timer -= delta
		if _sparkle_timer <= 0.0:
			_set_fmod_param(fmod_sparkle_param, 0.0)

func _reset_sparkle() -> void:
	_sparkle_timer = 0.0
	_boost_triggered_last_frame = false
	_set_fmod_param(fmod_sparkle_param, 0.0)

func _send_position_to_fmod() -> void:
	if not collision_shape or not (collision_shape.shape is RectangleShape2D):
		return

	var rect_shape = collision_shape.shape as RectangleShape2D
	var half_size = rect_shape.size * 0.5
	var xform = collision_shape.global_transform
	
	var top_left = xform * Vector2(-half_size.x, -half_size.y)
	var top_right = xform * Vector2(half_size.x, -half_size.y)
	var bottom_left = xform * Vector2(-half_size.x, half_size.y)

	var min_x = min(top_left.x, top_right.x)
	var max_x = max(top_left.x, top_right.x)
	var min_y = min(top_left.y, bottom_left.y)
	var max_y = max(top_left.y, bottom_left.y)

	var width = max_x - min_x
	var height = max_y - min_y

	if width <= 0.001 or height <= 0.001:
		return

	var player_pos = active_player.global_position

	# snapped statt snapp
	var rel_x = snapped(clamp((player_pos.x - min_x) / width, 0.0, 1.0), 0.01)
	var rel_y = snapped(clamp((max_y - player_pos.y) / height, 0.0, 1.0), 0.01)

	# Abwechselndes Senden von X und Y pro Intervall
	_send_toggle = not _send_toggle
	if _send_toggle:
		if abs(rel_x - _last_x) > 0.005:
			_last_x = rel_x
			_set_fmod_param("x", rel_x)
	else:
		if abs(rel_y - _last_y) > 0.005:
			_last_y = rel_y
			_set_fmod_param("y", rel_y)
