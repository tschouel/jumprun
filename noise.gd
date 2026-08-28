extends Node

## Vignette (dunkler werdender Rand) + unruhiges Rausch-/Stoersignal auf dem
## ColorRect - kommt vom zentralen ClosenessSource (fader_closeness.gd), nicht
## mehr direkt vom Fader-Rohwert. state_a/unangenehm (closeness 0) = maximale
## Koernung, perfect (closeness 1) = keine mehr.
##
## Performance: das Material wird NUR gesetzt, waehrend Koernung noetig ist.
## Bei closeness nahe 1 (perfect) laeuft ueberhaupt kein Shader auf dem
## ColorRect - das war bei einer riesigen Flaeche der eigentliche Kostenpunkt,
## nicht die Flaechengroesse an sich.
##
## Setup: den Shader "vignette_noise.gdshader" auf eine ShaderMaterial-Resource
## legen (z.B. per Rechtsklick im FileSystem -> Neue Resource -> ShaderMaterial,
## Shader zuweisen) und diese Resource unten bei "Shader Material" reinziehen.
## Das ColorRect selbst braucht KEIN Material im Inspector - das uebernimmt
## dieses Skript zur Laufzeit.

@export var closeness_source: ClosenessSource
@export var color_rect: ColorRect
@export var shader_material: ShaderMaterial

@export_group("Performance")
## Deaktiviert den Effekt automatisch, wenn im Editor getestet wird (Play-Button/
## F5/F6) - bleibt aber in einem exportierten Build ganz normal aktiv. So kannst
## du beim Testen schnell iterieren, ohne den Effekt fuers fertige Spiel zu
## verlieren oder vorm Export dran denken zu muessen, ihn wieder einzuschalten.
@export var disable_in_editor: bool = true

var _effect_disabled: bool = false

func _ready() -> void:
	_effect_disabled = disable_in_editor and OS.has_feature("editor")
	if color_rect:
		color_rect.material = null
	if closeness_source:
		closeness_source.closeness_changed.connect(_on_closeness_changed)

func _on_closeness_changed(closeness: float) -> void:
	if not color_rect or not shader_material:
		return
	if _effect_disabled:
		if color_rect.material:
			color_rect.material = null
		return
	# Umgedreht: closeness 0 (state_a/unangenehm) = maximale Koernung,
	# closeness 1 (perfect) = keine mehr.
	var intensity: float = 1.0 - closeness
	if intensity <= 0.001:
		if color_rect.material:
			color_rect.material = null
		return
	if color_rect.material != shader_material:
		color_rect.material = shader_material
	shader_material.set_shader_parameter("intensity", intensity)
