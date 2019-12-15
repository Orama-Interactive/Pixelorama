extends GridContainer

var palette_button = preload("res://Prefabs/PaletteButton.tscn");

var default_palette = [
	Color("#FF000000"),
	Color("#FF222034"),
	Color("#FF45283c"),
	Color("#FF663931"),
	Color("#FF8f563b"),
	Color("#FFdf7126"),
	Color("#FFd9a066"),
	Color("#FFeec39a"),
	Color("#FFfbf236"),
	Color("#FF99e550"),
	Color("#FF6abe30"),
	Color("#FF37946e"),
	Color("#FF4b692f"),
	Color("#FF524b24"),
	Color("#FF323c39"),
	Color("#FF3f3f74"),
	Color("#FF306082"),
	Color("#FF5b6ee1"),
	Color("#FF639bff"),
	Color("#FF5fcde4"),
	Color("#FFcbdbfc"),
	Color("#FFffffff"),
	Color("#FF9badb7"),
	Color("#FF847e87"),
	Color("#FF696a6a"),
	Color("#FF595652"),
	Color("#FF76428a"),
	Color("#FFac3232"),
	Color("#FFd95763"),
	Color("#FFd77bba"),
	Color("#FF8f974a"),
	Color("#FF8a6f30")
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var index := 0
	for color in default_palette:
		var new_button = palette_button.instance()
		new_button.get_child(0).modulate = color
		new_button.connect("pressed", self, "_on_color_select", [index])
		add_child(new_button)
		index += 1

func _on_color_select(index : int) -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.left_color_picker.color = default_palette[index]
		Global.update_left_custom_brush()
	elif Input.is_action_just_released("right_mouse"):
		Global.right_color_picker.color = default_palette[index]
		Global.update_right_custom_brush()
