extends Area2D

## Die PathFollow2D, an die der Player beim Betreten gehängt wird
@export var path_follow: PathFollow2D

## Optional: Zone-eigenes Tempo (bpm/units_per_bar), leer lassen für "Player-Standard behalten"
@export var override_bpm: float = 0.0
@export var override_units_per_bar: float = 0.0

var _previous_parent: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# WICHTIG: KEIN body_exited hier! Der Player wird durch das Umhängen
	# (reparenting) sofort an eine neue Position teleportiert - oft direkt
	# an/außerhalb der Kante dieser selben Area2D. Das löste vorher
	# body_exited -> detach -> is_on_path=false -> body_entered -> reattach
	# in einer Endlosschleife aus (das "zittern"). Das Verlassen des Pfads
	# passiert stattdessen über das Pfadende (siehe PathMovement.detach via
	# detach_from_path()).


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var player := body as CharacterBody2D
	if player.is_on_path:
		return
	if not path_follow:
		push_error("SlidingZone: path_follow ist nicht zugewiesen!")
		return
	call_deferred("_attach_to_path", player)


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
