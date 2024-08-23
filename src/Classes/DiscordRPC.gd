extends Node


func _ready():
	DiscordRPC.app_id = 1276204876472385638 # TODO Change with an official one -
	# this is a temporal one created just for first testings, DON'T use it for a stable release.
	
	DiscordRPC.details = tr("Just using Pixelorama")
	DiscordRPC.large_image = "mainicon" # NOTE This is linked to the app_id (read the discord API Docs).
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())

	DiscordRPC.refresh()
	
# Extra NOTE's :
# - This was made using only this Godot addon
# https://github.com/vaporvee/discord-rpc-godot (all the credits for them)
# [I really recommend to read the docs of that addon].
# - If you're wondering "why didn't you code this on an extension?", 
# my answer is that pixelorama doesn't support C#,
# and the extensions (as I saw on testings) can't contain godot addons either, so I had to do this.
# - a-and, this for some reason doesn't work if you're on ubuntu using the snap-store port of discord. 
