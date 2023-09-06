extends Panel


var extension_container :VBoxContainer
var thumbnail := ""
var download_link := ""
var download_path := ""
var tags := PackedStringArray()
var is_update = false  # An update instead of download

@onready var ext_name = $Panel/HBoxContainer/VBoxContainer/Name
@onready var ext_discription = $Panel/HBoxContainer/VBoxContainer/Description
@onready var ext_picture = $Panel/HBoxContainer/Picture
@onready var down_button = $Panel/HBoxContainer/VBoxContainer/Download
@onready var extension_downloader = $DownloadRequest

signal tags_detected

func set_info(info: Array, extension_path: String) -> void:
	ext_name.text = str(info[0], "-v", info[1])  # Name with version
	change_button_if_updatable(info[0], info[1])
	ext_discription.text = info[2]  # Description
	ext_discription.tooltip_text = ext_discription.text
	thumbnail = info[-2]  # Image link
	download_link = info[-1]  # Download link

	# Check for non-compulsory things if they exist
	for item in info:
		if typeof(item) == TYPE_ARRAY:
			# first array element should always be an identifier text type
			var identifier = item.pop_front()
			if identifier:
				# check for tags
				if identifier == "Tags":
					tags.append_array(item)
					emit_signal("tags_detected", tags)


	DirAccess.make_dir_recursive_absolute(str(extension_path,"Download/"))
	download_path = str(extension_path,"Download/",info[0],".pck")

	$RequestDelay.wait_time = randf() * 2 # to prevent sending bulk requests
	$RequestDelay.start()


func _on_RequestDelay_timeout() -> void:
	$RequestDelay.queue_free() # node no longer needed
	var _error = $ImageRequest.request(thumbnail) #image


func _on_ImageRequest_request_completed(_result, _response_code, _headers, body: PackedByteArray) -> void:
	# Update the recieved image
	$ImageRequest.queue_free()
	var image = Image.new()
	# for images on internet there is a hagh chance that extension is wrong
	# so check all of them even if they give error
	var _error = image.load_png_from_buffer(body)
	if _error != OK:
		var _err1 = image.load_jpg_from_buffer(body)
		if _err1 != OK:
			var _err2 = image.load_webp_from_buffer(body)
			if _err2 != OK:
				var _err3 = image.load_tga_from_buffer(body)
				if _err3 != OK:
					var _err4 = image.load_bmp_from_buffer(body)
	var texture = ImageTexture.create_from_image(image)
	ext_picture.texture_normal = texture
	ext_picture.connect("pressed", Callable(self, "enlarge_thumbnail").bind(texture))


func _on_Download_pressed() -> void:
	# Download File
	down_button.disabled = true
	extension_downloader.download_file = download_path
	extension_downloader.request(download_link)
	prepare_progress()


# CALLED AFTER THE EXTENSION DOWNLOADER HAS FINISHED IT'S JOB
func _on_DownloadRequest_request_completed(result: int, _response_code, _headers, _body) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		# Add extension
		extension_container.install_extension(download_path)
		if is_update:
			is_update = false
		announce_done(true)
	else:
		$Alert/Text.text = str("Unable to Download extension...\nHttp Code (",result,")").c_unescape()
		$Alert.popup_centered()
		announce_done(false)
	DirAccess.remove_absolute(download_path)


# UPDATES THE ENTRY NODE'S UI
func announce_done(success: bool):
	close_progress()
	down_button.disabled = false
	if success:
		$Panel/HBoxContainer/VBoxContainer/Done.visible = true
		down_button.text = "Re-Download"
		$DoneDelay.start()


# returns true if entry contains ALL tags in tag_array
func tags_match(tag_array: PackedStringArray):
	if tags.size() > 0:
		for tag in tag_array:
			if !tag in tags:
				return false
		return true
	else:
		if tag_array.size() > 0:
			return false
		return true


# UPDATES THE ENTRY NODE'S UI IF IT HAS AN UPDATE AVAILABLE
func change_button_if_updatable(name: String, new_version: float):
	for extension in extension_container.extensions.keys():
		if extension_container.extensions[extension].file_name == name:
			var old_version = str_to_var(extension_container.extensions[extension].version)
			if typeof(old_version) == TYPE_FLOAT:
				if new_version > old_version:
					down_button.text = "Update"
					is_update = true
				elif new_version == old_version:
					down_button.text = "Re-Download"


# Show an enlarged version of the thumbnail
func enlarge_thumbnail(texture: ImageTexture):
	$"%Enlarged".texture = texture
	$"%Enlarged".get_parent().popup_centered()


# A BEAUTIFICATION FUNCTION THAT HIDES "Done" label BAR AFTER SOME TIME
func _on_DoneDelay_timeout() -> void:
	$Panel/HBoxContainer/VBoxContainer/Done.visible = false


# PROGRESS BAR METHOD
func prepare_progress():
	$Panel/HBoxContainer/VBoxContainer/ProgressBar.visible = true
	$Panel/HBoxContainer/VBoxContainer/ProgressBar.value = 0
	$Panel/HBoxContainer/VBoxContainer/ProgressBar/ProgressTimer.start()


# PROGRESS BAR METHOD
func update_progress():
	var down = extension_downloader.get_downloaded_bytes()
	var total = extension_downloader.get_body_size()
	$Panel/HBoxContainer/VBoxContainer/ProgressBar.value = (float(down) / float(total)) * 100.0


# PROGRESS BAR METHOD
func close_progress():
	$Panel/HBoxContainer/VBoxContainer/ProgressBar.visible = false
	$Panel/HBoxContainer/VBoxContainer/ProgressBar/ProgressTimer.stop()


# PROGRESS BAR METHOD
func _on_ProgressTimer_timeout():
	update_progress()


func _manage_enlarded_thumbnail_close() -> void:
	$EnlardedThumbnail.hide()


func _manage_alert_close() -> void:
	$Alert.hide()
