extends Node2D
class_name StringWall
## Eine durchhaengende Saite, die als physische Wand funktioniert: solange
## sie intakt ist, blockiert sie den Weg (WallBlock). Ueber einen externen
## TensionTrigger.gd (Area2D beim Stimmschluessel) kann sie bis zu
## max_tension mal nachgespannt (request_tension_increase) UND wieder
## gelockert werden (request_tension_decrease). Ein weiterer
## Anspann-Versuch, obwohl schon voll gespannt, laesst sie reissen - danach
## wird ihre eigene Wand-Kollision UND (falls gesetzt) ein zusaetzlicher,
## im Inspector waehlbarer externer Collider deaktiviert, sodass der
## Spieler durchgehen kann. Kein Trampolin-Verhalten wie bei
## MusicString.gd - stattdessen ein leichter "Spick-Zurueck"-Bounce (Stufe
## 1, siehe naechster Absatz) MIT visueller Nachschwing-Vibration, solange
## die Saite intakt ist.
##
## LOCKERN (request_tension_decrease):
## Analog zu MusicString.gd: spielt tuning_peg_animation RUECKWAERTS ab
## (play_backwards() - speed_scale = -1.0 ist in Godot 4 unzuverlaessig).
## Bei Spannung 0 oder bereits gerissener Saite passiert nichts (gibt false
## zurueck). Reduziert NUR tension_level und den Durchhang - loest niemals
## das Reissen aus (das passiert ausschliesslich ueber
## request_tension_increase() bei bereits maximaler Spannung).
##
## ANKER-ORIENTIERUNG IST BELIEBIG (horizontal ODER vertikal):
## Durchhang, Bounce-Richtung UND Vibration liegen NICHT fest auf einer
## Achse, sondern folgen _local_normal(t) - der tatsaechlichen Normale an
## jedem einzelnen Kurvenpunkt (siehe naechster Absatz). Bei horizontal
## nebeneinander liegenden Ankern (Geigensaite) ergibt das "nach unten"
## (Standard-Verhalten). Bei vertikal gestapelten Ankern (Vorhang-artige
## Wand) ergibt es automatisch "seitlich". invert_sag_direction dreht das
## Vorzeichen um, falls die Saite zur "falschen" Seite ausbeult.
##
## KOLLISION/BOUNCE FOLGEN DER LOKALEN KURVENFORM:
## _local_normal(t) berechnet per finiter Differenz (Sample bei t-eps und
## t+eps) die tatsaechliche Tangente/Normale AN JEDEM Kurvenpunkt - sowohl
## _rebuild_collision (WallBlock/BounceArea) als auch die Bounce-Richtung
## und die Vibration nutzen diese lokale Normale, statt einer einzigen
## globalen Richtung. Die Kollisions-/Bounce-/Vibrations-Zone folgt dadurch
## sichtbar der tatsaechlichen Woelbung der Saite, bei jeder Durchhang-
## /Spannungsstufe.
##
## VIBRATION IST NUR VISUELL, NIEMALS PHYSISCH (wie bei MusicString.gd):
## _curve_point_global(t) liefert die STABILE Kurve (reiner Durchhang,
## KEINE Vibration) - "physische Wahrheit", genutzt fuer WallBlock,
## BounceArea und den Bounce-Check. _curve_visual_point_global(t) addiert
## zusaetzlich die abklingende Nachschwing-Vibration ENTLANG der lokalen
## Normale - NUR fuer die sichtbare Line2D. Kollisions-Polygone werden
## NICHT jeden Vibrations-Frame neu gebaut (nur bei _ready/Spannungs-
## aenderung, siehe _rebuild_collision vs. _rebuild_line_visual) - das
## verhindert die bei MusicString gefundenen Nebeneffekte (staendiges
## Neu-Backen der Collision Shapes durch wiederholtes Zuweisen von
## .polygon kann body_exited/entered-Signale spontan ausloesen). Die
## effektive Vibrationsamplitude wird zusaetzlich automatisch auf
## wall_thickness * vibration_max_amplitude_ratio gedeckelt, damit die
## Linie nie optisch durch die (unsichtbare, aber feste) WallBlock-
## Kollision schlaegt. Ausgeloest wird die Vibration bei jedem
## Stufe-1-Bounce-Treffer, zentriert um die Auftreffstelle entlang der
## Saite.
##
## BOUNCE STUFE 1 (leichtes Zurueckfedern beim Reinspringen):
## WallBlock ist ein StaticBody2D und stoppt den Spieler bereits hart -
## dadurch kann kein body_entered/Ueberlappung fuer einen Bounce entstehen
## (der Spieler kommt ja nie wirklich "rein"). Deshalb gibt es zusaetzlich
## BounceArea: eine duenne, nicht-blockierende Area2D-Pufferzone knapp
## AUSSERHALB der eigentlichen WallBlock-Kollision (wall_thickness +
## bounce_area_margin), ebenfalls entlang der lokalen Normale aufgebaut.
## Sobald ein CharacterBody2D dort eintritt (waehrend die Saite noch nicht
## gerissen ist), wird NUR die Geschwindigkeitskomponente ENTLANG der
## lokalen Normale auf wall_bounce_strength in die Richtung gesetzt, aus
## der der Koerper kam - die tangentiale Komponente (z.B. vertikale
## Bewegung bei einer seitlichen Wand) bleibt unangetastet. Nach dem
## Reissen wird BounceArea zusammen mit WallBlock deaktiviert.
##
## WICHTIG zu Positionen: die Kurve wird komplett in GLOBALEN Koordinaten
## berechnet und erst beim Zeichnen/Kollision-Setzen in das lokale
## Koordinatensystem des jeweiligen Ziel-Nodes umgerechnet (to_local) -
## dadurch spielt es keine Rolle, wo StringLine/WallBlock/BounceArea
## relativ zu StringWall im Baum positioniert sind (Rotation/Skalierung
## dieser Nodes muessen aber bei 0 bzw. 1,1 bleiben, sonst werden die
## umgerechneten Punkte verzerrt).
##
## COLLISION-BUILD-MODE = SEGMENTS (WICHTIG):
## wall_collision.polygon ist ein duennes, langgestrecktes Vieleck mit
## vielen (line_segments*2+2) fast-kollinearen Punkten. Godots
## Standard-build_mode "Solids" versucht sowas automatisch in konvexe
## Teilformen zu zerlegen - bei duennen, fast-geraden Vielecken schlaegt
## dieser Zerlegungs-Algorithmus bekanntermassen fehl ("Convex decomposing
## failed"). Fix: build_mode wird in _ready() per Code explizit auf
## BUILD_SEGMENTS gesetzt (fuer wall_collision UND bounce_collision).
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) auf die zwei Befestigungspunkte
##    ziehen. AnchorRight = Seite mit dem Stimmschluessel. Beliebige
##    Orientierung (horizontal oder vertikal zueinander) moeglich.
## 2. StringLine (Line2D) als Kind, als Scene Unique Name markieren.
## 3. TuningPeg (AnimatedSprite2D) als Kind, als Scene Unique Name
##    markieren. Animation (tuning_peg_animation) ohne Loop.
## 4. WallBlock (StaticBody2D) + CollisionPolygon2D als Kind, beide als
##    Scene Unique Name markieren - das ist die eigentliche Wand-Kollision,
##    die den Weg blockiert, solange die Saite haelt.
## 5. Einen TensionTrigger-Node (eigenes Skript, siehe TensionTrigger.gd)
##    irgendwo beim Stimmschluessel platzieren und "String Node" im
##    Inspector auf diesen StringWall-Node zeigen lassen (oder automatische
##    Erkennung nutzen). increase_key spannt an (und laesst bei
##    max_tension reissen), decrease_key lockert.
## 6. OPTIONAL, fuer die "Seil reisst"-Optik: StringLineRight (Line2D) als
##    Kind, als Scene Unique Name markieren, Visible im Editor AUS lassen.
##    Im Szenenbaum WICHTIG unterhalb von optisch deckenden Nodes (z.B.
##    einer grossflaechigen "Violin"-Deko) einordnen, sonst wird das
##    baumelnde Seil beim Reissen dahinter versteckt gezeichnet.
## 7. OPTIONAL: external_collider_to_disable im Inspector auf einen
##    beliebigen anderen CollisionShape2D/CollisionPolygon2D in der Szene
##    zeigen lassen - der wird beim Reissen ZUSAETZLICH deaktiviert.
## 8. BounceArea (Area2D) + CollisionPolygon2D als Kind, beide als Scene
##    Unique Name markieren - fuer den Stufe-1-Bounce inkl. Vibration.
##    Polygon-Punkte werden automatisch gesetzt.

