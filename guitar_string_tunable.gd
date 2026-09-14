extends Line2D

## Gitarrensaite: liegt in Ruhe gerade (mit leichtem Durchhang bei
## niedriger Spannung, siehe SPANNUNG/DURCHHANG unten) zwischen start_point
## und end_point, wird an bis zu 4 waehlbaren Punkten (press_points)
## heruntergedrueckt, wenn der zugehoerige Hebel (gleicher Index) aktiv
## ist, und vibriert nach jedem pluck()-Aufruf mit abklingender Amplitude -
## wie eine echte angezupfte Saite.
##
## Es gibt zwei Zupf-"Pedale": das Standard-Pedal (pluck(false), von
## start_point bis zum aktiven Druckpunkt vibrierend) und ein zweites Pedal
## (pluck(true), von end_point bis zum aktiven Druckpunkt vibrierend) - der
## jeweils andere Teil der Saite liegt "tot" auf dem Bund, genau wie bei einer
## echten Gitarre, je nachdem von welcher Seite gerade gespielt wird.
##
## STIMMSCHLUESSEL / TONHOEHE:
## Zusaetzlich zur Bund-Mechanik kann die Saite ueber einen externen
## TensionTrigger.gd (Area2D beim Stimmschluessel) bis zu max_tension mal
## nachgespannt (request_tension_increase) oder wieder gelockert werden
## (request_tension_decrease) - fuer bis zu 4 (bzw. max_tension)
## verschiedene Tonhoehen. Die Spannung wirkt auf ZWEI Dinge: die Vibration
## (hoehere Spannung = hoehere Vibrationsfrequenz UND kleinere Amplitude,
## siehe SPANNUNG / TONHOEHE unten) UND den sichtbaren Durchhang (siehe
## SPANNUNG/DURCHHANG direkt darunter). Die Bund-Druck-Logik (press_points)
## und die Zupf-Mechanik (pluck) bleiben davon komplett unberuehrt. Die
## Saite kann NICHT reissen - keine Reissmechanik in diesem Skript.
##
## AN BEIDEN LIMITS GIBT ES OPTISCHES FEEDBACK (tuning_peg_max_animation):
## Sowohl beim Versuch, ueber max_tension hinaus anzuspannen
## (request_tension_increase), ALS AUCH beim Versuch, unter 0 zu lockern
## (request_tension_decrease), wird dieselbe "schon am Limit"-Animation
## abgespielt - reines optisches Feedback, die Spannung aendert sich dabei
## in beiden Faellen NICHT.
##
## SPANNUNG/DURCHHANG (neu):
## Bei Spannung 0 (Stufe 1) haengt die Saite leicht parabelfoermig durch
## (max_sag Pixel in der Mitte, siehe _sag_shape) - bei max_tension (Stufe
## 4) ist sie straff gerade (min_sag). Der Durchhang wird glatt animiert
## (_sag_tween, dieselbe Dauer wie tension_animation_duration) und ist ein
## rein additiver Offset ENTLANG DERSELBEN Normale wie die Press-Biegung
## und die Vibration - alle drei ueberlagern sich einfach, ohne sich
## gegenseitig zu stoeren.
##
## Setup: als Line2D-Node in die Szene, dieses Skript dran. start_point/
## end_point auf zwei Node2D (z.B. Marker2D an Sattel/Steg) setzen. Bei
## press_points bis zu 4 Marker2D reinziehen, an den Stellen platziert, wo
## deine 4 Hebel die Saite druecken sollen (Index = Hebel-Nummer). Bei
## pluck_point/pluck_point_alt je einen Marker2D dort platzieren, wo die
## beiden Pedale zupfen. TuningPeg (AnimatedSprite2D) als Kind dieses
## Line2D-Nodes anlegen, als Scene Unique Name markieren - zwei Animationen
## ohne Loop noetig: eine normale Dreh-Animation (tuning_peg_animation,
## z.B. "turn") und eine fuer den Fall, dass schon am Limit ist (egal ob
## oben oder unten) und man trotzdem weiter drehen will
## (tuning_peg_max_animation, muss EXAKT so im SpriteFrames heissen wie
## hier eingetragen, sonst bleibt _is_turning haengen und die Saite
## reagiert auf gar nichts mehr).
## Einen TensionTrigger-Node (eigenes Skript, siehe TensionTrigger.gd)
## irgendwo beim Stimmschluessel platzieren, "String Node" im Inspector auf
## diesen Line2D-Node zeigen lassen (oder automatische Erkennung nutzen -
## findet ihn ueber has_method("request_tension_increase")).

