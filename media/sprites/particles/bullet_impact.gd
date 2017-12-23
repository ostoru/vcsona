extends RigidBody
var lifetime = 80
func _ready():
	set_fixed_process(true)
func _fixed_process(delta):
	lifetime -= 1
	if lifetime <= 0:
		queue_free()
	else:
		var cbodies = get_colliding_bodies()
		if cbodies != []:
			for a in cbodies:
				print("hit ", a)
				queue_free()
	pass
