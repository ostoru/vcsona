extends KinematicBody
var difference
var lifetime = 800
var speed = 200
func _ready():
	difference = get_node("Spatial").get_global_transform().origin - get_global_transform().origin
	set_fixed_process(true)
func _fixed_process(delta):
	lifetime -= 1
	if lifetime <= 0:
		queue_free()
	else:
		move(difference * delta * speed)
		if is_colliding():
			var body = get_collider()
			if body.is_in_group("char"):
				body.stats.hp_cur -= 20
			self_destruct()

func self_destruct():
	var dest = load("res://media/sprites/particles/bullet_impact.xml").instance()
	dest.set_transform(get_transform())
	get_parent().add_child(dest)
	queue_free()