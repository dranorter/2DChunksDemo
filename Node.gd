extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# Make some far-away chunks
	$Area2D/notchunk/chunknetwork.generate_near(Vector2(10000,10000),10)
	# Now our root chunk should be the biggest one.
	# We should have a nice, big, far-away chunk in the upper right.
	var planet1 = $Area2D/notchunk.get_child(0).generate_near(Vector2(-10000,-10000),5)
	var planet2 = $Area2D/notchunk.get_child(0).generate_near(Vector2(30000,30000),6)
	
	planet1.set_meta("Biome", "planet")
	planet2.set_meta("Biome", "planet")
	planet1.set_color(Color(.1,.7,.1))
	planet2.set_color(Color(.1,.7,.1))
	
	#$notchunk.get_child(0).get_child(2).set_meta("Biome", "planet")
	#$notchunk.get_child(0).get_child(2).set_color(Color(.1,.7,.1))
	#print(len($notchunk.get_child(0).get_child(2).get_chunk_children()))
	#print($notchunk.get_child(0).get_child(1).position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass