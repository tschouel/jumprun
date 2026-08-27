extends Area2D

## Ziehe hier das/die CollisionShape2D der Plattform(en) rein, durch die
## man bei DIESER Leiter runterklettern koennen soll (z.B. der eine
## One-Way-Boden, den die Leiter durchdringt). NICHT die ganze Level-Layer -
## nur genau die Shape(s), die zu dieser Leiter gehoeren. Dadurch bleiben
## alle anderen One-Way-Plattformen im Level normal solide.
@export var blocking_platforms: Array[CollisionShape2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_near_ladder"):
		body.set_near_ladder(true, self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_near_ladder"):
		body.set_near_ladder(false, self)

## Wird vom GroundMovement-Modul aufgerufen, um NUR die Plattform(en)
## dieser einen Leiter durchlaessig zu machen.
func set_platforms_passable(passable: bool) -> void:
	for shape in blocking_platforms:
		if shape:
			shape.disabled = passable
