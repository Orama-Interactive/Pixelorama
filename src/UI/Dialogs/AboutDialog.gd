extends WindowDialog

const TRANSLATORS_DICTIONARY := {
	"Emmanouil Papadeas (Overloaded)": ["Greek"],
	"Xenofon Konitsas (huskee)": ["Greek"],
	"Lena Louloudaki (Soliscital)": ["Greek"],
	"Hugo Locurcio (Calinou)": ["French"],
	"blackjoker77777": ["French"],
	"Yoshiip (myoshipro)": ["French"],
	"Iorvethe": ["French"],
	"Paul Coral (lepaincestbon)": ["French"],
	"RED (REDOOO)": ["French"],
	"Aidan Olsen (PossiblyAShrub)": ["French"],
	"Jean-Loup Macarit (leyk973)": ["French"],
	"Lulullia (lulullia902)": ["French"],
	"Anne Onyme 017 (Anne17)": ["French"],
	"Nicolas.C (nico57c)": ["French"],
	"EGuillemot": ["French"],
	"Schweini07": ["German"],
	"Martin Zabinski (Martin1991zab)": ["German"],
	"Manuel (DrMoebyus)": ["German"],
	"Dawid Niedźwiedzki (tiritto) ": ["Polish"],
	"Serhiy Dmytryshyn (dies)": ["Polish"],
	"Igor Santarek (jegor377)": ["Polish"],
	"RainbowP": ["Polish"],
	"Michał (molters.tv)": ["Polish"],
	"Michael Alexsander (YeldhamDev)": ["Brazilian Portuguese"],
	"Cedulio Cezar (ceduliocezar)": ["Brazilian Portuguese"],
	"Alexandre Oliveira (rockytvbr)": ["Brazilian Portuguese"],
	"IagoAndrade": ["Brazilian Portuguese"],
	"chacal_exodius": ["Brazilian Portuguese"],
	"Lucas Santiago (lu.santi.oli)": ["Brazilian Portuguese"],
	"TheNoobPro44": ["Brazilian Portuguese"],
	"DippoZz": ["Brazilian Portuguese"],
	"Luciano Salomoni (LucianoSalomoni)": ["Brazilian Portuguese"],
	"Carlos A. G. Silva (CarloSilva)": ["Brazilian Portuguese"],
	"Vitor Gabriel (Ranbut)": ["Brazilian Portuguese"],
	"Andreev Andrei": ["Russian"],
	"ax trifonov (ax34)": ["Russian"],
	"Artem (blinovartem)": ["Russian"],
	"Иван Соколов (SokoL1337)": ["Russian"],
	"Daniil Belyakov (ermegil)": ["Russian"],
	"stomleny_cmok": ["Russian", "Ukrainian"],
	"Bohdan Matviiv (BodaMat)": ["Ukrainian"],
	"Ruslan Hryschuk (kifflow) ": ["Ukrainian"],
	"Kinwailo": ["Chinese Traditional"],
	"曹恩逢 (SiderealArt)": ["Chinese Traditional"],
	"Chenxu Wang": ["Chinese Simplified"],
	"Catherine Yang (qzcyyw13)": ["Chinese Simplified"],
	"王晨旭 (wcxu21)": ["Chinese Simplified"],
	"Marco Galli (Gaarco)": ["Italian"],
	"StarFang208": ["Italian"],
	"Azagaya VJ (azagaya.games)": ["Spanish"],
	"Lilly And (KatieAnd)": ["Spanish"],
	"UncleFangs": ["Spanish"],
	"foralistico": ["Spanish"],
	"Jaime Arancibia Soto": ["Spanish", "Catalan"],
	"Jose Callejas (satorikeiko)": ["Spanish"],
	"Javier Ocampos (Leedeo)": ["Spanish"],
	"Art Leeman (artleeman)": ["Spanish"],
	"DevCentu": ["Spanish"],
	"Seifer23": ["Catalan"],
	"Joel García Cascalló (jocsencat) ": ["Catalan"],
	"Agnis Aldiņš (NeZvers)": ["Latvian"],
	"Edgars Korns (Eddy11)": ["Latvian"],
	"Teashrock": ["Esperanto"],
	"Blend_Smile": ["Indonesian"],
	"NoahParaduck": ["Indonesian"],
	"Channeling": ["Indonesian"],
	"heydootdoot": ["Indonesian"],
	"Martin Novák (novhack)": ["Czech"],
	"Lullius": ["Norwegian Bokmål"],
	"Aninuscsalas": ["Hungarian"],
	"jaehyeon1090": ["Korean"],
	"sfun_G": ["Korean"],
	"KripC2160": ["Korean", "Japanese"],
	"daisuke osada (barlog)": ["Japanese"],
	"Motomo.exe": ["Japanese"],
	"hebekeg": ["Japanese"],
	"M. Gabriel Lup": ["Romanian"],
	"ANormalKnife": ["Turkish"],
	"kmsecer": ["Turkish"],
	"Rıdvan SAYLAR": ["Turkish"],
	"latbat58": ["Turkish"],
	"M Buhari Horoz (Sorian01)": ["Turkish"],
	"br.bahrampour": ["Turkish"],
	"gegekyz": ["Turkish"],
	"Vancat": ["Turkish"],
	"Ferhat Geçdoğan (ferhatgec)": ["Turkish"],
	"designy": ["Turkish"],
	"libre ajans (libreajans)": ["Turkish"],
	"CaelusV": ["Danish"],
	"GGIEnrike":
	[
		"Romanian",
		"French",
		"German",
		"Italian",
		"Portuguese",
		"Serbian (Cyrillic)",
		"Brazilian Portuguese"
	],
}

