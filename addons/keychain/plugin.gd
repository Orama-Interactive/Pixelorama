tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("Keychain", "res://addons/keychain/Keychain.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("Keychain")
