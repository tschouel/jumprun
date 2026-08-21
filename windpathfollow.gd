extends PathFollow2D

@export var speed: float = 600.0
@export var launch_velocity: float = 400.0

var is_moving: bool = false
var attached_player: CharacterBody2D = null
var _original_parent: Node = null


func _ready() -> void:
	# WICHTIG: PathFollow2D hat standardmäßig loop = true. Dann wird "progress"
	# beim Erreichen der Kurvenlänge automatisch umgebrochen (Modulo) statt
	# stehen zu bleiben - "progress_ratio" erreicht dadurch NIE zuverlässig
	# >= 1.0, weil er kurz vorher schon wieder Richtung 0 wrapped. Genau das
	# hat verhindert, dass _release_player() je ausgelöst wurde, und die Fahrt
	# lief endlos in einer Schleife weiter (inkl. sichtbarem Ruckler bei jedem
	# Wrap, weil die Rotation am Kurvenende abrupt auf den Kurvenanfang springt).
	loop = false

	# WICHTIG: "rotates" muss an sein, damit "self.rotation" zuverlässig die
	# glatte Kurententangente widerspiegelt. path_movement.gd (auf dem Player)
	# nutzt genau diesen Wert jetzt als Rotations-/Blickrichtungs-Quelle statt
	# einer aus Positions-Deltas rekonstruierten (und damit rauschanfälligen)
	# Richtung - das war die Ursache der hartnäckigen Ruckler.
	rotates = true


func _physics_process(delta: float) -> void:
	# WICHTIG: Muss im gleichen Takt laufen wie player.gd's _physics_process()
	# und wie die Physics Interpolation selbst (siehe Camera2D-Log-Meldung:
	# "overridden to physics process mode due to use of physics interpolation").
	# Vorher lief das hier in _process() (Render-Framerate, z.B. 144 FPS) - das
	# hat sich mit dem festen Physik-Tick (60 Hz), auf dem Player-Bewegung und
	# Interpolation basieren, überschnitten und genau die Mikroruckler erzeugt.
	if is_moving:
		progress += speed * delta
		if progress_ratio >= 1.0:
			print("[WindPath] progress_ratio erreicht 1.0 -> release. progress=", progress, " progress_ratio=", progress_ratio)
			_release_player()


func attach_player(player: CharacterBody2D) -> void:
	if attached_player:
		return
	var parent_path := get_parent() as Path2D
	var curve_length = parent_path.curve.get_baked_length() if parent_path and parent_path.curve else 0.0
	print("[WindPath] attach_player: ", player.name, " | Kurvenlänge: ", curve_length)
	attached_player = player
	_original_parent = player.get_parent()
	print("[WindPath] original_parent = ", _original_parent)
	call_deferred("_do_attach", player)


func _do_attach(player: CharacterBody2D) -> void:
	# 1. Reparenten - Position bleibt dank keep_global_transform (2. Argument) erhalten.
	player.reparent(self, true)

	# 2. ALLE Positions-/Zustandsänderungen fertig durchführen, BEVOR die
	#    Interpolation zurückgesetzt wird. Vorher lag der Reset VOR "progress = 0.0",
	#    wodurch der dadurch ausgelöste Sprung der PathFollow2D (und damit von Player
	#    und Kamera als Kinder) nicht mehr vom Reset erfasst wurde und stattdessen
	#    sichtbar über mehrere Frames interpoliert/"weggeglitten" ist.
	progress = 0.0
	player.is_on_path = true

	# 3. Jetzt, wo die finale Transform steht, Interpolation zurücksetzen.
	#    WICHTIG: reset_physics_interpolation() propagiert NICHT automatisch an
	#    Kind-Nodes. Deshalb hier explizit für PathFollow2D selbst, den Player
	#    UND die Kamera (Kind vom Player, eigene Interpolations-Historie) aufrufen.
	reset_physics_interpolation()
	player.reset_physics_interpolation()
	_reset_camera_interpolation(player)

	is_moving = true
	print("[WindPath] _do_attach fertig, is_on_path=", player.is_on_path, " global_position=", player.global_position)


func _release_player() -> void:
	if not attached_player:
		return
	is_moving = false
	var player = attached_player
	var exit_dir = Vector2.RIGHT.rotated(rotation)
	print("[WindPath] release: rotation=", rotation, " exit_dir=", exit_dir, " global_position VOR release=", player.global_position)
	call_deferred("_do_release", player, exit_dir)


func _do_release(player: CharacterBody2D, exit_dir: Vector2) -> void:
	player.reparent(_original_parent, true)
	player.is_on_path = false
	player.keep_upright = true
	player.global_rotation = 0.0
	player.velocity = exit_dir * launch_velocity

	# Auch hier: erst Position/Zustand final setzen, dann resetten - inkl. Kamera.
	player.reset_physics_interpolation()
	_reset_camera_interpolation(player)

	print("[WindPath] release fertig: neue global_position=", player.global_position, " velocity=", player.velocity)
	attached_player = null


func _reset_camera_interpolation(player: CharacterBody2D) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		cam = player.get_viewport().get_camera_2d()
	if cam:
		cam.reset_physics_interpolation()
