extends Node2D
class_name LevelAudioController

# WICHTIG: Trag hier den echten Event-Pfad ein (siehst du im Fmod-event Feld,
# z.B. "event:/Nuttes" - ohne die geschweifte Klammer/GUID danach)
const EVENT_PATH: String = "event:/Nuttes"
const PARAM_GO: String = "Go"

var event: FmodEvent = null

func _ready() -> void:
	event = FmodServer.create_event_instance(EVENT_PATH)
	if event == null:
		push_error("[AudioController] Konnte Event nicht erstellen: " + EVENT_PATH)
		return

	event.set_parameter_by_name(PARAM_GO, 0)
	event.start()
	print("[AudioController] Event gestartet, Go = 0")

# NUR ZUM TESTEN: Zahlentasten 0, 1, 2 setzen Go direkt
func _unhandled_key_input(input_event: InputEvent) -> void:
	if input_event is InputEventKey and input_event.pressed and not input_event.echo:
		if input_event.keycode == KEY_0:
			set_go(0)
		elif input_event.keycode == KEY_1:
			set_go(1)
		elif input_event.keycode == KEY_2:
			set_go(2)

func set_go(value: Variant) -> void:
	if event == null:
		push_error("[AudioController] Kein Event vorhanden, kann Go nicht setzen.")
		return

	var float_val: float = float(value)
	print("[AudioController] Sende '", PARAM_GO, "' = ", float_val)
	event.set_parameter_by_name(PARAM_GO, float_val)

	var readback = event.get_parameter_by_name(PARAM_GO)
	print("[AudioController] DEBUG Rücklese-Wert direkt vom FmodEvent-Objekt: ", readback)
