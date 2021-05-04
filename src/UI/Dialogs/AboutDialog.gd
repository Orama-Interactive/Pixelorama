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

onready var slogan_label : Label = $AboutUI/IconsButtons/SloganAndLinks/VBoxContainer/PixeloramaSlogan
onready var copyright_label : Label = $AboutUI/Copyright

onready var latin_font_italic = preload("res://assets/fonts/Roboto-Italic.tres")
onready var cjk_font = preload("res://assets/fonts/CJK/DroidSansFallback-Regular.tres")
onready var latin_font_small = preload("res://assets/fonts/Roboto-Small.tres")
onready var cjk_font_small = preload("res://assets/fonts/CJK/DroidSansFallback-Small.tres")


func _ready() -> void:
	create_donors()
	create_contributors()


func _on_AboutDialog_about_to_show() -> void:
	window_title = tr("About Pixelorama") + " " + Global.current_version

	if Global.is_cjk(TranslationServer.get_locale()):
		slogan_label.add_font_override("font", cjk_font)
		copyright_label.add_font_override("font", cjk_font_small)
	else:
		slogan_label.add_font_override("font", latin_font_italic)
		copyright_label.add_font_override("font", latin_font_small)

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

	create_developers()
	create_translators()

func _on_AboutDialog_popup_hide() -> void:
	groups.clear()
	developers.clear()
	translators.clear()


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
	OS.shell_open("https://www.orama-interactive.com")


func _on_GitHub_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/Pixelorama")


func _on_Donate_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")


func create_developers() -> void:
	var dev_root := developers.create_item()
	developers.create_item(dev_root).set_text(0, "  Manolis Papadeas (Overloaded) - " + tr("Lead Programmer"))
	developers.create_item(dev_root).set_text(0, "  John Nikitakis (Erevos) - " + tr("UI Designer"))


func create_donors() -> void:
	var donors_root := donors.create_item()
	donors.create_item(donors_root).set_text(0, "  pcmxms - https://www.nonamefornowsoft.com.br/")
	donors.create_item(donors_root).set_text(0, "  Mike King")
	donors.create_item(donors_root).set_text(0, "  Guillaume Gautier")
	donors.create_item(donors_root).set_text(0, "  Hugo Locurcio")
	donors.create_item(donors_root).set_text(0, "  MysteryStudio")
	donors.create_item(donors_root).set_text(0, "  Ryan C. Gordon (icculus)")
	donors.create_item(donors_root).set_text(0, "  Benedikt")


func create_contributors() -> void:
	var contributor_root := contributors.create_item()
	contributors.create_item(contributor_root).set_text(0, "  Hugo Locurcio (Calinou)")
	contributors.create_item(contributor_root).set_text(0, "  CheetoHead (greusser)")
	contributors.create_item(contributor_root).set_text(0, "  Michael Alexsander (YeldhamDev)")
	contributors.create_item(contributor_root).set_text(0, "  Martin Novák (novhack)")
	contributors.create_item(contributor_root).set_text(0, "  Laurenz Reinthaler (Schweini07)")
	contributors.create_item(contributor_root).set_text(0, "  Darshan Phaldesai (luiq54)")
	contributors.create_item(contributor_root).set_text(0, "  kleonc")
	contributors.create_item(contributor_root).set_text(0, "  azagaya")
	contributors.create_item(contributor_root).set_text(0, "  Kinwailo")
	contributors.create_item(contributor_root).set_text(0, "  Igor Santarek (jegor377)")
	contributors.create_item(contributor_root).set_text(0, "  Xenofon Konitsas (huskee)")
	contributors.create_item(contributor_root).set_text(0, "  Martin Zabinski (Martin1991zab)")
	contributors.create_item(contributor_root).set_text(0, "  Marco Galli (Gaarco)")
	contributors.create_item(contributor_root).set_text(0, "  Fayez Akhtar (Variable)")
	contributors.create_item(contributor_root).set_text(0, "  Matheus Pesegoginski (MatheusPese)")
	contributors.create_item(contributor_root).set_text(0, "  AbhinavKDev (abhinav3967)")
	contributors.create_item(contributor_root).set_text(0, "  sapient_cogbag")
	contributors.create_item(contributor_root).set_text(0, "  dasimonde")
	contributors.create_item(contributor_root).set_text(0, "  Matthew Paul (matthewpaul-us)")
	contributors.create_item(contributor_root).set_text(0, "  danielnaoexiste")
	contributors.create_item(contributor_root).set_text(0, "  PinyaColada")
	contributors.create_item(contributor_root).set_text(0, "  Subhang Nanduri (SbNanduri)")
	contributors.create_item(contributor_root).set_text(0, "  Dávid Gábor BODOR (dragonfi)")
	contributors.create_item(contributor_root).set_text(0, "  John Jerome Romero (Wishdream)")
	contributors.create_item(contributor_root).set_text(0, "  Andreev Andrei")
	contributors.create_item(contributor_root).set_text(0, "  Aaron Franke (aaronfranke)")
	contributors.create_item(contributor_root).set_text(0, "  rob-a-bolton")
	contributors.create_item(contributor_root).set_text(0, "  Vriska Weaver (henlo-birb)")
	contributors.create_item(contributor_root).set_text(0, "  Rémi Verschelde (akien-mga)")
	contributors.create_item(contributor_root).set_text(0, "  gschwind")
	contributors.create_item(contributor_root).set_text(0, "  THWLF")
	contributors.create_item(contributor_root).set_text(0, "  Gamespleasure")
	contributors.create_item(contributor_root).set_text(0, "  ballerburg9005")
	contributors.create_item(contributor_root).set_text(0, "  DragonOfWar")
	contributors.create_item(contributor_root).set_text(0, "  kevinms")


