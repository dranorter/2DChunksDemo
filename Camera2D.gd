extends Camera2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	make_current()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				zoom /= 1.2
			if event.button_index == BUTTON_WHEEL_DOWN:
				zoom *= 1.2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("scroll_down") or Input.is_mouse_button_pressed(BUTTON_WHEEL_DOWN):
		zoom *= 1.2
	if Input.is_action_pressed("scroll_up")  or Input.is_mouse_button_pressed(BUTTON_WHEEL_UP):
		zoom /= 1.2
		print(zoom)


func _on_Area2D_player_moved(position):
	#offset = position
	#print("yep")
	pass
