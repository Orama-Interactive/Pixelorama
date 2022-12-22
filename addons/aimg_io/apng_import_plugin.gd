tool
class_name AImgIOAPNGImportPlugin
extends EditorImportPlugin

func get_importer_name() -> String:
	return "aimgio.apng_animatedtexture"

func get_visible_name() -> String:
	return "APNG as AnimatedTexture"

func get_save_extension() -> String:
	return "res"

func get_resource_type() -> String:
	return "AnimatedTexture"

func get_recognized_extensions() -> Array:
	return ["png"]

func get_preset_count():
	return 1

func get_preset_name(i):
	return "Default"

func get_import_options(i):
	return []

func get_option_visibility(option, options):
	return true

func import(load_path: String, save_path: String, options, platform_variants, gen_files):
	var res = AImgIOAPNGImporter.load_from_file(load_path)
	if res[0] != null:
		push_error("AImgIOPNGImporter: " + res[0])
		return ERR_FILE_UNRECOGNIZED
	else:
		var frames = res[1]
		var root: AnimatedTexture = AnimatedTexture.new()
		root.frames = len(frames)
		root.fps = 1
		for i in range(len(frames)):
			var f: AImgIOFrame = frames[i]
			root.set_frame_delay(i, f.duration - 1.0)
			var tx = ImageTexture.new()
			tx.create_from_image(f.content)
			tx.storage = ImageTexture.STORAGE_COMPRESS_LOSSLESS
			root.set_frame_texture(i, tx)
		return ResourceSaver.save(save_path + ".res", root)
