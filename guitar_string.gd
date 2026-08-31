extends Line2D

## Gitarrensaite: liegt in Ruhe gerade zwischen start_point und end_point,
## wird an bis zu 4 waehlbaren Punkten (press_points) heruntergedrueckt, wenn
## der zugehoerige Hebel (gleicher Index) aktiv ist, und vibriert nach jedem
## pluck()-Aufruf mit abklingender Amplitude - wie eine echte angezupfte Saite.
##
## Es gibt zwei Zupf-"Pedale": das Standard-Pedal (pluck(false), von
## start_point bis zum aktiven Druckpunkt vibrierend) und ein zweites Pedal
## (pluck(true), von end_point bis zum aktiven Druckpunkt vibrierend) - der
## jeweils andere Teil der Saite liegt "tot" auf dem Bund, genau wie bei einer
## echten Gitarre, je nachdem von welcher Seite gerade gespielt wird.
##
## Setup: als Line2D-Node in die Szene, dieses Skript dran. start_point/
## end_point auf zwei Node2D (z.B. Marker2D an Sattel/Steg) setzen. Bei
## press_points bis zu 4 Marker2D reinziehen, an den Stellen platziert, wo
## deine 4 Hebel die Saite druecken sollen (Index = Hebel-Nummer). Bei
## pluck_point/pluck_point_alt je einen Marker2D dort platzieren, wo die
## beiden Pedale zupfen.

@export var start_point: Node2D
@export var end_point: Node2D
@export var segments: int = 40

@export_group("Bund-Druckpunkte")
## Bis zu 4 Punkte (z.B. Marker2D), an denen die Saite heruntergedrueckt wird,
## wenn der zugehoerige Hebel (gleicher Index) aktiv ist. Leer lassen fuer
## Hebel, die (noch) keinen eigenen Punkt haben.
@export var press_points: Array[Node2D] = []
## Wie schnell die Saite zum Druckpunkt hin bzw. wieder zurueck interpoliert.
@export var press_speed: float = 20.0
## Wie weit (in Pixeln senkrecht zur Saite) der Druckpunkt die Saite "durchbiegt".
@export var press_depth: float = 12.0

@export_group("Vibration")
## Zupfpunkt fuer das STANDARD-Pedal (pluck(false)) - vibrierender Bereich ist
## dann start_point bis zum aktiven Druckpunkt. Leer lassen = Mitte des Bereichs.
@export var pluck_point: Node2D
## Zupfpunkt fuer das ZWEITE Pedal (pluck(true)) - vibrierender Bereich ist
## dann end_point bis zum aktiven Druckpunkt. Leer lassen = Mitte des Bereichs.
@export var pluck_point_alt: Node2D
@export var vibration_amplitude: float = 10.0
## Wie SCHNELL die Vibration nach einem pluck() wieder abklingt (pro Sekunde).
## GROESSERER Wert = schneller WEG (kuerzer sichtbar), KLEINERER Wert = laenger
## sichtbar/haelt laenger an. Bei z.B. 15.0 ist die Vibration in ~0.07s komplett
## verschwunden - fuer laenger sichtbare Vibration eher 1.5 bis 3.0 probieren.
@export_range(0.1, 10.0, 0.1) var vibration_decay: float = 2.5
@export var vibration_frequency: float = 18.0

@export_group("Debug")
@export var debug_prints: bool = false

var _pressed_lever: int = -1
var _pressed_lever_alt: int = -1
var _press_amount: float = 0.0
var _vibration_time: float = 0.0
var _vibration_strength: float = 0.0
var _vibrate_from_end: bool = false

func _ready() -> void:
	# Ohne das hier zeichnet Line2D jede schraege Strecke treppig/pixelig -
	# das haengt NICHT von der Anzahl der Punkte/segments ab, sondern ist
	# reines Rendering. antialiased + runde Verbindungen beheben das.
	antialiased = true
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	_update_points()

func _process(delta: float) -> void:
	if not (start_point and end_point):
		return
	_vibration_time += delta
	_vibration_strength = max(_vibration_strength - vibration_decay * delta, 0.0)
	var has_target: bool = _pressed_lever >= 0 and _pressed_lever < press_points.size() and press_points[_pressed_lever] != null
	var target_press: float = 1.0 if has_target else 0.0
	_press_amount = move_toward(_press_amount, target_press, press_speed * delta)
	_update_points()

## Setzt, welcher Hebel (Index 0..3) die Saite gerade herunterdrueckt (fuer die
## sichtbare Biegung UND als Druckpunkt beim Standard-Pedal/E). -1 = keiner.
func set_pressed_lever(index: int) -> void:
	_pressed_lever = index

## Setzt den Druckpunkt-Index, der beim ZWEITEN Pedal (Q, vibrate_from_end)
## als Grenze fuer den vibrierenden Bereich gilt - mit umgekehrter Prioritaet
## (niedrigster gehaltener Index gewinnt statt hoechster). Beeinflusst NICHT
## die sichtbare Biegung der Saite, nur die Vibrationsgrenze beim Q-Pedal.
func set_pressed_lever_alt(index: int) -> void:
	_pressed_lever_alt = index

## Loest eine abklingende Vibration aus. from_end = false: Standard-Pedal,
## vibrierender Bereich start_point -> Druckpunkt. from_end = true: zweites
## Pedal, vibrierender Bereich end_point -> Druckpunkt.
func pluck(from_end: bool = false) -> void:
	_vibration_strength = 1.0
	_vibrate_from_end = from_end
	if debug_prints:
		var p: Node2D = pluck_point_alt if from_end else pluck_point
		print("[", get_path(), "] pluck(from_end=", from_end, ") -> pluck_point_t=", _project_t(p))

