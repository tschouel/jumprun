extends Area2D
class_name Obstacle

@export_group("FMOD & Gameplay Target")
## Ziehe hier die Node mit dem LevelAudioController-Script rein (optional, wird sonst automatisch gefunden)
@export var audio_controller: Node
@export var parameter_name: String = "Fail"
@export var target_value: float = 1.0

@export_group("UI & Kollisions-Aktionen")
@export var trigger_ui_change: bool = true
## Startet die Szene bei Berührung neu (verzögert um die Dauer des Fail-Sounds)
@export var reload_on_hit: bool = true

var triggered: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not audio_controller:
		audio_controller = get_tree().get_first_node_in_group("audio_controller")
	print("Obstacle: audio_controller =", audio_controller)

func _on_area_entered(area: Area2D) -> void:
	_trigger_obstacle(area)

func _on_body_entered(body: Node2D) -> void:
	_trigger_obstacle(body)

func _trigger_obstacle(incoming_node: Node2D) -> void:
	print("Obstacle: _trigger_obstacle aufgerufen mit", incoming_node)

	if triggered:
		print("Obstacle: bereits getriggert, breche ab")
		return

	# Player-Knoten ermitteln (falls z. B. die Kollisionsbox getroffen wurde)
	var player: Node2D = incoming_node
	if not (player is CharacterBody2D):
		player = incoming_node.get_parent()

	var is_player = incoming_node.is_in_group("player") or "player" in incoming_node.name.to_lower() or player is CharacterBody2D
	print("Obstacle: ist Spieler:", is_player)

	if not is_player:
		return

	triggered = true
	print("Obstacle: triggere Effekte")

	# 1. Visuelles Feedback für das Hindernis
	var color_rect = get_node_or_null("ColorRect")
	if color_rect:
		color_rect.modulate.a = 0.3

	# 2. Singer UI benachrichtigen
	if trigger_ui_change:
		var singer_ui = get_tree().root.find_child("SingerUI", true, false)
		if singer_ui and singer_ui.has_method("trigger_miss_expression"):
			singer_ui.trigger_miss_expression()

	# 3. AudioController sicherstellen
	if not audio_controller:
		audio_controller = get_tree().get_first_node_in_group("audio_controller")

	# 4. Fail-Sequenz & Reload
	if reload_on_hit:
		# Priorität 1: AudioController übernimmt Fail-Parameter, Player-Stopp & verzögerten Reload
		if audio_controller and audio_controller.has_method("trigger_fail_sequence"):
			print("Obstacle: Starte trigger_fail_sequence über AudioController")
			audio_controller.trigger_fail_sequence(player)
			return

		# Priorität 2: Manueller Parameter-Send + LaneZone Crash
		if audio_controller and audio_controller.has_method("set_parameter"):
			print("Obstacle: Sende Parameter manuell an AudioController")
			audio_controller.set_parameter(parameter_name, target_value)

		var lane_zone = _find_active_lane_zone()
		if lane_zone and lane_zone.has_method("trigger_crash_and_reload"):
			lane_zone.trigger_crash_and_reload(player)
		else:
			get_tree().reload_current_scene()
	else:
		# Falls kein Reload gewünscht ist, nur Parameter abschicken
		if audio_controller and audio_controller.has_method("set_parameter"):
			audio_controller.set_parameter(parameter_name, target_value)

func _find_active_lane_zone() -> LaneZone:
	var zones = get_tree().get_nodes_in_group("lane_zones")
	for zone in zones:
		if zone is LaneZone:
			return zone
			
	return get_tree().root.find_child("*LaneZone*", true, false) as LaneZone
