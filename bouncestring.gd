extends Node2D
class_name BounceString
## Einfaches, elastisches Seil (wie eine gespannte Saite): der Spieler faellt
## hinein und wird abgefedert - RICHTUNG des Abfederns haengt von der
## NEIGUNG der Saite ab (wie ein echtes Trampolin): bei einer horizontalen
## Saite fliegt der Spieler gerade nach oben, bei einer geneigten Saite wird
## er senkrecht zur Saitenflaeche (entlang der Flaechennormale) weggeschleudert
## - bei 45 Grad also spuerbar seitlich, nicht einfach nur hoch. Im Gegensatz
## zu MusicString OHNE Nachspannen (Taste E) und OHNE Reissen - Durchhang und
## Sprungstaerke sind einfach feste Werte, die ihr im Inspector einstellt.
##
## Nach jedem Bounce vibriert die Saite sichtbar nach (abklingende
## Nachschwing-Animation), zentriert um den tatsaechlichen Aufprallpunkt
## (Spielerposition auf die Saite projiziert) und zu beiden Enden hin
## abklingend - identisches Prinzip wie in MusicString.gd, hier aber mit
## fixer Amplitude/Frequenz statt spannungsabhaengiger Skalierung, da
## BounceString keine Spannungsstufen kennt.
##
## Optisch und technisch bewusst analog zu MusicString.gd aufgebaut: gleiche
## globale Koordinatenberechnung (unabhaengig von der Position der Kind-Nodes
## im Baum) und gleiches Antialiasing/runde Line2D-Enden (_style_line), damit
## beide Saitentypen im Spiel einheitlich aussehen. Ebenfalls mit dem
## gleichen Mehrfach-Bounce-Fix wie MusicString.gd.
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) im Editor auf die zwei
##    Befestigungspunkte der Saite ziehen. Die NEIGUNG dieser beiden Punkte
##    zueinander bestimmt jetzt die Abfeder-Richtung (siehe oben).
## 2. StringLine (Line2D) irgendwo als Kind anlegen, als Scene Unique Name
##    markieren (%). Breite/Farbe/Textur im Line2D-Inspector wie gewuenscht
##    einstellen - der Code setzt nur die "points" (und ein paar rein
##    optische Zeicheneigenschaften, siehe _style_line unten).
## 3. BounceArea (Area2D) als Kind anlegen, CollisionPolygon2D als dessen
##    Kind, beide als Scene Unique Name markieren. Die Polygon-Punkte werden
##    automatisch vom Skript gesetzt, im Editor braucht ihr da nichts
##    einzuzeichnen.
## 4. OPTIONAL, gegen Durchfallen: SolidBlock (StaticBody2D) als Kind
##    anlegen, CollisionPolygon2D als dessen Kind, beide als Scene Unique
##    Name markieren. Das ist die feste Sperre UNTER der Bounce-Zone, die
##    verhindert, dass der Spieler jemals unter die durchhaengende Saite
##    gelangt. Ohne diesen Node funktioniert die Saite trotzdem, nur kann
##    der Spieler dann bei starkem Durchhang eventuell seitlich darunter
##    hindurchlaufen.

@export_group("Durchhang (Line2D-Kurve)")
## Wie stark die Saite durchhaengt (in Pixeln). Kleiner = straffer gespannt.
@export var sag: float = 40.0
## Aufloesung der Kurve - mehr Punkte = glatter, aber etwas teurer.
@export var line_segments: int = 24
## "Dicke" der Bounce-Zone um die Kurve herum (Kollisions-Toleranz).
@export var bounce_thickness: float = 24.0
## Wie weit der feste Sperr-Block (falls angelegt) UNTER der Bounce-Zone
## nach unten reicht - muss nur gross genug sein, dass der Spieler ihn nie
## "von unten umgehen" kann.
@export var solid_block_depth: float = 1200.0

@export_group("Federkraft")
## Sprungkraft, mit der der Spieler abgefedert wird, wenn er in die Saite
## faellt.
@export var bounce_velocity: float = 700.0
## Wenn AN: die Abfeder-RICHTUNG folgt der Neigung der Saite (senkrecht zur
## Flaeche, wie ein echtes Trampolin - bei 45 Grad wird seitlich
## abgefedert). Wenn AUS: klassisches Verhalten, immer gerade nach oben,
## unabhaengig von der Neigung (altes Verhalten).
@export var use_surface_angle: bool = true
## Nur relevant, wenn use_surface_angle AN ist: mischt zwischen reiner
## Aufwaerts-Richtung (0.0) und voller Flaechennormale (1.0). Bei 1.0 wird
## bei einer stark geneigten Saite entsprechend stark seitlich geschleudert;
## kleinere Werte daempfen den seitlichen Anteil, falls euch die volle
## Neigung zu extrem ist.
@export_range(0.0, 1.0, 0.05) var angle_influence: float = 1.0

