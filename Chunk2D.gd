extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export (int) var min_size

export (int) var chunk_level

export (PackedScene) var chunk_template

var cached_abs_pos

var Self = load("res://Node2D.tscn")

var Marker = load("res://Marker.tscn")

var start_search_point

# Called when the node enters the scene tree for the first time.
func _ready():
	$Square.color = Color(randf(), randf(), randf())
	#$Square.color = Color(0.094353, 0.081055, 0.324219)
	start_search_point = self
	$Square/StaticBody2D/CollisionShape2D.set_deferred("disabled", true)

func set_color(c):
	$Square.color = c

func make_solid(solidity):
	$Square/StaticBody2D/CollisionShape2D.set_deferred("disabled",solidity)

func set_chunk_level(n):
	chunk_level = n
	$Square.scale.x = pow(3,n) * 40
	$Square.scale.y = pow(3,n) * 40
	$Square/Border.width = 0.05 * 40 / $Square.scale.x
	# Hide bigger chunks under smaller ones
	$Square.z_index = -chunk_level
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func get_size():
	return $Square.scale

func contains(pos):
	# Position is absolute, and we need it to be relative to parent
	#if (get_parent().has_method("generate_near")):
	#	pos = pos - get_parent().position
	
	#var pathmarker = Marker.instance()
	#pathmarker.position = pos - position
	#add_child(pathmarker)
	
	return !((pos - position).x < 0 or (pos - position).y < 0 or (pos-position).x > $Square.scale.x or (pos-position).y > $Square.scale.y)

func get_chunk_children():
	var returnlist = []
	for x in get_children():
		 if x.has_method("get_chunk_children") and x.chunk_level == chunk_level - 1: returnlist.append(x)
	return returnlist

func absolute_ish_position():
	if cached_abs_pos != null:
		return cached_abs_pos
	var pos = position
	var forefather = get_parent()
	if forefather.has_method("absolute_ish_position"):
		pos += forefather.absolute_ish_position()
	cached_abs_pos = pos
	return pos

func _on_player_moved(pos):
	# The *original* chunk receives this
	# instead of the top-level chunk. Gotta convert
	# coords before handing off.
	#pos -= (absolute_ish_position() - position)
	
	#Now I try to send the signal to a good guess at where pos is.
	# So here's the corrected coords for that:
	pos -= (start_search_point.absolute_ish_position() - start_search_point.position)
	if start_search_point.chunk_level > min_size or !start_search_point.contains(pos):
		start_search_point = start_search_point.generate_near(pos)