signal tension_changed(new_level: int)
signal wall_broken

@export_group("Spannung")
@export var max_tension: int = 4
@export var start_tension: int = 0
@export var tension_animation_duration: float = 0.5

@export_group("Durchhang (Line2D-Kurve)")
@export var max_sag: float = 70.0
@export var min_sag: float = 8.0
@export var line_segments: int = 24
## "Dicke" der Wand-Kollision um die Kurve herum (entlang der lokalen
## Normale an jedem Kurvenpunkt, siehe _local_normal).
@export var wall_thickness: float = 24.0
## Dreht die Durchhang-/Bounce-/Vibrations-Richtung um. Rein optisch/
## Richtungs-Vorzeichen - keine Positionsaenderung der Anker noetig. Falls
## die Saite zur "falschen" Seite ausbeult, hier umschalten.
@export var invert_sag_direction: bool = false

@export_group("Bounce (Stufe 1)")
## Zusaetzlicher Abstand UEBER wall_thickness hinaus, in dem die
## BounceArea-Pufferzone liegt - so wird der Spieler schon abgefangen,
## BEVOR er hart gegen die feste WallBlock-Kollision laeuft.
@export var bounce_area_margin: float = 10.0
## Staerke des leichten Zurueckfederns, entlang der lokalen Normale.
@export var wall_bounce_strength: float = 250.0
## Zusaetzliche Toleranz ENTLANG der Anker-Linie (in Pixeln) ueber die
## Anker hinaus, in der ein Bounce noch erkannt wird.
@export var bounce_horizontal_margin: float = 32.0

