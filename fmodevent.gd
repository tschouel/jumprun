class_name LevelAudioController

extends FmodEventEmitter2D

const PARAM_GO: String = "Go"

func _ready() -> void:
	# 1. Event starten
	if has_method("play"):
		play()
	elif has_method("start"):
		call("start")

	# Einen Frame warten, damit FMOD die Instanz fertig aufbauen kann
	await get_tree().process_frame

	# 2. Initialwert 0
	set_go(0)

# NUR ZUM TESTEN: Zahlentasten 0, 1, 2 setzen Go direkt, unabhängig vom restlichen Spiel
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_0:
			set_go(0)
		elif event.keycode == KEY_1:
			set_go(1)
		elif event.keycode == KEY_2:
			set_go(2)

func set_go(value: Variant) -> void:
	var float_val: float = float(value)
	var str_val: String = str(int(round(float_val)))
	print("[AudioController] Sende '", PARAM_GO, "' = ", float_val, " (Label: \"", str_val, "\")")

	print("[AudioController] DEBUG hat set_parameter_by_name_with_label: ", has_method("set_parameter_by_name_with_label"))
	if has_method("set_parameter_by_name_with_label"):
		call("set_parameter_by_name_with_label", PARAM_GO, str_val)

	print("[AudioController] DEBUG hat set_parameter_by_name: ", has_method("set_parameter_by_name"))
	if has_method("set_parameter_by_name"):
		call("set_parameter_by_name", PARAM_GO, float_val)

	print("[AudioController] DEBUG hat set_parameter: ", has_method("set_parameter"))
	if has_method("set_parameter"):
		set_parameter(PARAM_GO, float_val)

	var param_path: String = "fmod_parameters/" + PARAM_GO
	print("[AudioController] DEBUG '", param_path, "' existiert an dieser Node: ", param_path in self)
	if param_path in self:
		set(param_path, float_val)

	# Direkt danach nachfragen, was FMOD JETZT als Wert für 'Go' zurückgibt
	if has_method("get_parameter"):
		var readback = get_parameter(PARAM_GO)
		print("[AudioController] DEBUG Rücklese-Wert von get_parameter('Go'): ", readback)