func generate_near(pos, target_level = min_size):
	if !contains(pos) or chunk_level < target_level:
		# Outside current chunk.
		var parent = get_parent()
		if !get_parent().has_method("set_chunk_level"):
			# Make a new top-level chunk.
			print("Ascending to level "+str(chunk_level+1))
			parent = Self.instance()
			var old_parent = get_parent()
			old_parent.add_child(parent)
			old_parent.remove_child(self)
			# Adding child. Game will crash if there are around 100K nodes.
			parent.add_child(self)
			#self.show()
			parent.set_chunk_level(chunk_level + 1)
			# New parent's position will be relative to our parent, so
			# just translate ours as appropriate for size
			parent.position = position - get_size()
			# Our own position needs to be relative to the new parent
			var old_position = position
			position = $Square.scale
			# We think of "pos" as relative to our parent, so it needs updated too
			#pos = pos - position + new_parent.position + get_size()
			pos = pos - parent.position
		# Position is relative to us; we need to convert when handing off.
		#print("Going up")
		
		return parent.generate_near(pos + parent.position, target_level)
	else:
		# pos is inside this chunk
		if (chunk_level > target_level):
			var found_pos = false
			for child in get_chunk_children():
				# We need to hand off a relative position
				if child.contains(pos - position):
					found_pos = true
			# We need to have subdivisions.
			if !found_pos and len(get_chunk_children()) < 9:
				var old_children = get_chunk_children()
				
				var nw_child = Self.instance()
				add_child(nw_child)
				nw_child.set_chunk_level(chunk_level - 1)
				#nw_child.position = position
				
				var n_child = Self.instance()
				add_child(n_child)
				n_child.set_chunk_level(chunk_level - 1)
				#n_child.position = position
				n_child.position.x += n_child.get_size().x
				
				var ne_child = Self.instance()
				add_child(ne_child)
				ne_child.set_chunk_level(chunk_level - 1)
				#ne_child.position = position
				ne_child.position.x += ne_child.get_size().x*2
				
				var w_child = Self.instance()
				add_child(w_child)
				w_child.set_chunk_level(chunk_level - 1)
				#w_child.position = position
				w_child.position.y += w_child.get_size().y
				
				var c_child = Self.instance()
				add_child(c_child)
				c_child.set_chunk_level(chunk_level - 1)
				#c_child.position = position
				c_child.position += c_child.get_size()
				
				var e_child = Self.instance()
				add_child(e_child)
				e_child.set_chunk_level(chunk_level - 1)
				#e_child.position = position
				e_child.position += e_child.get_size()
				e_child.position.x += e_child.get_size().x
				
				var sw_child = Self.instance()
				add_child(sw_child)
				sw_child.set_chunk_level(chunk_level - 1)
				#sw_child.position = position
				sw_child.position.y += sw_child.get_size().y*2
				
				var s_child = Self.instance()
				add_child(s_child)
				s_child.set_chunk_level(chunk_level - 1)
				#s_child.position = position
				s_child.position += s_child.get_size()
				s_child.position.y += s_child.get_size().y
				
				var se_child = Self.instance()
				add_child(se_child)
				se_child.set_chunk_level(chunk_level - 1)
				#se_child.position = position
				se_child.position += se_child.get_size()*2
				
				for newchild in [nw_child, n_child, ne_child, w_child, c_child, e_child, sw_child, s_child, se_child]:
					for oldchild in old_children:
						if oldchild.position == newchild.position:
							remove_child(newchild)
				
				if has_meta("Biome"):
					var grass_color = Color(.1,.7,.1)
					var space_color = Color(0.094353, 0.081055, 0.324219)
					var dirt_color = Color(0.300781, 0.238694, 0.091644)
					# Copy parent by default
					for ch in get_chunk_children():
						ch.set_meta("Biome", get_meta("Biome"))
						ch.set_color($Square.color)
					if get_meta("Biome") == "planet":
						for ch in get_chunk_children():
							ch.set_meta("planet radius", get_size().x/3.0)
							ch.set_meta("planet center", get_size() /2.0)
						nw_child.set_meta("Biome","crust")
						ne_child.set_meta("Biome", "crust")
						sw_child.set_meta("Biome", "crust")
						se_child.set_meta("Biome", "crust")
						n_child.set_color(Color(.1,.7,.1))
						s_child.set_color(Color(.1,.7,.1))
						e_child.set_color(Color(.1,.7,.1))
						w_child.set_color(Color(.1,.7,.1))
						c_child.set_color(dirt_color)
						c_child.set_meta("Biome", "dirt")
						n_child.set_meta("Biome", "crust")
						s_child.set_meta("Biome", "crust")
						e_child.set_meta("Biome", "crust")
						w_child.set_meta("Biome", "crust")
					if get_meta("Biome") == "dirt":
						for ch in get_chunk_children():
							ch.set_meta("Biome", "dirt")
							ch.set_color(dirt_color)
							ch.make_solid(true)
						# We don't need to be solid anymore
						make_solid(false)
					if get_meta("Biome") == "crust":
						#print("Breaking down some crust. Planet position is "+str(get_meta("planet center")))
						for ch in get_chunk_children():
							var ch_center = ch.position + (ch.get_size()/2.0) + position
							if ch_center.distance_to(get_meta("planet center")) > get_meta("planet radius") + ch.get_size().x/1.5:
								# Child is in space
								ch.set_meta("Biome", "space")
								ch.set_color(space_color)
							elif ch_center.distance_to(get_meta("planet center")) < get_meta("planet radius") - ch.get_size().x/1.5:
								# Child is planet interior
								ch.set_meta("Biome", "dirt")
								ch.set_color(dirt_color)
							else:
								# Child is crust, just like us! yay!
								ch.set_meta("Biome", "crust")
								ch.set_meta("planet center", get_meta("planet center") - position)
								ch.set_meta("planet radius", get_meta("planet radius"))
								ch.set_color(grass_color)
