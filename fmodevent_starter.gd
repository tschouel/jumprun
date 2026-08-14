class_name LevelAudioController
extends FmodEventEmitter2D

@export var go_parameter_name: String = "Go"

func _ready() -> void:
	# 1. Event starten
	play()
	# 2. Initialwert 0
	set_go(0)

func set_go(value: Variant) -> void:
	var label_str: String = str(value)
	var float_val: float = float(value)

	print("[FMOD] Aktualisiere '", go_parameter_name, "' auf: ", value)

	# 1. Standard-Methode der Node
	if has_method("set_parameter"):
		set_parameter(go_parameter_name, float_val)

	# 2. Direkter Zugriff auf die interne Event-Instanz der Node
	# (Das zwingt die laufende C++ Instanz zur Aktualisierung)
	if "event_instance" in self and self.event_instance != null:
		var inst = self.event_instance
		if inst.has_method("set_parameter_by_name_with_label"):
			inst.set_parameter_by_name_with_label(go_parameter_name, label_str)
		if inst.has_method("set_parameter_by_name"):
			inst.set_parameter_by_name(go_parameter_name, float_val)
