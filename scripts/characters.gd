extends Spatial
var chars = []
var play_mode
func _ready():
	for a in get_children():
		if a.is_in_group("char"):
			chars.append(a)

func start_actions(target_node):
	set_fixed_process(true)
	for a in chars:
		a.action_start(target_node)

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
	set_fixed_process(false)
		
	get_node("../map_cam").make_current()

const DEFAULT_ACTION_COOLDOWN = 30
var action_cooldown = DEFAULT_ACTION_COOLDOWN
var passive_ready = 1
func _fixed_process(delta):
	print("action_cooldown ",action_cooldown)
	if action_cooldown <= 0:
		print("passive_ready ",passive_ready)
		if passive_ready > 0:
			passive_ready -= 1
		update_one_passive_character()
		action_cooldown = DEFAULT_ACTION_COOLDOWN
	else:
		action_cooldown -= 1

var char_index = 0
var target_index = 0
func update_one_passive_character():
	print(1,"char index ",char_index," chars.size ",chars.size())
	if char_index < chars.size(): #selects one of our characters from the deployed list
		print(2,"char.active ",chars[char_index].active)
		if !chars[char_index].active: #detects if the character is being used by the player
			print(3,"char.passive_ready ",chars[char_index].passive_ready)
			if chars[char_index].passive_ready: #detects if the character is already executing passive actions
				print(4,"target_index",target_index," chars.size",chars.size())
				if target_index < chars.size(): #selects a target from the deployed list
					chars[char_index].new_passive_action(chars[target_index])
					target_index += 1
				else:
					target_index = 0
				print(5,"target index",target_index)
			print(6)
		print(7," ",char_index)
		char_index += 1
	else:
		print(8," ",char_index)
		char_index = 0
	print(10)