extends CanvasLayer
## Temporäres Debug-Overlay: zeigt die aktuelle FPS-Zahl oben links im Spiel an.
## NUR zum Testen - danach wieder entfernen/deaktivieren.
##
## SETUP:
## 1. Neue Szene erstellen: Node -> CanvasLayer, dieses Skript draufziehen.
## 2. Diese Szene als Autoload eintragen: Projekteinstellungen -> Autoload ->
##    Pfad zur Szene auswaehlen -> "Add" klicken.
## 3. Spiel starten (F5) - oben links erscheint jetzt laufend die FPS-Zahl.
## 4. Zum Entfernen: einfach den Autoload-Eintrag wieder loeschen oder deaktivieren.

var label: Label

func _ready() -> void:
	layer = 100  # ganz oben, ueber allem anderen UI
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

func _process(_delta: float) -> void:
	label.text = "FPS: %d" % Engine.get_frames_per_second()
