extends Spatial
var chars = []
var play_mode
func _ready():
	for a in get_children():
		if a.is_in_group("char"):
			chars.append(a)
func start_actions():
	for a in chars:
		a.action_start()
func end_actions():
	chars = []
	for child in get_children():
		child.set_pause_mode(PAUSE_MODE_STOP)
		if child.is_in_group("destroy"): #destroys bullets and projectiles, does not affect destructable objects
			child.queue_free()
		if child.is_in_group("char"):
			chars.append(child)
			child.action_end()
#		if a.action_end()
		
	get_node("../map cam").make_current()