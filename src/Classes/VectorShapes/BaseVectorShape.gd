class_name BaseVectorShape
extends Reference

# Draw the shape on this CanvasItem RID using the VisualServer
func draw(_canvas_item: RID) -> void:
	return


# Is point inside this shape? Useful for selecting the shape with a mouse click
func has_point(_point: Vector2) -> bool:
	return false
