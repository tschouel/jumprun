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
## AUSSTIEGS-SPERRE (neu): Falls gopichand gesetzt ist, wird beim Start des
## Finales sofort gopichand.lock_exit() aufgerufen - damit kann der Spieler
## waehrend/nach dem Finale nicht mehr per F aus dem Instrument aussteigen.
## exit_lock_duration bestimmt, ob/wann die Sperre wieder aufgehoben wird:
## 0.0 (Standard) = Sperre bleibt DAUERHAFT bestehen (passend zum
## dauerhaften Kamera-Zoom - gedacht als endgueltiger Abschluss-Moment).
## > 0 = nach so vielen Sekunden wird automatisch gopichand.unlock_exit()
## aufgerufen und der Spieler kann das Instrument wieder verlassen.
##
## KOMPATIBEL MIT DEM success_target-MUSTER: die oeffentliche Methode heisst
## bewusst start_tuning(), damit dieser Node direkt als final_target in
## CallAndResponse.gd eingetragen werden kann.
##
## LEVEL-AUFBAU (neu): zusaetzlich zu den Schmetterlingen kann
## level_build_targets beliebige ANDERE bereits vorhandene Komponenten
## enthalten (z.B. Teile der naechsten Szene, die sich beim Finale bewegen/
## aufbauen sollen - RhythmicMover, VibratingString, TuningPeg_weight, etc.).
## Jedes Element wird zeitversetzt (level_build_stagger_delay, unabhaengig
## vom stagger_delay der Schmetterlinge) ausgeloest, indem start_tuning()
## aufgerufen wird, falls vorhanden, sonst start() - so funktioniert es mit
## JEDER bisherigen Komponente in diesem Projekt, ohne dass du irgendwo eine
## Wrapper-Methode nachruesten musst.
##
## Setup:
## 1. Leerer Node, dieses Skript drauf.
## 2. player auf den Spieler zeigen lassen.
## 3. camera_zoom_target/camera_zoom_duration/camera_zoom_curve nach Wunsch
##    einstellen (bleibt dauerhaft).
## 4. camera_offset_x/camera_offset_y/camera_offset_duration/
##    camera_offset_revert_delay fuer den temporaeren Offset-Effekt
##    einstellen.
## 5. gopichand auf die Gopichand-Node-Instanz (gopichand.gd) zeigen lassen,
##    aus der der Spieler beim Finale nicht mehr aussteigen koennen soll.
##    exit_lock_duration nach Wunsch einstellen (0 = dauerhaft gesperrt).
## 6. butterflies: Array mit deinen 3 TunerButterfly-Instanzen, in der
##    Reihenfolge, in der sie starten sollen.
## 7. stagger_delay: Abstand in Sekunden zwischen den Startzeitpunkten der
##    einzelnen Schmetterlinge.
## 8. level_build_targets: Array mit allen weiteren Komponenten, die sich
##    beim Finale aufbauen/bewegen sollen (in Start-Reihenfolge).
##    level_build_stagger_delay: Abstand zwischen deren Startzeitpunkten.
## 9. Als final_target in call_and_response.gd eintragen.

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

@export_group("Ausstiegs-Sperre")
## Die Gopichand-Instanz (gopichand.gd), aus der der Spieler waehrend des
## Finales nicht mehr per F aussteigen koennen soll. Leer lassen, wenn
## keine Sperre gebraucht wird.
@export var gopichand: Node
## 0.0 = Sperre bleibt dauerhaft bestehen (Standard, passend zum
## dauerhaften Kamera-Zoom). > 0 = Sperre wird nach so vielen Sekunden
## automatisch wieder aufgehoben.
@export var exit_lock_duration: float = 0.0

@export_group("Schmetterlinge")
## Die 3 TunerButterfly-Instanzen, in Start-Reihenfolge.
@export var butterflies: Array[Node] = []
## Zeitabstand zwischen den einzelnen Start-Zeitpunkten (leicht versetzt
## statt alle exakt gleichzeitig).
@export var stagger_delay: float = 0.4

@export_group("Level-Aufbau (optional)")
## Beliebige weitere, bereits vorhandene Komponenten, die beim Finale
## ausgeloest werden sollen (z.B. Teile der naechsten Szene) - unabhaengig
## von den Schmetterlingen oben. Jedes Element braucht lediglich eine
## eigene start_tuning()- oder start()-Methode (start_tuning() hat Vorrang,
## falls beide vorhanden sind).
@export var level_build_targets: Array[Node] = []
## Zeitabstand zwischen den einzelnen Start-Zeitpunkten der
## level_build_targets (eigener Wert, unabhaengig von stagger_delay).
@export var level_build_stagger_delay: float = 0.3

var _ground_module: Node = null

## Wird von aussen aufgerufen (z.B. CallAndResponse.gd als final_target).
func start_tuning() -> void:
	_cache_ground_module()
	_lock_exit()
	_apply_camera_zoom()
	_apply_camera_offset()
	_start_butterflies_staggered()
	_start_level_build_staggered()

func _cache_ground_module() -> void:
	if not player:
		return
	_ground_module = player.get_node_or_null("GroundMovement")

## Sperrt sofort den Ausstieg aus gopichand (falls gesetzt) und plant -
## nur falls exit_lock_duration > 0 - das automatische Aufheben der Sperre.
func _lock_exit() -> void:
	if not gopichand or not gopichand.has_method("lock_exit"):
		return
	gopichand.lock_exit()
	if exit_lock_duration > 0.0:
		get_tree().create_timer(exit_lock_duration).timeout.connect(
			func() -> void:
				if is_instance_valid(gopichand) and gopichand.has_method("unlock_exit"):
					gopichand.unlock_exit()
		)

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

## Loest alle level_build_targets zeitversetzt aus - im Unterschied zu den
## Schmetterlingen (die IMMER start_tuning() haben) wird hier pro Element
## start_tuning() bevorzugt, falls vorhanden, sonst start() - damit
## funktioniert es unveraendert mit allen bisherigen Komponenten-Typen
## (RhythmicMover, VibratingString, ...), egal welchen Methodennamen sie
## fuer "jetzt loslegen" verwenden.
func _start_level_build_staggered() -> void:
	for i in range(level_build_targets.size()):
		var target: Node = level_build_targets[i]
		if not target:
			continue
		if i == 0:
			_trigger_level_build_target(target)
		else:
			var delay: float = level_build_stagger_delay * float(i)
			get_tree().create_timer(delay).timeout.connect(
				func() -> void:
					if is_instance_valid(target):
						_trigger_level_build_target(target)
			)

func _trigger_level_build_target(target: Node) -> void:
	if target.has_method("start_tuning"):
		target.start_tuning()
	elif target.has_method("start"):
		target.start()
