extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween := $Tween
	tween.interpolate_property(self, "rect_position", rect_position, Vector2(rect_position.x, rect_position.y - 100), 1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(self, "modulate", modulate, Color(modulate.r, modulate.g, modulate.b, 0), 1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()

func _on_Timer_timeout() -> void:
	queue_free()
