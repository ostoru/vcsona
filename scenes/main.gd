extends Node
var options = {
	view_sensitivity = .15,
	global_light = true,
	global_shadows = true
	}

func _ready():
	set_process(true)
func _process(delta):
	if get_node("main menu/options").is_pressed():
		get_node("options").show()
	if get_node("main menu/vs_ai").is_pressed():
		var inst = load("res://scenes/ai deathmatch test.xml").instance()
		inst.options = options
		get_node(".").add_child(inst)
		get_node("main menu").queue_free()
		set_process(false)
	if get_node("main menu/vs_human").is_pressed():
		var inst = load("res://scenes/hot seat deathmatch test.tscn").instance()
		inst.options = options
		get_node(".").add_child(inst)
		get_node("main menu").queue_free()
		set_process(false)
	if get_node("main menu/vs_human1").is_pressed():
		var inst = load("res://scenes/hot seat deathmatch test1.tscn").instance()
		inst.options = options
		get_node(".").add_child(inst)
		get_node("main menu").queue_free()
		set_process(false)
	if get_node("main menu/quit").is_pressed():
		get_tree().quit()
		pass