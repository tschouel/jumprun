class_name LevelAudioController
extends FmodEventEmitter2D

const PARAM_GO: String = "Go"

func _ready() -> void:
	# 1. Event starten
	if has_method("play"):
		play()
	elif has_method("start"):
		call("start")

	# NEU: einen Frame warten, damit FMOD die Instanz fertig aufbauen kann
	await get_tree().process_frame

	# 2. Initialwert 0 (jetzt erst, nachdem gewartet wurde)
	set_go(0)

func set_go(value: Variant) -> void:
	var float_val: float = float(value)
	var str_val: String = str(int(round(float_val)))
	print("[AudioController] Sende '", PARAM_GO, "' = ", float_val, " (Label: \"", str_val, "\")")

	if has_method("set_parameter_by_name_with_label"):
		call("set_parameter_by_name_with_label", PARAM_GO, str_val)

	if has_method("set_parameter_by_name"):
		call("set_parameter_by_name", PARAM_GO, float_val)

	if has_method("set_parameter"):
		set_parameter(PARAM_GO, float_val)

	var param_path: String = "fmod_parameters/" + PARAM_GO
	if param_path in self:
		set(param_path, float_val)
