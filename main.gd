extends Node


func _ready():set_fixed_process(true)
	pass
func _fixed_process(delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()