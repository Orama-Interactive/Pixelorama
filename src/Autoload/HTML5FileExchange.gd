extends Node
# Code taken and modified from https://github.com/Pukkah/HTML5-File-Exchange-for-Godot
# Thanks to Pukkah from GitHub for providing the original code

signal InFocus


func _ready() -> void:
	if OS.get_name() == "HTML5" and OS.has_feature('JavaScript'):
		_define_js()


func _notification(notification:int) -> void:
	if notification == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		emit_signal("InFocus")


func _define_js() -> void:
	# Define JS script
	JavaScript.eval("""
	var fileData;
	var fileType;
	var fileName;
	var canceled;
	function upload_image() {
		canceled = true;
		var input = document.createElement('INPUT');
		input.setAttribute("type", "file");
		input.setAttribute("accept", "image/png, image/jpeg, image/webp");
		input.click();
		input.addEventListener('change', event => {
			if (event.target.files.length > 0){
				canceled = false;}
			var file = event.target.files[0];
			var reader = new FileReader();
			fileType = file.type;
			fileName = file.name;
			reader.readAsArrayBuffer(file);
			reader.onloadend = function (evt) {
				if (evt.target.readyState == FileReader.DONE) {
					fileData = evt.target.result;
				}
			}
		  });
	}
	function upload_palette() {
		canceled = true;
		var input = document.createElement('INPUT');
		input.setAttribute("type", "file");
		input.setAttribute("accept", "application/json, .gpl, .pal, image/png, image/jpeg, image/webp");
		input.click();
		input.addEventListener('change', event => {
			if (event.target.files.length > 0){
				canceled = false;}
			var file = event.target.files[0];
			var reader = new FileReader();
			fileType = file.type;
			fileName = file.name;
			if (fileType == "image/png" || fileType == "image/jpeg" || fileType == "image/webp"){
				reader.readAsArrayBuffer(file);
			}
			else {
				reader.readAsText(file);
			}
			reader.onloadend = function (evt) {
				if (evt.target.readyState == FileReader.DONE) {
					fileData = evt.target.result;
				}
			}
		  });
	}
	function upload_shader() {
		canceled = true;
		var input = document.createElement('INPUT');
		input.setAttribute("type", "file");
		input.setAttribute("accept", ".shader");
		input.click();
		input.addEventListener('change', event => {
			if (event.target.files.length > 0){
				canceled = false;}
			var file = event.target.files[0];
			var reader = new FileReader();
			fileType = file.type;
			fileName = file.name;
			reader.readAsText(file);
			reader.onloadend = function (evt) {
				if (evt.target.readyState == FileReader.DONE) {
					fileData = evt.target.result;
				}
			}
		  });
	}
	function download(fileName, byte, type) {
		var buffer = Uint8Array.from(byte);
		var blob = new Blob([buffer], { type: type});
		var link = document.createElement('a');
		link.href = window.URL.createObjectURL(blob);
		link.download = fileName;
		link.click();
	};
	""", true)


func load_image() -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	# Execute JS function
	JavaScript.eval("upload_image();", true) # Opens prompt for choosing file

	yield(self, "InFocus") # Wait until JS prompt is closed

	yield(get_tree().create_timer(0.5), "timeout") # Give some time for async JS data load

	if JavaScript.eval("canceled;", true): # If File Dialog closed w/o file
		return

	# Use data from png data
	var image_data
	while true:
		image_data = JavaScript.eval("fileData;", true)
		if image_data != null:
			break
		yield(get_tree().create_timer(1.0), "timeout") # Need more time to load data

	var image_type = JavaScript.eval("fileType;", true)
	var image_name = JavaScript.eval("fileName;", true)

	var image = Image.new()
	var image_error
	match image_type:
		"image/png":
			image_error = image.load_png_from_buffer(image_data)
		"image/jpeg":
			image_error = image.load_jpg_from_buffer(image_data)
		"image/webp":
			image_error = image.load_webp_from_buffer(image_data)
		var invalid_type:
			print("Invalid type: " + invalid_type)
			return
	if image_error:
		print("An error occurred while trying to display the image.")
		return
	else:
		OpenSave.handle_loading_image(image_name, image)


func load_palette() -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	# Execute JS function
	JavaScript.eval("upload_palette();", true) # Opens prompt for choosing file

	yield(self, "InFocus") # Wait until JS prompt is closed

	yield(get_tree().create_timer(0.5), "timeout") # Give some time for async JS data load

	if JavaScript.eval("canceled;", true): # If File Dialog closed w/o file
		return

	# Use data from palette file data
	var palette_data
	while true:
		palette_data = JavaScript.eval("fileData;", true)
		if palette_data != null:
			break
		yield(get_tree().create_timer(1.0), "timeout") # Need more time to load data

	var file_type = JavaScript.eval("fileType;", true)
	var file_name = JavaScript.eval("fileName;", true)
	if file_name.ends_with(".gpl"):
		var palette := Palette.new()
		palette = Import.import_gpl(file_name, palette_data)
		Global.palette_container.attempt_to_import_palette(palette)
	elif file_name.end_with(".pal"):
		var palette := Palette.new()
		palette = Import.import_pal_palette(file_name, palette_data)
		Global.palette_container.attempt_to_import_palette(palette)
	else:
		match file_type:
			"image/png":
				var image := Image.new()
				var err = image.load_png_from_buffer(palette_data)
				if !err:
					Global.palette_container.import_image_palette(file_name, image)
			"application/json":
				var palette : Palette = Palette.new().deserialize(palette_data)
				palette.source_path = file_name
				Global.palette_container.attempt_to_import_palette(palette)
			var invalid_type:
				print("Invalid type: " + invalid_type)
				return


func save_image(image : Image, file_name : String = "export") -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	var png_data = Array(image.save_png_to_buffer())
	JavaScript.eval("download('%s', %s, 'image/png');" % [file_name, str(png_data)], true)


func save_gif(data, file_name : String = "export") -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	JavaScript.eval("download('%s', %s, 'image/gif');" % [file_name, str(Array(data))], true)


func load_shader() -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	# Execute JS function
	JavaScript.eval("upload_shader();", true) # Opens prompt for choosing file

	yield(self, "InFocus") # Wait until JS prompt is closed

	yield(get_tree().create_timer(0.5), "timeout") # Give some time for async JS data load

	if JavaScript.eval("canceled;", true): # If File Dialog closed w/o file
		return

	# Use data from png data
	var file_data
	while true:
		file_data = JavaScript.eval("fileData;", true)
		if file_data != null:
			break
		yield(get_tree().create_timer(1.0), "timeout") # Need more time to load data

#	var file_type = JavaScript.eval("fileType;", true)
	var file_name = JavaScript.eval("fileName;", true)

	var shader = Shader.new()
	shader.code = file_data

	var shader_effect_dialog = Global.control.get_node("Dialogs/ImageEffects/ShaderEffect")
	shader_effect_dialog.change_shader(shader, file_name.get_basename())

