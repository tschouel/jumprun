extends Area2D
@export var left_creature: AnimatedSprite2D
@export var right_creature: AnimatedSprite2D
@export var left_color_rect: ColorRect
@export var right_color_rect: ColorRect
func _ready() -> void:
	body_entered.connect(_on_body_entered)
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var player := body as CharacterBody2D
	if player == null:
		return
	if left_creature == null or right_creature == null:
		push_warning("%s: left_creature oder right_creature ist im Inspector nicht gesetzt!" % name)
		return
	var moving_right: bool = player.velocity.x > 0.0
	if player.velocity.x == 0.0:
		# Fallback, falls der Spieler z.B. genau auf der Linie spawnt
		moving_right = player.global_position.x > global_position.x
	if moving_right:
		left_creature.play_end()
		right_creature.play_start(true)
		if left_color_rect:
			left_color_rect.fade_out()
		if right_color_rect:
			right_color_rect.fade_in()
	else:
		right_creature.play_end()
		left_creature.play_start(true)
		if right_color_rect:
			right_color_rect.fade_out()
		if left_color_rect:
			left_color_rect.fade_in()
