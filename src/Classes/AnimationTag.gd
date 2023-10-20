class_name AnimationTag
extends RefCounted
## A class for frame tag properties
##
## A tag indicates an animation of your sprite. Using several tags you can organize different
## animations of your sprite.[br]
## Here is an example of how a new tag may be created ([b]without[/b] any undo-redo functionality)
##[codeblock]
##func create_tag(tag_name: StringName, color: Color, from: int, to: int):
##    var tags_list = Global.current_project.animation_tags.duplicate()
##    var new_tag = AnimationTag.new(tag_name, color, from, to)
##    tags_list.append(new_tag)
##    # now make it the new animation_tags (so that the setter is called to update UI)
##    Global.current_project.animation_tags = tags_list
## [/codeblock]
## Here is an example of how a new tag may be created ([b]with[/b] undo-redo functionality)
## [codeblock]
##func create_tag(tag_name: StringName, color: Color, from: int, to: int):
##    var new_animation_tags := Global.current_project.animation_tags.duplicate()
##    # Loop through the tags to create new classes for them, so that they won't be the same
##    # as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
##    for i in new_animation_tags.size():
##        new_animation_tags[i] = AnimationTag.new(
##            new_animation_tags[i].name,
##            new_animation_tags[i].color,
##            new_animation_tags[i].from,
##            new_animation_tags[i].to
##        )
##
##    new_animation_tags.append(AnimationTag.new(tag_name, color, from, to))
##
##    # Handle Undo/Redo
##    Global.current_project.undos += 1
##    Global.current_project.undo_redo.create_action("Adding a Tag")
##    Global.current_project.undo_redo.add_do_method(Global.general_redo)
##    Global.current_project.undo_redo.add_undo_method(Global.general_undo)
##    Global.current_project.undo_redo.add_do_property(
##        Global.current_project, "animation_tags", new_animation_tags
##    )
##    Global.current_project.undo_redo.add_undo_property(
##        Global.current_project, "animation_tags", Global.current_project.animation_tags
##    )
##    Global.current_project.undo_redo.commit_action()
## [/codeblock]

var name: String  ## Name of tag
var color: Color  ## Color of tag
var from: int  ## First frame number in the tag (first frame in timeline is numbered 1)
var to: int  ## First frame number in the tag (first frame in timeline is numbered 1)


## Class Constructor (used as [code]AnimationTag.new(name, color, from, to)[/code])
func _init(_name, _color, _from, _to) -> void:
	name = _name
	color = _color
	from = _from
	to = _to
