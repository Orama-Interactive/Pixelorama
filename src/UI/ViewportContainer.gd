extends ViewportContainer

func _ready():
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA

func _on_ViewportContainer_mouse_entered() -> void:
	Global.has_focus = true


func _on_ViewportContainer_mouse_exited() -> void:
	Global.has_focus = false
