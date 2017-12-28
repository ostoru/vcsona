extends Sprite3D
export var lifetime = 8

func _ready():
	set_fixed_process(true)
func _fixed_process(delta):
	lifetime -= 1
	if lifetime <= 0:
		queue_free()