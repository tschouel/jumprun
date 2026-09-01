extends Node

## Steuert die Aufblas-Animation des Dudelsacks (3 Stufen, siehe pump()) UND
## den Sprung mit Flugphase (siehe jump()) - inklusive der beiden Trigger-
## Zonen, die diese Aktionen ausloesen.
##
## Start: sofort beim Laden spielt der Sprite eine Idle-Loop-Animation
## (idle_loop_animation_name) - der Dudelsack "atmet" im Leerzustand, bevor
## ueberhaupt gepumpt wurde.
##
## Pump-Ablauf: pump() -> pump_animation_names[0] -> loop_animation_names[0] ->
##         pump() -> pump_animation_names[1] -> loop_animation_names[1] ->
##         pump() -> pump_animation_names[2] -> loop_animation_names[2] (Ende)
##
## Setup Pump: als Node neben den AnimatedSprite2D des Dudelsacks in die Szene,
## dieses Skript dran, sprite zuweisen. Die Animationsnamen in den Arrays
## muessen exakt so im SpriteFrames-Panel existieren - idle_loop_animation_name
## und die drei loop_animation_names MIT Loop, die drei pump_animation_names
## OHNE Loop.
##
## Sprung-Ablauf: sprite.play(jump_sprite_animation_name) startet SOFORT beim
## Trigger, ohne Verzoegerung. Die BEWEGUNG (mover, body) folgt separat davon
## den frame_path_keys / frame_body_offset_keys. Sobald jump_sprite_animation_name
## fertig ist (animation_finished), spielt _finish_jump() sofort im Anschluss
## loop_stand_animation_name (MIT Loop im SpriteFrames-Panel) - die Landung
## bleibt so nicht auf dem letzten Jump-Frame haengen, sondern geht direkt in
## eine stehende Loop-Animation ueber.
##
## WICHTIG - Pfad ist RELATIV, nicht absolut: mover wird beim Sprungstart NICHT
## hart auf path_follow.global_position (den fest gezeichneten ersten Punkt der
## Path2D-Kurve) gesetzt. Stattdessen wird beim Start von jump() die aktuelle
## Position von mover als _jump_origin gemerkt, und danach nur noch die
## VERSCHIEBUNG entlang der Kurve (relativ zu ihrem eigenen Startpunkt,
## _path_start_global) auf diese Ausgangsposition addiert:
##   mover.global_position = _jump_origin + (path_follow.global_position - _path_start_global)
## Grund: wenn der Dudelsack beim Ausloesen des Triggers nicht exakt auf dem
## Punkt steht, an dem die Path2D-Kurve gezeichnet wurde, wuerde ein hartes
## mover.global_position = path_follow.global_position beim Start einen
## sofortigen Teleport-Sprung erzeugen (die Kurvenform bleibt trotzdem exakt
## erhalten, sie startet nur dort, wo der Dudelsack gerade wirklich ist, statt
## dort, wo sie im Editor hingezeichnet wurde).
##
## Positions-Update (mover + body): ZWEI getrennte Bewegungen an
## verschiedenen Nodes, aber BEIDE werden im selben Funktionsaufruf
## (_update_jump_position, jeden Physik-Tick) gesetzt:
##   1) Die grosse Flugkurve (Pfad A->B, relativ wie oben beschrieben): mover
##      ist ein Node2D, dessen GLOBALE Position dem Pfad folgt. sprite und
##      AnimatableBody2D (body) sind beide KINDER von mover und wandern
##      automatisch mit.
##   2) Die kleine, lokale Rueckenverschiebung: body.position (LOKAL, relativ
##      zu mover) wird ueber frame_body_offset_keys gesetzt - Vector3(frame,
##      offset.x, offset.y), analog zu frame_path_keys.
##
## Der aktuelle "Frame" wird NICHT als Ganzzahl (sprite.frame) verwendet,
## sondern als fliessende Nachkommazahl ueber sprite.frame_progress (0..1
## Fortschritt im aktuellen Frame) addiert - sonst bleibt die Position fuer
## mehrere Renderbilder exakt stehen und springt dann sprunghaft weiter
## (Flimmern), weil sprite.frame sich nur so oft aendert, wie die Flipbook-FPS
## es hergeben, nicht jeden Renderframe.
##
## WICHTIG zu _finish_jump(): body.position wird beim Landen NICHT einfach auf
## body_rest_local_position zurueckgesetzt (das wuerde einen Sprung erzeugen,
## falls der letzte frame_body_offset_keys-Eintrag einen anderen Wert vorsieht
## als body_rest_local_position). Stattdessen wird beim Landen der Wert des
## LETZTEN frame_body_offset_keys-Eintrags uebernommen, damit body genau dort
## bleibt, wo die Kurve es fuer den letzten Frame vorsieht - nahtlos.
##
## WICHTIG zur Flimmern-Ursache: die Rueckenverschiebung wird bewusst NICHT
## ueber einen AnimationPlayer animiert, sondern hier im Skript ueber
## frame_body_offset_keys - ein AnimationPlayer (Process Callback Physics),
## der gleichzeitig mit diesem Skript im selben Physik-Tick schreibt, hat zu
## Flimmern gefuehrt (nicht deterministische Schreibreihenfolge).
##
## frame_path_keys: x = Animations-Frame, y = Fortschritt (0..1) entlang des
## Pfads bei diesem Frame. Aufsteigend nach x sortieren, mindestens 2
## Eintraege (Start + Ende).
## frame_body_offset_keys: x = Animations-Frame, y = lokaler X-Offset,
## z = lokaler Y-Offset (addiert auf body_rest_local_position). Aufsteigend
## nach x sortieren. Leer lassen, wenn kein Wobble gebraucht wird.
##
## Ausserdem im Projekt (Projekteinstellungen -> Rendering -> 2D -> Snap):
## "Snap 2D Transforms to Pixel" und "Snap 2D Vertices to Pixel" aktiviert
## lassen, und Physics Interpolation (Projekteinstellungen -> Physics ->
## Common) an - beides hilft zusaetzlich gegen Flimmern bei bewegten
## Physik-Bodies.
##
## Von aussen (Trigger/Luftpumpe etc.) per Duck-Typing aufrufen:
##   if bagpipe.has_method("pump"): bagpipe.pump()
##   if bagpipe.has_method("jump"): bagpipe.jump()

