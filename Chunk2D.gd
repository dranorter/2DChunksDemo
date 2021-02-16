extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export (int) var min_size

export (int) var chunk_level

export (PackedScene) var chunk_template

var template
var cached_abs_pos
var stored_size
var chunk_dict
var cached_children

var Self = load("res://Node2D.tscn")

var Marker = load("res://Marker.tscn")

var start_search_point

var fully_generated

var grass_color = Color(.1,.7,.1)
var space_color = Color(0.094353, 0.081055, 0.324219)
var dirt_color = Color(0.300781, 0.238694, 0.091644)

var chunk_generation
var mutex
var semaphore
var thread_pos_queue
var thread_callback_queue
var exit_thread = false
var thread_top
var thread_target_level_queue
var thread_margin_queue

signal generated_children

# Downward-traversing, called when the node enters the scene tree for the first time.
func _enter_tree():
#	var parent = get_parent()
#	if parent.has_method("generate_near"):
#		if parent.template != null:
#			template = parent.template
#		else:
#			template = chunk_template.instance()
#	else:
#		template = chunk_template.instance()
	#template = chunk_template.instance()
	#template = $Square
	#setup_shape()
	pass

func setup_shape():
	#var path = template.polygon
	add_child(template)
	#$Square.polygon = path
	#$Square/Border.points = path
	#$Square/StaticBody2D/CollisionShape2D.shape.segments = path

# Upward-traversing, called when the node enters the scene tree for the first time.
func _ready():
	#$Square.color = Color(randf(), randf(), randf())
	template = $Square
	template.color = Color(randf(), randf(), randf())
	#$Square.color = Color(0.094353, 0.081055, 0.324219)
	start_search_point = self
	#make_solid(false)
	fully_generated = false
	min_size = 0
	set_meta("id","c")
	set_chunk_level(0)
	chunk_dict = {}
	cached_children = []
	thread_pos_queue = []
	thread_callback_queue = []
	thread_target_level_queue = []
	thread_margin_queue = []

func set_color(c):
	#$Square.color = c
	template.color = c

func make_solid(solidity):
	#$Square/StaticBody2D/CollisionShape2D.set_deferred("disabled",!solidity)
	template.get_node("StaticBody2D/CollisionShape2D").set_deferred("disabled",!solidity)
	# We've set child solidity, so now its parent needs to be not solid
	if get_parent() != null:
		if get_parent().has_method("make_solid"):
			get_parent().make_solid(false)

func set_chunk_level(n):
	chunk_level = n
	set_size(pow(3,n)*40)
	# Hide bigger chunks under smaller ones
	#$Square.z_index = -1-chunk_level
	template.z_index = -1-chunk_level
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func set_size(s):
	# Size s needs to be divided by template's size.
	# We put template's size in metadata in the template.
	#$Square.scale.x = float(s)/template.get_meta("size")
	#$Square.scale.y = $Square.scale.x
	#$Square/Border.width = 0.05 * 40 / $Square.scale.x
	#stored_size = $Square.scale * template.get_meta("size")
	template.scale.x = float(s)/template.get_meta("size")
	template.scale.y = template.scale.x
	stored_size = template.scale * template.get_meta("size")

func get_size():
	if stored_size == null:
#		stored_size = $Square.scale * template.get_meta("size")
		stored_size = template.scale * template.get_meta("size")
	return stored_size

func get_child(id):
	if chunk_dict.has(id):
		return chunk_dict[id]
	else:
		for child in get_chunk_children():
			if child.get_meta("id") == id:
				chunk_dict[id] = child
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
	#return !((pos - position).x < -margin or (pos - position).y < -margin or (pos-position).x > 
#	get_size().x + margin or (pos-position).y > get_size().y + margin)

func get_chunk_children():
	var returnlist = []
	for x in cached_children:
		returnlist.append(x)
	if len(returnlist) == template.get_meta("children"):
		return returnlist
	else:
		for x in get_children():
			if (not x in returnlist) and x.has_method("get_chunk_children") and x.chunk_level == chunk_level - 1:
				returnlist.append(x)
				cached_children.append(x)
	return returnlist