@export_group("Vibration bei Bounce")
## Basis-Amplitude bei Spannung 0. Wird pro Spannungsstufe reduziert (siehe
## vibration_amplitude_decrease_per_tension) und zusaetzlich automatisch
## auf wall_thickness * vibration_max_amplitude_ratio gedeckelt - rein
## visuell, beliebig hoch waehlbar, ohne die Kollision je zu beeinflussen.
@export var vibration_amplitude: float = 14.0
## Basis-Frequenz bei Spannung 0. Wird pro Spannungsstufe erhoeht.
@export var vibration_frequency: float = 12.0
## Wie schnell die Vibration abklingt - hoeher = schneller ruhig.
@export var vibration_decay: float = 1.0
## Faktor, um wie viel die Frequenz PRO Spannungsstufe steigt.
@export var vibration_frequency_increase_per_tension: float = 0.5
## Faktor, um wie viel die Amplitude PRO Spannungsstufe sinkt.
@export var vibration_amplitude_decrease_per_tension: float = 0.15
## Untere Grenze, wie stark die Amplitude durch obigen Faktor maximal
## schrumpfen darf (relativ zur Basis-Amplitude).
@export_range(0.0, 1.0, 0.01) var vibration_amplitude_min_factor: float = 0.3
## SICHERHEITS-CLAMP (rein optisch): die effektive Vibrationsamplitude wird
## nie groesser als wall_thickness * dieser Faktor. Verhindert, dass die
## sichtbare Linie bei hoch gewaehlter vibration_amplitude optisch durch
## die (unsichtbare, aber feste) WallBlock-Kollision schlaegt.
@export_range(0.0, 1.0, 0.01) var vibration_max_amplitude_ratio: float = 0.85
## Mindestabstand (in t, 0..1) des Aufprallpunkts von den beiden Enden -
## verhindert eine "geknickte" Huellkurve bei Treffern ganz am Rand.
@export_range(0.01, 0.49, 0.01) var vibration_edge_margin: float = 0.05

