extends Node

func _ready() -> void:
	# 1. Banks manuell zur Laufzeit laden
	FmodServer.load_bank("res://banks/Desktop/Master.bank", FmodServer.FMOD_STUDIO_LOAD_BANK_NORMAL)
	FmodServer.load_bank("res://banks/Desktop/Master.strings.bank", FmodServer.FMOD_STUDIO_LOAD_BANK_NORMAL)
	
	print("FMOD Banks erfolgreich geladen!")
