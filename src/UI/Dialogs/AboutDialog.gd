extends WindowDialog

const CONTRIBUTORS := [
	"20kdc",
	"Aaron Franke (aaronfranke)",
	"AbhinavKDev (abhinav3967)",
	"Álex Román Núñez (EIREXE)",
	"AlphinAlbukhari",
	"Andreev Andrei",
	"Arron Washington (radicaled)",
	"ArthyChaux",
	"azagaya",
	"ballerburg9005",
	"CheetoHead (greusser)",
	"danielnaoexiste",
	"Darshan Phaldesai (luiq54)",
	"dasimonde",
	"Dávid Gábor BODOR (dragonfi)",
	"Fayez Akhtar (Variable)",
	"Gamespleasure",
	"GrantMoyer",
	"gschwind",
	"Haoyu Qiu (timothyqiu)",
	"Hugo Locurcio (Calinou)",
	"Igor Santarek (jegor377)",
	"Jeremy Behreandt (behreajj)",
	"John Jerome Romero (Wishdream)",
	"JumpJetAvocado",
	"Kawan Weege (Dwahgon)",
	"kevinms",
	"Kinwailo",
	"kleonc",
	"Laurenz Reinthaler (Schweini07)",
	"Marco Galli (Gaarco)",
	"Marquis Kurt (alicerunsonfedora)",
	"Martin Novák (novhack)",
	"Martin Zabinski (Martin1991zab)",
	"Matheus Pesegoginski (MatheusPese)",
	"Matteo Piovanelli (MatteoPiovanelli-Laser)",
	"Matthew Paul (matthewpaul-us)",
	"Michael Alexsander (YeldhamDev)",
	"mrtripie",
	"PinyaColada",
	"Rémi Verschelde (akien-mga)",
	"rob-a-bolton",
	"sapient_cogbag",
	"Silent Orb (silentorb)",
	"Subhang Nanduri (SbNanduri)",
	"THWLF",
	"Vriska Weaver (henlo-birb)",
	"Xenofon Konitsas (huskee)",
]

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

const DONORS := [
	"BasicIncomePlz",
	"Benedikt",
	"David Maziarka",
	"Guillaume Gautier",
	"Hugo Locurcio",
	"Jonas Rudlang",
	"Mike King",
	"MysteryStudio",
	"pcmxms - https://www.nonamefornowsoft.com.br/",
	"pookey",
	"Ryan C. Gordon (icculus)",
	"Sean Allen",
	"ShikadiGum",
	"Tassos Kyriakopoulos"
]

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
	for donor in DONORS:
		donors.create_item(donors_root).set_text(0, "  " + donor)


func create_contributors() -> void:
	var contributor_root := contributors.create_item()
	for contributor in CONTRIBUTORS:
		contributors.create_item(contributor_root).set_text(0, "  " + contributor)


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
