@tool
extends EditorPlugin

var apng_importer


func _enter_tree():
	apng_importer = AImgIOAPNGImportPlugin.new()
	add_import_plugin(apng_importer)


func _exit_tree():
	remove_import_plugin(apng_importer)
	apng_importer = null
