extends Area2D

@export var block: AnimatableBody2D        # Der Klotz (SinkBlock), der absinkt
@export var rain_particles: GPUParticles2D
@export var ground_node: Node2D            # Optional: Boden-Referenz (gleicher Parent wie block!)

@export var sink_distance: float = 120.0   # Wie tief der Block maximal einsinkt
@export var sink_duration: float = 1.2     # Dauer des Absinkens in Sekunden

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
		target_y = min(target_y, ground_node.position.y)  # nur korrekt bei gleichem Parent

	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # gegen das Stottern
	tween.tween_property(block, "position:y", target_y, sink_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_on_block_fully_sunk)


func _on_block_fully_sunk() -> void:
	if not rain_particles:
		return
	rain_particles.emitting = true
