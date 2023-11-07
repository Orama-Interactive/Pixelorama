class_name LayerEffect
extends RefCounted

var name := ""
var shader: Shader
var params := {}
var enabled := true


func _init(_name: String, _shader: Shader, _params := {}) -> void:
	name = _name
	shader = _shader
	params = _params


func duplicate() -> LayerEffect:
	return LayerEffect.new(name, shader, params.duplicate())
