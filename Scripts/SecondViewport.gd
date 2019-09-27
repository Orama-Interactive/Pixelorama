extends Viewport

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_2d = $"../../ViewportContainer/Viewport".world_2d