#					if get_meta("Biome") == "n_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						nw_child.set_meta("Biome", "nw_edge")
#						n_child.set_meta("Biome", "n_edge")
#						ne_child.set_meta("Biome", "ne_edge")
#						nw_child.set_color(Color(.1,.7,.1))
#						n_child.set_color(Color(.1,.7,.1))
#						ne_child.set_color(Color(.1,.7,.1))
#					if get_meta("Biome") == "w_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						nw_child.set_meta("Biome", "nw_edge")
#						w_child.set_meta("Biome", "w_edge")
#						sw_child.set_meta("Biome", "sw_edge")
#						nw_child.set_color(Color(.1,.7,.1))
#						w_child.set_color(Color(.1,.7,.1))
#						sw_child.set_color(Color(.1,.7,.1))
#					if get_meta("Biome") == "e_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						ne_child.set_meta("Biome", "ne_edge")
#						e_child.set_meta("Biome", "e_edge")
#						se_child.set_meta("Biome", "se_edge")
#						ne_child.set_color(Color(.1,.7,.1))
#						e_child.set_color(Color(.1,.7,.1))
#						se_child.set_color(Color(.1,.7,.1))
#					if get_meta("Biome") == "s_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						sw_child.set_meta("Biome", "sw_edge")
#						s_child.set_meta("Biome", "s_edge")
#						se_child.set_meta("Biome", "se_edge")
#						sw_child.set_color(Color(.1,.7,.1))
#						s_child.set_color(Color(.1,.7,.1))
#						se_child.set_color(Color(.1,.7,.1))
#
#					if get_meta("Biome") == "nw_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						nw_child.set_meta("Biome", "space")
#						n_child.set_meta("Biome", "space")
#						w_child.set_meta("Biome", "space")
#						for ch in [ne_child, c_child, sw_child]:
#							ch.set_meta("Biome", "nw_edge")
#							ch.set_color(Color(.1,.7,.1))
#						ne_child.set_meta("Biome", "n_edge")
#						sw_child.set_meta("Biome", "w_edge")
#					if get_meta("Biome") == "ne_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						ne_child.set_meta("Biome", "space")
#						n_child.set_meta("Biome", "space")
#						e_child.set_meta("Biome", "space")
#						for ch in [nw_child, c_child, se_child]:
#							ch.set_meta("Biome", "ne_edge")
#							ch.set_color(Color(.1,.7,.1))
#					if get_meta("Biome") == "sw_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						sw_child.set_meta("Biome", "space")
#						s_child.set_meta("Biome", "space")
#						w_child.set_meta("Biome", "space")
#						for ch in [nw_child, c_child, se_child]:
#							ch.set_meta("Biome", "sw_edge")
#							ch.set_color(Color(.1,.7,.1))
#					if get_meta("Biome") == "se_edge":
#						for ch in get_chunk_children():
#							ch.set_meta("Biome", "dirt")
#							ch.set_color(Color(0.300781, 0.238694, 0.091644))
#						se_child.set_meta("Biome", "space")
#						s_child.set_meta("Biome", "space")
#						e_child.set_meta("Biome", "space")
#						for ch in [ne_child, c_child, sw_child]:
#							ch.set_meta("Biome", "se_edge")
#							ch.set_color(Color(.1,.7,.1))
#						ne_child.set_meta("Biome", "e_edge")
#						sw_child.set_meta("Biome", "s_edge")
			# Now pass the task to the correct child
			for child in get_chunk_children():
				if child.contains(pos - position):
					found_pos = true
					# Position is relative to us - we need to convert
					#print("Going down")
					return child.generate_near(pos - position, target_level)
		else:
			# Current chunk is the right one
			#print("Found you")
			return self