## Projiziert einen beliebigen Node2D auf die Saitenlinie (0..1). -1 falls
## nicht berechenbar. Nur fuer Debug-Prints gedacht.
func _project_t(node: Node2D) -> float:
	if not node or not (start_point and end_point):
		return -1.0
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return -1.0
	return clamp((node.global_position - from).dot(dir / length) / length, 0.0, 1.0)

func _update_points() -> void:
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var dir_norm: Vector2 = dir / length
	var normal: Vector2 = dir_norm.orthogonal()

	var press_target: Node2D = null
	if _pressed_lever >= 0 and _pressed_lever < press_points.size():
		press_target = press_points[_pressed_lever]
	var press_t: float = 0.0
	if press_target:
		press_t = clamp((press_target.global_position - from).dot(dir_norm) / length, 0.0, 1.0)

	# Fuer die Vibrationsgrenze beim ZWEITEN Pedal (Q) gilt eine andere
	# Prioritaet als fuer die sichtbare Biegung/das Standard-Pedal (E): dort
	# gewinnt bei mehreren gehaltenen Hebeln der niedrigste Index (kuerzester
	# Weg), waehrend die Biegung selbst weiterhin dem hoechsten Index folgt
	# (_pressed_lever, siehe _poll_levers in guitar_mechanism.gd).
	var vib_press_target: Node2D = null
	if _pressed_lever_alt >= 0 and _pressed_lever_alt < press_points.size():
		vib_press_target = press_points[_pressed_lever_alt]
	var vib_press_t: float = 0.0
	if vib_press_target:
		vib_press_t = clamp((vib_press_target.global_position - from).dot(dir_norm) / length, 0.0, 1.0)

	# Vibrierender Bereich der Saite - haengt davon ab, ueber welches Pedal
	# zuletzt gezupft wurde:
	# - Standard-Pedal (_vibrate_from_end = false): von start_point (t=0) bis
	#   zum Druckpunkt - der Teil dahinter (Richtung end_point) liegt tot.
	# - Zweites Pedal (_vibrate_from_end = true): von end_point (t=1) bis zum
	#   Druckpunkt (mit der oben beschriebenen umgekehrten Prioritaet) - hier
	#   liegt stattdessen der Teil Richtung start_point tot.
	# Ohne aktiven Druckpunkt (kein Hebel gehalten) vibriert in beiden
	# Faellen die ganze Saite. _press_amount sorgt fuer einen weichen
	# Uebergang statt einem harten Umschalten.
	var vib_start_t: float = 0.0
	var vib_end_t: float = 1.0
	if _vibrate_from_end:
		if vib_press_target:
			vib_start_t = lerp(0.0, vib_press_t, _press_amount)
	else:
		if press_target:
			vib_end_t = lerp(1.0, press_t, _press_amount)
	vib_start_t = clamp(vib_start_t, 0.0, 0.98)
	vib_end_t = clamp(vib_end_t, vib_start_t + 0.02, 1.0)

	var active_pluck_point: Node2D = pluck_point_alt if _vibrate_from_end else pluck_point
	var pluck_t: float = (vib_start_t + vib_end_t) * 0.5
	if active_pluck_point:
		var raw_t: float = clamp((active_pluck_point.global_position - from).dot(dir_norm) / length, 0.0, 1.0)
		pluck_t = clamp(raw_t, vib_start_t + 0.001, vib_end_t - 0.001)

	var new_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var base: Vector2 = from.lerp(to, t)
		var local_point: Vector2 = to_local(base)
		# Bund-Druck: die GESAMTE Saite biegt sich durch, nicht nur eine kleine
		# Zone um den Druckpunkt - glatte (smoothstep) Rampe von 0 an beiden
		# Saitenenden bis zum vollen press_depth genau am Druckpunkt. Das gilt
		# unabhaengig davon, welches Pedal gerade zupft.
		if press_target and _press_amount > 0.0:
			var press_weight: float = 0.0
			if press_t <= 0.0:
				press_weight = 1.0 - smoothstep(0.0, 1.0, t)
			elif press_t >= 1.0:
				press_weight = smoothstep(0.0, 1.0, t)
			elif t <= press_t:
				press_weight = smoothstep(0.0, 1.0, t / press_t)
			else:
				press_weight = smoothstep(0.0, 1.0, 1.0 - (t - press_t) / (1.0 - press_t))
			local_point += normal * press_depth * press_weight * _press_amount
		# Vibration: nur innerhalb [vib_start_t, vib_end_t]. Ausserhalb liegt
		# die Saite tot auf dem Bund. Innerhalb hat die Huelle ihr Maximum bei
		# pluck_t und faellt zu beiden Seiten des Bereichs auf 0 ab.
		if t >= vib_start_t and t <= vib_end_t:
			var edge_fade: float
			if t <= pluck_t:
				var denom_left: float = pluck_t - vib_start_t
				edge_fade = sin(((t - vib_start_t) / denom_left) * (PI * 0.5)) if denom_left > 0.0001 else 1.0
			else:
				var denom_right: float = vib_end_t - pluck_t
				edge_fade = sin(((vib_end_t - t) / denom_right) * (PI * 0.5)) if denom_right > 0.0001 else 0.0
			var wave: float = sin(t * 20.0 + _vibration_time * vibration_frequency)
			local_point += normal * wave * edge_fade * vibration_amplitude * _vibration_strength
		new_points.append(local_point)
	points = new_points