@export_group("Vibration bei Bounce")
## Wie stark die Saite direkt nach dem Abfedern sichtbar nachschwingt.
@export var vibration_amplitude: float = 18.0
## Schwingungen pro Sekunde.
@export var vibration_frequency: float = 12.0
## Wie schnell die Vibration abklingt - hoeher = schneller ruhig.
@export var vibration_decay: float = 2.0
## Mindestabstand (in t, 0..1) des Aufprallpunkts von den beiden Enden -
## verhindert eine "geknickte" Huellkurve, falls der Spieler ganz am Rand
## der Saite aufkommt.
@export_range(0.01, 0.49, 0.01) var vibration_edge_margin: float = 0.05

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var bounce_area: Area2D = %BounceArea
@onready var bounce_collision: CollisionPolygon2D = %BounceArea/CollisionPolygon2D
# Optional - siehe Setup-Punkt 4 oben. Bleiben null, falls nicht angelegt.
@onready var solid_block: StaticBody2D = get_node_or_null("%SolidBlock")
@onready var solid_block_collision: CollisionPolygon2D = get_node_or_null("%SolidBlock/CollisionPolygon2D")

@export_group("Optik (Line2D)")
## Schaltet Antialiasing sowie runde Gelenke/Enden fuer StringLine ein -
## behebt das treppige/pixelige Aussehen bei schraegen Linien, rein optisch,
## kein Einfluss auf Physik/Kollision/Verhalten.
@export var smooth_line_rendering: bool = true

## body -> true, solange dieser Koerper gerade "bounce-bereit" ist - gleicher
## Mehrfach-Bounce-Schutz wie in MusicString.gd.
var _bodies_falling_ready: Dictionary = {}
var _vibration_time: float = -1.0  # -1 = keine Vibration aktiv
var _vibration_center_t: float = 0.5

func _ready() -> void:
	if smooth_line_rendering:
		_style_line(string_line)
	_rebuild_visual_and_collision()
	bounce_area.body_entered.connect(_on_bounce_area_body_entered)
	bounce_area.body_exited.connect(_on_bounce_area_body_exited)

## Rein optische Zeicheneinstellungen fuer ein Line2D: Antialiasing an,
## runde Gelenke/Enden statt eckiger. Behebt das treppige Aussehen bei
## schraegen Linien, hat keinerlei Einfluss auf Physik/Kollision/Verhalten.
func _style_line(line: Line2D) -> void:
	if not line:
		return
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

## Kurvenform: parabelfoermiger Durchhang, 0 an beiden Enden, Maximum in der
## Mitte. (Optisch fast nicht von einer echten Kettenlinie/Catenary zu
## unterscheiden, aber viel einfacher zu berechnen.)
func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

## Huellkurve fuer die Vibration: 1.0 genau am Aufprallpunkt
## (_vibration_center_t), faellt zu BEIDEN Enden (t=0 und t=1) sanft auf 0 ab
## - identisches Prinzip wie in MusicString.gd.
func _vibration_envelope(t: float) -> float:
	var center: float = _vibration_center_t
	if t <= center:
		var denom: float = center
		return sin((t / denom) * (PI * 0.5)) if denom > 0.0001 else 1.0
	else:
		var denom: float = 1.0 - center
		return sin(((1.0 - t) / denom) * (PI * 0.5)) if denom > 0.0001 else 0.0

## Punkt auf der Kurve in GLOBALEN Koordinaten (Weltposition), inklusive
## Durchhang UND (falls gerade aktiv) der abklingenden Nachschwing-Vibration.
func _curve_point_global(t: float) -> Vector2:
	var base: Vector2 = anchor_left.global_position.lerp(anchor_right.global_position, t)
	base.y += sag * _sag_shape(t)
	if _vibration_time >= 0.0:
		var amp: float = vibration_amplitude * exp(-vibration_decay * _vibration_time)
		base.y += amp * _vibration_envelope(t) * sin(_vibration_time * vibration_frequency * TAU)
	return base

## Projiziert eine globale Position auf die Saitenlinie (AnchorLeft ->
## AnchorRight) und gibt den Anteil t (0..1) zurueck, wo sie am naechsten liegt.
func _project_impact_t(global_pos: Vector2) -> float:
	var from: Vector2 = anchor_left.global_position
	var to: Vector2 = anchor_right.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return 0.5
	var t: float = (global_pos - from).dot(dir / length) / length
	return clamp(t, vibration_edge_margin, 1.0 - vibration_edge_margin)

## Startet die abklingende Nachschwing-Vibration, zentriert um impact_t
## (0..1 entlang der Saite).
func _start_vibration(impact_t: float = 0.5) -> void:
	_vibration_center_t = clamp(impact_t, vibration_edge_margin, 1.0 - vibration_edge_margin)
	_vibration_time = 0.0

