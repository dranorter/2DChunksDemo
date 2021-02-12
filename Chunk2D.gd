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

var fully_generated

var grass_color = Color(.1,.7,.1)
var space_color = Color(0.094353, 0.081055, 0.324219)
var dirt_color = Color(0.300781, 0.238694, 0.091644)

# Called when the node enters the scene tree for the first time.
func _ready():
	$Square.color = Color(randf(), randf(), randf())
	#$Square.color = Color(0.094353, 0.081055, 0.324219)
	start_search_point = self
	$Square/StaticBody2D/CollisionShape2D.set_deferred("disabled", true)
	fully_generated = false
	min_size = 0
	set_meta("id","center")

func set_color(c):
	$Square.color = c

func make_solid(solidity):
	$Square/StaticBody2D/CollisionShape2D.set_deferred("disabled",!solidity)
	# We've set child solidity, so now its parent needs to be not solid
	if get_parent() != null:
		if get_parent().has_method("make_solid"):
			get_parent().make_solid(false)

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

func get_child(id):
	for child in get_chunk_children():
		if child.get_meta("id") == id:
			return child
	return null

func contains(pos, margin = 0):
	if margin < 0 and get_size().x <= margin*2:
		return false
	if (pos - position).x < -margin:
		return false
	if (pos - position).y < -margin:
		return false
	if (pos - position).x > get_size().x + margin:
		return false
	if (pos - position).y > get_size().y + margin:
		return false
	return true
	#return !((pos - position).x < -margin or (pos - position).y < -margin or (pos-position).x > get_size().x + margin or (pos-position).y > get_size().y + margin)

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
	pos -= start_search_point.absolute_ish_position() - start_search_point.position
	if start_search_point.chunk_level > min_size or !start_search_point.contains(pos):
		var margin = 500
		start_search_point = start_search_point.generate_near(pos, min_size, margin)
#		start_search_point.generate_near(pos - Vector2(margin,0), min_size, 0)
#		start_search_point.generate_near(pos + Vector2(margin,0), min_size, 0)
#		start_search_point.generate_near(pos - Vector2(0,margin), min_size, 0)
#		start_search_point.generate_near(pos + Vector2(0,margin), min_size, 0)

func generate_near(pos, target_level = min_size, margin = 0):
	# We call an upwards search which calls a dawnward search;
	# this way we never vacillate between up and down.
	return upwards_search(pos, target_level, margin)

func blacken():
	set_color(Color(1,1,1))
	for ch in get_chunk_children():
		ch.blacken()

func upwards_search(pos, target_level = min_size, margin = 0):
	var marginv = 10*Vector2(margin,margin)
	var marginv2 = 10*Vector2(margin,-margin)
	#if (!contains(pos)) or (!contains(pos+marginv)) or (!contains(pos-marginv)) or (!contains(pos+marginv2)) or (!contains(pos-marginv2)):
	if !contains(pos) or chunk_level < target_level or !contains(pos,-margin) or (position + get_size()/2.0).distance_to(pos)>(get_size().length()-margin):
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
		
		return parent.upwards_search(pos + parent.position, target_level, margin)
	else:
		return downward_search(pos, target_level, margin)

func downward_search(pos, target_level = min_size, margin = 0):
	# If we've been called, we contain pos to within margin, so we should
	# create our sub-chunks unless we're already small enough.
	#if contains(pos,margin) and (chunk_level > target_level):
	if chunk_level > target_level:
		var found_pos = false
		for child in get_chunk_children():
			# We need to hand off a relative position
			if child.contains(pos - position):
				found_pos = true
		# We need to have subdivisions.
		#if (!found_pos or margin>0) and len(get_chunk_children()) < 9:
		#if !fully_generated or len(get_chunk_children()) < 9:
		var old_children = get_chunk_children()
		
		var ids = []
		for ch in old_children:
			ids.append(ch.get_meta("id"))
		if len(ids) < 9:
			# Used to skip this if found_pos. However, that doesn't give
			# children a chance to generate if they're very near pos, but pos
			# got found by the sibling. Ideally we might check whether the margin
			# is big enough to escape the child who found pos, given pos' exact
			# position.
			
			var nw_child = Self.instance()
			if ! "nw" in ids:
				add_child(nw_child)
				nw_child.set_chunk_level(chunk_level - 1)
				nw_child.set_meta("id","nw")
			else: nw_child = get_child("nw")
			
			var n_child = Self.instance()
			if ! "n" in ids:
				add_child(n_child)
				n_child.set_chunk_level(chunk_level - 1)
				#n_child.position = position
				n_child.position.x += n_child.get_size().x
				n_child.set_meta("id","n")
			else: n_child = get_child("n")
			
			var ne_child = Self.instance()
			if ! "ne" in ids:
				add_child(ne_child)
				ne_child.set_chunk_level(chunk_level - 1)
				#ne_child.position = position
				ne_child.position.x += ne_child.get_size().x*2
				ne_child.set_meta("id","ne")
			else: ne_child = get_child("ne")
			
			var w_child = Self.instance()
			if ! "w" in ids:
				add_child(w_child)
				w_child.set_chunk_level(chunk_level - 1)
				#w_child.position = position
				w_child.position.y += w_child.get_size().y
				w_child.set_meta("id","w")
			else: w_child = get_child("w")
			
			var c_child = Self.instance()
			if ! "c" in ids:
				add_child(c_child)
				c_child.set_chunk_level(chunk_level - 1)
				#c_child.position = position
				c_child.position += c_child.get_size()
				c_child.set_meta("id","c")
			else: c_child = get_child("c")
			
			var e_child = Self.instance()
			if ! "e" in ids:
				add_child(e_child)
				e_child.set_chunk_level(chunk_level - 1)
				#e_child.position = position
				e_child.position += e_child.get_size()
				e_child.position.x += e_child.get_size().x
				e_child.set_meta("id","e")
			else: e_child = get_child("e")
			
			var sw_child = Self.instance()
			if ! "sw" in ids:
				add_child(sw_child)
				sw_child.set_chunk_level(chunk_level - 1)
				#sw_child.position = position
				sw_child.position.y += sw_child.get_size().y*2
				sw_child.set_meta("id","sw")
			else: sw_child = get_child("sw")
			
			var s_child = Self.instance()
			if ! "s" in ids:
				add_child(s_child)
				s_child.set_chunk_level(chunk_level - 1)
				#s_child.position = position
				s_child.position += s_child.get_size()
				s_child.position.y += s_child.get_size().y
				s_child.set_meta("id","s")
			else: s_child = get_child("s")
			
			var se_child = Self.instance()
			if ! "se" in ids:
				add_child(se_child)
				se_child.set_chunk_level(chunk_level - 1)
				#se_child.position = position
				se_child.position += se_child.get_size()*2
				se_child.set_meta("id","se")
			else: se_child = get_child("se")
			
