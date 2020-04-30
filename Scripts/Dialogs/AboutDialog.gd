extends WindowDialog

onready var credits = $AboutUI/Credits
onready var groups : Tree = $AboutUI/Credits/Groups
onready var developer_container = $AboutUI/Credits/Developers
onready var contributors_container = $AboutUI/Credits/Contributors
onready var donors_container = $AboutUI/Credits/Donors
onready var translators_container = $AboutUI/Credits/Translators

onready var developers : Tree = $AboutUI/Credits/Developers/DeveloperTree
onready var contributors : Tree = $AboutUI/Credits/Contributors/ContributorTree
onready var donors : Tree = $AboutUI/Credits/Donors/DonorTree
onready var translators : Tree = $AboutUI/Credits/Translators/TranslatorTree

func _ready() -> void:
	var contributor_root := contributors.create_item()
	contributors.create_item(contributor_root).set_text(0, "  Hugo Locurcio (Calinou)")
	contributors.create_item(contributor_root).set_text(0, "  CheetoHead (greusser)")
	contributors.create_item(contributor_root).set_text(0, "  Michael Alexsander (YeldhamDev)")
	contributors.create_item(contributor_root).set_text(0, "  Schweini07")
	contributors.create_item(contributor_root).set_text(0, "  Martin Zabinski")
	contributors.create_item(contributor_root).set_text(0, "  azagaya")
	contributors.create_item(contributor_root).set_text(0, "  Andreev Andrei")
	contributors.create_item(contributor_root).set_text(0, "  Martin Novák (novhack)")
	contributors.create_item(contributor_root).set_text(0, "  Marco Galli (Gaarco)")
	contributors.create_item(contributor_root).set_text(0, "  Subhang Nanduri (SbNanduri)")
	contributors.create_item(contributor_root).set_text(0, "  danielnaoexiste")
	contributors.create_item(contributor_root).set_text(0, "  Noah Burck (haonkrub)")
	contributors.create_item(contributor_root).set_text(0, "  Darshan Phaldesai (luiq54)")
	contributors.create_item(contributor_root).set_text(0, "  Matheus Pesegoginski (MatheusPese)")
	contributors.create_item(contributor_root).set_text(0, "  sapient_cogbag")
	contributors.create_item(contributor_root).set_text(0, "  Kinwailo")
	contributors.create_item(contributor_root).set_text(0, "  Igor Santarek (jegor377)")
	contributors.create_item(contributor_root).set_text(0, "  Dávid Gábor BODOR (dragonfi)")

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
	var translators_button := groups.create_item(groups_root)

	developers_button.set_text(0,  "  " + tr("Developers"))
	# We use metadata to avoid being affected by translations
	developers_button.set_metadata(0, "Developers")
	developers_button.select(0)
	contributors_button.set_text(0,  "  " + tr("Contributors"))
	contributors_button.set_metadata(0, "Contributors")
	donors_button.set_text(0,  "  " + tr("Donors"))
	donors_button.set_metadata(0, "Donors")
	translators_button.set_text(0,  "  " + tr("Translators"))
	translators_button.set_metadata(0, "Translators")

	var dev_root := developers.create_item()
	developers.create_item(dev_root).set_text(0, "  Manolis Papadeas (Overloaded) - " + tr("Lead Programmer"))
	developers.create_item(dev_root).set_text(0, "  John Nikitakis (Erevos) - " + tr("UI Designer"))

	# Translators
	var translators_root := translators.create_item()
	translators.create_item(translators_root).set_text(0, "  Manolis Papadeas (Overloaded) - " + tr("Greek"))
	translators.create_item(translators_root).set_text(0, "  Xenofon Konitsas (huskee) - " + tr("Greek"))
	translators.create_item(translators_root).set_text(0, "  Hugo Locurcio (Calinou) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  blackjoker77777 - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Schweini07 - " + tr("German"))
	translators.create_item(translators_root).set_text(0, "  Martin Zabinski (Martin1991zab) - " + tr("German"))
	translators.create_item(translators_root).set_text(0, "  Dawid Niedźwiedzki (tiritto) - " + tr("Polish"))
	translators.create_item(translators_root).set_text(0, "  Serhiy Dmytryshyn (dies) - " + tr("Polish"))
	translators.create_item(translators_root).set_text(0, "  Michael Alexsander (YeldhamDev) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Cedulio Cezar (ceduliocezar) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Andreev Andrei - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  ax trifonov (ax34) - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  Artem (blinovartem) - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  JunYouIntrovert - " + tr("Chinese Traditional"))
	translators.create_item(translators_root).set_text(0, "  Chenxu Wang - " + tr("Chinese Simplified"))
	translators.create_item(translators_root).set_text(0, "  Marco Galli (Gaarco) - " + tr("Italian"))
	translators.create_item(translators_root).set_text(0, "  StarFang208 - " + tr("Italian"))
	translators.create_item(translators_root).set_text(0, "  azagaya - " + tr("Spanish"))
	translators.create_item(translators_root).set_text(0, "  Lilly And (KatieAnd) - " + tr("Spanish"))
	translators.create_item(translators_root).set_text(0, "  Agnis Aldiņš (NeZvers) - " + tr("Latvian"))
	translators.create_item(translators_root).set_text(0, "  Teashrock - " + tr("Esperanto"))

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
	elif "Translators" in selected:
		translators_container.visible = true


func _on_Website_pressed() -> void:
	OS.shell_open("https://www.orama-interactive.com/pixelorama")

func _on_GitHub_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/Pixelorama")

func _on_Donate_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")