func _process(delta: float) -> void:
	if _vibration_time >= 0.0:
		_vibration_time += delta
		var amp: float = vibration_amplitude * exp(-vibration_decay * _vibration_time)
		if amp < 0.5:
			_vibration_time = -1.0
		_rebuild_visual_and_collision()

## Berechnet die Flaechennormale der Saite (senkrecht zur Verbindungslinie
## AnchorLeft->AnchorRight), IMMER nach oben orientiert (negative Y-Haelfte)
## - bei einer horizontalen Saite also (0,-1) (gerade hoch), bei einer 45
## Grad geneigten Saite entsprechend schraeg. angle_influence mischt das mit
## der reinen Aufwaerts-Richtung, falls der volle Effekt zu stark ist.
func _get_bounce_direction() -> Vector2:
	var straight_up: Vector2 = Vector2.UP
	if not use_surface_angle:
		return straight_up
	var along: Vector2 = (anchor_right.global_position - anchor_left.global_position)
	if along.length() < 0.001:
		return straight_up
	along = along.normalized()
	var normal: Vector2 = Vector2(-along.y, along.x)  # 90 Grad gedreht
	if normal.y > 0.0:
		normal = -normal  # sicherstellen, dass die Normale nach OBEN zeigt
	var blended: Vector2 = straight_up.lerp(normal, angle_influence)
	if blended.length() < 0.001:
		return straight_up
	return blended.normalized()

## Berechnet die Kurve einmal in globalen Koordinaten und rechnet sie dann
## fuer JEDEN Ziel-Node einzeln in dessen lokales Koordinatensystem um
## (to_local) - dadurch ist es egal, ob StringLine/BounceArea/SolidBlock bei
## (0,0) relativ zu diesem Node sitzen oder irgendwo anders.
func _rebuild_visual_and_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_global: Vector2 = _curve_point_global(t)
		string_line.add_point(string_line.to_local(p_global))
		top_points.append(bounce_collision.to_local(p_global + Vector2(0.0, -bounce_thickness)))
		bottom_points.append(bounce_collision.to_local(p_global + Vector2(0.0, bounce_thickness)))
	var bounce_bottom: Array[Vector2] = bottom_points.duplicate()
	bounce_bottom.reverse()
	bounce_collision.polygon = PackedVector2Array(top_points + bounce_bottom)

	if solid_block_collision:
		# SolidBlock: gleiche Kurve als Oberkante (auf Hoehe der Bounce-Zone-
		# Unterkante), reicht aber viel weiter nach unten - das verhindert,
		# dass der Spieler jemals unter die durchhaengende Saite gelangen kann.
		var block_top_points: Array[Vector2] = []
		var block_bottom_points: Array[Vector2] = []
		for i in range(line_segments + 1):
			var t: float = float(i) / float(line_segments)
			var p_global: Vector2 = _curve_point_global(t)
			block_top_points.append(solid_block_collision.to_local(p_global + Vector2(0.0, bounce_thickness)))
			block_bottom_points.append(solid_block_collision.to_local(p_global + Vector2(0.0, solid_block_depth)))
		block_bottom_points.reverse()
		solid_block_collision.polygon = PackedVector2Array(block_top_points + block_bottom_points)

## Erstmaliges Betreten der BounceArea - markiert den Koerper sofort als
## bounce-bereit und versucht direkt einen Bounce.
func _on_bounce_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_bodies_falling_ready[body] = true
	_try_bounce(body)

## Aufraeumen, sobald ein Koerper die Area tatsaechlich komplett verlaesst.
func _on_bounce_area_body_exited(body: Node2D) -> void:
	_bodies_falling_ready.erase(body)

func _physics_process(_delta: float) -> void:
	for body in bounce_area.get_overlapping_bodies():
		if not (body is CharacterBody2D):
			continue
		if body.velocity.y < 0.0:
			_bodies_falling_ready[body] = true
		_try_bounce(body)

## Zentrale Bounce-Logik: bouncet nur, wenn der Koerper tatsaechlich FAELLT
## (velocity.y > 0) UND gerade als bounce-bereit markiert ist. Die
## Abfeder-RICHTUNG kommt aus _get_bounce_direction() statt immer stur nach
## oben zu zeigen - bei geneigten Saiten wird also seitlich abgefedert, wie
## bei einem echten Trampolin. Zusaetzlich wird die Nachschwing-Vibration
## am tatsaechlichen Aufprallpunkt gestartet.
func _try_bounce(body: CharacterBody2D) -> void:
	if not _bodies_falling_ready.get(body, false):
		return
	if body.velocity.y > 0.0:
		body.velocity = _get_bounce_direction() * bounce_velocity
		_start_vibration(_project_impact_t(body.global_position))
		_bodies_falling_ready[body] = false
