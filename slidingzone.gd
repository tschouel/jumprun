extends Area2D

## Die PathFollow2D, an die der Player beim Betreten gehängt wird
@export var path_follow: PathFollow2D

## Optional: Zone-eigenes Tempo (bpm/units_per_bar), leer lassen für "Player-Standard behalten"
@export var override_bpm: float = 0.0
@export var override_units_per_bar: float = 0.0

@export_group("Checkpoint & Respawn")
## Position VOR dem ersten Hindernis-Collider und der F-Abfrage-Zone -
## hierhin wird der Spieler nach einem Hindernis-Treffer zurückgesetzt.
## Leer lassen = altes Verhalten (Hindernis stoppt nur, kein Respawn).
@export var respawn_point: Node2D
## ScreenFade-Instanz (CanvasLayer) in der Szene. Leer lassen = kein Fade,
## nur eine Wartezeit in gleicher Länge.
@export var screen_fade: ScreenFade
@export var fade_out_duration: float = 1.5
@export var fade_in_duration: float = 0.5

@export_group("F-Prompt Anzeige")
## Optional: AnimatedSprite2D, das einen blinkenden "F"-Hinweis zeigt,
## solange der Spieler in der Zone steht und noch nicht rutscht. Wird
## automatisch gestoppt, sobald F erfolgreich gedrueckt wurde, und wieder
## gestartet, sobald der Spieler die Saite wieder verlaesst (Pfadende) und
## erneut F druecken muss. Leer lassen = kein Effekt.
@export var f_prompt_sprite: AnimatedSprite2D
## Zusaetzlich zum Stoppen des Loops auch komplett ausblenden, solange
## gerutscht wird.
@export var hide_f_prompt_while_sliding: bool = true

var _previous_parent: Node = null
var _player_in_zone: bool = false
var _current_player: CharacterBody2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# WICHTIG: body_exited ist jetzt UNBEDENKLICH (anders als frueher!),
	# weil das Attachen nicht mehr automatisch bei body_entered passiert,
	# sondern nur noch ueber die F-Taste (_unhandled_input). Die alte
	# Endlosschleife (body_exited -> detach -> body_entered -> reattach)
	# konnte nur entstehen, wenn body_entered SELBST das Attachen ausloeste
	# - das ist hier nicht mehr der Fall, body_entered setzt nur noch
	# _player_in_zone.
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
	if not path_follow:
		push_error("SlidingZone: path_follow ist nicht zugewiesen!")
		return
	if event is InputEventKey and event.physical_keycode == KEY_F and event.pressed and not event.is_echo():
		_attach_to_path(_current_player)


func _attach_to_path(player: CharacterBody2D) -> void:
	if player.is_on_path:
		return

	_previous_parent = player.get_parent()

	# NEU: statt immer bei progress = 0.0 (Pfadanfang) einzusteigen, den
	# Punkt auf der Kurve suchen, der der tatsächlichen Eintrittsposition
	# des Spielers am nächsten liegt. Sonst "springt" der Spieler beim
	# Betreten der Zone an den Pfadanfang, selbst wenn die Zone mitten auf
	# dem Pfad liegt.
	var path2d := path_follow.get_parent() as Path2D
	var entry_progress: float = 0.0
	if path2d and path2d.curve:
		var local_pos: Vector2 = path2d.to_local(player.global_position)
		entry_progress = path2d.curve.get_closest_offset(local_pos)

	_previous_parent.remove_child(player)
	path_follow.add_child(player)
	path_follow.progress = entry_progress

	player.position = Vector2.ZERO
	player.rotation = 0.0

	if override_bpm > 0.0 and override_units_per_bar > 0.0:
		player.set_zone_tempo(override_bpm, override_units_per_bar)

	# Referenz auf diese Zone am Player hinterlegen, damit PathMovement beim
	# Pfadende zurück-detachen kann, ohne dass player.gd diese Zone kennen muss.
	player.set_meta("sliding_zone", self)

	player.is_on_path = true

	# Physics Interpolation zurücksetzen: verhindert, dass Godot den Sprung
	# der Rotation (von 0 auf die Pfad-Tangente) ueber mehrere Frames hinweg
	# sichtbar einblendet - das erzeugt den wilden Ausschlag der Figur beim
	# Einstieg in die Sliding Zone.
	player.reset_physics_interpolation()

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_physics_interpolation()

	if f_prompt_sprite:
		f_prompt_sprite.stop()
		if hide_f_prompt_while_sliding:
			f_prompt_sprite.visible = false

	# Checkpoint-Respawn nur aktivieren, wenn diese Zone einen respawn_point
	# konfiguriert hat - sonst bleibt das alte Verhalten (Hindernis stoppt
	# nur) unveraendert bestehen.
	if respawn_point and player.has_meta("path_movement_module"):
		var path_movement = player.get_meta("path_movement_module")
		if path_movement and path_movement.has_method("set_respawn_zone"):
			path_movement.set_respawn_zone(self)

	# Falls dieser Pfad einen RampTestSequencer hat (Mid-Path Tastentest),
	# dessen Erfolg/Fehlschlag-Zustand zuruecksetzen, damit ein neuer
	# Versuch nach einem Respawn wieder frisch beginnt.
	if path2d:
		for child in path2d.get_children():
			if child is RampTestSequencer:
				child.reset_test()


