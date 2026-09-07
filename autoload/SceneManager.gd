extends Node

var current_scene: Node = null
var scene_container: Node = null
var is_transitioning: bool = false

func register_container(container: Node) -> void:
	scene_container = container

func goto_scene(scene_path: String, spawn_id: String = "default") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	call_deferred("_deferred_goto_scene", scene_path, spawn_id)

func _deferred_goto_scene(scene_path: String, spawn_id: String) -> void:
	if current_scene:
		current_scene.queue_free()
		await current_scene.tree_exited

	var packed_scene: PackedScene = load(scene_path)
	current_scene = packed_scene.instantiate()
	scene_container.add_child(current_scene)

	if current_scene.has_method("place_player_at"):
		current_scene.place_player_at(spawn_id)

	is_transitioning = false
