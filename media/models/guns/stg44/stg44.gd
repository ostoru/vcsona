extends BoneAttachment
#generic gun.gd
#to shoot spawn the bullet in origin and direct it to origin/direction
#to shoot while aiming, make balance look to aim. make origin shoot at balance/direction normaly
func _ready():
	get_node("Camera").look_at(get_node("balance/direction").get_global_transform().origin,Vector3(0,1,0))