@export_group("Stimmschluessel")
@export var tuning_peg_animation: String = "turn"

@export_group("Optik (Line2D)")
@export var smooth_line_rendering: bool = true

@export_group("Reissen")
## Optionaler externer Collider (z.B. eine Gap-CollisionShape2D/Polygon2D
## anderswo im Level), der beim Reissen ZUSAETZLICH zur eigenen
## WallBlock-Kollision deaktiviert wird. Muss eine "disabled"-Property
## besitzen (CollisionShape2D oder CollisionPolygon2D). Leer lassen, wenn
## nicht benoetigt.
@export var external_collider_to_disable: Node
@export var break_rope_segments: int = 14
@export var break_gravity: float = 1400.0
@export var break_damping: float = 0.985
## Staerke des Anfangsimpulses beim Reissen, entlang snap_dir (aktuell
## Vector2.DOWN) - sorgt fuer einen kurzen "Schnapp"-Ruck nach unten, bevor
## die reine Schwerkraft uebernimmt. Auf 0 setzen fuer einen Fall komplett
## ohne Anfangsimpuls.
@export var break_snap_strength: float = 60.0
@export var break_time_scale: float = 1.0

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var wall_block: StaticBody2D = %WallBlock
@onready var wall_collision: CollisionPolygon2D = %WallBlock/CollisionPolygon2D
@onready var bounce_area: Area2D = %BounceArea
@onready var bounce_collision: CollisionPolygon2D = %BounceArea/CollisionPolygon2D
@onready var tuning_peg: AnimatedSprite2D = %TuningPeg
@onready var string_line_right: Line2D = get_node_or_null("%StringLineRight")

enum PendingAction { NONE, INCREASE, DECREASE, BREAK }

var tension_level: int = 0
var is_broken: bool = false
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _display_sag: float = 0.0
var _sag_tween: Tween
var _vibration_time: float = -1.0  # -1 = keine Vibration aktiv
var _vibration_center_t: float = 0.5
var _rope_points: PackedVector2Array = PackedVector2Array()
var _rope_prev_points: PackedVector2Array = PackedVector2Array()
var _rope_segment_length: float = 0.0
var _rope_active: bool = false

func _ready() -> void:
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	if smooth_line_rendering:
		_style_line(string_line)
		_style_line(string_line_right)
	# Segments statt Solids: verhindert "Convex decomposing failed" bei
	# diesen duennen, vielpunktigen Polygonen (siehe Klassenkommentar oben).
	wall_collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	bounce_collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	_rebuild_collision()
	_rebuild_line_visual()
	tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)
	bounce_area.body_entered.connect(_on_bounce_area_body_entered)
	if string_line_right:
		string_line_right.visible = false

