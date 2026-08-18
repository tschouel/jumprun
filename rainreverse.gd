extends Area2D

@export var block: AnimatableBody2D
@export var rain_particles: GPUParticles2D
@export var ground_node: Node2D

@export var sink_distance: float = 120.0
@export var sink_duration: float = 1.2
@export var reverse_duration: float = 1.0

@export var reverse_velocity_min: float = 150.0
@export var reverse_velocity_max: float = 250.0

@export var reverse_direction: Vector3 = Vector3(0, -1, 0)   # steil nach oben
@export var reverse_spread: float = 90.0                     # kleiner als 180 -> mehrheitlich in Richtung "direction"
@export var reverse_gravity: Vector3 = Vector3(0, -40, 0)    # leichter Zug weiter nach oben statt 0

@export var emission_offset: Vector2 = Vector2(15, -30)   # Y negativ = nach oben, weg von den Füßen

@export var reverse_amount_factor: float = 0.5            # Halbe Partikelanzahl

@export var hidden_duration: float = 2.0   # Sekunden, die eine Note unsichtbar bleibt, bevor sie erscheint

@export var circle_max_radius: float = 40.0
@export var circle_duration: float = 0.35
@export var circle_color: Color = Color(1, 1, 1, 0.8)

var is_sunk: bool = false
var is_reversed: bool = false
var active_player: CharacterBody2D = null


func _ready() -> void:
	if not block:
		block = get_parent()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_reversed and rain_particles and active_player and is_instance_valid(active_player):
		rain_particles.global_position = active_player.global_position + emission_offset


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_sunk:
		is_sunk = true
		active_player = body
		sink_into_ground()


func sink_into_ground() -> void:
	var target_y = block.position.y + sink_distance
	if ground_node:
		target_y = min(target_y, ground_node.position.y)

	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(block, "position:y", target_y, sink_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_on_block_fully_sunk)


func _on_block_fully_sunk() -> void:
	reverse_rain()


func reverse_rain() -> void:
	if not rain_particles:
		return

	var mat = rain_particles.process_material as ParticleProcessMaterial
	if not mat:
		return

	var start_pos = rain_particles.global_position
	if active_player and is_instance_valid(active_player):
		start_pos = active_player.global_position + emission_offset
		rain_particles.global_position = start_pos

	# restart() setzt emitting intern wieder auf true -> deshalb DANACH erst ausschalten
	rain_particles.restart()
	rain_particles.emitting = false

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	rain_particles.amount = max(1, int(rain_particles.amount * reverse_amount_factor))

	apply_hidden_start(mat)

	show_circle_effect(start_pos)
	await get_tree().create_timer(circle_duration).timeout

	is_reversed = true
	rain_particles.emitting = true

	var tween = create_tween().set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_property(mat, "gravity", reverse_gravity, reverse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mat, "direction", reverse_direction, reverse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mat, "spread", reverse_spread, reverse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mat, "initial_velocity_min", reverse_velocity_min, reverse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mat, "initial_velocity_max", reverse_velocity_max, reverse_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func apply_hidden_start(mat: ParticleProcessMaterial) -> void:
	# Note bleibt "hidden_duration" Sekunden unsichtbar, erscheint dann schlagartig (kein Überblenden)
	var lifetime = rain_particles.lifetime
	var offset = 0.0
	if lifetime > 0.0:
		offset = clamp(hidden_duration / lifetime, 0.0, 1.0)

	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, offset])

	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient

	mat.color_ramp = gradient_texture


func show_circle_effect(pos: Vector2) -> void:
	var circle := Node2D.new()
	get_tree().current_scene.add_child(circle)
	circle.global_position = pos
	circle.z_index = 10

	var radius = 0.0
	circle.draw.connect(func():
		circle.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, circle_color, 3.0, true)
	)

	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(
		func(r): radius = r; circle.queue_redraw(),
		0.0, circle_max_radius, circle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, circle_duration)
	tween.tween_callback(circle.queue_free)
