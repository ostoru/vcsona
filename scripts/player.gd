# Copyright (c) 2015 Calinou
# This source code form is governed by the MIT license.
# See LICENSE.md for more information.

extends RigidBody

export var active = false
export var ally = false

var stats = {
	active = false,
	ally = false,
	hp_cur = 100,
	hp_max = 100,
	stm_max = 100,
	stm_cur = 100
	}

var view_sensitivity = 0.25
var yaw = 0
var pitch = 0
var is_moving = false

const max_accel = 0.005
const air_accel = 0.02

var timer = 0

# Walking speed and jumping height are defined later.
var walk_speed
var jump_speed

var health = 100
var stamina = 10000
var ray_length = 10

#selects charater using mouse click
func _mouse_enter():
	get_node("icon/highlight").set_scale(Vector3(1,1,1) * 3)
	get_node("icon").play("default")
func _mouse_exit():
	get_node("icon/highlight").set_scale(Vector3(1,1,1))
	get_node("icon").stop()
func _input_event(camera, event, click_pos, click_normal, shape_idx):
	if event.is_action("attack"):
		active = true
		get_node("../").start_actions()
	pass

# called by parent node
onready var ani_tree = get_node("Yaw/AnimationTreePlayer")
func action_start():
	pitch = .5
	ani_tree.animation_node_set_animation("anim",ani_node.get_animation("mn -loop"))
	get_node("Yaw/metarig").show()
	get_node("icon").hide()
	if active:
		get_node("Yaw/Camera").make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_fixed_process(true)
		set_process_input(true)
		get_node("Crosshair").show()

# called by parent node
func action_end():
	get_node("Yaw/metarig").hide()
	get_node("icon").show()
	get_node("Yaw/Camera").clear_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_fixed_process(false)
	set_process_input(false)
	get_node("Crosshair").hide()
	active = false
	pass

func _input(event):
	if event.type == InputEvent.MOUSE_MOTION:
		yaw = fmod(yaw - event.relative_x * view_sensitivity, 360)
		pitch = max(min(pitch - (-event.relative_y * view_sensitivity * .01), 1), 0)
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

	# Quit the game:
	if Input.is_action_pressed("quit"):
		quit()
	elif Input.is_action_pressed("char reload"):
		get_node("../").end_actions()

onready var bullet_inst_scene = preload("res://media/sprites/particles/bullet_impact.xml")
onready var world = get_node("../")
onready var ani_node = get_node("Yaw/AnimationPlayer")

func shoot():
	var bullet_inst = bullet_inst_scene.instance()
	var origin = get_node("Yaw/gun/origin").get_global_transform()
	bullet_inst.set_transform(origin)
	var direction = get_node("Yaw/gun/origin/direction").get_global_transform()
	bullet_inst.set_linear_velocity((direction.origin - origin.origin).normalized() * 50)
	bullet_inst.add_to_group("destroy")
	world.add_child(bullet_inst)

func _fixed_process(delta):
	get_node("FPS").set_text(str(OS.get_frames_per_second(), " FPS"))
	get_node("Stamina").set_value(stamina)
	
	timer -= 1
	if timer <= 0:
		if Input.is_action_pressed("attack"):
			shoot()
			get_node("Sounds").play("rifle")
			timer = 8
	
	is_moving = false


func _integrate_forces(state):
	# Default walk speed:
	walk_speed = 3.5
	# Default jump height:
	jump_speed = 5
	
	# Cap stamina:
	if stamina >= 10000:
		stamina = 10000
	if stamina <= 0:
		stamina = 0
	
	var aim = get_node("Yaw").get_global_transform().basis
	
	var direction = Vector3()
	var ani_to_play = "mn -loop"
	if active:
		var anim_dir = Vector2()
		if Input.is_action_pressed("move_forwards"):
			direction += aim[2]
			anim_dir = Vector2(0,1)
			is_moving = true
		if Input.is_action_pressed("move_backwards"):
			direction -= aim[2]
			anim_dir = Vector2(0,-1)
			is_moving = true
		if Input.is_action_pressed("move_left"):
			anim_dir = Vector2(-1,0)
			direction += aim[0]
			is_moving = true
		if Input.is_action_pressed("move_right"):
			anim_dir = Vector2(1,0)
			direction -= aim[0]
			is_moving = true
		if anim_dir == Vector2(0,1):
			ani_to_play = "mf -loop"
		elif anim_dir == Vector2(0,-1):
			ani_to_play = "mb -loop"
		elif anim_dir == Vector2(-1,0):
			ani_to_play = "ml -loop"
		elif anim_dir == Vector2(1,0):
			ani_to_play = "mr -loop"
#		else:
#			ani_to_play = "mn -loop"
	ani_tree.timeseek_node_seek("seek",pitch)
	ani_tree.animation_node_set_animation("anim",ani_node.get_animation(ani_to_play))
	direction = direction.normalized()
	var ray = get_node("Ray")
	
	# Increase walk speed and jump height while running and decrement stamina:
	if Input.is_action_pressed("run") and is_moving and ray.is_colliding() and stamina > 0:
		walk_speed *= 1.4
		jump_speed *= 1.2
		stamina -= 15
	
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
		stamina += 5
		if active:
			if Input.is_action_pressed("jump") and stamina > 150:
				apply_impulse(Vector3(), normal * jump_speed * get_mass())
				ani_node.play("jump")
				get_node("Sounds").play("jump")
				stamina -= 150

	else:
		apply_impulse(Vector3(), direction * air_accel * get_mass())

	state.integrate_forces()

func _exit_scene():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Functions
# =========

# Quits the game:
func quit():
	get_tree().quit()
