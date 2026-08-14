extends Node

const PARAM_GO: String = "Go"
const PARAM_FAIL: String = "Fail"

## Ziehe hier die FmodEventEmitter2D-Node rein (die mit dem Event drauf, OHNE eigenes Script)
@export var fmod_emitter: FmodEventEmitter2D

@export_group("Fail / Game Over")
## Wie viele Sekunden soll FMOD nach dem Fail weiterspielen, bevor das Level neu lädt?
@export var fail_delay_seconds: float = 1.5 

var _is_failing: bool = false

func _ready() -> void:
	add_to_group("audio_controller")

	if not fmod_emitter:
		push_error("[AudioController] Kein fmod_emitter zugewiesen! Im Inspector die FmodEventEmitter2D-Node reinziehen.")
		return

	fmod_emitter.play()
	fmod_emitter.set_parameter(PARAM_GO, 0)
	fmod_emitter.set_parameter(PARAM_FAIL, 0)
	print("[AudioController] Event gestartet, Go = 0, Fail = 0")

func set_go(value: Variant) -> void:
	if not fmod_emitter:
		push_error("[AudioController] Kein fmod_emitter zugewiesen.")
		return

	var float_val: float = float(value)
	print("[AudioController] Sende '", PARAM_GO, "' = ", float_val)
	fmod_emitter.set_parameter(PARAM_GO, float_val)

func set_fail(value: Variant = 1.0) -> void:
	if not fmod_emitter:
		push_error("[AudioController] Kein fmod_emitter zugewiesen.")
		return

	var float_val: float = float(value)
	print("[AudioController] Sende '", PARAM_FAIL, "' = ", float_val)
	fmod_emitter.set_parameter(PARAM_FAIL, float_val)

## Setzt Fail=1, friert den Player ein, wartet die Musik-Dauer ab und lädt die Szene neu
func trigger_fail_sequence(player: Node2D = null) -> void:
	if _is_failing:
		return
	_is_failing = true

	# 1. Fail-Parameter an FMOD senden
	set_fail(1.0)

	# 2. Player stoppen / Crash auslösen
	if player:
		if "forward_speed" in player:
			player.forward_speed = 0.0
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		
		var lane_module = player.get_node_or_null("LaneMovement")
		if lane_module and lane_module.has_method("trigger_crash"):
			lane_module.trigger_crash()

	# 3. Warten, bis FMOD das Fail-File zu Ende gespielt hat
	print("[AudioController] Fail ausgelöst – warte ", fail_delay_seconds, " Sekunden...")
	await get_tree().create_timer(fail_delay_seconds).timeout

	# 4. Level sauber neu starten
	get_tree().reload_current_scene()

func set_parameter(parameter_name: String, value: Variant) -> void:
	if not fmod_emitter:
		push_error("[AudioController] Kein fmod_emitter zugewiesen.")
		return

	var float_val: float = float(value)
	print("[AudioController] Empfange set_parameter: ", parameter_name, " = ", float_val)
	
	fmod_emitter.set_parameter(parameter_name, float_val)
	print("[AudioController] Parameter gesendet: ", parameter_name, " = ", float_val)
