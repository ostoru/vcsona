# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends Spatial

func _ready():
	set_process_input(true)
func _input(event):
	if event.is_action("ui_cancel"):
		get_tree().quit()
	pass