signal tension_changed(new_level: int)

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
## Basis-Amplitude bei Spannung 0 (siehe Spannungsgruppe unten fuer die
## tonhoehen-abhaengige Reduktion).
@export var vibration_amplitude: float = 10.0
## Wie SCHNELL die Vibration nach einem pluck() wieder abklingt (pro Sekunde).
## GROESSERER Wert = schneller WEG (kuerzer sichtbar), KLEINERER Wert = laenger
## sichtbar/haelt laenger an. Bei z.B. 15.0 ist die Vibration in ~0.07s komplett
## verschwunden - fuer laenger sichtbare Vibration eher 1.5 bis 3.0 probieren.
@export_range(0.1, 10.0, 0.1) var vibration_decay: float = 2.5
## Basis-Frequenz bei Spannung 0 (siehe Spannungsgruppe unten fuer die
## tonhoehen-abhaengige Erhoehung).
@export var vibration_frequency: float = 18.0

@export_group("Spannung / Tonhoehe")
@export var max_tension: int = 4
@export var start_tension: int = 0
## Wie lange die Dreh-Animation des Stimmschluessels dauert, bevor die neue
## Tonhoehe (Frequenz/Amplitude) tatsaechlich greift - UND wie lange die
## Durchhang-Animation dauert (siehe naechste Gruppe).
@export var tension_animation_duration: float = 0.5
## Faktor, um wie viel die Vibrationsfrequenz PRO Spannungsstufe steigt (0.5
## = +50% Frequenz pro Stufe, bei max_tension=4 also bis zu +200% - hoeherer
## Ton bei mehr Spannung).
@export var vibration_frequency_increase_per_tension: float = 0.5
## Faktor, um wie viel die Vibrationsamplitude PRO Spannungsstufe sinkt
## (0.15 = -15% Amplitude pro Stufe - straffere Saite schwingt mit weniger
## Ausschlag).
@export var vibration_amplitude_decrease_per_tension: float = 0.15
## Untere Grenze, wie stark die Amplitude durch obigen Faktor maximal
## schrumpfen darf (relativ zur Basis-Amplitude - 0.3 = nie unter 30%).
@export_range(0.0, 1.0, 0.01) var vibration_amplitude_min_factor: float = 0.3

@export_group("Durchhang (Spannung -> Optik)")
## Wie stark die Saite bei Spannung 0 (Stufe 1) in der Mitte durchhaengt
## (in Pixeln, senkrecht zur Saite).
@export var max_sag: float = 6.0
## Wie stark sie bei voller Spannung (max_tension, Stufe 4) noch minimal
## durchhaengt - 0.0 fuer eine komplett gerade, straffe Saite.
@export var min_sag: float = 0.0

@export_group("Stimmschluessel")
## Name der normalen Dreh-Animation (Loop AUS).
@export var tuning_peg_animation: String = "turn"
## Name der Animation, die abgespielt wird, wenn man versucht ueber
## max_tension hinaus anzuspannen ODER unter 0 zu lockern (Loop AUS). Rein
## optisches Feedback an BEIDEN Limits, es passiert danach nichts weiter
## (kein Reissen in diesem Skript, keine Tonhoehen-Aenderung).
@export var tuning_peg_max_animation: String = "stuck"

@export_group("Debug")
@export var debug_prints: bool = false

@onready var tuning_peg: AnimatedSprite2D = %TuningPeg

enum PendingAction { NONE, INCREASE, DECREASE, MAX_FEEDBACK }

var tension_level: int = 0
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _active_anim_name: String = ""

var _pressed_lever: int = -1
var _pressed_lever_alt: int = -1
var _press_amount: float = 0.0
var _vibration_time: float = 0.0
var _vibration_strength: float = 0.0
var _vibrate_from_end: bool = false

var _display_sag: float = 0.0
var _sag_tween: Tween

