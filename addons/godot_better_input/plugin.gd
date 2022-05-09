tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("BetterInput", "res://addons/godot_better_input/BetterInput.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("BetterInput")
