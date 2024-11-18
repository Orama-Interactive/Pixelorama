extends Window

const AUTHORS: PackedStringArray = [
	"20kdc",
	"Aaron Franke (aaronfranke)",
	"AbhinavKDev (abhinav3967)",
	"Álex Román Núñez (EIREXE)",
	"alikin12",
	"AlphinAlbukhari",
	"Anaminus",
	"Andreev Andrei",
	"Arron Washington (radicaled)",
	"ArthyChaux",
	"azagaya",
	"ballerburg9005",
	"CheetoHead (greusser)",
	"Christos Tsoychlakis (ChrisTs8920)",
	"Clara Hobbs (Ratfink)",
	"danielnaoexiste",
	"Darshan Phaldesai (luiq54)",
	"dasimonde",
	"Dávid Gábor BODOR (dragonfi)",
	"donte5405",
	"Fayez Akhtar (Variable)",
	"Gamespleasure",
	"GrantMoyer",
	"gschwind",
	"Hamster5295",
	"Haoyu Qiu (timothyqiu)",
	"Hugo Locurcio (Calinou)",
	"huskee",
	"Igor Santarek (jegor377)",
	"Ivan Kruger (haythamnikolaidis)",
	"Jeremy Behreandt (behreajj)",
	"John Jerome Romero (Wishdream)",
	"JumpJetAvocado",
	"Kawan Weege (Dwahgon)",
	"kevinms",
	"Kiisu-Master",
	"Kinwailo",
	"kleonc",
	"Laurenz Reinthaler (Schweini07)",
	"Marco Galli (Gaarco)",
	"Mariano Semelman (msemelman)",
	"Marquis Kurt (alicerunsonfedora)",
	"Martin Novák (novhack)",
	"Martin Zabinski (Martin1991zab)",
	"Matheus Pesegoginski (MatheusPese)",
	"Matteo Piovanelli (MatteoPiovanelli-Laser)",
	"Matthew Paul (matthewpaul-us)",
	"Michael Alexsander (YeldhamDev)",
	"mrtripie",
	"nicejammer",
	"PinyaColada",
	"Rémi Verschelde (akien-mga)",
	"rob-a-bolton",
	"RorotoSic",
	"sapient_cogbag",
	"Silent Orb (silentorb)",
	"Subhang Nanduri (SbNanduri)",
	"TheLsbt",
	"THWLF",
	"Vaibhav Kubre (kubre)",
	"Vriska Weaver (henlo-birb)",
]

