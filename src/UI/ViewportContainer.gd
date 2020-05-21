extends ViewportContainer


func _on_ViewportContainer_mouse_entered() -> void:
	Global.has_focus = true


func _on_ViewportContainer_mouse_exited() -> void:
	Global.has_focus = false
