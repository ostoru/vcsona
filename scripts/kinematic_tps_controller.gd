
extends KinematicBody

#classes
const default_data_model=preload("res://addons/eco.fps.controller/player_data_base.gd")
const default_projectile_factory=preload("res://addons/eco.fps.controller/projectiles/Projectile_Factory.gd")

onready var playground = get_node("../")
var _is_loaded = false
var velocity=Vector3()
var yaw = 0
var pitch = 0
var is_moving=false
var on_floor=false
var jump_timeout=0
var step_timeout=0
var attack_timeout=0
var fly_mode=false
var alive=true
var current_target=null
var current_target_2d_pos=null
var multijump=0
var is_attacking=false
var is_jumping=false
var weapon_base=null

onready var bullet_factory=null
onready var player_data=null

onready var camera=get_node("eco_yaw/camera")
onready var sfx=get_node("eco_sfx")
onready var tween=get_node("eco_tween")

var aim_offset=Vector3(0,1.5,0)

const GRAVITY_FACTOR=3

# params
export(bool) var active=true setget _set_active

## dimensions
export(float) var leg_length=0.4 setget _set_leg_length
export(float) var body_radius=0.6 setget _set_body_radius
export(float) var body_height=0.8 setget _set_body_height
export(float) var camera_height=1.7 setget _set_camera_height
export(float) var action_range=2 setget _set_action_range

## actions
export(String) var action_forward="char front"
export(String) var action_backward="char back"
export(String) var action_left="char left"
export(String) var action_right="char right"
export(String) var action_attack="char fire"
export(String) var action_jump="char jump"
export(String) var action_use="char use"
export(String) var action_reload="char reload"

## physics
export(float) var ACCEL= 2
export(float) var DEACCEL= 4 
export(float) var FLY_SPEED=100
export(float) var FLY_ACCEL=4
export(float) var GRAVITY=-9.8
export(float) var MAX_JUMP_TIMEOUT=0.2
export(float) var MAX_ATTACK_TIMEOUT=0.2
export(int) var MAX_SLOPE_ANGLE = 40
export(float) var STAIR_RAYCAST_HEIGHT=0.75
export(float) var STAIR_RAYCAST_DISTANCE=0.58
export(float) var STAIR_JUMP_SPEED=5
export(float) var STAIR_JUMP_TIMEOUT=0.1
export(float) var footstep_factor=0.004
export(float) var view_sensitivity = 0.3

export(NodePath) var sfx_library=null
## weapon
export(String) var weapon="" setget _set_weapon
export(bool) var embed_children=false

# signals
signal start_shoot
signal stop_shoot
signal attribute_changed(key,value)
signal reload_weapon
signal ammo_used

#################################################################################3

# initializer
func _ready():

	_is_loaded=true

	bullet_factory=get_bullet_factory_instance()
	
	if player_data==null:
		var data=default_data_model.new()
		data.bullet_factory=bullet_factory
		set_player_data(data)

	if sfx_library!=null and !sfx_library.is_empty():
		var node=get_node(sfx_library)
		if node!=null and node.has_method("get_sample_library"):
			get_node("eco_sfx").set_sample_library(node.get_sample_library())
	
	weapon_base=bullet_factory.get_base(player_data.weapon_base_type)
	get_node("eco_yaw/camera/shoot-point").add_child(weapon_base)
	weapon_base.owner=self
	weapon_base.set_sample_library(sfx.get_sample_library())
	
	_update_params()
	
	if embed_children:
		_embed_children()
	
	tween.start()
	
	get_node("eco_yaw/camera/actionRay").add_exception(self)
	
	set_fixed_process(true)
	set_process_input(true)
	
	_regen_bullet()
	

func _update_params():
	_set_active(active)
	_set_leg_length(leg_length)
	_set_body_radius(body_radius)
	_set_body_height(body_height)
	_set_camera_height(camera_height)
	_set_action_range(action_range)
	_set_weapon(weapon)

func notify_attribute_change(key,value):
	emit_signal("attribute_changed",key,value)

func _embed_children():
	var children=self.get_children()
	for child in children:
		if child.get_name().left(4)=="eco_":
			continue
		else:
			remove_child(child)
			camera.add_child(child)

