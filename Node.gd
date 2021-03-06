extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var planet1
var planet2

# Called when the node enters the scene tree for the first time.
func _ready():
	# Make some far-away chunks
	$notchunk/chunknetwork.generate_near(Vector2(10000,10000),10)
	# Now our root chunk should be the biggest one.
	# We should have a nice, big, far-away chunk in the upper right.
	var planet1_callback = funcref(self,"set_planet1")
	var planet2_callback = funcref(self,"set_planet2")
	print("planets: "+str(planet1_callback)+", "+str(planet2_callback))
	$notchunk.get_child(0).generate_near(Vector2(-10000,-10000),5,0,planet1_callback)
	$notchunk.get_child(0).generate_near(Vector2(30000,30000),6,0,planet2_callback)
	
	#$notchunk.get_child(0).get_child(2).set_meta("Biome", "planet")
	#$notchunk.get_child(0).get_child(2).set_color(Color(.1,.7,.1))
	#print(len($notchunk.get_child(0).get_child(2).get_chunk_children()))
	#print($notchunk.get_child(0).get_child(1).position)

func set_planet1(chunk):
	print("got here")
	planet1 = chunk
	planet1.set_meta("Biome", "planet")
	planet1.set_color(Color(.1,.7,.1))

func set_planet2(chunk):
	print("got here")
	planet2 = chunk
	planet2.set_meta("Biome", "planet")
	planet2.set_color(Color(.1,.7,.1))
