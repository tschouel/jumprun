extends Area2D
class_name Bubble

## Eine einzelne Seifenblase. Steigt sanft nach oben, wackelt seitlich (Sinus)
## und platzt, sobald sie eine Node in der Gruppe "harp_strings" berührt.

@export var radius: float = 10.0
@export var rise_speed: float = 60.0
@export var wobble_amplitude: float = 18.0
@export var wobble_frequency: float = 1.2 # Hz
@export var initial_direction: Vector2 = Vector2.UP
@export var bubble_color: Color = Color(0.75, 0.9, 1.0, 0.35)
@export var rim_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var lifetime: float = 8.0 # Sicherheitsnetz, falls nie eine Saite getroffen wird
@export var pop_effect_scene: PackedScene = preload("res://pop_effect.tscn")

var _age: float = 0.0
var _wobble_phase: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Fallback-Startposition, falls die Blase nicht über launch() gestartet wird
	# (z.B. wenn man sie manuell in einer Testszene platziert).
	_spawn_position = global_position
	_wobble_phase = randf() * TAU
	area_entered.connect(_on_area_entered)
	_ensure_collision_shape()
	queue_redraw()


func _ensure_collision_shape() -> void:
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	add_child(shape_node)


## Wird von BubbleMachine aufgerufen, NACHDEM die Blase per add_child() in den
## Baum gehängt wurde, damit global_position korrekt relativ zum Parent ist.
func launch(spawn_pos: Vector2) -> void:
	_spawn_position = spawn_pos
	_age = 0.0
	_wobble_phase = randf() * TAU
	global_position = spawn_pos


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return

	var dir: Vector2 = initial_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var travel: Vector2 = dir * rise_speed * _age
	var wobble: Vector2 = perp * wobble_amplitude * sin(_age * wobble_frequency * TAU + _wobble_phase)
	global_position = _spawn_position + travel + wobble
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, bubble_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, rim_color, 1.5, true)
	# kleiner Glanzpunkt für den "Seifenblasen"-Look
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.22, Color(1, 1, 1, 0.6))


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("harp_strings") and area.has_method("pluck"):
		area.pluck(global_position)
		_pop()


func _pop() -> void:
	if pop_effect_scene:
		var fx = pop_effect_scene.instantiate()
		var parent := get_parent()
		if parent:
			parent.add_child(fx)
			fx.global_position = global_position
	queue_free()
