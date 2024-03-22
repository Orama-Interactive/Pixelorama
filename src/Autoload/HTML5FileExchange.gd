extends Node
## Code taken and modified from https://github.com/Pukkah/HTML5-File-Exchange-for-Godot
## Thanks to Pukkah from GitHub for providing the original code

signal in_focus
signal image_loaded  ## Emits a signal for returning loaded image info


func _ready() -> void:
	if OS.has_feature("web"):
		_define_js()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		in_focus.emit()


func _define_js() -> void:
	(
		JavaScriptBridge
		. eval(
			"""
	var fileData;
	var fileType;
	var fileName;
	var canceled;
	function upload_image() {
		canceled = true;
		var input = document.createElement('INPUT');
		input.setAttribute("type", "file");
		input.setAttribute(
			"accept", ".pxo, image/png, image/jpeg, image/webp, image/bmp, image/x-tga"
		);
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
	""",
			true
		)
	)


## If (load_directly = false) then image info (image and its name)
## will not be directly forwarded it to OpenSave
func load_image(load_directly := true) -> void:
	if !OS.has_feature("web"):
		return
	# Execute JS function
	JavaScriptBridge.eval("upload_image();", true)  # Opens prompt for choosing file
	await in_focus  # Wait until JS prompt is closed
	await get_tree().create_timer(0.5).timeout  # Give some time for async JS data load

	if JavaScriptBridge.eval("canceled;", true) == 1:  # If File Dialog closed w/o file
		return

	# Use data from png data
	var image_data: PackedByteArray
	while true:
		image_data = JavaScriptBridge.eval("fileData;", true)
		if image_data != null:
			break
		await get_tree().create_timer(1.0).timeout  # Need more time to load data

	var image_type: String = JavaScriptBridge.eval("fileType;", true)
	var image_name: String = JavaScriptBridge.eval("fileName;", true)

	var image := Image.new()
	var image_error: Error
	var image_info := {}
	match image_type:
		"image/png":
			if load_directly:
				# In this case we can afford to try APNG,
				# because we know we're sending it through OpenSave handling.
				# Otherwise we could end up passing something incompatible.
				var res := AImgIOAPNGImporter.load_from_buffer(image_data)
				if res[0] == null:
					# Success, pass to OpenSave.
					OpenSave.handle_loading_aimg(image_name, res[1])
					return
			image_error = image.load_png_from_buffer(image_data)
		"image/jpeg":
			image_error = image.load_jpg_from_buffer(image_data)
		"image/webp":
			image_error = image.load_webp_from_buffer(image_data)
		"image/bmp":
			image_error = image.load_bmp_from_buffer(image_data)
		"image/x-tga":
			image_error = image.load_tga_from_buffer(image_data)
		var invalid_type:
			if image_name.get_extension().to_lower() == "pxo":
				var temp_file_path := "user://%s" % image_name
				var temp_file := FileAccess.open(temp_file_path, FileAccess.WRITE)
				temp_file.store_buffer(image_data)
				temp_file.close()
				OpenSave.open_pxo_file(temp_file_path)
				DirAccess.remove_absolute(temp_file_path)
				return
			print("Invalid type: " + invalid_type)
			return
	if image_error:
		print("An error occurred while trying to display the image.")
		return
	else:
		image_info = {"image": image, "name": image_name}
		if load_directly:
			OpenSave.handle_loading_image(image_name, image)
	image_loaded.emit(image_info)


func load_shader() -> void:
	if !OS.has_feature("web"):
		return

	# Execute JS function
	JavaScriptBridge.eval("upload_shader();", true)  # Opens prompt for choosing file

	await in_focus  # Wait until JS prompt is closed
	await get_tree().create_timer(0.5).timeout  # Give some time for async JS data load

	if JavaScriptBridge.eval("canceled;", true):  # If File Dialog closed w/o file
		return

	# Use data from png data
	var file_data
	while true:
		file_data = JavaScriptBridge.eval("fileData;", true)
		if file_data != null:
			break
		await get_tree().create_timer(1.0).timeout  # Need more time to load data

#	var file_type = JavaScriptBridge.eval("fileType;", true)
	var file_name = JavaScriptBridge.eval("fileName;", true)

	var shader := Shader.new()
	shader.code = file_data

	var shader_effect_dialog = Global.control.get_node("Dialogs/ImageEffects/ShaderEffect")
	if is_instance_valid(shader_effect_dialog):
		shader_effect_dialog.change_shader(shader, file_name.get_basename())