func get_template_children():
	var tch = []
	for child in template.get_children():
		if child.is_in_group("template"):
			tch.append(child)
	return tch

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
	# Upward search is outside the thread,
	# and it will handle triggering the thread for the downward
	# search part.
	start_generation(pos)

func _exit_tree():
	if chunk_generation != null:
		mutex.lock()
		exit_thread = true
		mutex.unlock()
		semaphore.post()
		if chunk_generation.is_active():
			chunk_generation.wait_to_finish()

func start_generation(pos):
	#Now I try to send the signal to a good guess at where pos is.
	# So here's the corrected coords for that:
	pos -= start_search_point.absolute_ish_position() - start_search_point.position
	if start_search_point.chunk_level > min_size or !start_search_point.contains(pos):
		var margin = 500#500
		var startpoint
		#mutex.lock()
		startpoint = start_search_point
		#mutex.unlock()
		startpoint.generate_near(pos, min_size, margin, funcref(self,"set_start_point"))
#		start_search_point.generate_near(pos - Vector2(margin,0), min_size, 0)
#		start_search_point.generate_near(pos + Vector2(margin,0), min_size, 0)
#		start_search_point.generate_near(pos - Vector2(0,margin), min_size, 0)
#		start_search_point.generate_near(pos + Vector2(0,margin), min_size, 0)

func generate_near(pos, target_level = min_size, margin = 0,callback=funcref(self,"set_start_point")):
	print(callback)
	# We call an upwards search which calls a dawnward search;
	# this way we never vacillate between up and down.
	return upwards_search(pos, target_level, margin, callback)

func set_start_point(pos):
	print("setting start point")
	if pos != null:
		if mutex != null:
			mutex.lock()
			start_search_point = pos
			mutex.unlock()
		else:
			start_search_point = pos

func blacken():
	set_color(Color(1,1,1))
	for ch in get_chunk_children():
		ch.blacken()

func upwards_search(pos, target_level = min_size, margin = 0, callback=funcref(self,"set_start_point")):
	print(callback)
	var marginv = 10*Vector2(margin,margin)
	var marginv2 = 10*Vector2(margin,-margin)
	#if (!contains(pos)) or (!contains(pos+marginv)) or (!contains(pos-marginv)) or (!contains(pos+marginv2)) or (!contains(pos-marginv2)):
	#if !contains(pos) or chunk_level < target_level or !contains(pos,-margin) or (position + get_size()/2.0).distance_to(pos)>(get_size().length()-margin):
	if !contains(pos,-margin) or chunk_level < target_level:
		# Outside current chunk.
		var parent = get_parent()
		if !get_parent().has_method("set_chunk_level"):
			parent = generate_parent()
			# We think of "pos" as relative to our parent, so it needs updated too
			#pos = pos - position + new_parent.position + get_size()
			pos = pos - parent.position
		return parent.upwards_search(pos + parent.position, target_level, margin, callback)
	else:
		#return downward_search(pos, target_level, margin)
		# The end of the upwards_search is going to actually instantiate the thread.
		thread_queue_handler(pos, target_level, margin, callback)

func thread_queue_handler(pos, target_level, margin, callback):
	print("queue handler: "+str(callback))
	#print("Reached queue handler for "+str(chunk_generation))
	if chunk_generation == null:
		chunk_generation = Thread.new()
		mutex = Mutex.new()
		semaphore = Semaphore.new()
		exit_thread = false
	mutex.lock()
	#print("Got mutex lock")
	var skip = false
	if pos in thread_pos_queue:
		if callback == thread_callback_queue[thread_pos_queue.find(pos)]:
			skip = true
			print("duplicate encountered")
	if !skip:
		print("Adding "+str(callback)+" to queue")
		thread_pos_queue.append(pos)
		thread_callback_queue.append(callback)
		thread_target_level_queue.append(target_level)
		thread_margin_queue.append(margin)
	mutex.unlock()
	if not chunk_generation.is_active():
		print("Queue is "+str(len(thread_pos_queue))+". Starting thread function on "+str(self))
		chunk_generation.start(self, "_thread_function")
	else:
		semaphore.post()
	#	print("Chunk generation was already active here, request is on the queue")

