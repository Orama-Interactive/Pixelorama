extends Window

## Usage:
## Change the "STORE_NAME" and "STORE_LINK"
## Don't touch anything else

const STORE_NAME := "Extension Explorer"
# gdlint: ignore=max-line-length
const STORE_LINK := "https://raw.githubusercontent.com/Orama-Interactive/PixeloramaExtensionRepository/main/extension_repository.md"
## File that will contain information about extensions available for download
const STORE_INFORMATION_FILE := STORE_NAME + ".md"
const EXTENSION_ENTRY_TSCN := preload("res://src/UI/ExtensionExplorer/Entry/ExtensionEntry.tscn")

# Variables placed here due to their frequent use
var _extension_path := ProjectSettings.globalize_path(Extensions.EXTENSIONS_PATH)
var _custom_links_remaining: int  ## Remaining custom links to be processed
var _redirects: Array[String]
var _faulty_custom_links: Array[String]
var _extension_name_sorter: PackedStringArray

# node references used in this script
@onready var content: VBoxContainer = $"%Content"
@onready var store_info_downloader: HTTPRequest = %StoreInformationDownloader
@onready var main_store_link: LineEdit = %MainStoreLink
@onready var custom_store_links: VBoxContainer = %CustomStoreLinks
@onready var search_manager: LineEdit = %SearchManager
@onready var tab_container: TabContainer = %TabContainer
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var update_timer: Timer = %UpdateTimer
@onready var faulty_links_label: Label = %FaultyLinks
@onready var custom_link_error: AcceptDialog = %ErrorCustom
@onready var error_get_info: AcceptDialog = %Error


func _ready() -> void:
	# Basic setup
	main_store_link.text = STORE_LINK
	# tell the downloader where to download the repository information
	store_info_downloader.download_file = _extension_path.path_join(STORE_INFORMATION_FILE)


func _on_Store_about_to_show() -> void:
	fetch_repositories()


func fetch_repositories() -> void:
	# Clear old tags
	search_manager.available_tags = PackedStringArray()
	for tag in search_manager.tag_list.get_children():
		tag.queue_free()
	# Clear old entries
	for entry in content.get_children():
		entry.queue_free()
	_faulty_custom_links.clear()
	_custom_links_remaining = custom_store_links.custom_links.size()
	_extension_name_sorter.clear()
	fetch_info(STORE_LINK)


func _on_close_requested() -> void:
	hide()


func fetch_info(link: String) -> void:
	if _extension_path != "":  # Did everything went smoothly in _ready() function?
		# everything is ready, now request the repository information
		# so that available extensions could be displayed
		var error := store_info_downloader.request(link)
		if error == OK:
			prepare_progress()
		else:
			printerr("Unable to get info from remote repository.")
			error_getting_info(error)


## Gets called when the extension repository information has finished downloading.
func _on_StoreInformation_request_completed(
	result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		var file_path := _extension_path.path_join(STORE_INFORMATION_FILE)
		# process the info contained in the file
		var file := FileAccess.open(file_path, FileAccess.READ)
		while not file.eof_reached():
			process_line(file.get_line())
		file.close()
		DirAccess.remove_absolute(file_path)
		# Hide the progress bar because it's no longer required
		close_progress()
	else:
		printerr("Unable to get info from remote repository.")
		error_getting_info(result)


func close_progress() -> void:
	progress_bar.get_parent().visible = false
	tab_container.visible = true
	update_timer.stop()
	if _redirects.size() > 0:
		var next_link := _redirects.pop_front() as String
		fetch_info(next_link)
	else:
		# no more redirects, jump to the next store
		_custom_links_remaining -= 1
		if _custom_links_remaining >= 0:
			var next_link: String = custom_store_links.custom_links[_custom_links_remaining]
			fetch_info(next_link)
		else:
			if _faulty_custom_links.size() > 0:  # manage custom faulty links
				faulty_links_label.text = ""
				for link in _faulty_custom_links:
					faulty_links_label.text += str(link, "\n")
				custom_link_error.popup_centered_clamped()


# Signal connected from Preferences.tscn
func _on_explore_pressed() -> void:
	popup_centered_clamped()


## Function related to error dialog
func _on_CopyCommand_pressed() -> void:
	DisplayServer.clipboard_set(
		"sudo flatpak override com.orama_interactive.Pixelorama --share=network"
	)


## Adds a new extension entry to the "content"
func add_entry(info: Dictionary) -> void:
	var entry := EXTENSION_ENTRY_TSCN.instantiate()
	var extension_name: String = info.get("name", "")
	_extension_name_sorter.append(extension_name)
	_extension_name_sorter.sort()
	content.add_child(entry)
	content.move_child(entry, _extension_name_sorter.find(extension_name))
	entry.set_info(info, _extension_path)
	search_manager.add_new_tags(info.get("tags", PackedStringArray()))


## Gets called when data couldn't be fetched from remote repository
func error_getting_info(result: int) -> void:
	# Shows a popup if error is from main link (i-e MainStore)
	# Popups for errors in custom_links are handled in close_progress()
	if _custom_links_remaining == custom_store_links.custom_links.size():
		error_get_info.popup_centered_clamped()
		error_get_info.title = error_string(result)
	else:
		_faulty_custom_links.append(custom_store_links.custom_links[_custom_links_remaining])
	close_progress()


## Progress bar method
func prepare_progress() -> void:
	progress_bar.get_parent().visible = true
	tab_container.visible = false
	progress_bar.value = 0
	update_timer.start()


## Progress bar method
func update_progress() -> void:
	var down := store_info_downloader.get_downloaded_bytes()
	var total := store_info_downloader.get_body_size()
	progress_bar.value = (float(down) / float(total)) * 100.0


## Progress bar method
func _on_UpdateTimer_timeout() -> void:
	update_progress()


# DATA PROCESSORS
func process_line(line: String) -> void:
	# If the line isn't a comment, we will check data type
	var raw_data
	line = line.strip_edges()
	# Attempting to convert to a variable other than a string
	if not line.strip_edges().begins_with("#"):  # This check prevents error Invalid color code: #
		raw_data = str_to_var(line)
	if !raw_data:  # attempt failed, using it as string
		raw_data = line

	# Determine action based on data type
	match typeof(raw_data):
		TYPE_ARRAY:
			var extension_data: Dictionary = parse_extension_data(raw_data)
			add_entry(extension_data)
		TYPE_STRING:
			# it's most probably a repository link
			var link: String = raw_data.strip_edges()
			if !link in _redirects and link.begins_with("http") and "://" in link:
				_redirects.append(link)


func parse_extension_data(raw_data: Array) -> Dictionary:
	var result := {}
	# Check for non-compulsory things if they exist
	for item in raw_data:
		if typeof(item) == TYPE_ARRAY:
			# first array element should always be an identifier text type
			var identifier = item.pop_front()
			if typeof(identifier) == TYPE_STRING and item.size() > 0:
				match identifier:
					"name":
						result["name"] = item[0]
					"version":
						result["version"] = item[0]
					"sha256":
						result["sha256"] = item[0]
					"description":
						result["description"] = item[0]
					"readme":
						result["readme"] = item[0]
					"thumbnail":
						result["thumbnail"] = item[0]
					"download_link":
						result["download_link"] = item[0]
					"tags":  # (this should remain as an array)
						var tags: Array = item.map(
							func(element):
								if typeof(element) == TYPE_STRING:
									return element.capitalize()
						)
						result["tags"] = tags
	return result


func _on_report_issue_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/PixeloramaExtensionRepository/issues")
