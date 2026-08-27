extends Area2D

@export var block: AnimatableBody2D        # Der Klotz (SinkBlock), der absinkt
@export var ground_node: Node2D            # Optional: Boden-Referenz (gleicher Parent wie block!)
@export var sink_distance: float = 120.0   # Wie tief der Block maximal einsinkt
@export var sink_duration: float = 1.2     # Dauer des Absinkens in Sekunden

@export_group("Reset durch andere Tasten")
## Wird eine dieser Areas ausgelöst (z.B. andere Kassettenplayer-Tasten),
## springt DIESE Taste zurück in ihre Ausgangsposition.
@export var reset_triggers: Array[Area2D] = []
@export var reset_duration: float = 0.4

var is_sunk: bool = false
var _original_y: float = 0.0

func _ready() -> void:
	if not block:
		block = get_parent()  # Fallback: StepTrigger liegt als Kind am Klotz
	_original_y = block.position.y

	body_entered.connect(_on_body_entered)

	for other in reset_triggers:
		if other:
			other.body_entered.connect(_on_reset_trigger_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_sunk:
		is_sunk = true
		sink_into_ground()

func _on_reset_trigger_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if not is_sunk:
		return
	reset_button()

func sink_into_ground() -> void:
	var target_y = block.position.y + sink_distance
	if ground_node:
		target_y = min(target_y, ground_node.position.y)  # nur korrekt bei gleichem Parent
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # gegen das Stottern
	tween.tween_property(block, "position:y", target_y, sink_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func reset_button() -> void:
	is_sunk = false
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(block, "position:y", _original_y, reset_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