func _style_line(line: Line2D) -> void:
	if not line:
		return
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Anspann-Taste drueckt. Startet die Dreh-Animation. Ist bereits max_tension
## erreicht, reisst die Saite (nach Ende der Animation), statt weiter zu
## spannen. Gibt true zurueck, wenn tatsaechlich eine Animation gestartet
## wurde.
func request_tension_increase() -> bool:
	if is_broken:
		return false
	if _is_turning:
		return false
	_is_turning = true
	if tension_level >= max_tension:
		_pending_action = PendingAction.BREAK
	else:
		_pending_action = PendingAction.INCREASE
	tuning_peg.play(tuning_peg_animation)
	return true

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Lockern-Taste drueckt. Spielt tuning_peg_animation RUECKWAERTS ab
## (play_backwards() - speed_scale = -1.0 ist in Godot 4 unzuverlaessig).
## Bei Spannung 0 oder bereits gerissener Saite passiert nichts (gibt false
## zurueck). Loest NIEMALS das Reissen aus - das passiert ausschliesslich
## ueber request_tension_increase() bei bereits maximaler Spannung.
func request_tension_decrease() -> bool:
	if is_broken:
		return false
	if _is_turning:
		return false
	if tension_level <= 0:
		return false
	_is_turning = true
	_pending_action = PendingAction.DECREASE
	tuning_peg.play_backwards(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	if tuning_peg.animation != tuning_peg_animation:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.BREAK:
		_break_wall()
	elif action == PendingAction.INCREASE:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())
	elif action == PendingAction.DECREASE:
		tension_level = clampi(tension_level - 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())

func _target_sag() -> float:
	var t: float = float(tension_level) / float(max_tension)
	return lerp(max_sag, min_sag, t)

func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

## Einheitsvektor SENKRECHT zur GERADEN Linie AnchorLeft->AnchorRight -
## dient nur als Referenz-Vorzeichen (fuer invert_sag_direction und um die
## lokale Normale konsistent auszurichten), NICHT direkt als Versatz-
## Richtung fuer Kollision/Bounce/Vibration (siehe _local_normal).
func _perp_axis() -> Vector2:
	var dir: Vector2 = anchor_right.global_position - anchor_left.global_position
	if dir.length() <= 0.0001:
		return Vector2.DOWN
	var perp: Vector2 = dir.normalized().rotated(PI / 2.0)
	if invert_sag_direction:
		perp = -perp
	return perp

## STABILE (strukturell/physische) Kurve - reiner Durchhang, OHNE
## Vibration. Wird fuer WallBlock, BounceArea und den Bounce-Check
## verwendet. Aendert sich NUR, wenn sich _display_sag aendert
## (Spannungswechsel) - NICHT waehrend der Vibration.
func _curve_point_global(t: float) -> Vector2:
	var base: Vector2 = anchor_left.global_position.lerp(anchor_right.global_position, t)
	base += _perp_axis() * _display_sag * _sag_shape(t)
	return base

## Lokale Normale AN EINEM BESTIMMTEN Kurvenpunkt t (stabile Kurve, ohne
## Vibration), per finiter Differenz aus zwei nahen Kurvenpunkten (t-eps,
## t+eps) bestimmt - folgt damit der tatsaechlichen Woelbung der Saite an
## dieser Stelle. Das Vorzeichen wird an _perp_axis() ausgerichtet, damit
## "positive Richtung" ueberall konsistent dieselbe Seite meint.
func _local_normal(t: float) -> Vector2:
	var eps: float = 0.01
	var t0: float = clamp(t - eps, 0.0, 1.0)
	var t1: float = clamp(t + eps, 0.0, 1.0)
	if t0 == t1:
		return _perp_axis()
	var tangent: Vector2 = _curve_point_global(t1) - _curve_point_global(t0)
	if tangent.length() <= 0.0001:
		return _perp_axis()
	var normal: Vector2 = tangent.normalized().rotated(PI / 2.0)
	if normal.dot(_perp_axis()) < 0.0:
		normal = -normal
	return normal

## Huellkurve fuer die Vibration: 1.0 genau am Aufprallpunkt
## (_vibration_center_t), faellt zu BEIDEN Enden (t=0 und t=1) sanft auf 0 ab.
func _vibration_envelope(t: float) -> float:
	var center: float = _vibration_center_t
	if t <= center:
		var denom: float = center
		return sin((t / denom) * (PI * 0.5)) if denom > 0.0001 else 1.0
	else:
		var denom: float = 1.0 - center
		return sin(((1.0 - t) / denom) * (PI * 0.5)) if denom > 0.0001 else 0.0

