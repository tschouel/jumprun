class_name RampTimerUI
extends CanvasLayer
## Zeigt waehrend des Schanzen-Minigames (siehe PathRampMovement.gd/
## RampTestSequencer.gd) die zu druckende Taste an, mit einem sich
## leerenden Pie-Timer dahinter - und folgt dabei der Bildschirmposition
## des Spielers (CanvasLayer sitzt sonst fix im Screen-Space, unabhaengig
## von Kamera/Weltposition).
##
## SETUP IM EDITOR:
## - Dieses Skript auf eine CanvasLayer-Node legen.
## - Kind-Node "PromptContainer" (Control, z.B. CenterContainer), darin:
##   - Kind-Node "PieControl" (Control, feste min. Groesse z.B. 100x100),
##     Skript RampPieControl.gd
##   - Kind-Node "KeyLabel" (Label), zentriert ueber/vor dem PieControl
## - ALLE DREI NODES UNTEN IM INSPECTOR ZUWEISEN (Prompt Container,
##   Key Label, Pie Control) - kein automatisches Suchen ueber Node-Pfade
##   mehr, damit es unabhaengig von der genauen Namensgebung funktioniert.

@export var prompt_container: Control
@export var key_label: Label
@export var pie: Control

@export_group("Positionierung")
## Wie weit (in Pixeln) die Anzeige ueber dem verfolgten Ziel schwebt.
@export var above_offset: float = 150.0

var _target: Node2D = null


func _ready() -> void:
	layer = 100
	visible = false


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(_target) or not prompt_container:
		return
	# Weltposition des Ziels in Bildschirm-/bzw. CanvasLayer-Koordinaten
	# umrechnen (canvas_transform beruecksichtigt die aktive Kamera) und
	# die Anzeige mittig darueber positionieren.
	var screen_pos: Vector2 = get_viewport().canvas_transform * _target.global_position
	var container_size: Vector2 = prompt_container.size
	prompt_container.position = screen_pos - Vector2(container_size.x * 0.5, container_size.y + above_offset)


## target: der Node (z.B. der Spieler), ueber dem die Anzeige schweben soll.
func show_prompt(key_name: String, target: Node2D = null) -> void:
	if key_label:
		key_label.text = key_name
	if pie and pie.has_method("set_progress"):
		pie.set_progress(1.0)
	_target = target
	visible = true


func update_progress(remaining_ratio: float) -> void:
	if pie and pie.has_method("set_progress"):
		pie.set_progress(remaining_ratio)


func hide_prompt() -> void:
	visible = false
	_target = null
