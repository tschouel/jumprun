extends Node2D
class_name BounceString
## Einfaches, elastisches Seil (wie eine gespannte Saite): der Spieler faellt
## hinein und wird nach oben katapultiert. Im Gegensatz zu MusicString OHNE
## Nachspannen (Taste E) und OHNE Reissen - Durchhang und Sprungstaerke sind
## einfach feste Werte, die ihr im Inspector einstellt.
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) im Editor auf die zwei
##    Befestigungspunkte der Saite ziehen (gleiche Hoehe oder leicht
##    unterschiedlich, beides geht).
## 2. StringLine (Line2D) irgendwo als Kind anlegen, als Scene Unique Name
##    markieren (%). Breite/Farbe/Textur im Line2D-Inspector wie gewuenscht
##    einstellen - der Code setzt nur die "points".
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

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var bounce_area: Area2D = %BounceArea
@onready var bounce_collision: CollisionPolygon2D = %BounceArea/CollisionPolygon2D
# Optional - siehe Setup-Punkt 4 oben. Bleiben null, falls nicht angelegt.
@onready var solid_block: StaticBody2D = get_node_or_null("%SolidBlock")
@onready var solid_block_collision: CollisionPolygon2D = get_node_or_null("%SolidBlock/CollisionPolygon2D")

func _ready() -> void:
	_rebuild_visual_and_collision()
	bounce_area.body_entered.connect(_on_bounce_area_body_entered)

## Kurvenform: parabelfoermiger Durchhang, 0 an beiden Enden, Maximum in der
## Mitte. (Optisch fast nicht von einer echten Kettenlinie/Catenary zu
## unterscheiden, aber viel einfacher zu berechnen.)
func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

func _curve_point(t: float) -> Vector2:
	var base: Vector2 = anchor_left.position.lerp(anchor_right.position, t)
	base.y += sag * _sag_shape(t)
	return base

func _rebuild_visual_and_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	var block_bottom_points: Array[Vector2] = []
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p: Vector2 = _curve_point(t)
		string_line.add_point(p)
		top_points.append(p + Vector2(0.0, -bounce_thickness))
		bottom_points.append(p + Vector2(0.0, bounce_thickness))
		if solid_block_collision:
			block_bottom_points.append(p + Vector2(0.0, solid_block_depth))

	var bounce_bottom: Array[Vector2] = bottom_points.duplicate()
	bounce_bottom.reverse()
	bounce_collision.polygon = PackedVector2Array(top_points + bounce_bottom)

	if solid_block_collision:
		# SolidBlock: gleiche Kurve als Oberkante (auf Hoehe der Bounce-Zone-
		# Unterkante), reicht aber viel weiter nach unten - das verhindert,
		# dass der Spieler jemals unter die durchhaengende Saite gelangen kann.
		var block_bottom_reversed: Array[Vector2] = block_bottom_points.duplicate()
		block_bottom_reversed.reverse()
		solid_block_collision.polygon = PackedVector2Array(bottom_points + block_bottom_reversed)

func _on_bounce_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	# Nur federn, wenn der Spieler tatsaechlich FAELLT (nicht wenn er von
	# unten reinspringt oder seitlich reinlaeuft) - sonst wuerde die Saite
	# auch bei jeder seitlichen Beruehrung katapultieren.
	if body.velocity.y > 0.0:
		body.velocity.y = -bounce_velocity
