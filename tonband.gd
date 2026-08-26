@tool
extends Line2D

@export_group("Trigger")
@export var trigger: Area2D
@export var moves_on_trigger: bool = true

@export_group("Tempo")
@export var target_speed: float = 200.0
@export var acceleration: float = 300.0
@export var start_moving: bool = false

@export_group("Flattern & Breiten-Chaos")
@export var flutter_enabled: bool = true
@export var flutter_amount: float = 3.0
@export var flutter_speed: float = 1.5
@export var width_base: float = 8.0
@export var width_jitter_amount: float = 2.0
@export var width_jitter_speed: float = 2.0

@export_group("Kurven-Import")
@export var source_path: Path2D
@export var sync_from_path: bool = false:
	get:
		return false
	set(value):
		if value:
			_sync_from_path()

var _current_speed: float = 0.0
var _is_moving: bool = false
var _texture_offset: float = 0.0
var _shader_material: ShaderMaterial = null
var _base_points: PackedVector2Array = PackedVector2Array()
var _noise: FastNoiseLite = null
var _flutter_time: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_is_moving = start_moving
	_shader_material = material as ShaderMaterial
	_base_points = points.duplicate()
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var goal_speed: float = target_speed if _is_moving else 0.0
	_current_speed = move_toward(_current_speed, goal_speed, acceleration * delta)
	if _current_speed != 0.0 and _shader_material:
		_texture_offset += _current_speed * delta
		_shader_material.set_shader_parameter("offset_px", _texture_offset)

	if flutter_enabled and _noise:
		_flutter_time += delta
		_apply_flutter()

func _apply_flutter() -> void:
	var t: float = _flutter_time * flutter_speed
	width = width_base + _noise.get_noise_1d(t * width_jitter_speed) * width_jitter_amount

	if _base_points.size() < 2:
		return
	var jittered: PackedVector2Array = PackedVector2Array()
	jittered.resize(_base_points.size())
	var last_index: int = _base_points.size() - 1
	for i in range(_base_points.size()):
		var p: Vector2 = _base_points[i]
		var prev: Vector2 = _base_points[i - 1] if i > 0 else p
		var next: Vector2 = _base_points[i + 1] if i < last_index else p
		var tangent: Vector2 = next - prev
		var normal: Vector2 = tangent.orthogonal().normalized() if tangent.length() > 0.001 else Vector2.UP
		var n: float = _noise.get_noise_2d(t, float(i) * 0.6)
		var edge_t: float = float(i) / float(max(last_index, 1))
		var edge_weight: float = 4.0 * edge_t * (1.0 - edge_t)
		jittered[i] = p + normal * n * flutter_amount * edge_weight
	points = jittered

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_is_moving = moves_on_trigger

func _sync_from_path() -> void:
	if not source_path or not source_path.curve:
		push_warning("Tonband: kein Path2D mit Curve zugewiesen.")
		return
	var baked: PackedVector2Array = source_path.curve.get_baked_points()
	var local_points: PackedVector2Array = PackedVector2Array()
	for p in baked:
		local_points.append(to_local(source_path.to_global(p)))
	points = local_points
	_base_points = local_points.duplicate()