const TRANSLATORS_DICTIONARY := {
	"Emmanouil Papadeas (Overloaded)": ["Greek"],
	"huskee": ["Greek"],
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
	"Roroto Sic (Roroto_Sic)": ["French"],
	"ninjdai": ["French"],
	"celeste tollec (celeste73-t)": ["French"],
	"Schweini07": ["German"],
	"Martin Zabinski (Martin1991zab)": ["German"],
	"Manuel (DrMoebyus)": ["German"],
	"Dominik K. (mezotv)": ["German"],
	"alikin12": ["German"],
	"Dawid Niedźwiedzki (tiritto)": ["Polish"],
	"Serhiy Dmytryshyn (dies)": ["Polish"],
	"Igor Santarek (jegor377)": ["Polish"],
	"RainbowP": ["Polish"],
	"Michał (molters.tv)": ["Polish"],
	"Dandailo": ["Polish"],
	"makabeus": ["Polish"],
	"Donda": ["Polish"],
	"Piotr Kostrzewski (piotrkostrzewski)": ["Polish"],
	"Tmpod": ["Portuguese"],
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
	"Geraldo PMJ (geraldopmj)": ["Brazilian Portuguese"],
	"snorring_parrot": ["Brazilian Portuguese"],
	"iLeonardito (iLeoww)": ["Brazilian Portuguese"],
	"Heliana Moreira (helimoreira)": ["Brazilian Portuguese"],
	"Andreev Andrei": ["Russian"],
	"ax trifonov (ax34)": ["Russian"],
	"Artem (blinovartem)": ["Russian"],
	"Иван Соколов (SokoL1337)": ["Russian"],
	"Daniil Belyakov (ermegil)": ["Russian"],
	"Elijah Fronzak (pincetgore)": ["Russian"],
	"toxidcheckery": ["Russian"],
	"stomleny_cmok": ["Russian", "Ukrainian"],
	"Bohdan Matviiv (BodaMat)": ["Ukrainian"],
	"Ruslan Hryschuk (kifflow)": ["Ukrainian"],
	"Dmitry D (homecraft)": ["Ukrainian"],
	"Misha Dyshlenko (lony_official)": ["Ukrainian"],
	"Kinwailo": ["Chinese Traditional"],
	"曹恩逢 (SiderealArt)": ["Chinese Traditional"],
	"Aden Pun (adenpun2000)": ["Chinese Traditional"],
	"NoahsarkTaiwan": ["Chinese Traditional"],
	"EarthlyEric (EarthlyEric6)": ["Chinese Traditional"],
	"Chenxu Wang": ["Chinese Simplified"],
	"Catherine Yang (qzcyyw13)": ["Chinese Simplified"],
	"王晨旭 (wcxu21)": ["Chinese Simplified"],
	"Haruka Kasugano (Kasugano_0)": ["Chinese Simplified"],
	"Peerin (Mrsjh)": ["Chinese Simplified"],
	"ppphp": ["Chinese Simplified"],
	"lxhzzy06": ["Chinese Simplified"],
	"Mozt": ["Chinese Simplified"],
	"Marco Galli (Gaarco)": ["Italian"],
	"StarFang208": ["Italian"],
	"Damiano Guida (damiano.guida22)": ["Italian"],
	"albano battistella (albanobattistella)": ["Italian"],
	"Azagaya VJ (azagaya.games)": ["Spanish"],
	"Lilly And (KatieAnd)": ["Spanish"],
	"UncleFangs": ["Spanish"],
	"foralistico": ["Spanish"],
	"Jaime Arancibia Soto": ["Spanish", "Catalan"],
	"Jose Callejas (satorikeiko)": ["Spanish"],
	"Javier Ocampos (Leedeo)": ["Spanish"],
	"Art Leeman (artleeman)": ["Spanish"],
	"DevCentu": ["Spanish"],
	"Nunnito Nevermind (Nunnito)": ["Spanish"],
	"_LuJaimes (Hannd)": ["Spanish"],
	"Aleklons16 (Aleklons)": ["Spanish"],
	"linux_user_mx": ["Spanish"],
	"Quetzalcoutl (QuetzalcoutlDev)": ["Spanish"],
	"Santiago (Zhamty)": ["Spanish"],
	"Jesus Lavado (jess_lav)": ["Spanish"],
	"Alejandro Moctezuma (AlejandroMoc)": ["Spanish"],
	"Seifer23": ["Catalan"],
	"Joel García Cascalló (jocsencat)": ["Catalan"],
	"Agnis Aldiņš (NeZvers)": ["Latvian"],
	"Edgars Korns (Eddy11)": ["Latvian"],
	"Teashrock": ["Esperanto"],
	"Blend_Smile": ["Indonesian"],
	"NoahParaduck": ["Indonesian"],
	"Channeling": ["Indonesian"],
	"heydootdoot": ["Indonesian"],
	"elidelid": ["Indonesian"],
	"Martin Novák (novhack)": ["Czech"],
	"Lullius": ["Norwegian Bokmål"],
	"Aninus Partikler (aninuscsalas)": ["Hungarian"],
	"jaehyeon1090": ["Korean"],
	"sfun_G": ["Korean"],
	"KripC2160": ["Korean", "Japanese"],
	"daisuke osada (barlog)": ["Japanese"],
	"Motomo.exe": ["Japanese"],
	"hebekeg": ["Japanese"],
	"M. Gabriel Lup": ["Romanian"],
	"Robert Banks (robert-banks)": ["Romanian", "Polish"],
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
	"Sabri Ünal (yakushabb)": ["Turkish"],
	"Lucifer25x": ["Turkish"],
	"CaelusV": ["Danish"],
	"Jonas Vejlin (jonas.vejlin)": ["Danish"],
	"Cat (cultcats)": ["Danish"],
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

const DONORS: PackedStringArray = [
	"BasicIncomePlz",
	"Benedikt",
	"Hugo Locurcio",
	"Jérôme P.",
	"Jonas Rudlang",
	"Mike King",
	"ShikadiGum",
	"Tassos Kyriakopoulos",
	"Πολιτισμός Τύπου 1",
	"Ormanus"
]

@export_multiline var licenses: PackedStringArray

@onready var credits := $AboutUI/Credits as HSplitContainer
@onready var groups := $AboutUI/Credits/Groups as Tree
@onready var authors_container := $AboutUI/Credits/Authors as VBoxContainer
@onready var donors_container := $AboutUI/Credits/Donors as VBoxContainer
@onready var translators_container := $AboutUI/Credits/Translators as VBoxContainer
@onready var licenses_container := $AboutUI/Credits/Licenses as VBoxContainer
@onready var authors := $AboutUI/Credits/Authors/AuthorTree as Tree
@onready var donors := $AboutUI/Credits/Donors/DonorTree as Tree
@onready var translators := $AboutUI/Credits/Translators/TranslatorTree as Tree
@onready var license_tabs := $AboutUI/Credits/Licenses/LicenseTabs as TabBar
@onready var license_text := $AboutUI/Credits/Licenses/LicenseText as TextEdit
@onready var pixelorama_slogan := (
	$AboutUI/IconsButtons/SloganAndLinks/VBoxContainer/PixeloramaSlogan as Label
)
@onready var copyright_label := $AboutUI/Copyright as Label


func _ready() -> void:
	pixelorama_slogan.label_settings.font_color = get_theme_color(&"font_color", &"Label")
	copyright_label.label_settings.font_color = get_theme_color(&"font_color", &"Label")
	create_donors()
	license_tabs.add_tab("Pixelorama")
	license_tabs.add_tab("Godot")
	license_tabs.add_tab("FreeType")
	license_tabs.add_tab("mbed TLS")
	license_tabs.add_tab("Keychain")
	license_tabs.add_tab("Roboto")
	license_tabs.add_tab("Dockable Container")
	license_tabs.add_tab("aimgio")
	license_tabs.add_tab("godot-gdgifexporter")
	license_tabs.add_tab("cleanEdge")
	license_tabs.add_tab("OmniScale")
	license_tabs.add_tab("gd-obj")
	license_text.text = licenses[0]


func _notification(what: int) -> void:
	if not is_instance_valid(pixelorama_slogan):
		return
	if what == NOTIFICATION_THEME_CHANGED:
		pixelorama_slogan.label_settings.font_color = get_theme_color(&"font_color", &"Label")
		copyright_label.label_settings.font_color = get_theme_color(&"font_color", &"Label")


func _on_AboutDialog_about_to_show() -> void:
	title = tr("About Pixelorama") + " " + Global.current_version

	var groups_root := groups.create_item()
	#var developers_button := groups.create_item(groups_root)
	var authors_button := groups.create_item(groups_root)
	var donors_button := groups.create_item(groups_root)
	var translators_button := groups.create_item(groups_root)
	var licenses_button := groups.create_item(groups_root)
	authors_button.set_text(0, "  " + tr("Authors"))
	# We use metadata to avoid being affected by translations
	authors_button.set_metadata(0, "Authors")
	authors_button.select(0)
	donors_button.set_text(0, "  " + tr("Donors"))
	donors_button.set_metadata(0, "Donors")
	translators_button.set_text(0, "  " + tr("Translators"))
	translators_button.set_metadata(0, "Translators")
	licenses_button.set_text(0, "  " + tr("Licenses"))
	licenses_button.set_metadata(0, "Licenses")

	create_authors()
	create_translators()


func _on_visibility_changed() -> void:
	if visible:
		return
	groups.clear()
	authors.clear()
	translators.clear()
	Global.dialog_open(false)


func _on_Groups_item_selected() -> void:
	for child in credits.get_children():
		if child != groups:
			child.visible = false

	var selected: String = groups.get_selected().get_metadata(0)
	if "Authors" in selected:
		authors_container.visible = true
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


func create_donors() -> void:
	var donors_root := donors.create_item()
	for donor in DONORS:
		donors.create_item(donors_root).set_text(0, "  " + donor)


func create_authors() -> void:
	var author_root := authors.create_item()
	authors.create_item(author_root).set_text(
		0, "  Emmanouil Papadeas (Overloaded) - " + tr("Lead Developer")
	)
	authors.create_item(author_root).set_text(0, "  John Nikitakis (Erevos) - " + tr("UI Designer"))
	for author in AUTHORS:
		authors.create_item(author_root).set_text(0, "  " + author)


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


func _on_LicenseTabs_tab_changed(tab: int) -> void:
	license_text.text = licenses[tab]


func _on_close_requested() -> void:
	hide()