func _thread_function(arg):
	var should_exit = false
	#print("thread function started")
	var ltpq
	mutex.lock()
	ltpq = len(thread_pos_queue)
	mutex.unlock()
	while !should_exit:
		#print(thread_pos_queue)
		if ltpq == 0:
			semaphore.wait()
		#print("locking...")
		mutex.lock()
		#print(len(thread_pos_queue))
		var pos = thread_pos_queue.pop_front()
		#print(len(thread_pos_queue))
		ltpq = len(thread_pos_queue)
		var callback = thread_callback_queue.pop_front()
		var target_level = thread_target_level_queue.pop_front()
		var margin = thread_margin_queue.pop_front()
		mutex.unlock()
		#print("Unlocking...")
		print("in thread: "+str(callback))
		var thread_context = [self,callback,mutex,semaphore]
		#print("Entering downward search")
		var result = downward_search(pos,target_level,margin,thread_context)
		#callback.call_func(result)
		mutex.lock()
		#start_search_point = result
		should_exit = exit_thread
		mutex.unlock()
	chunk_generation.call_deferred("wait_to_finish")

func noop():
	pass

func downward_search(pos, target_level = min_size, margin = 0, thread_context=[self, funcref(self,"noop"), mutex, semaphore]):
	#print("Downward search reached "+str(chunk_level))
	#if chunk_level <= 1:
	#	print("Reached level "+str(chunk_level)+" from target of "+str(target_level))
	# The downward part happens in a thread, being passed down from some 
	# endpoint of the upward search. We need to be cautious about adding to the
	# tree, and we also want to gracefully handly "collisions" where we 
	# descend to a chunk that has another thread.
	if self != thread_context[0]:
		if chunk_generation != null:
			if chunk_generation.is_active():
				if len(thread_context) > 0:
					#print("Back to queue on "+str(chunk_level))
					#print(str(thread_context[0].chunk_generation)+", "+str(chunk_generation))
					# Steal search process from the other thread,
					# so that we don't generate child nodes twice.
					mutex.lock()
					thread_pos_queue.append(pos)
					thread_callback_queue.append(thread_context[1])
					mutex.unlock()
					semaphore.post()
					return
	
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
		# We'll keep old children and new children separate.
		# Old children are already in the tree and need to defer any
		# calls to add children. New children aren't in the tree yet
		# and can add their own new children immediately.
		var old_children = get_chunk_children()
		var new_children = []
		var ids = []
		for ch in old_children:
			ids.append(ch.get_meta("id"))
		if len(ids) < template.get_meta("children"):
			# Used to skip this if found_pos. However, that doesn't give
			# children a chance to generate if they're very near pos, but pos
			# got found by the sibling. Ideally we might check whether the margin
			# is big enough to escape the child who found pos, given pos' exact
			# position.
			
			# We need all the children for the logic of the search,
			# but within the search thread we can't add them,
			# so we leave that to the main thread.
			call_deferred("generate_children",pos, target_level, margin, thread_context)
			# I'd do a yield here to resume, but it doesn't seem to work between threads.
			return
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
			#print ("Recursive lies in "+str(self))
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
	#print("Continuing search beyond children")
	#print(self)
	# We have to do extra calls to generate new cells in more than just one position.
	for child in get_chunk_children():
		if margin > 0 and !fully_generated:
			if child.contains(pos - position, margin):
				# Lie to our children to avoid stack overflow here
				var fake_pos = Vector2(pos.x,pos.y)
				fake_pos.x = clamp(pos.x-position.x,child.position.x + 1,child.position.x+child.get_size().x - 1)
				fake_pos.y = clamp(pos.y-position.y,child.position.y + 1,child.position.y+child.get_size().y - 1)
				child.downward_search(fake_pos, target_level, margin)
	# Now pass the task to the correct child
	for child in get_chunk_children():
		if child.contains(pos - position):
			# Position is relative to us - we need to convert
			#print("Going down from "+str(chunk_level))
			return child.downward_search(pos - position, target_level, margin, thread_context)
	if chunk_level == target_level and contains(pos):
		# Current level is target level
		if target_level == min_size:
			fully_generated = true
		# Current chunk is the right one
		#print("Found you")
		thread_context[1].call_func(self)
		#thread_context[1].call_func()
		return self
	# Should be impossible to get here
	if chunk_level > target_level and contains(pos):
		var debug_children = get_chunk_children()
		var debug_size = get_size()
		var debug_childsizes = []
		for child in debug_children:
			debug_childsizes.append(child.get_size())
		var debug_containment = []
		for child in debug_children:
			debug_containment.append(child.contains(pos - position))
		print("Should be impossible to get here.")

