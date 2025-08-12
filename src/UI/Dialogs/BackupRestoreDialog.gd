extends Window

const MONTHS := [
	"JANUARY",
	"FEBRUARY",
	"MARCH",
	"APRIL",
	"MAY",
	"JUNE",
	"JULY",
	"AUGUST",
	"SEPTEMBER",
	"OCTOBER",
	"NOVEMBER",
	"DECEMBER"
]

var selected_session: String
var session_directories: Array
var session_project_files: Array

@onready var sessions_list: ItemList = %sessions
@onready var projects_list: ItemList = %projects


func _on_about_to_popup() -> void:
	populate_info()


func _on_visibility_changed() -> void:
	if visible:
		return
	Global.dialog_open(false)


func populate_info():
	sessions_list.clear()
	projects_list.clear()
	projects_visible(false)
	session_directories = DirAccess.get_directories_at(OpenSave.BACKUPS_DIRECTORY)
	session_directories.reverse()

	for i in session_directories.size():
		if i == 0:
			sessions_list.add_item("(Current Session)")
		else:
			sessions_list.add_item(humanize_session_name(session_directories[i]))


func humanize_session_name(session_name: StringName) -> StringName:
	var info_array = session_name.split("_", false)
	var year := int(info_array[0])
	# using clamp here just to make sure this doesn't cause any problems
	var month_name: String = MONTHS[clamp(int(info_array[1]) - 1, 0, 11)]
	var day := int(info_array[2])
	var hour := int(info_array[3])
	var minute := int(info_array[4])
	var second := int(info_array[5])

	var prefix = ""
	var current_datetime := Time.get_datetime_dict_from_system()
	if (
		year == current_datetime.year
		and int(info_array[1]) == current_datetime.month
		and day == current_datetime.day
	):
		var lapse_prefix = " hr ago"
		var diff = current_datetime.hour - hour
		if diff == 0:
			lapse_prefix = " min ago"
			diff = current_datetime.minute - minute
			if diff == 0:
				lapse_prefix = " sec ago"
				diff = current_datetime.second - second
		prefix = str("(", diff, lapse_prefix, ")")

	return str(day, " ", month_name.capitalize(), " ", year, "    ", prefix)


func load_session(index: int) -> void:
	var session_path = OpenSave.BACKUPS_DIRECTORY.path_join(session_directories[index])
	for project_file in DirAccess.get_files_at(session_path):
		# Load the project
		OpenSave.open_pxo_file(session_path.path_join(project_file), false, false)

		# remove the project's save_path so that uses doesn't accidentally save IN the
		# backup folder
		var added_project = Global.projects[-1]
		if added_project.name == project_file.get_basename():
			added_project.save_path = ""


func update_project_list(index: int) -> void:
	projects_list.clear()
	selected_session = session_directories[index]
	session_project_files = DirAccess.get_files_at(
		OpenSave.BACKUPS_DIRECTORY.path_join(selected_session)
	)
	for project_file in session_project_files:
		projects_list.add_item(project_file.get_basename())
	projects_visible(true)


func load_project(index: int) -> void:
	# Load the project
	var p_path = OpenSave.BACKUPS_DIRECTORY.path_join(selected_session).path_join(
		session_project_files[index]
	)
	OpenSave.open_pxo_file(p_path, false, false)
	# remove the project's save_path so that uses doesn't accidentally save IN the
	# backup folder
	var added_project = Global.projects[-1]
	if added_project.name == session_project_files[index].get_basename():
		added_project.save_path = ""


func _on_close_requested() -> void:
	hide()


func projects_visible(value: bool):
	$PanelContainer/VBoxContainer/GridContainer/ProjectsLabel.visible = value
	projects_list.visible = true
	var grid := $PanelContainer/VBoxContainer/GridContainer as GridContainer
	if value:
		grid.columns = 2
		return
	grid.columns = 1
