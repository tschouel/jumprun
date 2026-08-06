extends FmodEventEmitter2D

func _ready() -> void:
	# Baut eine klitzekleine Verzögerung ein, damit die FMOD Banks im Speicher geladen sind
	call_deferred("_start_bgm")

func _start_bgm() -> void:
	play()
