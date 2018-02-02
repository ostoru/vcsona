# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends RigidBody

var initialized = false
export var active = false
export var ally = false
var ai_mode = false
var target = self
var passive_ready = true
const DEFF_ACTION_TIMER = 800
var action_timer = DEFF_ACTION_TIMER

onready var world = get_node("../")
onready var navmesh = get_node("../../Navigation")
onready var bullet_inst_scene = preload("res://media/sprites/particles/bullet_instance.xml")
onready var ani_tree = get_node("Yaw/AnimationTreePlayer")
onready var ani_node = get_node("Yaw/AnimationPlayer")

var stats = {
	#unit info
	name = "", #for now, just node name
	active = false,
	ally = false,
	
	#base stats
	hp_cur = 100, #increases towards maximum at turn start
	hp_max = 100,
	stm_cur = 1000, #resets between actions, uses action_count to determine maximum
	stm_max = 1000,
	
	speed_max = 5,
	speed_min = 1,
	speed_cur = 1,
	
	action_count = 0 #used for buff/debuff while reusing a character in the same turn
	}

var weapon = {
	#weapon type
	weapon_name = "generic riffle",
	reloading = 0,
	cooldown = 0,
	
	#weapon stats
	active = {
		magazine_max = 30,
		magazine_cur = 0,
		reserve_max = 150,
		reserve_cur = 150,
		reload_speed = 30,
		rate_of_fire = 15,
		projectile_speed = 400,
		},
	passive = {
		magazine_max = 10,
		magazine_cur = 0,
		reserve_max = -1,
		reserve_cur = -1,
		reload_speed = 30,
		rate_of_fire = 5,
		projectile_speed = 200,
		},
	current = {
		magazine_max = 0,
		magazine_cur = 0,
		reserve_max = 0,
		reserve_cur = 0,
		reload_speed = 0,
		rate_of_fire = 0,
		projectile_speed = 0,
		},
	}

onready var options = get_node("../../../").options
var yaw = 0
var pitch = 0.5

const max_accel = 0.005
const air_accel = 0.02

var jump_speed

var models = []
func _ready():
	stats.name = get_name()
	rotate_y(rand_range(0,2))
	for child in get_node("Yaw/metarig/Skeleton").get_children():
		if child extends MeshInstance:
			models.append(child)
	get_node("Yaw/metarig/Skeleton").rotate_y(deg2rad(180))
	get_node("gui").hide()
	dogtag.hide()

#select charater using mouse clicks

onready var dogtag = get_node("dogtag")
func update_dogtag():
	dogtag.get_node("weapon name").set_text(weapon.weapon_name)
	dogtag.get_node("name").set_text(self.get_name())
	dogtag.get_node("hp").set_max(stats.hp_max)
	dogtag.get_node("hp").set_val(stats.hp_max)
	dogtag.get_node("hp/label").set_text(str(stats.hp_cur) + "/" + str(stats.hp_max))
	dogtag.get_node("stamina").set_max(stats.stm_max)
	dogtag.get_node("stamina").set_val(stats.stm_cur)
	dogtag.get_node("stamina/label").set_text(str(stats.stm_cur) + "/" + str(stats.stm_max))
	dogtag.get_node("bullets").set_max(weapon.active.magazine_max)
	dogtag.get_node("bullets").set_val(weapon.active.magazine_cur)
	dogtag.get_node("bullets/label").set_text(str(weapon.active.magazine_cur) + "/" + str(weapon.active.magazine_max))


# called by parent node
func action_start(active_node,current_target):
	get_node("Body").get_shape().set_radius(.18)
	get_node("Body").get_shape().set_height(1.5)
	pitch = .5
	ani_tree.timeseek_node_seek("seek",.5)
	ani_tree.animation_node_set_animation("move",ani_node.get_animation("mn -loop"))
	get_node("Yaw/metarig").show()
	get_node("icon").hide()
	get_node("Yaw/metarig/Skeleton/gun/origin").set_rotation(Vector3(0,0,0))
	action_timer = DEFF_ACTION_TIMER
	get_node("gui/health_enemy").set_max(action_timer)
	set_fixed_process(true)
	if active_node == self:
		active = true
		target = current_target
	else:
		target = active_node
	if active: #for some reason doesn't work in the "active_node == self" check:
		weapon.current = weapon.active
		if ally:
			set_process_input(true)
			
		else:
			ai_mode = true
			start_active_action()
		get_node("Yaw/metarig/Skeleton/gun/Camera").make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_node("gui").show()
	else:
		weapon.current = weapon.passive
	update_materials()

