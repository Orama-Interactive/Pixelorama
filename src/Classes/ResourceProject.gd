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


static func instantiate(resource_title: String, updater: Callable, resource_image: Image = null):
	if not resource_image:
		resource_image = Image.create_empty(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
		)
	var resource_proj := ResourceProject.new([], resource_title, resource_image.get_size())
	resource_proj.layers.append(PixelLayer.new(resource_proj))
	resource_proj.frames.append(resource_proj.new_empty_frame())
	resource_proj.frames[0].cels[0].set_content(resource_image)
	resource_proj.resource_updated.connect(updater)
	Global.projects.append(resource_proj)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1


## Returns the full image of the [Frame] at [param frame_idx] in resource project.
func get_frame_image(frame_idx: int) -> Image:
	var frame_image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	if frame_idx >= 0 and frame_idx < frames.size():
		var frame := frames[frame_idx]
		DrawingAlgos.blend_layers(frame_image, frame, Vector2i.ZERO, self)
	else:
		printerr(
			(
				"frame index: %s not found in ResourceProject, frames.size(): %s"
				% [str(frame_idx), str(frames.size())]
			)
		)
	return frame_image
