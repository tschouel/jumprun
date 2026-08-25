extends Area2D
class_name HarpString

## Eine einzelne Harfensaite. Der Pivot-Punkt (Node-Origin) sitzt oben am Hals,
## die Saite verläuft im lokalen Raum entlang der +Y-Achse nach unten.
## Harp.gd stellt Rotation + Länge ein, um den Fächer-Look zu erzeugen.
##
## Beim Pluck (ausgelöst z.B. durch eine platzende Blase) schwingt die Saite
## mit einer gedämpften Sinuskurve aus und wird dabei live neu gezeichnet.

@export var string_length: float = 200.0
@export var string_width: float = 4.0
@export var pluck_amplitude_max: float = 14.0
@export var pluck_frequency: float = 6.0 # Hz
@export var pluck_damping: float = 4.0
@export var string_color: Color = Color(0.85, 0.75, 0.5)

## Für später: hier kann ein Harfenton (AudioStream) hinterlegt werden.
## Ist pluck_sound gesetzt, wird er bei jedem pluck() automatisch abgespielt.
@export var pluck_sound: AudioStream = null
@export var note_name: String = "" # z.B. "C4" - rein informativ, für spätere Audio-Zuordnung

var _pluck_time: float = 0.0
var _pluck_offset: float = 0.0
var _is_plucking: bool = false
var _collision_shape: CollisionShape2D
var _audio_player: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("harp_strings")
	set_process(false)
	_ensure_collision_shape()
	_update_shape()


func _ensure_collision_shape() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.shape = RectangleShape2D.new()
		add_child(_collision_shape)


func set_length(l: float) -> void:
	string_length = l
	_update_shape()


func _update_shape() -> void:
	_ensure_collision_shape()
	var rect: RectangleShape2D = _collision_shape.shape
	rect.size = Vector2(string_width, string_length)
	_collision_shape.position = Vector2(0, string_length * 0.5)
	queue_redraw()


func pluck(_hit_position: Vector2 = Vector2.ZERO) -> void:
	_pluck_time = 0.0
	_is_plucking = true
	set_process(true)
	if pluck_sound:
		_play_sound()


func _play_sound() -> void:
	if _audio_player == null:
		_audio_player = AudioStreamPlayer2D.new()
		add_child(_audio_player)
	_audio_player.stream = pluck_sound
	_audio_player.pitch_scale = randf_range(0.98, 1.02)
	_audio_player.play()


func _process(delta: float) -> void:
	_pluck_time += delta
	var decay: float = exp(-pluck_damping * _pluck_time)
	_pluck_offset = pluck_amplitude_max * decay * cos(TAU * pluck_frequency * _pluck_time)
	queue_redraw()
	if decay < 0.01:
		_is_plucking = false
		_pluck_offset = 0.0
		set_process(false)
		queue_redraw()


func _draw() -> void:
	var segments := 24
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var envelope: float = sin(PI * t) # 0 an den Enden, 1 in der Mitte
		var bulge: float = _pluck_offset * envelope
		points.append(Vector2(bulge, string_length * t))
	draw_polyline(points, string_color, max(string_width * 0.4, 1.0), true)

	var anchor_color := string_color.darkened(0.3)
	draw_circle(Vector2.ZERO, string_width * 0.9, anchor_color)
	draw_circle(Vector2(0, string_length), string_width * 0.9, anchor_color)
