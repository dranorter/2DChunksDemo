extends KinematicBody2D

signal player_moved

var velocity

func _ready():
	velocity = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var velocity = Vector2()
	if Input.is_action_pressed("ui_right"):
		velocity -= 300 * $Area2D.gravity_vec.normalized().rotated(TAU/4)
	if Input.is_action_pressed("ui_left"):
		velocity += 300 * $Area2D.gravity_vec.normalized().rotated(TAU/4)
	if Input.is_action_pressed("ui_down"):
		velocity += 300 * $Area2D.gravity_vec.normalized()
	if Input.is_action_pressed("ui_up"):
		velocity -= 300 * $Area2D.gravity_vec.normalized()
	if velocity.length() > 0:
		$AnimatedSprite.play()
		position += velocity*delta
		emit_signal("player_moved", position)
	else:
		$AnimatedSprite.stop()
	$Area2D.gravity_vec = get_parent().planet2.absolute_ish_position() + get_parent().planet2.get_size()/2 - position
	$AnimatedSprite.set_rotation($Area2D.gravity_vec.angle()-TAU/4)#(-atan2($Area2D.gravity_vec.y, $Area2D.gravity_vec.x))

func _physics_process(delta):
	move_and_collide($Area2D.gravity_vec/10000)
	emit_signal("player_moved", position)
