class_name BassSlideZone
extends Area2D
## Analog zu SlidingZone.gd, aber für den Kontrabass-Abschnitt:
## - Aktivierung NICHT automatisch bei body_entered, sondern per Taste F,
##   solange sich der Spieler innerhalb dieser Area2D befindet.
## - 5 parallele Saiten-Pfade (statt nur einem) - die dem Spieler beim
##   Betreten am nächsten liegende Saite wird automatisch gewählt.
## - Verwaltet den Checkpoint-Respawn nach einem Hindernis-Treffer (Fade to
##   Black, Teleport zu respawn_point, Fade zurück).

@export_group("Saiten (Pfade)")
## Alle 5 parallelen Saiten-Pfade (PathFollow2D-Kinder der jeweiligen
## Path2D-Nodes), z.B. von der tiefsten bis zur höchsten Saite.
@export var path_follows: Array[PathFollow2D] = []

@export_group("Checkpoint & Respawn")
## Position VOR dem ersten Hindernis-Collider und der F-Abfrage-Zone -
## hierhin wird der Spieler nach einem Hindernis-Treffer zurückgesetzt.
@export var respawn_point: Node2D
## ScreenFade-Instanz (CanvasLayer) in der Szene, die für den
## Checkpoint-Respawn verwendet wird. Leer lassen = kein Fade, nur eine
## Wartezeit in gleicher Länge.
@export var screen_fade: ScreenFade
@export var fade_out_duration: float = 1.5
@export var fade_in_duration: float = 0.5

@export_group("Zone-eigenes Tempo")
## Optional: Zone-eigenes Tempo (bpm/units_per_bar), leer lassen für
## "Player-Standard behalten".
@export var override_bpm: float = 0.0
@export var override_units_per_bar: float = 0.0

@export_group("Kamera-Gefühl (Geschwindigkeit)")
## Ziel-Zoom waehrend des Bass-Slidens (ueber GroundMovement.
## set_camera_zoom_override). Werte > 1.0 zoomen raus (mehr Spielfeld
## sichtbar, wirkt oft schneller), Werte < 1.0 zoomen rein.
@export var camera_zoom_target: Vector2 = Vector2(1.15, 1.15)
## Zusaetzlicher Kamera-Offset waehrend des Slidens (z.B. leicht nach unten,
## damit man mehr von dem sieht, worauf man zurutscht).
@export var camera_offset_target: Vector2 = Vector2(0.0, 60.0)
## Dauer der Kamera-Ein-/Ausblendung (Tween) beim Betreten/Verlassen.
@export var camera_transition_duration: float = 0.4

@export_group("F-Prompt Anzeige")
## Optional: AnimatedSprite2D, das einen blinkenden "F"-Hinweis zeigt,
## solange der Spieler in der Zone steht und noch nicht rutscht. Wird
## automatisch gestoppt, sobald F erfolgreich gedrueckt wurde, und wieder
## gestartet, sobald der Spieler die Saite wieder verlaesst (normal ODER
## per Checkpoint-Respawn) und erneut F druecken muss. Leer lassen = kein
## Effekt.
@export var f_prompt_sprite: AnimatedSprite2D
## Zusaetzlich zum Stoppen des Loops auch komplett ausblenden, solange
## gerutscht wird.
@export var hide_f_prompt_while_sliding: bool = true

var _previous_parent: Node = null
var _player_in_zone: bool = false
var _current_player: CharacterBody2D = null
var _previous_player_z_index: int = 0
## Z-Index, den der Spieler waehrend des Bass-Slidens bekommt - stellt
## sicher, dass er IMMER ueber visuellen Elementen wie der Kontrabass-
## Silhouette ("Boden") gezeichnet wird, unabhaengig davon, auf welcher
## der 5 Saiten er sich befindet und wo diese im Szenenbaum liegen.
@export var slide_z_index: int = 10


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if f_prompt_sprite:
		f_prompt_sprite.visible = true
		f_prompt_sprite.play()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_zone = true
	_current_player = body as CharacterBody2D


func _on_body_exited(body: Node2D) -> void:
	if body != _current_player:
		return
	_player_in_zone = false
	_current_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone or not _current_player:
		return
	if _current_player.is_on_path:
		return
	if event is InputEventKey and event.physical_keycode == KEY_F and event.pressed and not event.is_echo():
		_attach_to_path(_current_player)


