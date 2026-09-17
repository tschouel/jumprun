@tool
class_name ColorTint
extends Node

## Faerbt EIN beliebiges CanvasItem (Sprite2D, AnimatedSprite2D, Node2D,
## Polygon2D, Line2D, ...) ueber target.modulate ein - die Farbe kommt aus
## derselben TuningPegColor-Resource (siehe tuning_peg_color.gd), die auch
## TuningPeg.gd fuer sein color_theme-Feld benutzt. Dadurch kannst du EIN UND
## DIESELBE .tres-Datei sowohl bei deinen TuningPegs als auch bei ganz
## anderen Objekten einsetzen - alle damit verknuepften Objekte faerben sich
## dann gemeinsam auf einen Schlag um.
##
## @tool (wichtig): dieses Skript laeuft dadurch AUCH direkt im Godot-Editor,
## nicht erst wenn du auf Play druecktst - die Farbe erscheint sofort im
## 2D-Viewport, sobald du target oder color_theme (bzw. dessen color-Wert)
## aenderst. OHNE @tool wuerde die ganze Einfaerbung erst beim tatsaechlichen
## Spielstart passieren, im Editor selbst saehe man also gar nichts - das war
## vermutlich der Grund, warum es zuerst nicht geklappt hat.
##
## Setup - ZWEI Varianten, beide funktionieren gleich gut:
## A) Direkt auf das zu faerbende CanvasItem selbst (z.B. eine
##    AnimatedSprite2D-Node) als IHR Script eintragen. target kannst du dann
##    einfach LEER lassen - zeigt automatisch auf sich selbst.
## B) Als eigenen Kind-Node (Typ "Node") unter das zu faerbende Objekt
##    haengen, dieses Skript drauf, target im Inspector explizit auf das zu
##    faerbende CanvasItem ziehen (falls es NICHT der direkte Eltern-Node
##    sein soll).
##
## In beiden Faellen: color_theme auf dieselbe tuning_peg_color.tres-Datei
## ziehen, die du auch bei deinen TuningPegs benutzt (siehe
## tuning_peg_color.gd). Farbe danach jederzeit aendern: die .tres-Datei
## oeffnen und color anpassen - wirkt sofort auf ALLE Objekte UND alle
## TuningPegs, die diese Datei referenzieren, schon im Editor, kein Play
## noetig.
##
## WICHTIG bei schwarzer/dunkler Grafik: standardmaessig wird die Farbe ueber
## target.modulate gesetzt - das MULTIPLIZIERT nur mit der Texturfarbe, kann
## schwarze Pixel (0,0,0) also niemals aufhellen. Hat target ein
## ShaderMaterial mit dem Shader recolor_silhouette.gdshader zugewiesen
## (Inspector -> CanvasItem -> Material), wird stattdessen dessen
## tint_color-Parameter gesetzt, der die Farbe komplett ERSETZT - das faerbt
## auch rein schwarz gezeichnete PNGs korrekt ein. Ohne so ein ShaderMaterial
## faellt der Code automatisch auf modulate zurueck.

@export var target: CanvasItem:
	set(value):
		target = value
		_apply_color()

@export var color_theme: TuningPegColor:
	set(value):
		if color_theme and color_theme.changed.is_connected(_apply_color):
			color_theme.changed.disconnect(_apply_color)
		color_theme = value
		if color_theme and not color_theme.changed.is_connected(_apply_color):
			color_theme.changed.connect(_apply_color)
		_apply_color()

func _ready() -> void:
	if not target:
		# Umweg ueber eine Object-typisierte Variable: der statische
		# GDScript-Checker kennt "self" hier nur als ColorTint (unsere
		# extends Node-Deklaration) und weiss nicht, dass diese Node zur
		# Laufzeit z.B. tatsaechlich eine AnimatedSprite2D sein kann - ein
		# direktes "self as CanvasItem" lehnt er deshalb als angeblich
		# unmoeglichen Cast ab. Object ist die gemeinsame Basisklasse aller
		# Godot-Objekte, ein Cast von Object aus ist daher immer erlaubt und
		# wird ganz normal zur Laufzeit geprueft.
		var self_as_object: Object = self
		target = self_as_object as CanvasItem
	if not target:
		target = get_parent() as CanvasItem
	_apply_color()

func _apply_color() -> void:
	if color_theme and target:
		_apply_tint(target, color_theme.color)

## Setzt die Farbe entweder ueber ein zugewiesenes ShaderMaterial (siehe
## recolor_silhouette.gdshader - ersetzt die Farbe komplett, funktioniert
## auch bei schwarzer Grafik) oder, falls kein solches Material vorhanden
## ist, als Fallback ueber modulate (multipliziert nur - reicht bei
## heller/weisser Grafik). queue_redraw() am Ende ist noetig, damit die
## Aenderung auch im EDITOR (nicht nur im laufenden Spiel) sofort sichtbar
## wird - ohne das haelt der Editor-Viewport die Node faelschlich fuer
## unveraendert und zeichnet sie nicht neu, bis irgendwas anderes einen
## Redraw auslsst.
func _apply_tint(node: CanvasItem, color: Color) -> void:
	if node.material is ShaderMaterial:
		(node.material as ShaderMaterial).set_shader_parameter("tint_color", color)
	else:
		node.modulate = color
	node.queue_redraw()
