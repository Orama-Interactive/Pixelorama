extends GridContainer

const licenses = {
	"CC0-1.0":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description":
		"Public domain dedication. No attribution required. Free use for any purpose."
	},
	"CC-BY-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Attribution required. Commercial use allowed. Modifications allowed."
	},
	"CC-BY-SA-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": true,
		"description":
		"Attribution required. Commercial use allowed. Derivatives must use same license."
	},
	"CC-BY-ND-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": false,
		"share_alike_required": false,
		"description": "Attribution required. Commercial use allowed. No modifications allowed."
	},
	"CC-BY-NC-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": false,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Attribution required. Non-commercial use only. Modifications allowed."
	},
	"CC-BY-NC-SA-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": false,
		"derivatives_allowed": true,
		"share_alike_required": true,
		"description":
		"Attribution required. Non-commercial use only. Derivatives must use same license."
	},
	"CC-BY-NC-ND-4.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": false,
		"derivatives_allowed": false,
		"share_alike_required": false,
		"description": "Attribution required. Non-commercial use only. No modifications allowed."
	},
	"PDM-1.0":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Public Domain Mark. Work is believed free of copyright restrictions."
	},
	"Public-Domain":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "No copyright restrictions. Free for any use."
	},
	"Unlicense":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Explicit waiver of all copyright rights."
	},
	"FAL-1.3":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": true,
		"description":
		"Free Art License. Copyleft license requiring derivatives to remain free under same license."
	},
	"OFL-1.1":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description":
		"Open Font License. Allows modification and embedding of fonts with attribution."
	},
	"OGA-BY-3.0":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "OpenGameArt license requiring attribution for game assets."
	},
	"Unsplash-License":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Free image use including commercial use with platform restrictions."
	},
	"Pexels-License":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Free stock media license allowing commercial use."
	},
	"ARR":
	{
		"attribution_required": true,
		"commercial_use_allowed": false,
		"derivatives_allowed": false,
		"share_alike_required": false,
		"description": "All rights reserved. No reuse without explicit permission."
	},
	"Royalty-Free":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "One-time license fee allows use without recurring royalties."
	},
	"Rights-Managed":
	{
		"attribution_required": true,
		"commercial_use_allowed": true,
		"derivatives_allowed": false,
		"share_alike_required": false,
		"description": "Usage restricted by contract terms (time, region, purpose)."
	},
	"Editorial-Use-Only":
	{
		"attribution_required": true,
		"commercial_use_allowed": false,
		"derivatives_allowed": false,
		"share_alike_required": false,
		"description":
		"Only allowed for news/editorial use, not advertising or commercial promotion."
	},
	"Commercial-Use-Only":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Allows commercial usage under defined conditions."
	},
	"Personal-Use-Only":
	{
		"attribution_required": false,
		"commercial_use_allowed": false,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Only for private non-commercial use."
	},
	"Extended-License":
	{
		"attribution_required": false,
		"commercial_use_allowed": true,
		"derivatives_allowed": true,
		"share_alike_required": false,
		"description": "Expanded rights beyond standard license terms."
	},
}

@onready var preset_options: MenuButton = $PresetOptions
@onready var licence_name: LineEdit = $LicenceName


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var popup: PopupMenu = preset_options.get_popup()
	for license in licenses:
		popup.add_item(license)
		var prperties := (
			"""
Description: {description}\n
HIGHLIGHTS:
=> Requires attribution: {attribution_required}
=> Commercial use: {commercial_use_allowed}
=> Derivatives: {derivatives_allowed}
=> Adaptions to be licensed under the same license?: {share_alike_required}
"""
			. format(
				{
					"description": licenses[license]["description"],
					"attribution_required":
					"Yes" if licenses[license]["attribution_required"] else "Optional",
					"commercial_use_allowed":
					"Allowed" if licenses[license]["commercial_use_allowed"] else "Forbidden",
					"derivatives_allowed":
					"Allowed" if licenses[license]["derivatives_allowed"] else "Forbidden",
					"share_alike_required":
					"Yes" if licenses[license]["share_alike_required"] else "No"
				}
			)
		)

		popup.set_item_tooltip(popup.item_count - 1, prperties)
	popup.index_pressed.connect(
		func(index):
			licence_name.text = popup.get_item_text(index)
			licence_name.text_changed.emit(licence_name.text)
	)
