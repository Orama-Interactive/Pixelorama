class_name BaseCel
extends Reference
# Base class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var opacity: float

# Methods to Override:

# TODO H: Perhaps get_content, set_content, and delete_content/clear_content methods will be good to have here:
#			- get_content will return certain content of the cel (should metadata be included?)
#			- set_content will set the content (same structure as get_content returns)
#			- delete/clear_content will erase it,
#			- using get_content and set_content could become useful for linking/unlinking cels, and will be reversible for undo
#				- this can be used to replace copy_cel and copy_all_cels in layer classes
#			- using all 3 will allow you to delete content, and undo it in cel button
#				= making this generic and should solve issues with combing cel_button scripts into 1
#			- copy_content may also be a useful method to have

# TODO H1: These content methods need good doc comments:

func set_content(content: Array) -> void:
	return

# TODO H0: Consider if the return content methods should have a bool option for including a texture,
# of if the texture should be completely not included (textures aren't always needed. But how can we
# ensure that different texture types are properly set up if textures are completely not included here?
# Will seperate methods for the textures be able to work well?
# Maybe for now, don't worry about possible different texture types, and don't do copying layers/frames
func get_content() -> Array:
	return []


func create_empty_content() -> Array:
	return []


func copy_content() -> Array:
	return []


# TODO H: Should this be the case?
# Each Cel type should have a get_image function, which will either return
# its image data for PixelCels, or return a render of that cel. It's meant
# for read-only usage of image data from any type of cel

# TODO NOTE ^: I'm thinking this shouldn't be the case right now. I'm thinking each cel should have
#				a texture var. using texture.get_data it can be possible to copy selections or color pick.
#				There will be an update_texture method, which will either immedietly update it, or set it
#				to be queued for update (only frames that aren't currently being viewed). When the user
#				isn't drawing, Pixelorama can update these textures. (maybe an update_texture and a queue_texture_update
#				method may be better, we'll see

func get_image() -> Image:
	return null


func save_image_data_to_pxo(_file: File) -> void:
	return


func load_image_data_from_pxo(_file: File, _project_size: Vector2) -> void:
	return


func create_cel_button() -> Node:
	return null