func _effective_vibration_frequency() -> float:
	return vibration_frequency * (1.0 + float(tension_level) * vibration_frequency_increase_per_tension)

## Effektive Basis-Amplitude (vor Zeit-Abklingen), inkl. Spannungsreduktion
## UND dem Sicherheits-Clamp gegen wall_thickness.
func _effective_vibration_amplitude() -> float:
	var factor: float = max(1.0 - float(tension_level) * vibration_amplitude_decrease_per_tension, vibration_amplitude_min_factor)
	var raw_amplitude: float = vibration_amplitude * factor
	var visual_cap: float = wall_thickness * vibration_max_amplitude_ratio
	return min(raw_amplitude, visual_cap)

## Wie _curve_point_global(), aber zusaetzlich MIT der abklingenden
## Nachschwing-Vibration, ENTLANG der lokalen Normale an diesem Punkt,
## addiert. Ausschliesslich fuer die sichtbare Line2D gedacht - hat
## absichtlich keinerlei Einfluss auf Kollision oder Bounce-Erkennung.
func _curve_visual_point_global(t: float) -> Vector2:
	var base: Vector2 = _curve_point_global(t)
	if _vibration_time >= 0.0:
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		var freq: float = _effective_vibration_frequency()
		var offset: float = amp * _vibration_envelope(t) * sin(_vibration_time * freq * TAU)
		base += _local_normal(t) * offset
	return base

## Berechnet den Kurven-Anteil t (0..1 entlang AnchorLeft->AnchorRight) fuer
## eine gegebene globale Position, OHNE ihn auf 0..1 zu begrenzen. Wird fuer
## den Bounce-Check gebraucht (Grenzen-Pruefung ENTLANG der Anker-Linie -
## unabhaengig davon, ob diese horizontal, vertikal oder schraeg verlaeuft).
func _raw_t(global_pos: Vector2) -> float:
	var from: Vector2 = anchor_left.global_position
	var to: Vector2 = anchor_right.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return 0.5
	return (global_pos - from).dot(dir / length) / length

## Startet die abklingende Nachschwing-Vibration, zentriert um impact_t
## (0..1 entlang der Saite). Betrifft NUR die Line2D-Optik - keine
## Kollision wird dadurch neu gebaut.
func _start_vibration(impact_t: float = 0.5) -> void:
	_vibration_center_t = clamp(impact_t, vibration_edge_margin, 1.0 - vibration_edge_margin)
	_vibration_time = 0.0

## Waehrend der Vibration wird HIER NUR die sichtbare Line2D aktualisiert -
## bewusst NICHT die Kollisions-Polygone. Das verhindert, dass
## WallBlock/BounceArea waehrend der Vibration unnoetig staendig neu
## gebacken werden.
func _process(delta: float) -> void:
	if _rope_active:
		_step_rope_simulation(delta)
	if _vibration_time >= 0.0:
		_vibration_time += delta
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		if amp < 0.5:
			_vibration_time = -1.0
		_rebuild_line_visual()

func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Wird waehrend der Spann-/Lockerungs-Animation jeden Tween-Schritt
## aufgerufen - hier AENDERT sich die stabile Kurve wirklich, deshalb
## werden hier (und nur hier, bzw. beim initialen _ready) Line UND
## Kollision gemeinsam neu gebaut.
func _set_display_sag(value: float) -> void:
	_display_sag = value
	_rebuild_collision()
	_rebuild_line_visual()

## Baut NUR die sichtbare Line2D neu auf, mit der VISUELLEN (vibrierenden)
## Kurve. Wird jeden Frame waehrend der Vibration aufgerufen - beruehrt
## keinerlei Kollisions-Polygone.
func _rebuild_line_visual() -> void:
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_visual_global: Vector2 = _curve_visual_point_global(t)
		string_line.add_point(string_line.to_local(p_visual_global))

