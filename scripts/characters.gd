extends Spatial
var chars = []
var ally_chars = []
var enemy_chars = []
const MAP_MODE = 0
const ACTION_MODE = 2
var play_mode

func _ready():
	set_fixed_process(true)
	update_children_list()

func start_actions(target_node):
	play_mode = ACTION_MODE
	for a in chars:
		a.action_start(target_node,get_node("player"))

var next_turn_ai = false
func end_actions():
	play_mode = MAP_MODE
	chars = []
	for child in get_children():
		child.set_pause_mode(PAUSE_MODE_STOP)
		if child.is_in_group("destroy"): #destroys bullets and projectiles, does not affect destructable objects
			child.queue_free()
		if child.is_in_group("char"):
			chars.append(child)
			child.action_end()
			if child.active:
				next_turn_ai = child.ai_mode
	get_node("../map_cam").make_current()

const DEFAULT_ACTION_COOLDOWN = 30
var action_cooldown = DEFAULT_ACTION_COOLDOWN
var passive_ready = 1
func _fixed_process(delta):
	if play_mode == MAP_MODE:
		if next_turn_ai:
			start_actions(enemy_chars[0])
	elif play_mode == ACTION_MODE:
		if action_cooldown <= 0:
			if passive_ready > 0:
				passive_ready -= 1
			update_one_passive_character()
			action_cooldown = DEFAULT_ACTION_COOLDOWN
		else:
			action_cooldown -= 1

var char_index = 0
var target_index = 0
func update_one_passive_character():
	if char_index < chars.size(): #selects one of our characters from the deployed list
		if !chars[char_index].active: #detects if the character is being used by the player
			if chars[char_index].passive_ready: #detects if the character is already executing passive actions
				if target_index < chars.size(): #selects a target from the deployed list
					chars[char_index].start_passive_action(chars[target_index])
					target_index += 1
				else:
					target_index = 0
		char_index += 1
	else:
		char_index = 0

func update_children_list():
	chars = []
	for child in get_children():
		if child.is_in_group("char"):
			chars.append(child)
			if child.ally:
				ally_chars.append(child)
			else:
				enemy_chars.append(child)
	print(ally_chars,enemy_chars)