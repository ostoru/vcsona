# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends Spatial

func _ready():
	
	get_all_the_children_in_node(get_tree().get_root())
	set_process_input(true)

func get_all_the_children_in_node(node):
#	print(node)
	for a in node.get_children():
		if a extends NavigationMeshInstance:
			var nv = get_node("Navigation")
			if a.get_parent() != get_node("Navigation"):
				nv.navmesh_create(a.get_navigation_mesh(),a.get_global_transform())
				print("    done    ")
				
		get_all_the_children_in_node(a)
	
func _input(event):
	if event.is_action("ui_cancel"):
		get_tree().quit()
	pass