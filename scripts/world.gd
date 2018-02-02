# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends Spatial
var options = {}
func _ready():
	get_all_the_children_in_node(get_tree().get_root())
	if options.global_light == true:
		get_node("global light").show()
		if options.global_shadows == true:
			get_node("global light").set_project_shadows(true)
		else:
			get_node("global light").set_project_shadows(false)
	else:
		get_node("global light").hide()

func get_all_the_children_in_node(node):

	for a in node.get_children():
		if a extends NavigationMeshInstance:
			var nv = get_node("Navigation")
			if a.get_parent() != get_node("Navigation"):
				nv.navmesh_create(a.get_navigation_mesh(),a.get_global_transform())
				a.queue_free()
		get_all_the_children_in_node(a)