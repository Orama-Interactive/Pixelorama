extends WindowDialog

onready var credits = $AboutUI/Credits
onready var groups : Tree = $AboutUI/Credits/Groups
onready var developer_container = $AboutUI/Credits/Developers
onready var contributors_container = $AboutUI/Credits/Contributors
onready var donors_container = $AboutUI/Credits/Donors

onready var developers : Tree = $AboutUI/Credits/Developers/DeveloperTree
onready var contributors : Tree = $AboutUI/Credits/Contributors/ContributorTree
onready var donors : Tree = $AboutUI/Credits/Donors/DonorTree

func _ready() -> void:
	var contributor_root := contributors.create_item()
	contributors.create_item(contributor_root).set_text(0, "  Hugo Locurcio")
	contributors.create_item(contributor_root).set_text(0, "  CheetoHead")
	contributors.create_item(contributor_root).set_text(0, "  Schweini07")
	contributors.create_item(contributor_root).set_text(0, "  Dawid Niedźwiedzki")
	contributors.create_item(contributor_root).set_text(0, "  Michael Alexsander")
	contributors.create_item(contributor_root).set_text(0, "  Martin Zabinski")
	contributors.create_item(contributor_root).set_text(0, "  azagaya")
	contributors.create_item(contributor_root).set_text(0, "  Andreev Andrei")
	contributors.create_item(contributor_root).set_text(0, "  Gaarco")
	contributors.create_item(contributor_root).set_text(0, "  JunYouIntrovert")
	contributors.create_item(contributor_root).set_text(0, "  Subhang Nanduri")
	contributors.create_item(contributor_root).set_text(0, "  danielnaoexiste")
	contributors.create_item(contributor_root).set_text(0, "  huskee")

	var donors_root := donors.create_item()
	donors.create_item(donors_root).set_text(0, "  pcmxms")
	donors.create_item(donors_root).set_text(0, "  Mike King")

func _on_AboutDialog_about_to_show() -> void:
	var current_version : String = ProjectSettings.get_setting("application/config/Version")
	window_title = tr("About Pixelorama") + " " + current_version

	var groups_root := groups.create_item()
	var developers_button := groups.create_item(groups_root)
	var contributors_button := groups.create_item(groups_root)
	var donors_button := groups.create_item(groups_root)
	developers_button.set_text(0,  "  " + tr("Developers"))
	# We use metadata to avoid being affected by translations
	developers_button.set_metadata(0, "Developers")
	developers_button.select(0)
	contributors_button.set_text(0,  "  " + tr("Contributors"))
	contributors_button.set_metadata(0, "Contributors")
	donors_button.set_text(0,  "  " + tr("Donors"))
	donors_button.set_metadata(0, "Donors")

	var dev_root := developers.create_item()
	developers.create_item(dev_root).set_text(0, "  Manolis Papadeas (Overloaded) - " + tr("Lead Programmer"))
	developers.create_item(dev_root).set_text(0, "  John Nikitakis (Erevos) - " + tr("UI Designer"))

func _on_AboutDialog_popup_hide() -> void:
	groups.clear()
	developers.clear()

func _on_Groups_item_selected() -> void:
	for child in credits.get_children():
		if child != groups:
			child.visible = false

	var selected : String = groups.get_selected().get_metadata(0)
	if "Developers" in selected:
		developer_container.visible = true
	elif "Contributors" in selected:
		contributors_container.visible = true
	elif "Donors" in selected:
		donors_container.visible = true


func _on_Website_pressed() -> void:
	OS.shell_open("https://www.orama-interactive.com/pixelorama")

func _on_GitHub_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/Pixelorama")

func _on_Donate_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")