signal stage_completed(stage: int)
signal fully_pumped
signal landed

@export_group("Pumpen")
@export var sprite: AnimatedSprite2D
@export var idle_loop_animation_name: String = "loop0"
@export var pump_animation_names: Array[String] = ["pump1", "pump2", "pump3"]
@export var loop_animation_names: Array[String] = ["loop1", "loop2", "loop3"]

@export_group("Sprung")
## Node2D, dessen GLOBALE Position dem Pfad folgt. sprite und body muessen
## Kinder von mover sein.
@export var mover: Node2D
@export var jump_sprite_animation_name: String = "jump"
## Wird sofort abgespielt, wenn jump_sprite_animation_name fertig ist (Landung)
## - MIT Loop im SpriteFrames-Panel. Leer lassen, um stattdessen auf dem
## letzten Frame von jump_sprite_animation_name stehen zu bleiben.
@export var loop_stand_animation_name: String = "loopstand"
## Der Collider, auf dem die Spielfigur steht (Kind von mover).
@export var body: AnimatableBody2D
## Lokale Position (relativ zu mover), an der body ruht, wenn kein Sprung
## laeuft bzw. als Basis fuer frame_body_offset_keys. Normalerweise
## Vector2.ZERO, ausser der Collider sitzt im Sprite bewusst versetzt.
@export var body_rest_local_position: Vector2 = Vector2.ZERO
## Die frei gezeichnete Flugkurve. Ihre absolute Lage im Editor ist nur fuer
## die FORM der Kurve relevant - der tatsaechliche Startpunkt zur Laufzeit ist
## immer die aktuelle Position von mover, siehe Klassenkommentar.
@export var path: Path2D
## Kind von path - liest die Position entlang der Kurve aus.
@export var path_follow: PathFollow2D
## x = Animations-Frame, y = Fortschritt (0..1) entlang des Pfads bei diesem
## Frame. Aufsteigend nach x sortieren, mindestens 2 Eintraege (Start + Ende).
@export var frame_path_keys: Array[Vector2] = []
## x = Animations-Frame, y = lokaler X-Offset, z = lokaler Y-Offset (addiert
## auf body_rest_local_position) - fuer die Ruecken-/Fluegel-Verschiebung
## waehrend des Flugs. Aufsteigend nach x sortieren. Leer = kein Wobble.
@export var frame_body_offset_keys: Array[Vector3] = []

@export_group("Trigger Pumpe")
## Area2D, deren body_entered direkt pump() ausloest - keine Taste noetig.
@export var pump_zone: Area2D

@export_group("Trigger Sprung")
## Area2D, deren body_entered direkt jump() ausloest - keine Taste noetig.
@export var jump_zone: Area2D
## Falls true, loest der Sprung nur aus, wenn der Dudelsack voll gepumpt ist.
@export var require_full_pump: bool = false

