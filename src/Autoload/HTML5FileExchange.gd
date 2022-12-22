extends Node
# Code taken and modified from https://github.com/Pukkah/HTML5-File-Exchange-for-Godot
# Thanks to Pukkah from GitHub for providing the original code

signal in_focus
signal image_loaded  # emits a signal for returning loaded image info


func _ready() -> void:
	if OS.get_name() == "HTML5" and OS.has_feature("JavaScript"):
		_define_js()


func _notification(notification: int) -> void:
	if notification == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		emit_signal("in_focus")


func _define_js() -> void:
	# Define JS script
	JavaScript.eval(
		"""
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


# If (load_directly = false) then image info (image and it's name)
# will not be directly farwarded it to OpenSave
func load_image(load_directly := true):
	if OS.get_name() != "HTML5" or !OS.has_feature("JavaScript"):
		return

	# Execute JS function
	JavaScript.eval("upload_image();", true)  # Opens prompt for choosing file

	yield(self, "in_focus")  # Wait until JS prompt is closed

	yield(get_tree().create_timer(0.5), "timeout")  # Give some time for async JS data load

	if JavaScript.eval("canceled;", true):  # If File Dialog closed w/o file
		return

	# Use data from png data
	var image_data
	while true:
		image_data = JavaScript.eval("fileData;", true)
		if image_data != null:
			break
		yield(get_tree().create_timer(1.0), "timeout")  # Need more time to load data

	var image_type = JavaScript.eval("fileType;", true)
	var image_name = JavaScript.eval("fileName;", true)

	var image = Image.new()
	var image_error
	var image_info: Dictionary = {}
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
		var invalid_type:
			print("Invalid type: " + invalid_type)
			return
	if image_error:
		print("An error occurred while trying to display the image.")
		return
	else:
		image_info = {"image": image, "name": image_name}
		if load_directly:
			OpenSave.handle_loading_image(image_name, image)
	emit_signal("image_loaded", image_info)


func load_shader() -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature("JavaScript"):
		return

	# Execute JS function
	JavaScript.eval("upload_shader();", true)  # Opens prompt for choosing file

	yield(self, "in_focus")  # Wait until JS prompt is closed

	yield(get_tree().create_timer(0.5), "timeout")  # Give some time for async JS data load

	if JavaScript.eval("canceled;", true):  # If File Dialog closed w/o file
		return

	# Use data from png data
	var file_data
	while true:
		file_data = JavaScript.eval("fileData;", true)
		if file_data != null:
			break
		yield(get_tree().create_timer(1.0), "timeout")  # Need more time to load data

#	var file_type = JavaScript.eval("fileType;", true)
	var file_name = JavaScript.eval("fileName;", true)

	var shader = Shader.new()
	shader.code = file_data

	var shader_effect_dialog = Global.control.get_node("Dialogs/ImageEffects/ShaderEffect")
	shader_effect_dialog.change_shader(shader, file_name.get_basename())
