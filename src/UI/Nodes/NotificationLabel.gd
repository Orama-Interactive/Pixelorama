class_name NotificationLabel
extends Label


func _ready() -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rect_position", Vector2(rect_position.x, rect_position.y - 100), 1)
	tw.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0), 1)
	tw.connect("finished", self, "_on_tween_finished")


func _on_tween_finished() -> void:
	queue_free()
