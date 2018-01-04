extends Spatial
var chars = []
var ally_chars = []
var ally_down = []
var enemy_chars = []
const MAP_MODE = 0
const ACTION_MODE = 2
var play_mode

func _ready():
	set_fixed_process(true)
	update_children_list()

func start_actions(target_node): #target_node is the node that started the action
	update_children_list()
	play_mode = ACTION_MODE
	for a in chars:
		if a.ally:
			a.action_start(target_node,aquire_target(enemy_chars))
		else:
			a.action_start(target_node,aquire_target(ally_chars))
			

var next_turn_ai = false
var cooldown = 20
func end_actions(node):
	cooldown = 20
	play_mode = MAP_MODE
	chars = []
	next_turn_ai = node.ally
	update_children_list()
	for char in chars:
		char.action_end()
	get_node("../map_cam").make_current() #must be done after char.action_end()

const DEFAULT_ACTION_COOLDOWN = 30
var action_cooldown = DEFAULT_ACTION_COOLDOWN
var passive_ready = 1
func _fixed_process(delta):
	get_node("../map_cam/fps").set_text(str(OS.get_frames_per_second()))
	if play_mode == MAP_MODE:
		if cooldown <= 0:
			if next_turn_ai:
				update_children_list()
				var starter = aquire_target(enemy_chars)
				print(starter)
				start_actions(starter)
		else:
			cooldown -= 1
	elif play_mode == ACTION_MODE:
		if action_cooldown <= 0:
			if passive_ready > 0:
				passive_ready -= 1
			update_passive_characters()
			action_cooldown = DEFAULT_ACTION_COOLDOWN
		else:
			action_cooldown -= 1

var enemy_index = 0
var ally_index = 0
var enemy_target_index = 0
var ally_target_index = 0
func update_passive_characters():
	update_children_list()
	if ally_index < ally_chars.size():
		if check_passive_readyness(ally_chars[ally_index]):
			var target = aquire_target(enemy_chars)
			ally_chars[ally_index].start_passive_action(target)
			pass
		ally_index += 1
	else:
		ally_index = 0
	if enemy_index < enemy_chars.size():
		if check_passive_readyness(enemy_chars[enemy_index]):
			var target = aquire_target(ally_chars)
			enemy_chars[enemy_index].start_passive_action(target)
			pass
		enemy_index += 1
	else:
		enemy_index = 0
		pass

func check_passive_readyness(node):
	if !node.active:
		if node.passive_ready:
			return true
func aquire_target(target_list): #remember to update childrens first
	var index = 0
	if target_list.size() == 0:
		pass
	elif target_list.size() == 1:
		return target_list[0]
	else:
		var random = randi() % (target_list.size() - 1)
		print (random)
		return (target_list[random])
#		return a #todo, make this shit more comlicated, and include shitload of possible simple actions

func update_children_list():
	chars = []
	ally_chars = []
	enemy_chars = []
	for child in get_children():
		if child.is_in_group("char"):
			if child.stats.hp_cur <= 0: #is dead?
				if child.ally:
					ally_down.append(child.stats)
				if play_mode == MAP_MODE:
					child.queue_free()
			else:
				if child.ally:
					ally_chars.append(child)
				else:
					enemy_chars.append(child)
				chars.append(child)
		elif child.is_in_group("destroy"):
			if play_mode == MAP_MODE:
				child.queue_free()
	if enemy_chars == []:
		print("you won")
		get_tree().quit()
	elif ally_chars == []:
		print("you lose")
		get_tree().quit()