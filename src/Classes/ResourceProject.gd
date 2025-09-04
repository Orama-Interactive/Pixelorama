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
