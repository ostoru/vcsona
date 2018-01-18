# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends RigidBody

export var active = false
export var ally = false
var ai_mode = false
var target = self
var passive_ready = true
const DEFF_ACTION_TIMER = 200
var action_timer = DEFF_ACTION_TIMER

onready var world = get_node("../")
onready var navmesh = get_node("../../Navigation")
onready var bullet_inst_scene = preload("res://media/sprites/particles/bullet_instance.xml")
onready var ani_tree = get_node("Yaw/AnimationTreePlayer")
onready var ani_node = get_node("Yaw/AnimationPlayer")

var stats = {
	active = false,
	ally = false,
	hp_cur = 100,
	hp_max = 100,
	stm_max = 10000,
	stm_cur = 10000
	}

var view_sensitivity = 0.25
var yaw = 0
var pitch = 0.5
var is_moving = false

const max_accel = 0.005
const air_accel = 0.02

# Walking speed and jumping height are defined later.
var walk_speed
var jump_speed

var health = 100
var ray_length = 10

var models = []
func _ready():
	rotate_y(rand_range(0,2))
	for child in get_node("Yaw/metarig/Skeleton").get_children():
		if child extends MeshInstance:
			models.append(child)
	if ally:
		get_node("Yaw/icon/highlight").set_modulate(Color("#93efff")) #blue
		get_node("Yaw/icon/SpotLight").set_color(.5,Color("#93efff"))
	else:
		get_node("Yaw/icon/highlight").set_modulate(Color("#ff7070")) #red
		get_node("Yaw/icon/SpotLight").set_color(.5,Color("#ff7070"))
	get_node("Yaw/metarig/Skeleton").rotate_y(deg2rad(180))
	get_node("gui").hide()

#select charater using mouse clicks
func _mouse_enter():
	if ally:
		get_node("Yaw/icon/highlight").set_scale(Vector3(1,1,1) * 1.5)
#		get_node("Yaw/icon").play("default")
	get_node("Yaw/icon/OmniLight").show()
	get_node("Yaw/icon/SpotLight").show()
func _mouse_exit():
	get_node("Yaw/icon/highlight").set_scale(Vector3(1,1,1))
	get_node("Yaw/icon/OmniLight").hide()
	get_node("Yaw/icon/SpotLight").hide()
#	get_node("Yaw/icon").stop()
func _input_event(camera, event, click_pos, click_normal, shape_idx):
	if event.is_action("attack"):
		if ally:
			active = true
			get_node("Sounds").play("jump")
			if stats.hp_cur >= 0:
				get_node("../").start_actions(self)
		else:
			get_node("Sounds").play("fire")

# called by parent node
func action_start(active_node,current_target):
	get_node("Body").get_shape().set_radius(.18)
	get_node("Body").get_shape().set_height(1.5)
	pitch = .5
	ani_tree.timeseek_node_seek("seek",.5)
	ani_tree.animation_node_set_animation("move",ani_node.get_animation("mn -loop"))
	get_node("Yaw/metarig").show()
	get_node("Yaw/icon").hide()
	get_node("Yaw/metarig/Skeleton/gun/origin").set_rotation(Vector3(0,0,0))
	action_timer = DEFF_ACTION_TIMER
	get_node("gui/health_enemy").set_max(action_timer)
	set_fixed_process(true)
	if active_node == self:
		active = true
		target = current_target
	else:
		target = active_node
	if active:
		if ally:
			set_process_input(true)
		else:
			ai_mode = true
			start_active_action()
		get_node("Yaw/metarig/Skeleton/gun/Camera").make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_node("gui").show()
	update_materials()

# called by parent node
func action_end():
	get_node("Body").get_shape().set_radius(1)
	get_node("Body").get_shape().set_height(0)
	pitch = .5
	ani_tree.timeseek_node_seek("seek",.5)
	ani_tree.animation_node_set_animation("move",ani_node.get_animation("mn -loop"))
	active = false
	ai_mode = false
	get_node("Yaw/metarig").hide()
	get_node("Yaw/icon").show()
	get_node("Yaw/metarig/Skeleton/gun/origin").set_rotation(Vector3(0,0,0))
	get_node("Yaw/metarig/Skeleton/gun/Camera").clear_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_fixed_process(false)
	set_process_input(false)
	get_node("gui").hide()