## Baut die Kollisions-Polygone (WallBlock + BounceArea-Erkennungszone)
## anhand der STABILEN (nicht-vibrierenden) Kurve neu, mit der "Dicke" PRO
## PUNKT entlang von _local_normal(t) versetzt - dadurch folgen Kollision
## und Bounce-Zone der tatsaechlichen Woelbung der Saite. Wird NUR
## aufgerufen, wenn sich die stabile Kurve tatsaechlich aendert (initial in
## _ready und bei Spannungsaenderung in _set_display_sag) - explizit NICHT
## jeden Vibrations-Frame.
func _rebuild_collision() -> void:
	var wall_top_points: Array[Vector2] = []
	var wall_bottom_points: Array[Vector2] = []
	var bounce_top_points: Array[Vector2] = []
	var bounce_bottom_points: Array[Vector2] = []
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_stable_global: Vector2 = _curve_point_global(t)
		var normal: Vector2 = _local_normal(t)
		wall_top_points.append(wall_collision.to_local(p_stable_global - normal * wall_thickness))
		wall_bottom_points.append(wall_collision.to_local(p_stable_global + normal * wall_thickness))
		var bounce_offset: float = wall_thickness + bounce_area_margin
		bounce_top_points.append(bounce_collision.to_local(p_stable_global - normal * bounce_offset))
		bounce_bottom_points.append(bounce_collision.to_local(p_stable_global + normal * bounce_offset))
	var wall_bottom_reversed: Array[Vector2] = wall_bottom_points.duplicate()
	wall_bottom_reversed.reverse()
	wall_collision.polygon = PackedVector2Array(wall_top_points + wall_bottom_reversed)
	var bounce_bottom_reversed: Array[Vector2] = bounce_bottom_points.duplicate()
	bounce_bottom_reversed.reverse()
	bounce_collision.polygon = PackedVector2Array(bounce_top_points + bounce_bottom_reversed)

## Stufe-1-Bounce: sobald ein CharacterBody2D die BounceArea-Pufferzone
## betritt (waehrend die Saite noch intakt ist), wird NUR die
## Geschwindigkeitskomponente ENTLANG der lokalen Normale an der
## getroffenen Kurvenstelle auf wall_bounce_strength in die Richtung
## gesetzt, aus der der Koerper kam - die tangentiale Komponente bleibt
## unangetastet. Loest zusaetzlich die rein visuelle Nachschwing-Vibration
## aus, zentriert um die Auftreffstelle.
func _on_bounce_area_body_entered(body: Node2D) -> void:
	if is_broken:
		return
	if not (body is CharacterBody2D):
		return

	var raw_t: float = _raw_t(body.global_position)
	var anchor_length: float = (anchor_right.global_position - anchor_left.global_position).length()
	var margin_t: float = (bounce_horizontal_margin / anchor_length) if anchor_length > 0.0 else 0.0
	if raw_t < -margin_t or raw_t > 1.0 + margin_t:
		return  # Ausserhalb der Anker-Linie - kein Bounce.

	var t: float = clamp(raw_t, 0.0, 1.0)
	var curve_pos: Vector2 = _curve_point_global(t)
	var normal: Vector2 = _local_normal(t)
	var signed_dist: float = (body.global_position - curve_pos).dot(normal)
	var push_sign: float = 1.0 if signed_dist >= 0.0 else -1.0

	# Nur die Normalen-Komponente der Geschwindigkeit ersetzen, tangentiale
	# Komponente (entlang der Kurve/Anker-Linie) unveraendert lassen.
	var current_normal_component: Vector2 = normal * body.velocity.dot(normal)
	body.velocity -= current_normal_component
	body.velocity += normal * push_sign * wall_bounce_strength

	_start_vibration(t)

