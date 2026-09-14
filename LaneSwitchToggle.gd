extends Area2D
## TriggerArea, die den Lane-Wechsel (links/rechts zwischen den 5 Saiten)
## freischaltet oder sperrt. Wird EINMAL breit über ALLE 5 Saiten platziert
## (nicht pro Saite einzeln!) - egal auf welcher Saite der Spieler gerade
## rutscht, er durchquert dieselbe TriggerArea auf Höhe von Punkt B/C.
##
## SETUP: Zwei Instanzen dieser Szene im Level platzieren:
## - Punkt B: enable_lane_switching = true  (Wechsel wird ab hier erlaubt)
## - Punkt C: enable_lane_switching = false (Wechsel wird ab hier gesperrt,
##   Spieler bleibt auf der Saite, auf der er sich gerade befindet)

@export var enable_lane_switching: bool = true

@export_group("Kamera zurücksetzen")
## Falls aktiviert: setzt beim Durchqueren dieser TriggerArea den von
## BassSlideZone gesetzten Kamera-Zoom/-Offset wieder auf den Normalwert
## zurück (z.B. sinnvoll an Punkt C, damit die Kamera schon vor dem
## Pfadende wieder normal ist). Nutzt dasselbe Override-System wie
## BassSlideZone (GroundMovement.set/clear_camera_zoom_override).
@export var reset_camera: bool = false
@export var camera_reset_duration: float = 0.4


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_meta("path_bass_movement_module"):
		return

	var path_bass_movement = body.get_meta("path_bass_movement_module")
	if not path_bass_movement:
		return

	if enable_lane_switching:
		if path_bass_movement.has_method("enable_lane_switch"):
			path_bass_movement.enable_lane_switch()
	else:
		if path_bass_movement.has_method("disable_lane_switch"):
			path_bass_movement.disable_lane_switch()

	if reset_camera:
		var ground_module = body.get_node_or_null("GroundMovement")
		if ground_module:
			ground_module.clear_camera_zoom_override(camera_reset_duration)
			ground_module.clear_camera_offset_override(camera_reset_duration)