## Gibt den Node zurueck, zu dem der Spieler VOR dem Attach gehoerte -
## wird von PathRampMovement.begin_fail_fall() genutzt, um den Spieler bei
## einem misslungenen Ramp-Test korrekt aus der PathFollow2D zu loesen und
## wieder in die normale Levelhierarchie einzuhaengen.
func get_previous_parent() -> Node:
	return _previous_parent


## Wird von PathMovement aufgerufen, sobald path_follow.progress_ratio >= 1.0
func detach_from_path(player: CharacterBody2D) -> void:
	if not player.is_on_path:
		return

	# WICHTIG: die aktuelle Weltposition (= Pfad-ENDE, wo PathFollow2D den
	# Spieler gerade hingefuehrt hat) VOR dem Reparenting sichern - beim
	# manuellen remove_child()/add_child() behaelt Godot NICHT automatisch
	# die globale Position bei (die lokale Position bleibt zahlenmaessig
	# gleich, wird aber im neuen Elternteil anders interpretiert). Frueher
	# wurde hier stattdessen die ALTE, vor dem Einstieg gespeicherte
	# Startposition wiederhergestellt (_previous_global_transform) - das
	# hat den Spieler beim Pfadende faelschlich zurueck an den PFADANFANG
	# teleportiert. Lag der Zonen-Trigger dort (was er praktisch immer tut,
	# die Zone sitzt ja am Einstiegspunkt), loeste das sofort wieder
	# body_entered aus -> erneutes Anhaengen -> erneutes Durchlaufen ->
	# erneutes Zurueckteleportieren an den Anfang -> Endlosschleife.
	var end_transform: Transform2D = player.global_transform

	player.is_on_path = false
	player.remove_meta("sliding_zone")

	if path_follow.is_ancestor_of(player):
		path_follow.remove_child(player)
	if _previous_parent:
		_previous_parent.add_child(player)
		player.global_transform = end_transform

		# Physics Interpolation auch beim AUSSTIEG zuruecksetzen - sonst
		# blendet Godot den Rotations-/Positionssprung beim Reparenting
		# zurueck zum vorherigen Parent ueber mehrere Frames sichtbar ein,
		# was sich als Ruckler in der Rotation beim Pfadende zeigt.
		player.reset_physics_interpolation()
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_physics_interpolation()

	if f_prompt_sprite:
		f_prompt_sprite.visible = true
		f_prompt_sprite.play()

	if player.has_meta("path_movement_module"):
		var path_movement = player.get_meta("path_movement_module")
		if path_movement and path_movement.has_method("clear_respawn_zone"):
			path_movement.clear_respawn_zone()


## Wird von PathMovement bei einem Hindernis-Treffer aufgerufen (nur wenn
## respawn_point gesetzt ist, siehe set_respawn_zone): blendet auf Schwarz,
## setzt den Spieler zurück auf respawn_point (VOR dem Collider und der
## F-Abfrage-Zone) und blendet wieder auf. Der Spieler muss danach erneut
## in die Zone laufen und F drücken.
func respawn_after_obstacle_hit(player: CharacterBody2D) -> void:
	if not respawn_point:
		push_warning("SlidingZone: respawn_point ist nicht gesetzt!")
		return

	if screen_fade:
		await screen_fade.fade_out(fade_out_duration)
	else:
		await player.get_tree().create_timer(fade_out_duration).timeout

	player.is_on_path = false
	player.remove_meta("sliding_zone")

	# Robust gegenueber zwei Ausgangslagen: normaler Hindernis-Treffer
	# (Spieler ist noch Kind von path_follow) ODER Ramp-Test-Fehlschlag
	# (PathRampMovement.begin_fail_fall hat den Spieler bereits vorher aus
	# path_follow geloest und an _previous_parent gehaengt - dann NICHT
	# ein zweites Mal reparenten, sonst wirft Godot einen Fehler).
	if player.get_parent() != _previous_parent:
		var current_parent := player.get_parent()
		if current_parent:
			current_parent.remove_child(player)
		if _previous_parent:
			_previous_parent.add_child(player)

	player.global_position = respawn_point.global_position
	player.global_rotation = 0.0
	player.keep_upright = true
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_physics_interpolation()

	if f_prompt_sprite:
		f_prompt_sprite.visible = true
		f_prompt_sprite.play()

	if player.has_meta("path_movement_module"):
		var path_movement = player.get_meta("path_movement_module")
		if path_movement and path_movement.has_method("clear_respawn_zone"):
			path_movement.clear_respawn_zone()

	if screen_fade:
		await screen_fade.fade_in(fade_in_duration)