func _input(event):
	if event.type == InputEvent.MOUSE_MOTION:
		yaw = fmod(yaw - event.relative_x * view_sensitivity, 360)
		pitch = max(min(pitch - (event.relative_y * view_sensitivity * .01), 1), 0)
		get_node("Yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
#		get_node("Yaw/Camera").set_rotation(Vector3(deg2rad(pitch), 0, 0))
	
	# Toggle mouse capture:
	if Input.is_action_pressed("toggle_mouse_capture"):
		if (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			view_sensitivity = 0
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			view_sensitivity = 0.25

	elif Input.is_action_pressed("char reload"):
		get_node("../").end_actions(self)



func shoot():
	if cooldown_shoot <= 0: #normally i wouldn't put this here, but is going to be called from so many places i might as well
		get_node("Sounds").play("rifle")
		var bullet_inst = bullet_inst_scene.instance()
		var origin = get_node("Yaw/metarig/Skeleton/gun/origin").get_global_transform()
		bullet_inst.set_transform(origin)
		var direction = get_node("Yaw/metarig/Skeleton/gun/origin/direction").get_global_transform() #todo: add bullet spraying
		bullet_inst.add_to_group("destroy")
		world.add_child(bullet_inst)
		if active:
			cooldown_shoot = 5 #todo change this value for weapon rate of fire
		else:
			cooldown_shoot = 10 #todo change this value for weapon rate of fire

#main loop
func _fixed_process(delta):
	if stats.hp_cur > 0:
		update_gui()
		cooldown_shoot -= 1
		if active:
			if ally:
				if Input.is_action_pressed("attack"):
					shoot()
			else:
				action_timer -= 1
				if action_timer <= 0:
					get_node("../").end_actions(self) 
				else:
					passive_look_at_target()
		else: #passive characters
			passive_look_at_target()
			if remaining_passive_action > 0:
				passive_ready = false
				passive_action()
			else:
				end_passive_action()
		is_moving = false
	else:
		update_materials()

func _integrate_forces(state):
	# Default walk speed:
	walk_speed = 3.5
	# Default jump height:
	jump_speed = 5
	
	# Cap stamina:
	stats.stm_cur = max(0,min(stats.stm_cur,stats.stm_max))
#	if stats.stm_cur >= 10000:
#		stats.stm_cur = 10000
#	if stats.stm_cur <= 0:
#		stats.stm_cur = 0
	
	var aim = get_node("Yaw").get_global_transform().basis
	
	var direction = Vector3()
	var ani_to_play = "mn -loop"
	var anim_dir = Vector2()
	
	if active:
		if ai_mode:
			if path.size() > 0:
				direction = path[0] - get_global_transform().origin
				if direction.abs() < direction.normalized().abs():
					path.remove(0)
				else:
					is_moving = true
		else:
			if Input.is_action_pressed("move_forwards"):
				direction -= aim[2]
				anim_dir = Vector2(0,1)
				is_moving = true
			if Input.is_action_pressed("move_backwards"):
				direction += aim[2]
				anim_dir = Vector2(0,-1)
				is_moving = true
			if Input.is_action_pressed("move_left"):
				direction -= aim[0]
				anim_dir = Vector2(-1,0)
				is_moving = true
			if Input.is_action_pressed("move_right"):
				direction += aim[0]
				anim_dir = Vector2(1,0)
				is_moving = true
	
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
	direction = direction.normalized()
	var ray = get_node("Ray")
	
	# Increase walk speed and jump height while running and decrement stamina:
	if Input.is_action_pressed("run") and is_moving and ray.is_colliding() and stats.stm_cur > 0:
		walk_speed *= 1.4
		jump_speed *= 1.2
		stats.stm_cur -= 15
	
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

		var diff = floor_velocity + direction * walk_speed - state.get_linear_velocity()
		var vertdiff = aim[1] * diff.dot(aim[1])
		diff -= vertdiff
		diff = diff.normalized() * clamp(diff.length(), 0, max_accel / state.get_step())
		diff += vertdiff

		apply_impulse(Vector3(), diff * get_mass())

		# Regenerate stamina:
		stats.stm_cur += 5
		if active:
			if Input.is_action_pressed("jump") and stats.stm_cur > 150:
				apply_impulse(Vector3(), normal * jump_speed * get_mass())
				ani_tree.animation_node_set_animation("move",ani_node.get_animation("air -loop"))
				get_node("Sounds").play("jump")
				stats.stm_cur -= 150

	else:
		apply_impulse(Vector3(), direction * air_accel * get_mass())

	state.integrate_forces()

func _exit_scene():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Functions
# =========
var value = 1

func start_passive_action(node):
	if node != self:
		passive_ready = false
		target = node
		remaining_passive_action = 5
		return 1
	else:
		passive_ready = true
		return 0
	update_materials()

var remaining_passive_action = 5
var cooldown_shoot = 20

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
		if cooldown_shoot <= 0:
			shoot()
	update_materials()

func end_passive_action():
	if passive_ready == false:
		passive_ready = true
		get_node("../").passive_ready += 1
	remaining_passive_action = 0
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
	get_node("gui/health_self").set_val(stats.hp_cur)
	get_node("gui/health_self").set_max(stats.hp_max)
	get_node("gui/health_enemy").set_val(stats.hp_cur)
	get_node("gui/health_enemy").set_max(stats.hp_max)
	get_node("gui/stamina").set_val(stats.stm_cur)
	get_node("gui/stamina").set_max(stats.stm_max)
	get_node("gui/action").set_val(action_timer)
	get_node("gui/action").set_max(DEFF_ACTION_TIMER)
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