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

	# Execute js function
	JavaScript.eval("upload_image();", true) # opens prompt for choosing file

	yield(self, "InFocus") # wait until js prompt is closed

	yield(get_tree().create_timer(0.5), "timeout") #give some time for async js data load

	if JavaScript.eval("canceled;", true): # if File Dialog closed w/o file
		return

	# use data from png data
	var imageData
	while true:
		imageData = JavaScript.eval("fileData;", true)
		if imageData != null:
			break
		yield(get_tree().create_timer(1.0), "timeout") # need more time to load data

	var image_type = JavaScript.eval("fileType;", true)
	var image_name = JavaScript.eval("fileName;", true)

	var image = Image.new()
	var image_error
	match image_type:
		"image/png":
			image_error = image.load_png_from_buffer(imageData)
		"image/jpeg":
			image_error = image.load_jpg_from_buffer(imageData)
		"image/webp":
			image_error = image.load_webp_from_buffer(imageData)
		var invalid_type:
			print(invalid_type)
			return
	if image_error:
		print("An error occurred while trying to display the image.")
		return
	else:
		OpenSave.handle_loading_image(image_name, image)


func save_image(image : Image, file_name : String = "export") -> void:
	if OS.get_name() != "HTML5" or !OS.has_feature('JavaScript'):
		return

	var png_data = Array(image.save_png_to_buffer())
	JavaScript.eval("download('%s', %s, 'image/png');" % [file_name, str(png_data)], true)
