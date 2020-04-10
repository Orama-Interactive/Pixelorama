extends Node

var xdg_data_home : String
var xdg_data_dirs : Array

# Default location for xdg_data_home relative to $HOME
const default_xdg_data_home_rel := ".local/share"
const default_xdg_data_dirs := ["/usr/local/share", "/usr/share"]

const config_subdir_name := "pixelorama"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.has_feature("X11"):
		xdg_data_home = OS.get_environment("HOME").plus_file(default_xdg_data_home_rel)
		
	 


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