# Keys and mouse handler
func _input(ie):
	if not active:
		return
	
	if ie.type == InputEvent.MOUSE_MOTION:
		yaw = fmod(yaw - ie.relative_x * view_sensitivity, 360)
		pitch = max(min(pitch - ie.relative_y * view_sensitivity, 90), -90)
		get_node("eco_yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
		get_node("eco_yaw/camera").set_rotation(Vector3(deg2rad(pitch), 0, 0))
	
	if ie.type == InputEvent.KEY:
		if Input.is_action_pressed(action_use):
			var ray=get_node("eco_yaw/camera/actionRay")
			if ray.is_colliding():
				var obj=ray.get_collider()
				if obj.has_method("use"):
					obj.use(self)
		elif Input.is_action_pressed(action_reload):
			weapon_base.reload()
			attack_timeout=player_data.reload_time
			emit_signal("reload_weapon")


# main loop
func _fixed_process(delta):
	if Input.is_action_pressed("char fire"):
		playground.shoot(get_node("eco_yaw/camera/shoot-point").get_global_transform())
	
	refresh_current_target()
	
	if player_data.sound_to_play!=null:
		play_sound(player_data.sound_to_play)
		player_data.sound_to_play=null
	
	if fly_mode:
		_fly(delta)
	else:
		_walk(delta)

func _enter_tree():
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _fly(delta):
	# read the rotation of the camera
	var aim = get_node("eco_yaw/camera").get_global_transform().basis
	# calculate the direction where the player want to move
	var direction = Vector3()
	if Input.is_action_pressed(action_forward):
		direction -= aim[2]
	if Input.is_action_pressed(action_backward):
		direction += aim[2]
	if Input.is_action_pressed(action_left):
		direction -= aim[0]
	if Input.is_action_pressed(action_right):
		direction += aim[0]
	
	direction = direction.normalized()
		
	# calculate the target where the player want to move
	var target=direction*FLY_SPEED
	
	# calculate the velocity to move the player toward the target
	velocity=Vector3().linear_interpolate(target,FLY_ACCEL*delta)
	
	# move the node
	var motion=velocity*delta
	motion=move(motion)
	
	# slide until it doesn't need to slide anymore, or after n times
	var original_vel=velocity
	var attempts=4 # number of attempts to slide the node
	
	while(attempts and is_colliding()):
		var n=get_collision_normal()
		motion=n.slide(motion)
		velocity=n.slide(velocity)
		# check that the resulting velocity is not opposite to the original velocity, which would mean moving backward.
		if(original_vel.dot(velocity)>0):
			motion=move(motion)
			if (motion.length()<0.001):
				break
		attempts-=1

func _walk(delta):
	
	# process timers
	if jump_timeout>0:
		jump_timeout-=delta
	if attack_timeout>0:
		attack_timeout-=delta
	
	var ray = get_node("eco_ray")
	var step_ray=get_node("eco_stepRay")
	
	# read the rotation of the camera
	var aim = get_node("eco_yaw/camera").get_global_transform().basis
	# calculate the direction where the player want to move
	var direction = Vector3()
	if Input.is_action_pressed(action_forward):
		direction -= aim[2]
	if Input.is_action_pressed(action_backward):
		direction += aim[2]
	if Input.is_action_pressed(action_left):
		direction -= aim[0]
	if Input.is_action_pressed(action_right):
		direction += aim[0]
	if Input.is_action_pressed(action_attack) and attack_timeout<=0:
		shoot()
		is_attacking=true
	elif is_attacking and not Input.is_action_pressed(action_attack):
		is_attacking=false
		stop_shoot()
	
	#reset the flag for actor's movement state
	is_moving=(direction.length()>0)
	
	direction.y=0
	direction = direction.normalized()
	
	# clamp to ground if not jumping. Check only the first time a collision is detected (landing from a fall)
	var is_ray_colliding=ray.is_colliding()
	if !on_floor and jump_timeout<=0 and is_ray_colliding:
		set_translation(ray.get_collision_point())
		on_floor=true
		play_sound("player_land")
	elif on_floor and not is_ray_colliding:
		# check that flag on_floor still reflects the state of the ray.
		on_floor=false
	
	if on_floor:
		if step_timeout<=0:
			play_sound("player_footstep")
			step_timeout=1
		else:
			step_timeout-=velocity.length()*footstep_factor
		
		# if on floor move along the floor. To do so, we calculate the velocity perpendicular to the normal of the floor.
		var n=ray.get_collision_normal()
		velocity=velocity-velocity.dot(n)*n
		
		# if the character is in front of a stair, and if the step is flat enough, jump to the step.
		if is_moving and step_ray.is_colliding():
			var step_normal=step_ray.get_collision_normal()
			if (rad2deg(acos(step_normal.dot(Vector3(0,1,0))))< MAX_SLOPE_ANGLE):
				velocity.y=STAIR_JUMP_SPEED
				jump_timeout=STAIR_JUMP_TIMEOUT
		
		# apply gravity if on a slope too steep
		if (rad2deg(acos(n.dot(Vector3(0,1,0))))> MAX_SLOPE_ANGLE):
			velocity.y+=delta*GRAVITY*GRAVITY_FACTOR
	else:
		# apply gravity if falling
		velocity.y+=delta*GRAVITY*GRAVITY_FACTOR
	
	# calculate the target where the player want to move
	var target=direction*player_data.walk_speed
	# if the character is moving, he must accelerate. Otherwise he deccelerates.
	var accel=DEACCEL
	if is_moving:
		accel=ACCEL
	
	# calculate velocity's change
	var hvel=velocity
	hvel.y=0
	
	# calculate the velocity to move toward the target, but only on the horizontal plane XZ
	hvel=hvel.linear_interpolate(target,accel*delta)
	velocity.x=hvel.x
	velocity.z=hvel.z
	
	# move the node
	var motion=velocity*delta
	motion=move(motion)
	
	# slide until it doesn't need to slide anymore, or after n times
	var original_vel=velocity
	if(motion.length()>0 and is_colliding()):
		var n=get_collision_normal()
		motion=n.slide(motion)
		velocity=n.slide(velocity)
		# check that the resulting velocity is not opposite to the original velocity, which would mean moving backward.
		if(original_vel.dot(velocity)>0):
			motion=move(motion)
	
	if on_floor:
		# move with floor but don't change the velocity.
		var floor_velocity=_get_floor_velocity(ray,delta)
		if floor_velocity.length()!=0:
			move(floor_velocity*delta)
	
		# jump
		if Input.is_action_pressed(action_jump):
			velocity.y=player_data.jump_strength
			jump_timeout=MAX_JUMP_TIMEOUT
			on_floor=false
			multijump=player_data.get_modifier("multijump")
			play_sound("player_jump")
	elif Input.is_action_pressed(action_jump) and multijump>0 and jump_timeout<=0:
		velocity.y=player_data.jump_strength
		jump_timeout=MAX_JUMP_TIMEOUT
		on_floor=false
		multijump-=1
	
	# update the position of the raycast for stairs to where the character is trying to go, so it will cast the ray at the next loop.
	if is_moving:
		var sensor_position=Vector3(direction.z,0,-direction.x)*STAIR_RAYCAST_DISTANCE
		sensor_position.y=STAIR_RAYCAST_HEIGHT
		step_ray.set_translation(sensor_position)

func _get_floor_velocity(ray,delta):
	var floor_velocity=Vector3()
	# only static or rigid bodies are considered as floor. If the character is on top of another character, he can be ignored.
#	var object = ray.get_collider()
#	if object extends RigidBody or object extends StaticBody:
#		var point = ray.get_collision_point() - object.get_translation()
#		var floor_angular_vel = Vector3()
#		# get the floor velocity and rotation depending on the kind of floor
#		if object extends RigidBody:
#			floor_velocity = object.get_linear_velocity()
#			floor_angular_vel = object.get_angular_velocity()
#		elif object extends StaticBody:
#			floor_velocity = object.get_constant_linear_velocity()
#			floor_angular_vel = object.get_constant_angular_velocity()
#		# if there's an angular velocity, the floor velocity take it in account too.
#		if(floor_angular_vel.length()>0):
#			var transform = Matrix3(Vector3(1, 0, 0), floor_angular_vel.x)
#			transform = transform.rotated(Vector3(0, 1, 0), floor_angular_vel.y)
#			transform = transform.rotated(Vector3(0, 0, 1), floor_angular_vel.z)
#			floor_velocity += transform.xform_inv(point) - point
#			
#			# if the floor has an angular velocity (rotation force), the character must rotate too.
#			yaw = fmod(yaw + rad2deg(floor_angular_vel.y) * delta, 360)
#			get_node("eco_yaw").set_rotation(Vector3(0, deg2rad(yaw), 0))
	return Vector3(0,0,0)
#	return floor_velocity


func _on_ladders_body_enter( body ):
	if body==self:
		fly_mode=true

func _on_ladders_body_exit( body ):
	if body==self:
		fly_mode=false


func hit(source,special=false):
	player_data.hit(30)

func get_item(item):
	player_data.get_item(item)

func explosion_blown(explosion,strength,special):
	var t0=explosion.get_global_transform()
	var t1=get_global_transform()
	var blown_direction=t1.origin-t0.origin
	velocity+=blown_direction.normalized()*strength


func refresh_current_target():
	var camera=get_node("eco_yaw/camera")
	var screen_center=get_viewport().get_rect().size/2
	
	var pt=get_global_transform().origin
	var closest_enemy=null
	var closest_enemy_dist=-1
	
	var enemies=get_tree().get_nodes_in_group("enemy")
	var enemy_aim_offset=null
	for enemy in enemies:
		if enemy.has_method("get_aim_offset"):
			enemy_aim_offset=enemy.get_aim_offset()
		else:
			enemy_aim_offset=Vector3()
		var et=enemy.get_global_transform().origin+enemy_aim_offset
		var pos=camera.unproject_position(et)
		if screen_center.distance_to(pos)<50:
			var ed=et.distance_to(pt)
			if closest_enemy==null or ed<closest_enemy_dist:
				closest_enemy=enemy
				closest_enemy_dist=ed
				current_target_2d_pos=pos
	
	current_target=closest_enemy

func play_sound(sound):
	sfx.play(sound)

# Weapon management ###############################################################
func _handle_weapon(pool_type):
	
	if not _is_loaded or weapon_base==null:
		return
	
	if pool_type=="base":
		
		weapon_base.queue_free()
		weapon_base=bullet_factory.get_base(player_data.weapon_base_type)
		get_node("eco_yaw/camera/shoot-point").add_child(weapon_base)
		weapon_base.owner=self
		weapon_base.set_sample_library(sfx.get_sample_library())
	
	weapon_base.reset()
	weapon_base.regenerate()

func _regen_bullet():
	weapon_base.regenerate()
	tween.interpolate_callback(self,1,"_regen_bullet")

func shoot():
	if weapon_base.shoot():
		attack_timeout=1.0/player_data.fire_rate
	emit_signal("start_shoot")

func stop_shoot():
	weapon_base.stop_shoot()
	emit_signal("stop_shoot")

func notify_ammo_used():
	emit_signal("ammo_used")

func reload_weapon(amount=-1):
		weapon_base.reload(amount)

func set_ammo(value):
	weapon_base.remaining_total_bullets=value

func get_ammo():
	return weapon_base.remaining_total_bullets

func set_loaded_ammo(value=-1):
	if value==-1:
		value=player_data.bullet_pool_capacity
	weapon_base.remaining_bullets=value

func get_loaded_ammo():
	return weapon_base.remaining_bullets

# Setter/Getter #################################################################

func get_data():
	return player_data

func set_player_data(value):
	if value!=player_data:
		player_data=value
		player_data.connect("attribute_changed",self,"notify_attribute_change")
		player_data.connect("pool_changed",self,"_handle_weapon")
		player_data.connect("ammo_used",self,"notify_ammo_used")

func _set_leg_length(value):
	leg_length=value
	if _is_loaded:
		get_node("eco_body/leg").get_shape().set_length(value)
		get_node("eco_ray").set_cast_to(Vector3(0,-value*2,0))

func _set_body_radius(value):
	body_radius=value
	if _is_loaded:
		get_node("eco_body").get_shape().set_radius(value)

func _set_body_height(value):
	body_height=value
	if _is_loaded:
		get_node("eco_body").get_shape().set_height(value)

func _set_camera_height(value):
	camera_height=value
	if _is_loaded:
		get_node("eco_yaw/camera").set_translation(Vector3(0,value,0))

func _set_action_range(value):
	action_range=value
	if _is_loaded:
		get_node("eco_yaw/camera/actionRay").set_cast_to(Vector3(0,0,-value))

func _set_active(value):
	if value==active:
		return
	
	active=value
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _set_weapon(value):
	weapon=value
	
	if _is_loaded:
		player_data.equip_weapon(bullet_factory.get_config(weapon))
		emit_signal("attribute_changed","weapon",value)

func get_bullet_factory_instance():
	return default_projectile_factory.new()