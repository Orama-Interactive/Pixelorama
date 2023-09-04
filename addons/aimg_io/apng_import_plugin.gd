@tool
class_name AImgIOAPNGImportPlugin
extends EditorImportPlugin


func _get_importer_name() -> String:
	return "aimgio.apng_animatedtexture"


func _get_visible_name() -> String:
	return "APNG as AnimatedTexture"


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "AnimatedTexture"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["png"])


func _get_preset_count():
	return 1


func _get_preset_name(_i):
	return "Default"


func _get_import_options(_path: String, _i: int) -> Array[Dictionary]:
	return []


func _get_import_order():
	return 0


func _get_option_visibility(_path: String, _option, _options):
	return true


func _import(load_path: String, save_path: String, _options, _platform_variants, _gen_files):
	var res := AImgIOAPNGImporter.load_from_file(load_path)
	if res[0] != null:
		push_error("AImgIOPNGImporter: " + res[0])
		return ERR_FILE_UNRECOGNIZED
	var frames: Array = res[1]
	var root: AnimatedTexture = AnimatedTexture.new()
	root.frames = len(frames)
	for i in range(len(frames)):
		var f: AImgIOFrame = frames[i]
		root.set_frame_duration(i, f.duration)
		var tx := ImageTexture.new()
		tx.create_from_image(f.content)
		root.set_frame_texture(i, tx)
	return ResourceSaver.save(root, save_path + ".res")
