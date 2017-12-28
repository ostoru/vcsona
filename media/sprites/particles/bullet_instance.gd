extends RigidBody
export var lifetime = 80

func _ready():
	set_fixed_process(true)
func _fixed_process(delta):
	lifetime -= 1
	if lifetime <= 0:
		queue_free()
	else:
		var cbodies = get_colliding_bodies()
		if cbodies != []:
			for body in cbodies:
				if body.is_in_group("char"):
					body.stats.hp_cur -= 10
			self_destruct()

func self_destruct():
	var dest = load("res://media/sprites/particles/bullet_impact.xml").instance()
	dest.set_transform(get_transform())
	get_parent().add_child(dest)
	queue_free()