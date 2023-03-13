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


func get_preset_name(_i):
	return "Default"


func get_import_options(_i):
	# GDLint workaround - it really does not want this string to exist due to length.
	var hint = "Mipmaps,Repeat,Filter,Anisotropic Filter,Convert To Linear,Mirrored Repeat"
	return [
		{
			"name": "image_texture_storage",
			"default_value": 2,
			"property_hint": PROPERTY_HINT_ENUM_SUGGESTION,
			"hint_string": "Raw,Lossy,Lossless"
		},
		{"name": "image_texture_lossy_quality", "default_value": 0.7},
		{
			"name": "texture_flags",
			"default_value": 7,
			"property_hint": PROPERTY_HINT_FLAGS,
			"hint_string": hint
		},
		# We don't know if Godot will change things somehow.
		{"name": "texture_flags_add", "default_value": 0}
	]


func get_option_visibility(_option, _options):
	return true


func import(load_path: String, save_path: String, options, _platform_variants, _gen_files):
	var res := AImgIOAPNGImporter.load_from_file(load_path)
	if res[0] != null:
		push_error("AImgIOPNGImporter: " + res[0])
		return ERR_FILE_UNRECOGNIZED
	var frames: Array = res[1]
	var root: AnimatedTexture = AnimatedTexture.new()
	var flags: int = options["texture_flags"]
	flags |= options["texture_flags_add"]
	root.flags = flags
	root.frames = len(frames)
	root.fps = 1
	for i in range(len(frames)):
		var f: AImgIOFrame = frames[i]
		root.set_frame_delay(i, f.duration - 1.0)
		var tx := ImageTexture.new()
		tx.storage = options["image_texture_storage"]
		tx.lossy_quality = options["image_texture_lossy_quality"]
		tx.create_from_image(f.content, flags)
		root.set_frame_texture(i, tx)
	return ResourceSaver.save(save_path + ".res", root)