func _ready() -> void:
	# Ohne das hier zeichnet Line2D jede schraege Strecke treppig/pixelig -
	# das haengt NICHT von der Anzahl der Punkte/segments ab, sondern ist
	# reines Rendering. antialiased + runde Verbindungen beheben das.
	antialiased = true
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	if tuning_peg:
		tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)
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

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Anspann-Taste drueckt. Startet NUR die Dreh-Animation - die eigentliche
## Tonhoehen-/Durchhang-Aenderung passiert erst, wenn die Animation fertig
## durchgelaufen ist (siehe _on_tuning_peg_animation_finished). Ist bereits
## max_tension erreicht, spielt stattdessen tuning_peg_max_animation ab
## (reines Feedback, die Spannung aendert sich dabei NICHT). Gibt true
## zurueck, wenn tatsaechlich eine Animation gestartet wurde. Ohne
## zugewiesenen tuning_peg passiert nichts (gibt false zurueck).
func request_tension_increase() -> bool:
	if not tuning_peg:
		return false
	if _is_turning:
		return false
	_is_turning = true
	if tension_level >= max_tension:
		_pending_action = PendingAction.MAX_FEEDBACK
		_active_anim_name = tuning_peg_max_animation
		tuning_peg.play(tuning_peg_max_animation)
	else:
		_pending_action = PendingAction.INCREASE
		_active_anim_name = tuning_peg_animation
		tuning_peg.play(tuning_peg_animation)
	return true

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Lockern-Taste drueckt. Spielt die normale Dreh-Animation RUECKWAERTS ab
## (play_backwards() - speed_scale = -1.0 ist in Godot 4 unzuverlaessig).
## Bei Spannung 0 spielt stattdessen tuning_peg_max_animation ab (dasselbe
## "schon am Limit"-Feedback wie beim Ueberdrehen nach oben bei
## request_tension_increase) - reines optisches Feedback, die Spannung
## aendert sich dabei NICHT.
func request_tension_decrease() -> bool:
	if not tuning_peg:
		return false
	if _is_turning:
		return false
	_is_turning = true
	if tension_level <= 0:
		_pending_action = PendingAction.MAX_FEEDBACK
		_active_anim_name = tuning_peg_max_animation
		tuning_peg.play(tuning_peg_max_animation)
	else:
		_pending_action = PendingAction.DECREASE
		_active_anim_name = tuning_peg_animation
		tuning_peg.play_backwards(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	if tuning_peg.animation != _active_anim_name:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.INCREASE:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())
	elif action == PendingAction.DECREASE:
		tension_level = clampi(tension_level - 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())
	# MAX_FEEDBACK: keine Aenderung, war nur Optik.

func _target_sag() -> float:
	var t: float = float(tension_level) / float(max_tension)
	return lerp(max_sag, min_sag, t)

func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_display_sag(value: float) -> void:
	_display_sag = value
	_update_points()

## Kurvenform: parabelfoermiger Durchhang, 0 an beiden Enden, Maximum in der
## Mitte - identisch zum Prinzip aus MusicString.gd/StringWall.gd.
func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

## Effektive Vibrationsfrequenz fuer die aktuelle Spannungsstufe - steigt
## mit hoeherer Spannung (hoeherer Ton).
func _effective_vibration_frequency() -> float:
	return vibration_frequency * (1.0 + float(tension_level) * vibration_frequency_increase_per_tension)

## Effektive Vibrationsamplitude fuer die aktuelle Spannungsstufe - sinkt
## mit hoeherer Spannung (straffere Saite schwingt mit weniger Ausschlag).
func _effective_vibration_amplitude() -> float:
	var factor: float = max(1.0 - float(tension_level) * vibration_amplitude_decrease_per_tension, vibration_amplitude_min_factor)
	return vibration_amplitude * factor

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

	var effective_amplitude: float = _effective_vibration_amplitude()
	var effective_frequency: float = _effective_vibration_frequency()

	var new_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var base: Vector2 = from.lerp(to, t)
		var local_point: Vector2 = to_local(base)
		# Durchhang: parabelfoermiger, additiver Offset auf derselben
		# Normale wie Press-Biegung und Vibration - abhaengig von der
		# aktuellen Spannungsstufe (_display_sag, siehe _sag_shape).
		if _display_sag != 0.0:
			local_point += normal * _display_sag * _sag_shape(t)
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
		# Frequenz/Amplitude sind tonhoehen-abhaengig (siehe
		# _effective_vibration_frequency/_effective_vibration_amplitude oben).
		if t >= vib_start_t and t <= vib_end_t:
			var edge_fade: float
			if t <= pluck_t:
				var denom_left: float = pluck_t - vib_start_t
				edge_fade = sin(((t - vib_start_t) / denom_left) * (PI * 0.5)) if denom_left > 0.0001 else 1.0
			else:
				var denom_right: float = vib_end_t - pluck_t
				edge_fade = sin(((vib_end_t - t) / denom_right) * (PI * 0.5)) if denom_right > 0.0001 else 0.0
			var wave: float = sin(t * 20.0 + _vibration_time * effective_frequency)
			local_point += normal * wave * edge_fade * effective_amplitude * _vibration_strength
		new_points.append(local_point)
	points = new_points