# called by parent node
func action_end():
	get_node("Body").get_shape().set_radius(0)
	get_node("Body").get_shape().set_height(0)
	pitch = .5
	ani_tree.timeseek_node_seek("seek",.5)
	ani_tree.animation_node_set_animation("move",ani_node.get_animation("mn -loop"))
	
	if active:
		weapon.active = weapon.current
		active = false
		ai_mode = false
	else:
		weapon.passive = weapon.current
	get_node("Yaw/metarig").hide()
	get_node("icon").show()
	get_node("Yaw/metarig/Skeleton/gun/origin").set_rotation(Vector3(0,0,0))
	get_node("Yaw/metarig/Skeleton/gun/Camera").clear_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_fixed_process(false)
	set_process_input(false)
	get_node("gui").hide()

#main loop
func _fixed_process(delta):
	if stats.hp_cur > 0:
		action_timer -= 1
		weapon.cooldown -= 1
		weapon.reloading -= 1
		if weapon.reloading == 0:
			var mag_diff = weapon.current.magazine_max - weapon.current.magazine_cur
			if weapon.current.reserve_cur == -1:
				weapon.current.magazine_cur = weapon.current.magazine_max
			elif mag_diff < weapon.current.reserve_cur:
				weapon.current.magazine_cur += mag_diff
				weapon.current.reserve_cur -= mag_diff
			else:
				weapon.current.magazine_cur += weapon.current.reserve_cur
				weapon.current.reserve_cur = 0
		update_gui()
		if action_timer <= 0:
			get_node("../").end_actions(self)
		if active:
			if ally:
				check_player_input()
			else:
				passive_look_at_target() #todo: change for active look at characters
		else: #passive characters
			passive_look_at_target()
			if target.ally == self.ally:
				pass
			else:
				passive_action()
	else:
		if self.active:
			get_node("../").end_actions(self)
		update_materials()

#timers: all these are timers and are used to blend animations
var is_fullbody = 0 #full body animations
var is_running = 0 #min_max function (0,1), acts as speed multiplier
var is_aiming = 0 #min_max function (0,1), animation blend, zoom/pos modifier
var is_crouching = 0 #min max function

#tracking
var is_airborne = false
var is_moving = false
var is_grounded = true

export var can_cancel = 0 #countdown, check if it is <= 0. following options only apply when can_cancel is true
export var can_aim = true
export var can_move = true #being true doesn't mean that animations play
export var is_looking = true #is looking at camera's direction?
export var can_jump = 1 #decreses each time, always 1 over ground
export var can_evade = 2 # consecutive evades

var move_direction = Vector3()
var anim_dir = Vector2()
var input_direction = Vector2()

var relative_mouse_motion = Vector2()
func _input(event):
	if event.type == InputEvent.MOUSE_MOTION:
		relative_mouse_motion += event.relative_pos

