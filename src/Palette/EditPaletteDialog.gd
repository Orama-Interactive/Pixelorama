extends ConfirmationDialog

## Emitted when the user confirms their changes
signal saved(name: String, comment: String, width: int, height: int)
## Emitted when the user deletes a palette
signal deleted
## Emitted when the user exports a palette
signal exported(path: String)

const EXPORT_ACTION := &"export"
const DELETE_ACTION := &"delete"
const BIN_ACTION := &"trash"

# Keeps original size of edited palette
var origin_width := 0
var origin_height := 0

var old_name := ""

@onready var name_input := $VBoxContainer/PaletteMetadata/Name
@onready var comment_input := $VBoxContainer/PaletteMetadata/Comment
@onready var width_input := $VBoxContainer/PaletteMetadata/Width
@onready var height_input := $VBoxContainer/PaletteMetadata/Height
@onready var path_input := $VBoxContainer/PaletteMetadata/Path

@onready var size_reduced_warning := $VBoxContainer/SizeReducedWarning
@onready var already_exists_warning := $VBoxContainer/AlreadyExistsWarning
@onready var delete_confirmation := $DeleteConfirmation
@onready var export_file_dialog: FileDialog = $ExportFileDialog


func _ready() -> void:
	export_file_dialog.use_native_dialog = Global.use_native_file_dialogs
	# Add delete and export buttons to edit palette dialog
	add_button("Delete", false, DELETE_ACTION)
	add_button("Export", false, EXPORT_ACTION)
	delete_confirmation.add_button("Move to Trash", false, BIN_ACTION)


func open(current_palette: Palette) -> void:
	if current_palette:
		name_input.text = current_palette.name
		comment_input.text = current_palette.comment
		width_input.value = current_palette.width
		height_input.value = current_palette.height
		path_input.text = current_palette.path
		export_file_dialog.current_file = current_palette.name

		# Store original size so it can be compared with changed values
		# and warning can be shown if it is reduced
		origin_width = current_palette.width
		origin_height = current_palette.height
		toggle_size_reduced_warning(false)

		# Hide warning
		old_name = current_palette.name
		toggle_already_exists_warning(false)

		# Stop all inputs in the rest of the app
		Global.dialog_open(true)
		popup_centered()


## Shows/hides a warning when palette size is being reduced
func toggle_size_reduced_warning(to_show: bool) -> void:
	size_reduced_warning.visible = to_show
	# Required to resize window to correct size if warning causes content overflow
	size = size


## Shows/hides a warning when palette already exists
func toggle_already_exists_warning(to_show: bool) -> void:
	already_exists_warning.visible = to_show

	# Disable confirm button so user cannot save
	get_ok_button().disabled = to_show

	# Required to resize window to correct size if warning causes content overflow
	size = size


func _on_EditPaletteDialog_visibility_changed() -> void:
	Global.dialog_open(visible)


func _on_EditPaletteDialog_confirmed() -> void:
	saved.emit(name_input.text, comment_input.text, width_input.value, height_input.value)


func _on_EditPaletteDialog_custom_action(action: StringName) -> void:
	if action == DELETE_ACTION:
		delete_confirmation.popup_centered()
	elif action == EXPORT_ACTION:
		if OS.has_feature("web"):
			exported.emit()
		else:
			export_file_dialog.popup_centered()


func _on_delete_confirmation_confirmed() -> void:
	deleted.emit(true)
	delete_confirmation.hide()
	hide()


func _on_delete_confirmation_custom_action(action: StringName) -> void:
	if action == BIN_ACTION:
		deleted.emit(false)
		delete_confirmation.hide()
		hide()


func _on_size_value_changed(_value: int):
	# Toggle resize warning label if palette size was reduced
	var size_decreased: bool = (
		height_input.value < origin_height or width_input.value < origin_width
	)
	toggle_size_reduced_warning(size_decreased)


func _on_Name_text_changed(new_name: String):
	if old_name != new_name:
		if Palettes.does_palette_exist(new_name):
			toggle_already_exists_warning(true)
		else:
			toggle_already_exists_warning(false)

		# Disable ok button on empty name
		if new_name == "":
			get_ok_button().disabled = true


func _on_export_file_dialog_file_selected(path: String) -> void:
	exported.emit(path)
