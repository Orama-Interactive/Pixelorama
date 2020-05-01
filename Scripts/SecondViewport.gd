extends Viewport


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_2d = Global.canvas.get_parent().world_2d