@export_group("Debug")
@export var debug_prints: bool = false

var _stage: int = 0
var _busy: bool = false
var _jumping: bool = false
## mover.global_position im Moment, als der aktuelle Sprung gestartet wurde -
## der Pfad wird relativ dazu abgespielt, siehe Klassenkommentar.
var _jump_origin: Vector2 = Vector2.ZERO
## path_follow.global_position bei progress_ratio = 0.0, gemerkt beim
## Sprungstart - Referenzpunkt fuer die relative Verschiebung.
var _path_start_global: Vector2 = Vector2.ZERO

func _ready() -> void:
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if sprite and idle_loop_animation_name != "":
		sprite.speed_scale = 1.0
		sprite.play(idle_loop_animation_name)
	if pump_zone and not pump_zone.body_entered.is_connected(_on_pump_zone_entered):
		pump_zone.body_entered.connect(_on_pump_zone_entered)
	if jump_zone and not jump_zone.body_entered.is_connected(_on_jump_zone_entered):
		jump_zone.body_entered.connect(_on_jump_zone_entered)
	_reset_body_local_position()

## Positions-Update fuer den Sprung laeuft bewusst im Physik-Tick, nicht in
## _process - mover traegt einen AnimatableBody2D mit sync_to_physics=true,
## dessen Transform deshalb im _physics_process aktualisiert werden muss
## (sonst Flimmern/Ruckeln).
func _physics_process(_delta: float) -> void:
	if debug_prints and _jumping and not mover:
		print("[", get_path(), "] WARNUNG: mover ist nicht gesetzt, Sprung bewegt sich nicht")
	if _jumping and path and path_follow and sprite and mover:
		_update_jump_position()

## Loest die naechste Pump-Stufe aus. Gibt true zurueck, wenn der Aufruf
## angenommen wurde, false wenn schon voll gepumpt oder gerade noch eine
## Pump-Animation laeuft (Trigger-Aktivierung wird dann einfach ignoriert).
func pump() -> bool:
	if not sprite or is_full() or _busy:
		return false
	_busy = true
	sprite.stop()
	sprite.speed_scale = 1.0
	sprite.play(pump_animation_names[_stage])
	if debug_prints:
		print("[", get_path(), "] pump() -> Stufe ", _stage + 1, "/", pump_animation_names.size())
	return true

## true, sobald alle 3 Stufen durchlaufen sind (letzte Loop-Animation aktiv).
func is_full() -> bool:
	return _stage >= pump_animation_names.size()

func _on_animation_finished() -> void:
	if not sprite:
		return
	if _stage < pump_animation_names.size() and sprite.animation == pump_animation_names[_stage]:
		sprite.speed_scale = 1.0
		sprite.play(loop_animation_names[_stage])
		_stage += 1
		_busy = false
		stage_completed.emit(_stage)
		if debug_prints:
			print("[", get_path(), "] Stufe ", _stage, " abgeschlossen, Loop laeuft")
		if is_full():
			fully_pumped.emit()
	elif sprite.animation == jump_sprite_animation_name and _jumping:
		_finish_jump()

## Loest den Sprung mit Flugphase aus. Die Sprite-Animation startet SOFORT.
## mover bewegt sich NICHT sofort zum gezeichneten Kurvenanfang, sondern
## bleibt exakt an seiner aktuellen Position stehen - der Pfad wird relativ
## dazu abgespielt (siehe Klassenkommentar), damit es beim Trigger keinen
## Teleport-Sprung gibt, egal wo genau die Path2D-Kurve gezeichnet wurde.
## Gibt false zurueck, wenn schon ein Sprung laeuft oder Referenzen fehlen.
func jump() -> bool:
	if debug_prints and (not sprite or not mover or not path or not path_follow):
		print("[", get_path(), "] jump() abgebrochen - fehlende Referenz: sprite=", sprite, " mover=", mover, " path=", path, " path_follow=", path_follow)
	if not sprite or not mover or not path or not path_follow or _jumping:
		return false
	_jumping = true
	sprite.stop()
	sprite.speed_scale = 1.0
	sprite.play(jump_sprite_animation_name)
	path_follow.progress_ratio = 0.0
	_jump_origin = mover.global_position
	_path_start_global = path_follow.global_position
	if debug_prints:
		print("[", get_path(), "] jump() ausgeloest bei ", _jump_origin, " (Kurvenstart waere ", _path_start_global, " gewesen)")
	return true