export(Array, String, MULTILINE) var licenses: Array

onready var credits = $AboutUI/Credits
onready var groups: Tree = $AboutUI/Credits/Groups
onready var developer_container = $AboutUI/Credits/Developers
onready var contributors_container = $AboutUI/Credits/Contributors
onready var donors_container = $AboutUI/Credits/Donors
onready var translators_container = $AboutUI/Credits/Translators
onready var licenses_container = $AboutUI/Credits/Licenses

onready var developers: Tree = $AboutUI/Credits/Developers/DeveloperTree
onready var contributors: Tree = $AboutUI/Credits/Contributors/ContributorTree
onready var donors: Tree = $AboutUI/Credits/Donors/DonorTree
onready var translators: Tree = $AboutUI/Credits/Translators/TranslatorTree

onready var license_text: TextEdit = $AboutUI/Credits/Licenses/LicenseText

onready var slogan: Label = $AboutUI/IconsButtons/SloganAndLinks/VBoxContainer/PixeloramaSlogan
onready var copyright_label: Label = $AboutUI/Copyright


func _ready() -> void:
	create_donors()
	create_contributors()
	var license_buttons_container = $AboutUI/Credits/Licenses/LicenseButtonsContainer
	for button in license_buttons_container.get_children():
		button.connect("pressed", self, "_on_LicenseButton_pressed", [button.get_index()])
	license_text.text = licenses[0]


func _on_AboutDialog_about_to_show() -> void:
	window_title = tr("About Pixelorama") + " " + Global.current_version

	var groups_root := groups.create_item()
	var developers_button := groups.create_item(groups_root)
	var contributors_button := groups.create_item(groups_root)
	var donors_button := groups.create_item(groups_root)
	var translators_button := groups.create_item(groups_root)
	var licenses_button := groups.create_item(groups_root)

	developers_button.set_text(0, "  " + tr("Developers"))
	# We use metadata to avoid being affected by translations
	developers_button.set_metadata(0, "Developers")
	developers_button.select(0)
	contributors_button.set_text(0, "  " + tr("Contributors"))
	contributors_button.set_metadata(0, "Contributors")
	donors_button.set_text(0, "  " + tr("Donors"))
	donors_button.set_metadata(0, "Donors")
	translators_button.set_text(0, "  " + tr("Translators"))
	translators_button.set_metadata(0, "Translators")
	licenses_button.set_text(0, "  " + tr("Licenses"))
	licenses_button.set_metadata(0, "Licenses")

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

	var selected: String = groups.get_selected().get_metadata(0)
	if "Developers" in selected:
		developer_container.visible = true
	elif "Contributors" in selected:
		contributors_container.visible = true
	elif "Donors" in selected:
		donors_container.visible = true
	elif "Translators" in selected:
		translators_container.visible = true
	elif "Licenses" in selected:
		licenses_container.visible = true


func _on_Website_pressed() -> void:
	OS.shell_open("https://www.oramainteractive.com")


func _on_GitHub_pressed() -> void:
	OS.shell_open("https://github.com/Orama-Interactive/Pixelorama")


func _on_Donate_pressed() -> void:
	OS.shell_open("https://www.patreon.com/OramaInteractive")


func _on_LicenseButton_pressed(index: int) -> void:
	license_text.text = licenses[index]


