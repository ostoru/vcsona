extends Control
onready var options = get_node("../").options

func _ready():
	set_process(true)

func _process(delta):
	options.view_sensitivity = get_node("sensitivity/slider").get_val()
	get_node("sensitivity/slider/label").set_text(str(options.view_sensitivity))
	
	if get_node("back").is_pressed():
		hide()