## Setzt mover (Pfad, relativ zu _jump_origin/_path_start_global) UND body
## (lokaler Wobble) im selben Aufruf, damit pro Physik-Tick nur ein einziger,
## deterministischer kombinierter Zustand entsteht - siehe Klassenkommentar
## zur Flimmern-Ursache.
func _update_jump_position() -> void:
	var current_frame: float = float(sprite.frame) + sprite.frame_progress
	var progress: float = _frame_to_progress(current_frame)
	path_follow.progress_ratio = progress
	mover.global_position = _jump_origin + (path_follow.global_position - _path_start_global)
	if body:
		body.position = body_rest_local_position + _frame_to_body_offset(current_frame)

## Interpoliert linear zwischen den frame_path_keys-Paaren fuer den
## aktuellen (fliessenden) Animations-Frame. current_frame ist bewusst ein
## float (sprite.frame + sprite.frame_progress) statt einer Ganzzahl, sonst
## bleibt die Position zwischen zwei Flipbook-Frames stehen und springt dann
## sprunghaft weiter statt sich weich zu bewegen. Erwartet die Paare
## aufsteigend nach x sortiert.
func _frame_to_progress(current_frame: float) -> float:
	if frame_path_keys.is_empty():
		return 0.0
	if current_frame <= frame_path_keys[0].x:
		return frame_path_keys[0].y
	for i in range(frame_path_keys.size() - 1):
		var a: Vector2 = frame_path_keys[i]
		var b: Vector2 = frame_path_keys[i + 1]
		if current_frame <= b.x:
			var span: float = b.x - a.x
			var local_t: float = 0.0 if span <= 0.0 else (current_frame - a.x) / span
			return lerp(a.y, b.y, local_t)
	return frame_path_keys[frame_path_keys.size() - 1].y

## Analog zu _frame_to_progress, aber fuer den lokalen 2D-Offset von body
## (frame_body_offset_keys: x = Frame, y = Offset X, z = Offset Y).
func _frame_to_body_offset(current_frame: float) -> Vector2:
	if frame_body_offset_keys.is_empty():
		return Vector2.ZERO
	if current_frame <= frame_body_offset_keys[0].x:
		var first: Vector3 = frame_body_offset_keys[0]
		return Vector2(first.y, first.z)
	for i in range(frame_body_offset_keys.size() - 1):
		var a: Vector3 = frame_body_offset_keys[i]
		var b: Vector3 = frame_body_offset_keys[i + 1]
		if current_frame <= b.x:
			var span: float = b.x - a.x
			var local_t: float = 0.0 if span <= 0.0 else (current_frame - a.x) / span
			return Vector2(lerp(a.y, b.y, local_t), lerp(a.z, b.z, local_t))
	var last: Vector3 = frame_body_offset_keys[frame_body_offset_keys.size() - 1]
	return Vector2(last.y, last.z)

## Setzt body auf den Wert des LETZTEN frame_body_offset_keys-Eintrags (statt
## auf body_rest_local_position) - nahtloser Uebergang ohne Sprung beim Landen
## (siehe Klassenkommentar). Spielt danach direkt loop_stand_animation_name,
## damit nicht auf dem letzten Jump-Frame stehen geblieben wird.
func _finish_jump() -> void:
	if path_follow:
		path_follow.progress_ratio = 1.0
		mover.global_position = _jump_origin + (path_follow.global_position - _path_start_global)
	_jumping = false
	if body:
		if frame_body_offset_keys.is_empty():
			body.position = body_rest_local_position
		else:
			var last: Vector3 = frame_body_offset_keys[frame_body_offset_keys.size() - 1]
			body.position = body_rest_local_position + Vector2(last.y, last.z)
	if sprite and loop_stand_animation_name != "":
		sprite.speed_scale = 1.0
		sprite.play(loop_stand_animation_name)
	landed.emit()
	if debug_prints:
		print("[", get_path(), "] gelandet bei ", mover.global_position, " -> spielt ", loop_stand_animation_name)

## Setzt die lokale Position von body auf body_rest_local_position zurueck -
## nur fuer den allerersten Ruhezustand beim Start (siehe _ready()).
func _reset_body_local_position() -> void:
	if body:
		body.position = body_rest_local_position

func _on_pump_zone_entered(zone_body: Node2D) -> void:
	if zone_body.is_in_group("player"):
		pump()

func _on_jump_zone_entered(zone_body: Node2D) -> void:
	if zone_body.is_in_group("player"):
		if require_full_pump and not is_full():
			if debug_prints:
				print("[", get_path(), "] Sprung blockiert - noch nicht voll gepumpt")
			return
		jump()
