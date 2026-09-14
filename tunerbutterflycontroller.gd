extends Node
class_name TunerButterflySequenceController
## Orchestriert das Finale nach der letzten Call-and-Response-Stufe: zoomt
## die Kamera nochmal weiter raus UND verschiebt sie optional per Offset,
## dann startet leicht versetzt (siehe stagger_delay) bis zu 3
## TunerButterfly-Instanzen, die jeweils von ihrem eigenen
## flight_start_point aus ins Bild fliegen und ihre Dreh-Animation
## abspielen (loop_count fuer "6x durchlaufen" wird direkt an JEDER
## TunerButterfly-Instanz im Inspector eingestellt, nicht hier).
##
## KAMERA-ZOOM: bleibt wie bisher DAUERHAFT bestehen (kein automatisches
## Zuruecksetzen) - das ist als Abschluss-/Finale-Moment gedacht.
##
## KAMERA-OFFSET (neu): im Gegensatz zum Zoom wird der Offset NACH
## camera_offset_revert_delay Sekunden automatisch wieder auf seinen
## vorherigen Wert zurueckgesetzt (ueber clear_camera_offset_override()),
## unabhaengig von camera_zoom_duration. Auf 0/0 lassen (Standard), wenn
## kein Offset-Effekt gebraucht wird - dann passiert bzgl. Offset gar
## nichts.
##
## KOMPATIBEL MIT DEM success_target-MUSTER: die oeffentliche Methode heisst
## bewusst start_tuning(), damit dieser Node direkt als final_target in
## CallAndResponse.gd eingetragen werden kann.
##
## Setup:
## 1. Leerer Node, dieses Skript drauf.
## 2. player auf den Spieler zeigen lassen.
## 3. camera_zoom_target/camera_zoom_duration/camera_zoom_curve nach Wunsch
##    einstellen (bleibt dauerhaft).
## 4. camera_offset_x/camera_offset_y/camera_offset_duration/
##    camera_offset_revert_delay fuer den temporaeren Offset-Effekt
##    einstellen.
## 5. butterflies: Array mit deinen 3 TunerButterfly-Instanzen, in der
##    Reihenfolge, in der sie starten sollen.
## 6. stagger_delay: Abstand in Sekunden zwischen den Startzeitpunkten der
##    einzelnen Schmetterlinge.
## 7. Als final_target in call_and_response.gd eintragen.

@export var player: CharacterBody2D

@export_group("Kamera - Zoom (bleibt dauerhaft)")
## Ziel-Zoom fuer das Finale - Werte > 1 zoomen WEITER RAUS (siehe
## groundmovement.gd/gopichand.gd fuer die genaue Zoom-Konvention in eurem
## Setup, im Zweifel kurz ausprobieren).
@export var camera_zoom_target: Vector2 = Vector2(1.4, 1.4)
@export var camera_zoom_duration: float = 1.5
@export var camera_zoom_curve: Curve

@export_group("Kamera - Offset (wird automatisch zurueckgesetzt)")
## X-Ziel-Offset (in Pixeln). 0.0 UND camera_offset_y = 0.0 (Standard) =
## kein Offset-Effekt.
@export var camera_offset_x: float = 0.0
## Y-Ziel-Offset (in Pixeln).
@export var camera_offset_y: float = 0.0
## Dauer der Hin-Fahrt zum Offset-Ziel (0.0 = geschwindigkeitsbasiertes
## Smoothing wie ueberall sonst, > 0 = exakte Tween-Dauer).
@export var camera_offset_duration: float = 1.5
## Optionale Curve fuer die Hin-Fahrt.
@export var camera_offset_curve: Curve
## Nach WIE VIELEN Sekunden - gerechnet ab dem Erreichen des Offset-Ziels
## (also NACH camera_offset_duration) - der Offset automatisch wieder
## zurueckgefahren wird. Die Ruecklauf-Fahrt selbst nutzt dieselbe Dauer/
## Kurve wie die Hin-Fahrt (camera_offset_duration/camera_offset_curve).
@export var camera_offset_revert_delay: float = 3.0

@export_group("Schmetterlinge")
## Die 3 TunerButterfly-Instanzen, in Start-Reihenfolge.
@export var butterflies: Array[Node] = []
## Zeitabstand zwischen den einzelnen Start-Zeitpunkten (leicht versetzt
## statt alle exakt gleichzeitig).
@export var stagger_delay: float = 0.4

var _ground_module: Node = null

## Wird von aussen aufgerufen (z.B. CallAndResponse.gd als final_target).
func start_tuning() -> void:
	_cache_ground_module()
	_apply_camera_zoom()
	_apply_camera_offset()
	_start_butterflies_staggered()

func _cache_ground_module() -> void:
	if not player:
		return
	_ground_module = player.get_node_or_null("GroundMovement")

func _apply_camera_zoom() -> void:
	if not _ground_module or not _ground_module.has_method("set_camera_zoom_override"):
		return
	_ground_module.set_camera_zoom_override(camera_zoom_target, camera_zoom_duration, camera_zoom_curve)

## Faehrt die Kamera auf den Ziel-Offset UND plant automatisch das
## Zuruecksetzen nach camera_offset_revert_delay Sekunden (ab Erreichen des
## Ziels). Macht nichts, falls X und Y beide 0 sind.
func _apply_camera_offset() -> void:
	if camera_offset_x == 0.0 and camera_offset_y == 0.0:
		return
	if not _ground_module or not _ground_module.has_method("set_camera_offset_override"):
		return
	_ground_module.set_camera_offset_override(Vector2(camera_offset_x, camera_offset_y), camera_offset_duration, camera_offset_curve)

	# Automatisches Zuruecksetzen: warten bis die Hin-Fahrt fertig ist
	# (camera_offset_duration), DANN camera_offset_revert_delay Sekunden
	# beim Ziel-Offset bleiben, DANN zurueckfahren.
	var total_wait: float = camera_offset_duration + camera_offset_revert_delay
	get_tree().create_timer(total_wait).timeout.connect(
		func() -> void:
			if _ground_module and _ground_module.has_method("clear_camera_offset_override"):
				_ground_module.clear_camera_offset_override(camera_offset_duration, camera_offset_curve)
	)

func _start_butterflies_staggered() -> void:
	for i in range(butterflies.size()):
		var butterfly: Node = butterflies[i]
		if not butterfly or not butterfly.has_method("start_tuning"):
			continue
		if i == 0:
			butterfly.start_tuning()
		else:
			var delay: float = stagger_delay * float(i)
			get_tree().create_timer(delay).timeout.connect(
				func() -> void:
					if is_instance_valid(butterfly) and butterfly.has_method("start_tuning"):
						butterfly.start_tuning()
			)
