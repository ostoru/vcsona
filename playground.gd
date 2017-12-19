extends Spatial

func _ready():
	
	pass

var bullet = preload("res://bullet.tscn")
var last_bullet
func shoot(transform):
	last_bullet = transform
	add_child(bullet.instance())
	pass