extends Area2D

@export var rain_particles: GPUParticles2D
@export var ground_node: Node2D  # Optional: Falls dein Boden-Node direkt zugewiesen werden soll

var is_sunk: bool = false
var sink_distance: float = 120.0  # Wie tief der Block maximal einsinken soll
var sink_duration: float = 2.5    # Dauer des Absinkens in Sekunden
var active_player: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_sunk:
		is_sunk = true
		active_player = body
		sink_into_ground()

func sink_into_ground() -> void:
	# 1. Distanz begrenzen: Nicht tiefer als der Boden sinken
	var target_y = position.y + sink_distance
	if ground_node:
		target_y = min(target_y, ground_node.position.y)

	var tween = create_tween()
	
	# Block sanft nach unten absenken
	tween.tween_property(self, "position:y", target_y, sink_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Wenn der Block vollständig unten ist -> Regen anpassen
	tween.chain().tween_callback(_on_block_fully_sunk)

func _physics_process(delta: float) -> void:
	# Den Spieler synchron mit nach unten führen, bis er den Boden-Collider berührt
	if is_sunk and active_player and is_instance_valid(active_player):
		var sink_speed = (sink_distance / sink_duration) * delta
		active_player.move_and_collide(Vector2(0, sink_speed))

func _on_block_fully_sunk() -> void:
	# Physik-Nachführung des Spielers beenden
	active_player = null
	
	if not rain_particles:
		return

	var mat = rain_particles.process_material as ParticleProcessMaterial
	var rain_tween = create_tween().set_parallel(true)
	
	# 2. Tropfengröße im Material auf das Dreifache skalieren
	if mat:
		var target_scale_min = mat.scale_min * 3.0
		var target_scale_max = mat.scale_max * 3.0
		rain_tween.tween_property(mat, "scale_min", target_scale_min, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rain_tween.tween_property(mat, "scale_max", target_scale_max, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3. Zeitlupe: Geschwindigkeit sanft auf 0.3 drosseln
	rain_tween.tween_property(rain_particles, "speed_scale", 0.3, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
