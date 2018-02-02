extends StaticBody2D

func _ready():
	if get_parent().ally:
		get_node("highlight").set_modulate(Color("#93efff")) #blue
	else:
		get_node("highlight").set_modulate(Color("#ff7070")) #red

func _mouse_enter():
	if get_parent().ally:
		get_node("highlight").set_scale(Vector2(1,1) * 1.5)
func _mouse_exit():
	get_node("highlight").set_scale(Vector2(1,1))
func _input_event(viewport, event, shape_idx):
	if event.is_action("attack"):
		if get_parent().ally:
			var distance = (get_viewport().get_mouse_pos() - get_pos()).length()
			get_node("../../").action_starters.append([get_parent(),distance])