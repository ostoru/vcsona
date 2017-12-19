extends KinematicBody

func _ready():
	var transform = get_node("../").last_bullet
	set_transform(transform)
	set_fixed_process(true)
	pass

var lifetime = 80
func _fixed_process(delta):
	lifetime -= 1
	if lifetime <= 0:
		queue_free()
	elif is_colliding():
		#todo check for character / destructable
		queue_free()
	else:
		translate(Vector3(0,0,-1))