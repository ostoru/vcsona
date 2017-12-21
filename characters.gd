extends Spatial
var chars = []
func _ready():
	for a in get_children():
		a.add_to_group("char")
		chars.append(a)