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
	for a in chars:
		a.action_end()
	get_node("../map cam").make_current()