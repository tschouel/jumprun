extends Node2D
class_name PopEffect

## Kurzlebiger visueller Effekt für das Platzen einer Blase:
## ein expandierender, ausblassender Ring plus ein paar Tröpfchen.
## Zerstört sich nach life_time automatisch selbst.

@export var life_time: float = 0.35
@export var droplet_count: int = 8
@export var base_radius: float = 4.0
@export var spread_radius: float = 22.0
@export var effect_color: Color = Color(0.8, 0.92, 1.0)

var _elapsed: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for i in range(droplet_count):
		var a: float = (TAU / droplet_count) * i + randf_range(-0.2, 0.2)
		_angles.append(a)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= life_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clamp(_elapsed / life_time, 0.0, 1.0)
	var fade: float = 1.0 - progress

	# Expandierender Ring
	draw_arc(Vector2.ZERO, spread_radius * progress, 0.0, TAU, 24, Color(effect_color.r, effect_color.g, effect_color.b, fade * 0.6), 2.0, true)

	# Tröpfchen, die nach außen fliegen und verblassen
	for a in _angles:
		var dir := Vector2(cos(a), sin(a))
		var pos := dir * spread_radius * progress
		var r: float = base_radius * fade
		if r > 0.1:
			draw_circle(pos, r, Color(effect_color.r, effect_color.g, effect_color.b, fade))
