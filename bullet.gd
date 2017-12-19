extends KinematicBody

func _ready():
	var transform = get_node("../").last_bullet
	set_transform(transform)
	set_fixed_process(true)
	pass
func _fixed_process(delta):