func create_translators() -> void:
	var translators_root := translators.create_item()
	translators.create_item(translators_root).set_text(0, "  Manolis Papadeas (Overloaded) - " + tr("Greek"))
	translators.create_item(translators_root).set_text(0, "  Xenofon Konitsas (huskee) - " + tr("Greek"))
	translators.create_item(translators_root).set_text(0, "  Lena Louloudaki (Soliscital) - " + tr("Greek"))
	translators.create_item(translators_root).set_text(0, "  Hugo Locurcio (Calinou) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  blackjoker77777 - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Yoshiip (myoshipro) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Iorvethe - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Paul Coral (lepaincestbon) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  RED (REDOOO) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Aidan Olsen (PossiblyAShrub) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Jean-Loup Macarit (leyk973) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Lulullia (lulullia902) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Nicolas.C (nico57c) - " + tr("French"))
	translators.create_item(translators_root).set_text(0, "  Schweini07 - " + tr("German"))
	translators.create_item(translators_root).set_text(0, "  Martin Zabinski (Martin1991zab) - " + tr("German"))
	translators.create_item(translators_root).set_text(0, "  Dawid Niedźwiedzki (tiritto) - " + tr("Polish"))
	translators.create_item(translators_root).set_text(0, "  Serhiy Dmytryshyn (dies) - " + tr("Polish"))
	translators.create_item(translators_root).set_text(0, "  Igor Santarek (jegor377) - " + tr("Polish"))
	translators.create_item(translators_root).set_text(0, "  Michael Alexsander (YeldhamDev) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Cedulio Cezar (ceduliocezar) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Alexandre Oliveira (rockytvbr) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  IagoAndrade - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  chacal_exodius - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Lucas Santiago (lu.santi.oli) - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  TheNoobPro44 - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  DippoZz - " + tr("Brazilian Portuguese"))
	translators.create_item(translators_root).set_text(0, "  Andreev Andrei - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  ax trifonov (ax34) - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  Artem (blinovartem) - " + tr("Russian"))
	translators.create_item(translators_root).set_text(0, "  JunYouIntrovert - " + tr("Chinese Traditional"))
	translators.create_item(translators_root).set_text(0, "  Kinwailo - " + tr("Chinese Traditional"))
	translators.create_item(translators_root).set_text(0, "  Chenxu Wang - " + tr("Chinese Simplified"))
	translators.create_item(translators_root).set_text(0, "  Catherine Yang (qzcyyw13) - " + tr("Chinese Simplified"))
	translators.create_item(translators_root).set_text(0, "  Marco Galli (Gaarco) - " + tr("Italian"))
	translators.create_item(translators_root).set_text(0, "  StarFang208 - " + tr("Italian"))
	translators.create_item(translators_root).set_text(0, "  Azagaya VJ (azagaya.games) - " + tr("Spanish"))
	translators.create_item(translators_root).set_text(0, "  Lilly And (KatieAnd) - " + tr("Spanish"))
	translators.create_item(translators_root).set_text(0, "  UncleFangs - " + tr("Spanish"))
	translators.create_item(translators_root).set_text(0, "  Jaime Arancibia Soto - " + tr("Spanish") + " " + tr("and") + " " + tr("Catalan"))
	translators.create_item(translators_root).set_text(0, "  Agnis Aldiņš (NeZvers) - " + tr("Latvian"))
	translators.create_item(translators_root).set_text(0, "  Edgars Korns (Eddy11) - " + tr("Latvian"))
	translators.create_item(translators_root).set_text(0, "  Teashrock - " + tr("Esperanto"))
	translators.create_item(translators_root).set_text(0, "  Blend_Smile - " + tr("Indonesian"))
	translators.create_item(translators_root).set_text(0, "  Martin Novák (novhack) - " + tr("Czech"))
	translators.create_item(translators_root).set_text(0, "  Lullius - " + tr("Norwegian"))
	translators.create_item(translators_root).set_text(0, "  Aninuscsalas - " + tr("Hungarian"))
	translators.create_item(translators_root).set_text(0, "  jaehyeon1090 - " + tr("Korean"))
	translators.create_item(translators_root).set_text(0, "  sfun_G - " + tr("Korean"))
	translators.create_item(translators_root).set_text(0, "  KripC2160 - " + tr("Korean") + " " + tr("and") + " " + tr("Japanese"))
	translators.create_item(translators_root).set_text(0, "  daisuke osada (barlog) - " + tr("Japanese"))
	translators.create_item(translators_root).set_text(0, "  Motomo.exe - " + tr("Japanese"))
	translators.create_item(translators_root).set_text(0, "  hebekeg - " + tr("Japanese"))
	translators.create_item(translators_root).set_text(0, "  M. Gabriel Lup - " + tr("Romanian"))
	translators.create_item(translators_root).set_text(0, "  ANormalKnife - " + tr("Turkish"))
	translators.create_item(translators_root).set_text(0, "  kmsecer - " + tr("Turkish"))
	translators.create_item(translators_root).set_text(0, "  Rıdvan SAYLAR - " + tr("Turkish"))
	translators.create_item(translators_root).set_text(0, "  latbat58 - " + tr("Turkish"))
	translators.create_item(translators_root).set_text(0, "  M Buhari Horoz (Sorian01) - " + tr("Turkish"))
	translators.create_item(translators_root).set_text(0, "  br.bahrampour - " + tr("Turkish"))
