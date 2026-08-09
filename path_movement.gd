class_name PathMovement
extends Node

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D

# Speichert die vorherige Position, um die Neigung zu berechnen
var _last_global_pos: Vector2 = Vector2.ZERO

func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player:
		_last_global_pos = player.global_position

func process_movement(_delta: float) -> void:
	if not player or not player.is_on_path:
		return

	# Pfad-Neigung erlauben:
	player.keep_upright = false

	# 1. Schlitten-Sprite holen, sichtbar schalten & animieren
	var sliding_sprite = player.get_node_or_null("Sliding") as AnimatedSprite2D
	if sliding_sprite:
		player.show_only_sprite(sliding_sprite)
		_update_sliding_animation(sliding_sprite)

	# 2. Keine Physik/Gravity auf dem Pfad
	player.velocity = Vector2.ZERO

	# 3. Ausrichtung, Neigung & Spiegelung
	_handle_path_orientation(sliding_sprite)

func _update_sliding_animation(sliding_sprite: AnimatedSprite2D) -> void:
	if not sliding_sprite.sprite_frames:
		return

	var anim_names = sliding_sprite.sprite_frames.get_animation_names()
	if anim_names.is_empty():
		return

	var anim_to_play = "Sliding" if sliding_sprite.sprite_frames.has_animation("Sliding") else anim_names[0]
	if not sliding_sprite.is_playing() or sliding_sprite.animation != anim_to_play:
		sliding_sprite.play(anim_to_play)

func _handle_path_orientation(sliding_sprite: AnimatedSprite2D) -> void:
	var current_pos = player.global_position
	var move_vector = current_pos - _last_global_pos

	# 1. Prüfen, ob eine Bewegung stattfindet
	if move_vector.length_squared() > 0.001:
		
		# keep_upright kurz aushebeln/prüfen
		if not player.keep_upright:
			var angle = move_vector.angle()
			
			# Korrektur bei Linksfahrt (wegen flip_h)
			if move_vector.x < 0.0:
				angle += PI
				
			player.global_rotation = angle
		else:
			# Testweise: Zeigt im Output an, falls keep_upright die Rotation blockiert
			print("Rotation blockiert, weil player.keep_upright = true ist!")

		# 2. Spiegelung
		if sliding_sprite and "flip_h" in sliding_sprite:
			sliding_sprite.flip_h = move_vector.x < 0.0

	# WICHTIG: Diese beiden Zeilen MÜSSEN ausserhalb des IF-Blocks stehen,
	# damit _last_global_pos in jedem Frame auf den aktuellen Stand gebracht wird!
	_last_global_pos = current_pos
	player._last_global_x = current_pos.x
