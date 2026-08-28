extends Area2D
@export var block: AnimatableBody2D
@export var ground_node: Node2D
@export var sink_distance: float = 120.0
@export var sink_duration: float = 1.2
@export_group("Reset durch andere Tasten")
@export var reset_triggers: Array[Area2D] = []
@export var reset_duration: float = 0.4
@export_group("Anfangszustand")
## Wenn true, ist der Button beim Laden der Szene bereits heruntergedrueckt -
## der Block startet SOFORT in der versenkten Position (keine Animation),
## und sunk_state_changed(true) wird einmalig gesendet, damit andere Systeme
## (Kopplung, Reset-Logik etc.) den Startzustand mitbekommen.
@export var start_sunk: bool = false
@export_group("Debug")
## Godots Output-Konsole wird ueber eine laengere Testsession mit vielen
## angesammelten Zeilen spuerbar langsam beim Nachrendern - jede weitere
## print()-Zeile kann dann kurz haengen. Deshalb hier abschaltbar statt fest
## eingebaut. Bei Bedarf fuers Debuggen einfach wieder aktivieren.
@export var debug_prints: bool = false
## Feuert bei jedem echten Sink/Reset (und einmalig beim Laden, falls
## start_sunk aktiv ist) - fuer externe Systeme, die auf den Druckzustand
## reagieren wollen, ohne sich auf body_entered/exited verlassen zu muessen.
signal sunk_state_changed(sunk: bool)
var is_sunk: bool = false
var _original_y: float = 0.0
func _ready() -> void:
	if not block:
		block = get_parent()
	_original_y = block.position.y
	if debug_prints:
		print("[", get_path(), "] ready | block=", block.get_path(), " | original_y=", _original_y)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	for other in reset_triggers:
		if other:
			other.body_entered.connect(_on_reset_trigger_entered)
	if start_sunk:
		is_sunk = true
		block.position.y = _compute_sunk_y()
		if debug_prints:
			print("[", get_path(), "] start_sunk aktiv -> Block startet versenkt bei y=", block.position.y)
		# call_deferred, damit andere Skripte erst noch Zeit haben, sich in
		# ihrem eigenen _ready() mit sunk_state_changed zu verbinden, bevor
		# es feuert.
		call_deferred("_emit_initial_sunk_signal")
func _emit_initial_sunk_signal() -> void:
	sunk_state_changed.emit(true)
func _compute_sunk_y() -> float:
	var target_y = _original_y + sink_distance
	if ground_node:
		target_y = min(target_y, ground_node.position.y)
	return target_y
func _on_body_entered(body: Node2D) -> void:
	if debug_prints and body is CharacterBody2D:
		print("[", get_path(), "] PLAYER body_entered | is_sunk=", is_sunk, " | area_global_pos=", global_position, " | player_pos=", body.global_position)
	if body is CharacterBody2D and not is_sunk:
		is_sunk = true
		sink_into_ground()
func _on_body_exited(body: Node2D) -> void:
	if debug_prints and body is CharacterBody2D:
		print("[", get_path(), "] PLAYER body_exited | is_sunk=", is_sunk)
func _on_reset_trigger_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if not is_sunk:
		return
	if debug_prints:
		print("[", get_path(), "] wird zurückgesetzt durch anderen Trigger")
	reset_button()
func sink_into_ground() -> void:
	var target_y = _compute_sunk_y()
	if debug_prints:
		print("[", get_path(), "] sink_into_ground -> target_y=", target_y, " current=", block.position.y)
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(block, "position:y", target_y, sink_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sunk_state_changed.emit(true)
func reset_button() -> void:
	is_sunk = false
	if debug_prints:
		print("[", get_path(), "] reset_button -> zurück zu original_y=", _original_y, " current=", block.position.y)
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(block, "position:y", _original_y, reset_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sunk_state_changed.emit(false)
