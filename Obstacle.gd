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

	# Player-Knoten ermitteln (falls z. B. die Kollisionsbox getroffen wurde)
	var player: Node2D = incoming_node
	if not (player is CharacterBody2D):
		player = incoming_node.get_parent()

	var is_player = incoming_node.is_in_group("player") or "player" in incoming_node.name.to_lower() or player is CharacterBody2D

	if not is_player:
		return

	triggered = true

	# 1. Visuelles Feedback für das Hindernis
	var color_rect = get_node_or_null("ColorRect")
	if color_rect:
		color_rect.modulate.a = 0.3

	# 2. Singer UI benachrichtigen
	if trigger_ui_change:
		var singer_ui = get_tree().root.find_child("SingerUI", true, false)
		if singer_ui and singer_ui.has_method("trigger_miss_expression"):
			singer_ui.trigger_miss_expression()

	# 3. FMOD Parameter senden
	if music_emitter and music_emitter.has_method("set_parameter"):
		await get_tree().process_frame
		music_emitter.set_parameter(parameter_name, target_value)

	# 4. Crash-Animation triggern
	if reload_on_hit:
		# Suche nach JEDER LaneZone in der Szene, die den Crash ausführen kann
		var lane_zone = _find_active_lane_zone()
		if lane_zone and lane_zone.has_method("trigger_crash_and_reload"):
			lane_zone.trigger_crash_and_reload(player)
		else:
			# Direktes Reload nur als absoluter Fallback
			get_tree().reload_current_scene()

func _find_active_lane_zone() -> LaneZone:
	# Geht die Zonen-Gruppe oder den Szenenbaum durch
	var zones = get_tree().get_nodes_in_group("lane_zones")
	for zone in zones:
		if zone is LaneZone:
			return zone
			
	# Falls nicht in der Gruppe, rekursiv suchen
	return get_tree().root.find_child("*LaneZone*", true, false) as LaneZone
