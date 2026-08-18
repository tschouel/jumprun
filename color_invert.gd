extends Area2D

@export var invert_rect: ColorRect      # Das Vollbild-ColorRect mit dem Invert-Shader
@export var invert_duration: float = 1.0

var is_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_triggered:
		is_triggered = true
		invert_colors()


func invert_colors() -> void:
	if not invert_rect:
		return

	var mat = invert_rect.material as ShaderMaterial
	if not mat:
		return

	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(
		func(v): mat.set_shader_parameter("mix_factor", v),
		0.0, 1.0, invert_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