func create_developers() -> void:
	var dev_root := developers.create_item()
	developers.create_item(dev_root).set_text(
		0, "  Emmanouil Papadeas (Overloaded) - " + tr("Lead Programmer")
	)
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
	donors.create_item(donors_root).set_text(0, "  David Maziarka")
	donors.create_item(donors_root).set_text(0, "  Jonas Rudlang")
	donors.create_item(donors_root).set_text(0, "  ShikadiGum")
	donors.create_item(donors_root).set_text(0, "  pookey")


func create_contributors() -> void:
	var contributor_root := contributors.create_item()
	contributors.create_item(contributor_root).set_text(0, "  Fayez Akhtar (Variable)")
	contributors.create_item(contributor_root).set_text(0, "  Hugo Locurcio (Calinou)")
	contributors.create_item(contributor_root).set_text(0, "  CheetoHead (greusser)")
	contributors.create_item(contributor_root).set_text(0, "  Michael Alexsander (YeldhamDev)")
	contributors.create_item(contributor_root).set_text(0, "  Martin Novák (novhack)")
	contributors.create_item(contributor_root).set_text(0, "  Laurenz Reinthaler (Schweini07)")
	contributors.create_item(contributor_root).set_text(0, "  Darshan Phaldesai (luiq54)")
	contributors.create_item(contributor_root).set_text(0, "  mrtripie")
	contributors.create_item(contributor_root).set_text(0, "  kleonc")
	contributors.create_item(contributor_root).set_text(0, "  azagaya")
	contributors.create_item(contributor_root).set_text(0, "  Kinwailo")
	contributors.create_item(contributor_root).set_text(0, "  Igor Santarek (jegor377)")
	contributors.create_item(contributor_root).set_text(0, "  Xenofon Konitsas (huskee)")
	contributors.create_item(contributor_root).set_text(0, "  Martin Zabinski (Martin1991zab)")
	contributors.create_item(contributor_root).set_text(0, "  Marco Galli (Gaarco)")
	contributors.create_item(contributor_root).set_text(0, "  Matheus Pesegoginski (MatheusPese)")
	contributors.create_item(contributor_root).set_text(0, "  AbhinavKDev (abhinav3967)")
	contributors.create_item(contributor_root).set_text(0, "  sapient_cogbag")
	contributors.create_item(contributor_root).set_text(0, "  dasimonde")
	contributors.create_item(contributor_root).set_text(0, "  Matthew Paul (matthewpaul-us)")
	contributors.create_item(contributor_root).set_text(0, "  danielnaoexiste")
	contributors.create_item(contributor_root).set_text(0, "  20kdc")
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
	contributors.create_item(contributor_root).set_text(0, "  Kawan Weege (Dwahgon)")
	contributors.create_item(contributor_root).set_text(0, "  kevinms")
	contributors.create_item(contributor_root).set_text(0, "  Álex Román Núñez (EIREXE)")
	contributors.create_item(contributor_root).set_text(0, "  Jeremy Behreandt (behreajj)")
	contributors.create_item(contributor_root).set_text(0, "  Marquis Kurt (alicerunsonfedora)")
	contributors.create_item(contributor_root).set_text(0, "  Silent Orb (silentorb)")
	contributors.create_item(contributor_root).set_text(0, "  JumpJetAvocado")
	contributors.create_item(contributor_root).set_text(0, "  ArthyChaux")
	contributors.create_item(contributor_root).set_text(0, "  AlphinAlbukhari")
	contributors.create_item(contributor_root).set_text(
		0, "  Matteo Piovanelli (MatteoPiovanelli-Laser)"
	)
	contributors.create_item(contributor_root).set_text(0, "  Haoyu Qiu (timothyqiu)")
	contributors.create_item(contributor_root).set_text(0, "  GrantMoyer")
	contributors.create_item(contributor_root).set_text(0, "  Arron Washington (radicaled)")


func create_translators() -> void:
	var translators_root := translators.create_item()
	var translator_list := TRANSLATORS_DICTIONARY.keys()
	for translator in translator_list:
		var languages: Array = TRANSLATORS_DICTIONARY[translator]
		var language_string: String = tr(languages[0])
		for i in range(1, languages.size()):
			if i == languages.size() - 1:
				language_string += " %s %s" % [tr("and"), tr(languages[i])]
			else:
				language_string += ", %s" % [tr(languages[i])]

		var text := "  %s - %s" % [translator, language_string]
		translators.create_item(translators_root).set_text(0, text)
