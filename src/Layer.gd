class_name Layer
extends Reference


var name := ""
var visible := true
var locked := false
var frame_container : HBoxContainer
var new_cels_linked := false
var linked_cels := []

func _init(_name := tr("Layer") + " 0", _visible := true, _locked := false, _frame_container := HBoxContainer.new(), _new_cels_linked := false, _linked_cels := []) -> void:
	self.name = _name
	self.visible = _visible
	self.locked = _locked
	self.frame_container = _frame_container
	self.new_cels_linked = _new_cels_linked
	self.linked_cels = _linked_cels