func _attach_to_path(player: CharacterBody2D) -> void:
	if player.is_on_path:
		return
	if path_follows.is_empty():
		push_error("BassSlideZone: path_follows ist leer! Bitte im Inspector die 5 Saiten-Pfade zuweisen.")
		return

	# Naechstgelegene Saite zur aktuellen Position des Spielers waehlen -
	# so landet er beim Druecken von F immer auf der Saite, vor der er
	# gerade steht, statt immer auf einer festen Standard-Saite.
	var best_index: int = 0
	var best_dist: float = INF
	for i in range(path_follows.size()):
		var pf := path_follows[i]
		var path2d := pf.get_parent() as Path2D
		if not path2d or not path2d.curve:
			continue
		var local_pos: Vector2 = path2d.to_local(player.global_position)
		var offset: float = path2d.curve.get_closest_offset(local_pos)
		var closest_point: Vector2 = path2d.curve.sample_baked(offset)
		var dist: float = path2d.to_global(closest_point).distance_squared_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	var path_follow := path_follows[best_index]
	var path2d := path_follow.get_parent() as Path2D
	var entry_progress: float = 0.0
	if path2d and path2d.curve:
		var local_pos: Vector2 = path2d.to_local(player.global_position)
		entry_progress = path2d.curve.get_closest_offset(local_pos)

	_previous_parent = player.get_parent()
	_previous_parent.remove_child(player)
	path_follow.add_child(player)
	path_follow.progress = entry_progress

	player.position = Vector2.ZERO
	player.rotation = 0.0

	if override_bpm > 0.0 and override_units_per_bar > 0.0:
		player.set_zone_tempo(override_bpm, override_units_per_bar)

	player.set_meta("sliding_zone", self)
	player.is_on_path = true
	player.is_bass_slide_active = true
	player.reset_physics_interpolation()

	_previous_player_z_index = player.z_index
	player.z_index = slide_z_index

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_physics_interpolation()

	# PathBassMovement über die 5 Saiten, die Start-Saite und diese Zone
	# (für spätere Lane-Wechsel & Obstacle-Respawn) informieren. Bewusst
	# "path_bass_movement_module" statt "path_movement_module", damit das
	# unabhängige, alte PathMovement.gd nicht angefasst wird.
	if player.has_meta("path_bass_movement_module"):
		var path_bass_movement = player.get_meta("path_bass_movement_module")
		if path_bass_movement and path_bass_movement.has_method("begin_bass_slide"):
			path_bass_movement.begin_bass_slide(path_follows, best_index, self)

	# Kamera leicht rauszoomen/verschieben fuer ein staerkeres
	# Geschwindigkeitsgefuehl - nutzt das bestehende Override-System auf
	# GroundMovement, laeuft unabhaengig vom aktiven Movement-Modul weiter
	# (siehe GroundMovement._process), also auch waehrend PathBassMovement
	# aktiv ist.
	var ground_module = player.get_node_or_null("GroundMovement")
	if ground_module:
		ground_module.set_camera_zoom_override(camera_zoom_target, camera_transition_duration)
		ground_module.set_camera_offset_override(camera_offset_target, camera_transition_duration)

	if f_prompt_sprite:
		f_prompt_sprite.stop()
		if hide_f_prompt_while_sliding:
			f_prompt_sprite.visible = false


## Wird von PathMovement aufgerufen, sobald das Pfadende (progress_ratio
## >= 1.0) der aktuellen Saite erreicht ist - normales Verlassen, kein
## Hindernis-Treffer.
func detach_from_path(player: CharacterBody2D) -> void:
	if not player.is_on_path:
		return

	var end_transform: Transform2D = player.global_transform

	player.is_on_path = false
	player.is_bass_slide_active = false
	if player.has_meta("sliding_zone"):
		player.remove_meta("sliding_zone")

	var current_pf := player.get_parent() as PathFollow2D
	if current_pf and current_pf.is_ancestor_of(player):
		current_pf.remove_child(player)
	if _previous_parent:
		_previous_parent.add_child(player)
		player.global_transform = end_transform
		player.reset_physics_interpolation()
		player.z_index = _previous_player_z_index
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_physics_interpolation()

	var ground_module := player.get_node_or_null("GroundMovement")
	if ground_module:
		ground_module.clear_camera_zoom_override(camera_transition_duration)
		ground_module.clear_camera_offset_override(camera_transition_duration)

	if f_prompt_sprite:
		f_prompt_sprite.visible = true
		f_prompt_sprite.play()


## Wird von PathMovement bei einem Hindernis-Treffer aufgerufen: blendet
## auf Schwarz, setzt den Spieler zurück auf respawn_point (VOR dem
## Collider und der F-Abfrage-Zone) und blendet wieder auf. Der Spieler
## muss danach erneut in die Zone laufen und F drücken.
func respawn_after_obstacle_hit(player: CharacterBody2D) -> void:
	if not respawn_point:
		push_warning("BassSlideZone: respawn_point ist nicht gesetzt!")
		return

	if screen_fade:
		await screen_fade.fade_out(fade_out_duration)
	else:
		await player.get_tree().create_timer(fade_out_duration).timeout

	var current_pf := player.get_parent() as PathFollow2D
	player.is_on_path = false
	player.is_bass_slide_active = false
	if player.has_meta("sliding_zone"):
		player.remove_meta("sliding_zone")
	if current_pf and current_pf.is_ancestor_of(player):
		current_pf.remove_child(player)
	if _previous_parent:
		_previous_parent.add_child(player)

	player.global_position = respawn_point.global_position
	player.global_rotation = 0.0
	player.keep_upright = true
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.z_index = _previous_player_z_index

	var ground_module := player.get_node_or_null("GroundMovement")
	if ground_module:
		ground_module.clear_camera_zoom_override(camera_transition_duration)
		ground_module.clear_camera_offset_override(camera_transition_duration)

	if f_prompt_sprite:
		f_prompt_sprite.visible = true
		f_prompt_sprite.play()

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_physics_interpolation()

	if player.has_meta("path_bass_movement_module"):
		var path_bass_movement = player.get_meta("path_bass_movement_module")
		if path_bass_movement and path_bass_movement.has_method("reset_bass_slide_state"):
			path_bass_movement.reset_bass_slide_state()

	if screen_fade:
		await screen_fade.fade_in(fade_in_duration)
