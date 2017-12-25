extends Spatial
var chars = []
var play_mode
func _ready():
	for a in get_children():
		if a.is_in_group("char"):
			chars.append(a)

func start_actions():
	set_fixed_process(true)
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
	set_fixed_process(false)
		
	get_node("../map_cam").make_current()

const DEFAULT_ACTION_COOLDOWN = 3
var action_cooldown = DEFAULT_ACTION_COOLDOWN
func _fixed_process(delta):
	if action_cooldown <= 0:
		update_one_character()
		action_cooldown = DEFAULT_ACTION_COOLDOWN
	else:
		action_cooldown -= 1

var char_index = 0
var target_index = 0
func update_one_character():
	if char_index < chars.size():
		if !chars[char_index].active: #detects if the character is used
			if target_index < chars.size():
				chars[char_index].new_action(chars[target_index])
				target_index += 1
			else:
				target_index = 0
		char_index += 1
	else:
		char_index = 0
	pass