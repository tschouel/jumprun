extends Area2D

@export var target_scene_path: String = ""
@export var spawn_id: String = "default"
@export var interact_key: Key = KEY_E

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == interact_key:
			SceneManager.goto_scene(target_scene_path, spawn_id)
			get_viewport().set_input_as_handled()
