extends Area2D

@export var block: AnimatableBody2D
@export var ground_node: Node2D

@export var sink_distance: float = 120.0
@export var sink_duration: float = 1.2

@export var invert_rect: ColorRect      # Das Vollbild-ColorRect mit dem Invert-Shader
@export var invert_duration: float = 0.3   # schnellerer Übergang (rein & raus)

@export var bpm: float = 90.0
@export var beats_active: float = 4.0   # wie viele Beats der Invert-Effekt aktiv bleibt

var is_sunk: bool = false


func _ready() -> void:
	if not block:
		block = get_parent()  # Fallback: StepTrigger liegt als Kind am Klotz
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_sunk:
		is_sunk = true
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
	invert_colors()


func invert_colors() -> void:
	if not invert_rect:
		return

	var mat = invert_rect.material as ShaderMaterial
	if not mat:
		return

	# Reinblenden
	var tween_in = create_tween()
	tween_in.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween_in.tween_method(
		func(v): mat.set_shader_parameter("mix_factor", v),
		0.0, 1.0, invert_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Berechne, wie lange der Effekt (in Sekunden) aktiv bleiben soll, basierend auf BPM & Beat-Anzahl
	var beat_duration = 60.0 / bpm
	var active_duration = beat_duration * beats_active

	await get_tree().create_timer(invert_duration + active_duration).timeout

	# Wieder rausblenden
	var tween_out = create_tween()
	tween_out.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween_out.tween_method(
		func(v): mat.set_shader_parameter("mix_factor", v),
		1.0, 0.0, invert_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
