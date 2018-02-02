extends Spatial
export var hot_seat = false
var chars = []
var ally_chars = []
var enemy_chars = []
var ally_down = []

const MAP_MODE = 0
const ACTION_MODE = 1
const LOSE_MODE = 2
const WIN_MODE = 3
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
var ui_cooldown = DEFAULT_COUNTDOWN
const DEFAULT_COUNTDOWN = 15
func end_actions(node):
	ui_cooldown = DEFAULT_COUNTDOWN
	play_mode = MAP_MODE
	chars = []
	if hot_seat:
		pass
	else:
		next_turn_ai = node.ally
	update_children_list()
	for char in chars:
		char.action_end()
		if hot_seat:
			if char.ally:
				char.ally = false
			else:
				char.ally = true
	get_node("../map_cam").make_current() #must be done after char.action_end()

const DEFAULT_ACTION_COOLDOWN = 30
var action_cooldown = DEFAULT_ACTION_COOLDOWN
var passive_ready = 1
onready var map_cam = get_node("../map_cam")
var focus_char = 0
var focus_ally = 0
var focus_enemy = 0

const DEFAULT_PROXIMITY = 50
const PROXIMITY_MAX = 80
const PROXIMITY_MIN = 3
var proximity = DEFAULT_PROXIMITY
var diference = Vector3()
var over_timer = 0
var focus = true
var cam_speed = 0
var max_cam_speed = 10
func _fixed_process(delta):
	map_cam.get_node("fps").set_text(str(OS.get_frames_per_second()))
	
	if play_mode == MAP_MODE:
		ui_cooldown -= 1
		update_characters_icons()
		if next_turn_ai:
			if ui_cooldown <= 0:
				update_children_list()
				var starter = aquire_target(enemy_chars)
				start_actions(starter)
		else:
			diference = Vector3()
			if Input.is_action_pressed("move_left"):
				focus = false
				diference.x = -1
			elif Input.is_action_pressed("move_right"):
				focus = false
				diference.x = 1
			else:
				diference.x = 0
			if Input.is_action_pressed("move_forwards"):
				focus = false
				diference.z = -1
			elif Input.is_action_pressed("move_backwards"):
				focus = false
				diference.z = 1
			else:
				diference.z = 0
			
			if ui_cooldown <= 0:
				if Input.is_action_pressed("ui_focus_next"):
					focus = true
					if focus_char > 0:
						focus_char -= 1
					else:
						focus_char = chars.size() - 1
					ui_cooldown = DEFAULT_COUNTDOWN
				elif Input.is_action_pressed("ui_focus_prev"):
					focus = true
					if focus_char < chars.size() - 1:
						focus_char += 1
					else:
						focus_char = 0
					ui_cooldown = DEFAULT_COUNTDOWN
			if Input.is_action_pressed("map_zoom_in") or Input.is_mouse_button_pressed(BUTTON_WHEEL_UP):
				proximity = proximity * .9
			elif Input.is_action_pressed("map_zoom_out") or Input.is_mouse_button_pressed(BUTTON_WHEEL_DOWN):
				proximity = proximity * 1.1
			
			var origin_char = map_cam.get_global_transform().origin
			if focus:
				var target_char = chars[focus_char].get_global_transform().origin
				target_char.y = target_char.y + proximity
				diference = target_char.linear_interpolate(origin_char,.1)
			else:
				diference = origin_char + (diference.normalized() * (proximity/50))
			
			proximity = max(PROXIMITY_MIN,min(proximity,PROXIMITY_MAX))
			map_cam.set_translation(Vector3(diference.x,proximity,diference.z))
	
	elif play_mode == ACTION_MODE:
		if action_cooldown <= 0:
			if passive_ready > 0:
				passive_ready -= 1
#			update_passive_characters()
			action_cooldown = DEFAULT_ACTION_COOLDOWN
		else:
			action_cooldown -= 1
	elif play_mode == LOSE_MODE:
		get_node("../").get_node("map_cam/gui/fail").show()
		over_timer = min(over_timer,1)
		get_node("../").get_node("map_cam/gui/fail/fail1").set_modulate(Color(0,0,1,over_timer))
		over_timer += .01
	elif play_mode == WIN_MODE:
		get_node("../").get_node("map_cam/gui/fail").show()
		over_timer = min(over_timer,1)
		get_node("../").get_node("map_cam/gui/fail/fail1").set_modulate(Color(1,0,0,over_timer))
		over_timer += .01

func update_characters_icons():
	for char in chars:
		char.get_node("icon").set_pos(map_cam.unproject_position(char.get_global_transform().origin))



var enemy_index = 0
var ally_index = 0
var enemy_target_index = 0
var ally_target_index = 0

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
		play_mode = WIN_MODE
		print("you won")
	elif ally_chars == []:
		play_mode = LOSE_MODE
		print("you lose")