extends Area2D

@export_group("FMOD & Gameplay Target")
@export var music_emitter: FmodEventEmitter2D
@export var parameter_name: String = "Fall"
@export var target_value: float = 1.0
@export var trigger_ui_change: bool = true

@export_group("Kollisions-Aktion")
## Startet die Szene bei Berührung neu
@export var reload_on_hit: bool = true

var triggered: bool = false

func _ready() -> void:
	# Signal-Verbindungen automatisch beim Laden herstellen
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	_trigger_obstacle(area)

func _on_body_entered(body: Node2D) -> void:
	_trigger_obstacle(body)

func _trigger_obstacle(incoming_node: Node2D) -> void:
	if triggered:
		return

	# Nur auslösen, wenn es wirklich der Player / Notenkopf ist!
	var is_player = incoming_node.is_in_group("player") or "player" in incoming_node.name.to_lower()
	if not is_player:
		return

	triggered = true

	# 1. Visuelles Feedback: Obstacle ausgrauen
	var color_rect = get_node_or_null("ColorRect")
	if color_rect:
		color_rect.modulate.a = 0.3

	# 2. Singer UI benachrichtigen
	if trigger_ui_change:
		var singer_ui = get_tree().root.find_child("SingerUI", true, false)
		if singer_ui and singer_ui.has_method("trigger_miss_expression"):
			singer_ui.trigger_miss_expression()

	# 3. FMOD Parameter an den Emitter senden
	if music_emitter and music_emitter.has_method("set_parameter"):
		await get_tree().process_frame
		music_emitter.set_parameter(parameter_name, target_value)

	# 4. Level-Neustart bei Treffer
	if reload_on_hit:
		get_tree().reload_current_scene()
