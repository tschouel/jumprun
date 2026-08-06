extends TextureRect

# Ziehe hier im Inspektor deine beiden Bilder rein
@export var happy_texture: Texture2D
@export var sad_texture: Texture2D

func _ready() -> void:
	# Startbild setzen
	if happy_texture:
		texture = happy_texture

## Diese Funktion rufen wir auf, wenn der Spieler fällt/patzt
func trigger_miss_expression() -> void:
	if sad_texture:
		texture = sad_texture
		
		# Warten exakt 1 Beat (0.667s bei 90 BPM)
		await get_tree().create_timer(0.667).timeout
		
		# Zurück zum frohen Bild
		if happy_texture:
			texture = happy_texture
