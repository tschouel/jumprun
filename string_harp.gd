extends Node2D
class_name StringHarp
## Erzeugt automatisch mehrere StringRing-Instanzen nebeneinander, parallel
## zueinander, ohne dass man sie manuell in die Szene ziehen muss.
##
## start_point/end_point (zwei Marker2D-Kinder von StringHarp) definieren
## Position, Laenge UND Neigung der ERSTEN Saite. Jede weitere Saite (Index
## 1..count-1) wird exakt parallel dazu um spacing * Index verschoben -
## SENKRECHT zur Saitenrichtung. invert_direction dreht um, auf welche
## Seite hin aufgereiht wird (falls es "falschherum" spawnt).
##
## Setup: string_scene auf string_ring.tscn zeigen lassen. start_point/
## end_point auf zwei Marker2D-Kinder dieser StringHarp-Szene zeigen lassen.
## count = Gesamtzahl der Saiten, spacing = Abstand zwischen den Saiten.

@export var string_scene: PackedScene
@export var start_point: Node2D
@export var end_point: Node2D
@export var count: int = 32
@export var spacing: float = 40.0
## Dreht die Aufreih-Richtung um (falls die Saiten auf der falschen Seite
## der ersten Saite entstehen, z.B. links statt rechts).
@export var invert_direction: bool = false

func _ready() -> void:
	if not string_scene:
		push_warning("StringHarp: string_scene ist nicht gesetzt.")
		return
	if not start_point or not end_point:
		push_warning("StringHarp: start_point/end_point sind nicht gesetzt.")
		return

	var base_from: Vector2 = start_point.global_position
	var base_to: Vector2 = end_point.global_position
	var dir: Vector2 = base_to - base_from
	var normal: Vector2 = dir.orthogonal().normalized() if dir.length() > 0.0 else Vector2.DOWN
	if invert_direction:
		normal = -normal

	for i in range(count):
		var instance: Node2D = string_scene.instantiate()
		add_child(instance)
		var offset: Vector2 = normal * spacing * float(i)

		var inst_start: Node2D = instance.get_node_or_null("StartPoint")
		var inst_end: Node2D = instance.get_node_or_null("EndPoint")
		if inst_start:
			inst_start.global_position = base_from + offset
		if inst_end:
			inst_end.global_position = base_to + offset
