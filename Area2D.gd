extends Area2D

signal player_moved
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var velocity = Vector2()
	if Input.is_action_pressed("ui_right"):
		velocity.x += 100
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 100
	if Input.is_action_pressed("ui_down"):
		velocity.y += 100
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 100
	if velocity.length() > 0:
		$AnimatedSprite.play()
		position += velocity*delta
		emit_signal("player_moved", position)
	else:
		$AnimatedSprite.stop()
