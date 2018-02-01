extends Node
var options = {
	view_sensitivity = .15,
	}

func _ready():
	set_process(true)
func _process(delta):
	if get_node("main menu/options").is_pressed():
		get_node("options").show()
	if get_node("main menu/vs_ai").is_pressed():
		var inst = load("res://scenes/ai deathmatch test.xml").instance()
		get_node(".").add_child(inst)
		get_node("main menu").queue_free()
		set_process(false)
		print(options.view_sensitivity)
	if get_node("main menu/quit").is_pressed():
		get_tree().quit()
		pass