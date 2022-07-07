extends Button

var frame := 0
var layer := 0
var cel: GroupCel
var mat: Material


func _ready() -> void:
	button_setup()


func button_setup() -> void:
	rect_min_size.x = Global.animation_timeline.cel_size
	rect_min_size.y = Global.animation_timeline.cel_size

	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, layer]

	# Reset the checkers size because it assumes you want the same size as the canvas
	var checker = $CelTexture/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size
#	cel = Global.current_project.frames[frame].cels[layer]
	#image = cel.image


func _on_GroupCelButton_resized() -> void:
	get_node("CelTexture").rect_min_size.x = rect_min_size.x - 4
	get_node("CelTexture").rect_min_size.y = rect_min_size.y - 4


func _pressed():
	# TODO L: PixelCelButton could just use the func instead of signal too

	# TODO H: Some of the funtionality from PixelCelButton needs to be moved over
	pass
