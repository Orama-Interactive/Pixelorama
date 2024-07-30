extends VBoxContainer

@export var preferences_dialog: AcceptDialog
@export var add_extension_file_dialog: FileDialog

@onready var extensions := Global.control.get_node("Extensions") as Extensions
@onready var extension_list := $InstalledExtensions as ItemList
@onready var enable_button := $HBoxContainer/EnableButton as Button
@onready var uninstall_button := $HBoxContainer/UninstallButton as Button
@onready var enable_confirmation := %EnableExtensionConfirmation as ConfirmationDialog
@onready var delete_confirmation := %DeleteExtensionConfirmation as ConfirmationDialog


func _ready() -> void:
	for extension_name: String in extensions.extensions:
		var extension: Extensions.Extension = extensions.extensions[extension_name]
		_extension_loaded(extension, extension_name)
	extensions.extension_loaded.connect(_extension_loaded)
	extensions.extension_uninstalled.connect(_extension_uninstalled)
	delete_confirmation.add_button("Move to Trash", false, Extensions.BIN_ACTION)
	if OS.get_name() == "Web":
		$HBoxContainer/AddExtensionButton.disabled = true
		$HBoxContainer/OpenFolderButton.visible = false


func _extension_loaded(extension: Extensions.Extension, extension_name: String) -> void:
	extension_list.add_item(extension.display_name)
	var item_count := extension_list.get_item_count() - 1
	var tooltip = (
		"""
Version: %s
Author: %s
Description: %s
License: %s
"""
		% [str(extension.version), extension.author, extension.description, extension.license]
	)
	extension_list.set_item_tooltip(item_count, tooltip)
	extension_list.set_item_metadata(item_count, extension_name)


func _extension_uninstalled(extension_name: String) -> void:
	var item := -1
	for i in extension_list.get_item_count():
		if extension_list.get_item_metadata(i) == extension_name:
			item = i
			break
	if item == -1:
		print("Failed to find extension %s" % extension_name)
		return
	extension_list.remove_item(item)
	enable_button.disabled = true
	uninstall_button.disabled = true


func _on_InstalledExtensions_item_selected(index: int) -> void:
	extensions.extension_selected = index
	var file_name: String = extension_list.get_item_metadata(extensions.extension_selected)
	var extension: Extensions.Extension = extensions.extensions[file_name]
	if extension.enabled:
		enable_button.text = "Disable"
	else:
		enable_button.text = "Enable"
	enable_button.disabled = false
	if !extension.internal:
		uninstall_button.disabled = false
	else:
		uninstall_button.disabled = true


func _on_InstalledExtensions_empty_clicked(_position: Vector2, _button_index: int) -> void:
	extension_list.deselect_all()  # Clicking empty won't deselect by default, so doing it manually.
	enable_button.disabled = true
	uninstall_button.disabled = true


func _on_AddExtensionButton_pressed() -> void:
	add_extension_file_dialog.popup_centered()


func _on_EnableButton_pressed() -> void:
	var file_name: String = extension_list.get_item_metadata(extensions.extension_selected)
	var extension: Extensions.Extension = extensions.extensions[file_name]
	# Don't allow disabling internal extensions through this button.
	if extension.internal and extension.enabled_once:
		preferences_dialog.preference_update(true)
	else:
		if extension.enabled:  # If enabled, disable
			extension.enabled = false
			extensions.enable_extension(extension)
			enable_button.text = "Enable"
		else:  # If disabled, ask for user confirmation to enable
			if enable_confirmation.confirmed.is_connected(
				_on_enable_extension_confirmation_confirmed
			):
				enable_confirmation.confirmed.disconnect(
					_on_enable_extension_confirmation_confirmed
				)
			enable_confirmation.confirmed.connect(
				_on_enable_extension_confirmation_confirmed.bind(extension)
			)
			enable_confirmation.popup_centered()


func _on_UninstallButton_pressed() -> void:
	delete_confirmation.popup_centered()


func _on_OpenFolderButton_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(extensions.EXTENSIONS_PATH))


func _on_AddExtensionFileDialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		extensions.install_extension(path)


func _on_delete_confirmation_custom_action(action: StringName) -> void:
	if action == Extensions.BIN_ACTION:
		var extension_name: String = extension_list.get_item_metadata(extensions.extension_selected)
		extensions.uninstall_extension(extension_name, Extensions.UninstallMode.FILE_TO_BIN)
	delete_confirmation.hide()


func _on_enable_extension_confirmation_confirmed(extension: Extensions.Extension) -> void:
	extension.enabled = true
	extensions.enable_extension(extension)
	enable_button.text = "Disable"
	enable_confirmation.confirmed.disconnect(_on_enable_extension_confirmation_confirmed)


func _on_delete_confirmation_confirmed() -> void:
	extensions.uninstall_extension(extension_list.get_item_metadata(extensions.extension_selected))
