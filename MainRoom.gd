extends Node

func _ready() -> void:
	SceneManager.register_container($SceneContainer)
	SceneManager.goto_scene("res://MainRoom.tscn")