func generate_parent():
	# Make a new top-level chunk.
	#print("Ascending to level "+str(chunk_level+1))
	var parent = Self.instance()
	# All new chunks are centers of future higher-level chunks
	parent.set_meta("id","c")
	var old_parent = get_parent()
	old_parent.add_child(parent)
	old_parent.remove_child(self)
	# Adding child. Game will crash if there are around 100K nodes.
	parent.add_child(self)
	#self.show()
	parent.set_chunk_level(chunk_level + 1)
	# New parent's position will be relative to our parent, so
	# just translate ours as appropriate for size
	#parent.position = position - get_size()
	var main
	for ch in get_template_children():
		if ch.get_meta("id") == template.get_meta("main"):
			main = ch
	parent.position = position - (main.position)*(parent.get_size() / template.get_meta("size"))
	
	# Our own position needs to be relative to the new parent
	var old_position = position
	position = main.position * parent.get_size() / template.get_meta("size")
	#print("Going up"
	return parent

func generate_children(pos,target_level,margin,thread_context):
	#print("Generating children")
	# This happens in the main thread, but we want to resume the search
	# which triggered this, back in a search thread.
	var have_ids = []
	for ch in get_chunk_children():
		have_ids.append(ch.get_meta("id"))
	
	var want_ids = []
	var template_children = {}
	var gtc = get_template_children()
	for i in range(len(gtc)):
		want_ids.append(gtc[i].get_meta("id"))
		template_children[gtc[i].get_meta("id")] = gtc[i]
	
	for id in want_ids:
		if not id in have_ids:
			var new_child = Self.instance()
			add_child(new_child)
			new_child.set_chunk_level(chunk_level - 1)
			new_child.set_meta("id",id)
			new_child.position = template_children[id].position * get_size() / template.get_meta("size")
	if chunk_level - 1 == min_size:
		fully_generated = true
	var all_children = get_chunk_children()
	if has_meta("Biome"):
		# Copy parent by default
		for ch in all_children:
			#ch.set_meta("Biome", get_meta("Biome"))
			ch.set_color($Square.color)
		if get_meta("Biome") == "planet":
			for ch in all_children:
				ch.set_meta("planet radius", get_size().x/3.0)
				ch.set_meta("planet center", get_size() /2.0)
				ch.make_crust()
			get_child(template.get_meta("main")).make_dirt()
		if get_meta("Biome") == "dirt":
			for ch in all_children:
				ch.make_dirt()
		if get_meta("Biome") == "crust":
			#print("Breaking down some crust. Planet position is "+str(get_meta("planet center")))
			for ch in all_children:
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
	# Now we want to resume the downward search inside the thread.
	#print("Attempting to resume downward search")
	thread_queue_handler(pos, target_level, margin, thread_context[1])


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
