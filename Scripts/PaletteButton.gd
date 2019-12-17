extends Button

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

signal on_drop_data

export var index := 0;
export var color : Color = Color.white
export var draggable := false

var drag_preview_texture = preload("res://Assets/Graphics/Palette/swatch_drag_preview.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func get_drag_data(position):
	var data = null;
	if(draggable):
		#print(String(get_instance_id()) + ": Drag Start");
		data = {source_index = index};
		var drag_icon = TextureRect.new();
		drag_icon.texture = drag_preview_texture;
		drag_icon.modulate = color
		set_drag_preview(drag_icon);
	return data;

func can_drop_data(position, data):
	return true;

func drop_data(position, data):
	emit_signal("on_drop_data", data.source_index, index);
	pass;

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
