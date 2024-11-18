class_name ResourceProject
extends Project

signal resource_updated


func _init(_frames: Array[Frame] = [], _name := tr("untitled"), _size := Vector2i(64, 64)) -> void:
	super._init(_frames, _name + " (Virtual Resource)", _size)
