extends GridContainer

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var palette_button = load("res://Prefabs/PaletteButton.tscn");

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
func _ready():
	var index = 0
	for color in default_palette:
		var new_button = palette_button.instance()
		new_button.get_child(0).modulate = color
		new_button.connect("pressed", self, "_on_color_select", [index])
		add_child(new_button)
		index += 1
	pass # Replace with function body.

func _on_color_select(index):
	Global.left_color_picker.color = default_palette[index]
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
