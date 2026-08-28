extends AnimatedSprite2D

@export_group("Tempo")
@export var bpm: float = 120.0:
	set(value):
		bpm = value
		_update_speed()

@export_group("Fader-Steuerung")
@export var fader: Fader
@export var bpm_at_fader_min: float = 80.0
@export var bpm_at_fader_max: float = 140.0

@export_group("Animation")
@export var intro_animation: String = "Intro"
@export var loop_animation: String = "Loop"
@export var autostart: bool = true

@export_group("Schlag-Frames (wo der Taktstock aufschlägt)")
@export var intro_hit_frames: Array[int] = [0, 24]
@export var loop_hit_frames: Array[int] = [0]

@export_group("Einschlagpunkt")
## Marker2D/Node2D an der Spitze des Taktstocks - falls leer, wird self.global_position genutzt.
## Nur die X-Position davon zählt, Y wird bei allen Distanzberechnungen ignoriert.
@export var impact_point: Node2D

@export_group("Kamera-Shake")
@export var camera: Camera2D
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.15

@export_group("Distanz-Abhängigkeit")
@export var player_reference: Node2D
@export var max_distance: float = 800.0
@export_range(0.1, 2.0, 0.05) var falloff_curve: float = 0.4

@export_group("Druckwellen-Partikel")
@export var particles_left: GPUParticles2D
@export var particles_right: GPUParticles2D

@export_group("Druckwellen-Kraft (Spieler spürt die Welle)")
@export var push_strength: float = 400.0
@export var push_max_distance: float = 500.0
@export var wave_speed: float = 1200.0

var _shake_time: float = 0.0
var _camera_base_position: Vector2 = Vector2.ZERO
var _ground_module: Node = null

func _ready() -> void:
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if not frame_changed.is_connected(_on_frame_changed):
		frame_changed.connect(_on_frame_changed)
	if camera:
		_camera_base_position = camera.position
	if player_reference == self:
		push_warning("Taktstock: player_reference zeigt auf sich selbst, wird ignoriert.")
		player_reference = null
	if not player_reference:
		player_reference = get_tree().get_first_node_in_group("player") as Node2D
	if player_reference:
		_ground_module = player_reference.get_node_or_null("GroundMovement")
	if fader:
		fader.value_changed.connect(_on_fader_value_changed)
		_on_fader_value_changed(fader.get_value())
	else:
		_update_speed()
	if autostart:
		start()

func start() -> void:
	play(intro_animation)
	_on_beat_hit()

func _get_origin_x() -> float:
	return impact_point.global_position.x if impact_point else global_position.x

func _on_fader_value_changed(new_value: float) -> void:
	bpm = lerp(bpm_at_fader_min, bpm_at_fader_max, new_value)

func _update_speed() -> void:
	speed_scale = bpm / 60.0

func _process(delta: float) -> void:
	if not camera:
		return
	if _shake_time > 0.0:
		_shake_time = max(_shake_time - delta, 0.0)
		var time_falloff: float = _shake_time / shake_duration
		var distance_factor: float = _get_distance_factor()
		var strength: float = shake_strength * time_falloff * distance_factor
		var jitter: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
		camera.position = _camera_base_position + jitter
	else:
		camera.position = _camera_base_position

func _get_distance_factor() -> float:
	if not player_reference:
		return 1.0
	var dist: float = abs(_get_origin_x() - player_reference.global_position.x)
	var linear_factor: float = clamp(1.0 - (dist / max_distance), 0.0, 1.0)
	return pow(linear_factor, falloff_curve)

func _on_animation_finished() -> void:
	if animation == intro_animation:
		play(loop_animation)

func _on_frame_changed() -> void:
	if animation == intro_animation and frame in intro_hit_frames:
		_on_beat_hit()
	elif animation == loop_animation and frame in loop_hit_frames:
		_on_beat_hit()

func _on_beat_hit() -> void:
	_trigger_shake()
	_trigger_particles()
	_trigger_push()

func _trigger_shake() -> void:
	_shake_time = shake_duration

func _trigger_particles() -> void:
	if particles_left:
		particles_left.restart()
	if particles_right:
		particles_right.restart()

func _trigger_push() -> void:
	if not _ground_module or not player_reference:
		return
	var origin_x: float = _get_origin_x()
	var dist: float = abs(origin_x - player_reference.global_position.x)
	if dist > push_max_distance:
		return
	var direction: float = sign(player_reference.global_position.x - origin_x)
	if direction == 0.0:
		direction = 1.0
	var factor: float = clamp(1.0 - (dist / push_max_distance), 0.0, 1.0)
	var amount: float = push_strength * factor * direction
	var delay: float = dist / wave_speed if wave_speed > 0.0 else 0.0
	get_tree().create_timer(delay).timeout.connect(func(): _apply_delayed_push(amount))

func _apply_delayed_push(amount: float) -> void:
	if _ground_module:
		_ground_module.apply_push(amount)