#			move_child(s_child,10)
#			move_child(sw_child,10)
#			move_child(e_child,10)
#			move_child(c_child,10)
#			move_child(w_child,10)
#			move_child(ne_child,10)
#			move_child(n_child,10)
#			move_child(nw_child,10)
#
#			for newchild in [nw_child, n_child, ne_child, w_child, c_child, e_child, sw_child, s_child, se_child]:
#				for oldchild in old_children:
#					if oldchild.position == newchild.position:
#						remove_child(newchild)
			
			if chunk_level - 1 == min_size:
				fully_generated = true
			
			if has_meta("Biome"):
				# Copy parent by default
				for ch in get_chunk_children():
					#ch.set_meta("Biome", get_meta("Biome"))
					ch.set_color($Square.color)
				if get_meta("Biome") == "planet":
					for ch in get_chunk_children():
						ch.set_meta("planet radius", get_size().x/3.0)
						ch.set_meta("planet center", get_size() /2.0)
					nw_child.make_crust()
					ne_child.make_crust()
					sw_child.make_crust()
					se_child.make_crust()
					c_child.make_dirt()
					n_child.make_crust()
					s_child.make_crust()
					e_child.make_crust()
					w_child.make_crust()
				if get_meta("Biome") == "dirt":
					for ch in get_chunk_children():
						ch.make_dirt()
				if get_meta("Biome") == "crust":
					#print("Breaking down some crust. Planet position is "+str(get_meta("planet center")))
					for ch in get_chunk_children():
						var ch_center = ch.position + (ch.get_size()/2.0) + position
						if ch_center.distance_to(get_meta("planet center")) > get_meta("planet radius") + ch.get_size().x/1.5:
							# Child is in space
							ch.make_space()
						elif ch_center.distance_to(get_meta("planet center")) < get_meta("planet radius") - ch.get_size().x/1.5:
							# Child is planet interior
							ch.make_dirt()
						else:
							# Child is crust, just like us! yay!
							ch.make_crust()
							ch.set_meta("planet center", get_meta("planet center") - position)
							# Randomize height a bit
							ch.set_meta("planet radius", get_meta("planet radius")+(randf()-.5)*ch.get_size().x/2.0)
		if len(get_chunk_children()) == 9 and !fully_generated:
			var full_count = 0
			for ch in get_chunk_children():
				if ch.fully_generated:
					#print("got one")
					full_count += 1
			fully_generated = (full_count == 9)
	# Done creating sub-chunks.
	if margin > 0 and !(fully_generated or chunk_level <= target_level):
		# If we're within the margin, want to fully generate down to target_level.
		if contains(pos, margin) and !contains(pos):
			# We do this by lying to ourselves.
			var fake_pos = Vector2(pos.x,pos.y)
			fake_pos.x = clamp(pos.x,position.x+1, position.x+get_size().x-1)
			fake_pos.y = clamp(pos.y,position.y+1, position.y+get_size().y-1)
			var new_margin = max (margin - fake_pos.distance_to(pos), 0)
			assert(contains(fake_pos))
			set_color(Color(1,0,1))
			downward_search(fake_pos, target_level, margin)
		# But we still want to check for genuine containment, to have an
		# accurate return value.
	# Now pass the task to the correct child
	for child in get_chunk_children():
		if margin > 0 and !fully_generated:
			# We have to do extra calls to generate new cells in more than just one position.
			if child.contains(pos - position, margin):
				# Lie to our children to avoid stack overflow here
				var fake_pos = Vector2(pos.x,pos.y)
				fake_pos.x = clamp(pos.x-position.x,child.position.x + 1,child.position.x+child.get_size().x - 1)
				fake_pos.y = clamp(pos.y-position.y,child.position.y + 1,child.position.y+child.get_size().y - 1)
				child.downward_search(fake_pos, target_level, margin)
	for child in get_chunk_children():
		if child.contains(pos - position):
			# Position is relative to us - we need to convert
			#print("Going down")
			return child.downward_search(pos - position, target_level, margin)
	if chunk_level == target_level and contains(pos):
		# Current level is target level
		if target_level == min_size:
			fully_generated = true
		# Current chunk is the right one
		#print("Found you")
		return self

func make_space():
	set_meta("Biome","space")
	set_color(space_color)
	make_solid(false)

func make_crust():
	set_meta("Biome","crust")
	set_color(grass_color)
	make_solid(true)

func make_dirt():
	set_meta("Biome", "dirt")
	set_color(dirt_color)
	make_solid(true)
