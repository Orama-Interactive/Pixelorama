## This is a Debug Node wich will show some usefull info and buttons/input
## 
## The DiscordRPC Debug Node will show info about the current values of its variables and some buttons to change them.
##
## @tutorial: https://github.com/vaporvee/discord-rpc-godot/wiki
@tool
extends Node

func _ready() -> void:
	const DebugNodeGroup: PackedScene = preload("res://addons/discord-rpc-gd/nodes/Debug.tscn")
	add_child(DebugNodeGroup.instantiate())