## Deaktiviert die eigene Wand-Kollision, die Bounce-Pufferzone sowie
## (falls gesetzt) den externen Collider, spielt danach die "Seil
## reisst"-Optik ab.
func _break_wall() -> void:
	if is_broken:
		return
	is_broken = true
	wall_collision.set_deferred("disabled", true)
	bounce_collision.set_deferred("disabled", true)
	if external_collider_to_disable:
		external_collider_to_disable.set_deferred("disabled", true)
	wall_broken.emit()

	string_line.visible = false
	if string_line_right:
		string_line_right.visible = true
		_start_rope_simulation()

## Startet die Verlet-Seilsimulation ab der aktuellen (durchhaengenden)
## Kurvenform. AnchorRight bleibt waehrend der gesamten Simulation fixiert
## (siehe _step_rope_simulation) - das lose Ende faellt/schwingt frei.
func _start_rope_simulation() -> void:
	var point_count: int = break_rope_segments + 1
	var last: int = break_rope_segments
	_rope_points = PackedVector2Array()
	_rope_prev_points = PackedVector2Array()
	_rope_points.resize(point_count)
	_rope_prev_points.resize(point_count)

	for i in range(point_count):
		var t: float = float(i) / float(break_rope_segments)
		_rope_points[i] = _curve_point_global(t)

	var total_length: float = 0.0
	for i in range(last):
		total_length += _rope_points[i].distance_to(_rope_points[i + 1])
	_rope_segment_length = total_length / float(last)

	# Der Anfangs-Kick beim Reissen zeigt bewusst rein nach UNTEN (echte
	# Schwerkraft-Richtung, unabhaengig von der Anker-Orientierung). Die
	# Staerke skaliert weiterhin zur Spitze hin (t_from_tip), damit das
	# freie Ende staerker "schnappt" als der fixierte AnchorRight-Bereich.
	var snap_dir: Vector2 = Vector2.DOWN
	for i in range(point_count):
		var t_from_tip: float = 1.0 - float(i) / float(last)
		var kick: Vector2 = snap_dir * break_snap_strength * t_from_tip
		_rope_prev_points[i] = _rope_points[i] - kick

	_rope_active = true
	_apply_rope_constraints()
	_write_rope_points_to_line()

func _step_rope_simulation(delta: float) -> void:
	var sim_delta: float = delta * break_time_scale
	var last: int = _rope_points.size() - 1
	var max_speed: float = 0.0
	for i in range(_rope_points.size()):
		if i == last:
			_rope_points[i] = anchor_right.global_position
			_rope_prev_points[i] = anchor_right.global_position
			continue
		var current: Vector2 = _rope_points[i]
		var velocity: Vector2 = (current - _rope_prev_points[i]) * break_damping
		var next: Vector2 = current + velocity + Vector2(0.0, break_gravity) * sim_delta * sim_delta
		_rope_prev_points[i] = current
		_rope_points[i] = next
		max_speed = max(max_speed, velocity.length())

	_apply_rope_constraints()
	_write_rope_points_to_line()

	if max_speed < 0.3:
		_rope_active = false

func _write_rope_points_to_line() -> void:
	var local_points: PackedVector2Array = PackedVector2Array()
	local_points.resize(_rope_points.size())
	for i in range(_rope_points.size()):
		local_points[i] = string_line_right.to_local(_rope_points[i])
	string_line_right.points = local_points

func _apply_rope_constraints() -> void:
	var last: int = _rope_points.size() - 1
	for _iteration in range(8):
		for i in range(last):
			var p1: Vector2 = _rope_points[i]
			var p2: Vector2 = _rope_points[i + 1]
			var delta_vec: Vector2 = p2 - p1
			var dist: float = delta_vec.length()
			if dist < 0.0001:
				continue
			var diff: float = (dist - _rope_segment_length) / dist
			var correction: Vector2 = delta_vec * 0.5 * diff
			p1 += correction
			if i + 1 != last:
				p2 -= correction
			_rope_points[i] = p1
			_rope_points[i + 1] = p2
