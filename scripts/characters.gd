extends Spatial
var chars = []
var ally_chars = []
var ally_down = []
var enemy_chars = []
const MAP_MODE = 0
const ACTION_MODE = 1
var play_mode = MAP_MODE

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
var cooldown = DEFAULT_COUNTDOWN
const DEFAULT_COUNTDOWN = 20
func end_actions(node):
	cooldown = DEFAULT_COUNTDOWN
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
onready var map_cam = get_node("../map_cam")
var focus_char = 0
const DEFAULT_PROXIMITY = 50
const PROXIMITY_MAX = 80
const PROXIMITY_MIN = 3
var proximity = DEFAULT_PROXIMITY


func _fixed_process(delta):
	map_cam.get_node("fps").set_text(str(OS.get_frames_per_second()))
	
	if play_mode == MAP_MODE:
		cooldown -= 1
		if next_turn_ai:
			if cooldown <= 0:
				update_children_list()
				var starter = aquire_target(enemy_chars)
				print(starter)
				start_actions(starter)
		else:
			if cooldown <= 0:
				if Input.is_action_pressed("ui_focus_next"):
					if focus_char > 0:
						focus_char -= 1
					else:
						focus_char = chars.size() - 1
					cooldown = DEFAULT_COUNTDOWN
				elif Input.is_action_pressed("ui_focus_prev"):
					if focus_char < chars.size() - 1:
						focus_char += 1
					else:
						focus_char = 0
					cooldown = DEFAULT_COUNTDOWN
				if Input.is_action_pressed("map_zoom_in"):
					proximity = proximity * .9
				elif Input.is_action_pressed("map_zoom_out"):
					proximity = proximity * 1.1
				
		var target_char = chars[focus_char].get_global_transform().origin
		target_char.y = target_char.y + proximity
		var origin_char = map_cam.get_global_transform().origin
		var diference = origin_char.linear_interpolate(target_char,.2)
		proximity = max(PROXIMITY_MIN,min(proximity,PROXIMITY_MAX))
		map_cam.set_translation(Vector3(diference.x,proximity,diference.z))
			
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