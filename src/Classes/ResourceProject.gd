class_name ResourceProject
extends Project
## A class for easily editing individual project sub-resources like tiles, index maps, etc.
##
## The [ResourceProject] is basically a [Project], except that it doesn't get saved physically
## (as a .pxo file), instead, a [signal resource_updated] signal is emitted which can
## be used to update the resource in the [Project].[br]

## Emitted when the [ResourceProject] is saved.
@warning_ignore("unused_signal")
signal resource_updated(project: Project)


func _init(_frames: Array[Frame] = [], _name := tr("untitled"), _size := Vector2i(64, 64)) -> void:
	super._init(_frames, _name + " (Virtual Resource)", _size)


func get_frame_image(frame_idx: int) -> Image:
	var frame_image := Image.create_empty(
		size.x, size.y, false, Image.FORMAT_RGBA8
	)
	if frame_idx >= 0 and frame_idx < frames.size():
		var frame := frames[frame_idx]
		DrawingAlgos.blend_layers(frame_image, frame, Vector2i.ZERO, self)
	else:
		printerr(
			"frame index: %s not found in ResourceProject, frames.size(): %s" % [
				str(frame_idx), str(frames.size())
			]
		)
	return frame_image