func check_player_input():
	#cam_look
	yaw = fmod(yaw - relative_mouse_motion.x * options.view_sensitivity, 360)
	pitch = max(min(pitch - (relative_mouse_motion.y * options.view_sensitivity * .01), 1), 0)
	get_node("Yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
	relative_mouse_motion = Vector2()
	
	if Input.is_action_pressed("aim"):
		if can_aim:
			is_aiming = min (1, is_aiming + 0.1)
		else:
			is_aiming = 0
	else:
		is_aiming = max(is_aiming - .1, 0)
	get_node("Yaw/metarig/Skeleton/gun/Camera").set_perspective(95 - (65 * is_aiming), .1,1000)
	options.view_sensitivity = 0.15 - (0.1 * is_aiming)
	
	#movement
	move_direction = Vector3()
	is_moving = false
	rotation = get_node("Yaw").get_global_transform().basis
	if Input.is_action_pressed("move_forwards"):
		move_direction -= rotation[2]
		anim_dir = Vector2(0,1)
		is_moving = true
	if Input.is_action_pressed("move_backwards"):
		move_direction += rotation[2]
		anim_dir = Vector2(0,-1)
		is_moving = true
	if Input.is_action_pressed("move_left"):
		move_direction -= rotation[0]
		anim_dir = Vector2(-1,0)
		is_moving = true
	if Input.is_action_pressed("move_right"):
		move_direction += rotation[0]
		anim_dir = Vector2(1,0)
		is_moving = true
	
	if is_moving:
		if Input.is_action_pressed("run"):
			stats.speed_cur = min(stats.speed_cur + 0.1, stats.speed_max)
		else:
			stats.speed_cur = max(stats.speed_cur - 0.2, stats.speed_min)
	else:
		stats.speed_cur = max(0, stats.speed_cur - .1)
	
	
	if weapon.cooldown <= 0:
		if Input.is_action_pressed("attack"):
			shoot()
		if Input.is_action_pressed("char reload"):
			reload()
		pass
	pass

onready var rotation = get_node("Yaw").get_global_transform().basis
func _integrate_forces(state):
	jump_speed = 5
	
	# Cap stamina:
	stats.stm_cur = max(0,min(stats.stm_cur,stats.stm_max))
	
	
	if active:
		if ai_mode:
			move_direction = Vector3()
			if path.size() > 0:
				move_direction = path[0] - get_global_transform().origin
				if move_direction.abs() < move_direction.normalized().abs():
					path.remove(0)
				else:
					is_moving = true
	
	var ani_to_play = "mn -loop"
	if anim_dir == Vector2(0,1):
		ani_to_play = "mf -loop"
	elif anim_dir == Vector2(0,-1):
		ani_to_play = "mb -loop"
	elif anim_dir == Vector2(-1,0):
		ani_to_play = "ml -loop"
	elif anim_dir == Vector2(1,0):
		ani_to_play = "mr -loop"
	else:
		ani_to_play = "mn -loop"
	ani_tree.timeseek_node_seek("seek",pitch)
	ani_tree.animation_node_set_animation("move",ani_node.get_animation(ani_to_play))
	move_direction = move_direction.normalized()
	
	var ray = get_node("Ray")
	
	# Increase walk speed and jump height while running and decrement stamina:
	if Input.is_action_pressed("run") and is_moving and ray.is_colliding() and stats.stm_cur > 0:
		stats.speed_cur *= 2
		jump_speed *= 2
		stats.stm_cur -= 7
	if ray.is_colliding():
		var up = state.get_total_gravity().normalized()
		var normal = ray.get_collision_normal()
		var floor_velocity = Vector3()
		var object = ray.get_collider()
		
		if object extends RigidBody or object extends StaticBody:
			var point = ray.get_collision_point() - object.get_translation()
			var floor_angular_vel = Vector3()
			if object extends RigidBody:
				floor_velocity = object.get_linear_velocity()
				floor_angular_vel = object.get_angular_velocity()
			elif object extends StaticBody:
				floor_velocity = object.get_constant_linear_velocity()
				floor_angular_vel = object.get_constant_angular_velocity()
			# Surely there should be a function to convert Euler angles to a 3x3 matrix
			var transform = Matrix3(Vector3(1, 0, 0), floor_angular_vel.x)
			transform = transform.rotated(Vector3(0, 1, 0), floor_angular_vel.y)
			transform = transform.rotated(Vector3(0, 0, 1), floor_angular_vel.z)
			floor_velocity += transform.xform_inv(point) - point
			yaw = fmod(yaw + rad2deg(floor_angular_vel.y) * state.get_step(), 360)
			get_node("Yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
		var diff = floor_velocity + move_direction * stats.speed_cur - state.get_linear_velocity()
		var vertdiff = rotation[1] * diff.dot(rotation[1])
		diff -= vertdiff
		diff = diff.normalized() * clamp(diff.length(), 0, max_accel / state.get_step())
		diff += vertdiff
		apply_impulse(Vector3(), diff * get_mass())
		# Regenerate stamina:
		if active:
			if Input.is_action_pressed("jump") and stats.stm_cur > 30:
				apply_impulse(Vector3(), normal * jump_speed * get_mass())
				ani_tree.animation_node_set_animation("move",ani_node.get_animation("air -loop"))
				get_node("Sounds").play("jump")
				stats.stm_cur -= 30
	else:
		apply_impulse(Vector3(), move_direction * air_accel * get_mass())
	stats.stm_cur += 5
	state.integrate_forces()

func shoot():
	if weapon.cooldown <= 0: #normally i wouldn't put this here, but is going to be called from so many places i might as well
		if weapon.current.magazine_cur > 0:
			get_node("Sounds").play("rifle")
			var bullet_inst = bullet_inst_scene.instance()
			var origin = get_node("Yaw/metarig/Skeleton/gun/origin").get_global_transform()
			bullet_inst.set_transform(origin) #todo: add bullet spraying
			bullet_inst.add_to_group("destroy")
			world.add_child(bullet_inst)
			weapon.current.magazine_cur -= 1
			bullet_inst.speed = weapon.current.projectile_speed
			bullet_inst.lifetime = 2000 * 60 /weapon.current.projectile_speed
			weapon.cooldown = 1*60/weapon.current.rate_of_fire
		else:
			reload()

func reload():
	weapon.reloading = weapon.current.reload_speed
	weapon.cooldown = weapon.reloading

func _exit_scene():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Functions
# =========
var remaining_passive_action = 5
func passive_look_at_target():
	var yaw = get_node("Yaw")
	var look = (target.get_node("Body").get_global_transform().origin)
	look.y = self.get_translation().y
	yaw.look_at(look,Vector3(0,1,0))
#	rotate_y(deg2rad(182))
	var a = get_node("Body").get_global_transform().origin
	var b = target.get_node("Body").get_global_transform().origin
	a = Vector2(0,a.y)
	b = Vector2(0,b.y) / get_translation().distance_to(target.get_translation())
	get_node("Yaw/metarig/Skeleton/gun/origin").look_at(target.get_node("Body").get_global_transform().origin,Vector3(0,1,0))
	pitch = (a.angle_to(b)/2) + .5
	ani_tree.timeseek_node_seek("seek",pitch)

func passive_action():
	remaining_passive_action -= .1
	if target != self:
		var a = get_node("Body").get_global_transform().origin
		var b = get_node("Yaw/metarig/Skeleton/gun/origin/direction").get_global_transform().origin
		var c = target.get_node("Body").get_global_transform().origin
		if (a - c).normalized().dot((b - c).normalized()) > .9:
			shoot()
	update_materials()

var path
func start_active_action():
	path = null
	while typeof(path) != TYPE_VECTOR3_ARRAY:
		path = navmesh.get_simple_path(get_node("Body").get_global_transform().origin, target.get_node("Body").get_global_transform().origin,false)
	for point in path:
		var visual_path = preload ("res://media/sprites/particles/bullet_impact.xml").instance()
		visual_path.lifetime = DEFF_ACTION_TIMER
		visual_path.set_translation(point)
		get_node("../").add_child(visual_path)

func update_gui():
	get_node("gui/FPS").set_text(str(OS.get_frames_per_second()))
	get_node("gui/health_self").set_max(stats.hp_max)
	get_node("gui/health_self").set_val(stats.hp_cur)
	if weapon.reloading >= 0:
		get_node("gui/health_enemy").set_max(weapon.current.reload_speed)
		get_node("gui/health_enemy").set_val(weapon.current.reload_speed - weapon.reloading)
	else:
		var reserve_cur
		var magazine
		if active:
			pass
		else:
			pass
		get_node("gui/bullets").set_text(str(weapon.current.magazine_cur) + "/" + str(weapon.current.reserve_cur))
		get_node("gui/health_enemy").set_max(weapon.current.magazine_max)
		get_node("gui/health_enemy").set_val(weapon.current.magazine_cur)
		
	get_node("gui/stamina").set_max(stats.stm_max)
	get_node("gui/stamina").set_val(stats.stm_cur)
	get_node("gui/action").set_max(DEFF_ACTION_TIMER)
	get_node("gui/action").set_val(action_timer)
	pass

func update_materials():
	var mat_override = load("res://media/textures/other/passive_enemy.tres")
	if active or !passive_ready:
		if ally:
			mat_override = null
		else:
			mat_override = load("res://media/textures/other/active_enemy.tres")
	else:
		if ally:
			mat_override = load("res://media/textures/other/passive_ally.tres")
	if stats.hp_cur <= 0:
		mat_override = load("res://media/textures/other/dead.tres")
	for mesh in models:
			mesh.set_material_override(mat_override)
	pass