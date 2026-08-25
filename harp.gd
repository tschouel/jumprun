extends Node2D
class_name Harp

## Ordnet mehrere HarpString-Instanzen fächerförmig um einen gemeinsamen
## Pivot-Punkt (den "Hals" der Harfe, = Origin dieser Node) an, mit
## zunehmendem Winkel und zunehmender Länge - wie bei einer echten Harfe.

@export var harp_string_scene: PackedScene = preload("res://harp_string.tscn")
@export var string_count: int = 13
@export var angle_range: Vector2 = Vector2(-78, -12) # Grad, min/max Fächer-Winkel
@export var length_min: float = 140.0
@export var length_max: float = 320.0
@export var string_width: float = 4.0


func _ready() -> void:
	build_harp()


func build_harp() -> void:
	for i in range(string_count):
		var t: float = 0.0 if string_count <= 1 else float(i) / float(string_count - 1)
		var angle_deg: float = lerp(angle_range.x, angle_range.y, t)
		var length: float = lerp(length_min, length_max, t)

		var s = harp_string_scene.instantiate()
		add_child(s)
		s.rotation_degrees = angle_deg
		s.string_width = string_width
		s.set_length(length)
