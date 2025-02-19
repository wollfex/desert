extends MeshInstance3D

#==> OTHER <==#
var terrain = null
var autoLOD = 10
var oldLod = 0

#==> CODE <==#
func get_distance():
	var player_pos = terrain.player.global_position
	return int(player_pos.distance_to(position))


func kreiraj_noise_teren():
	var chunk_size = terrain.chunk_size
	var subdivide_size = chunk_size / (autoLOD * terrain.LOD)
	mesh = PlaneMesh.new()
	mesh.size = Vector2(chunk_size, chunk_size)
	mesh.subdivide_depth = subdivide_size
	mesh.subdivide_width = subdivide_size
	return mesh


func kreiraj_custom_col(trimesh = false):
	var Newmsh = kreiraj_noise_teren()
	var trn = create_noise_terrain(Newmsh)
	mesh = trn
	if trimesh:
		create_trimesh_collision()


func remove_chunk():
	var cName = "c_" + str(global_position.x) + "X" + str(global_position.z)
	terrain.chunk_list.erase(cName)
	create_tween().tween_property(self, "transparency", 1, terrain.chunk_show_speed).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(terrain.chunk_show_speed).timeout
	queue_free()


func _process(_delta):
	var dist = get_distance()
	if dist > (terrain.render_distance * terrain.chunk_size) / 1.25:
		remove_chunk()
		return

	if dist / terrain.chunk_size <= 3:
		autoLOD = 0.5
	if dist / terrain.chunk_size <= 6 and dist / terrain.chunk_size > 3:
		autoLOD = 1
	if dist / terrain.chunk_size <= 10 and dist / terrain.chunk_size > 6:
		autoLOD = 2
	if dist / terrain.chunk_size > 10:
		autoLOD = 3
	if dist / terrain.chunk_size > 20:
		autoLOD = 4
	if dist / terrain.chunk_size > 40:
		autoLOD = 6

	if oldLod != autoLOD:
		oldLod = autoLOD
		for child in get_children():
			if child.get_class() == "StaticBody3D":
				child.free()
		if autoLOD < 1 and terrain.optimised_collision:
			kreiraj_custom_col(true)
		elif not terrain.optimised_collision:
			kreiraj_custom_col(true)


func create_lod(_pos):
	var lod = 1
	mesh.subdivide_width = terrain.chunk_size / lod
	mesh.subdivide_depth = terrain.chunk_size / lod
	return mesh


func create_noise_terrain(_mesh):
	var sTool = SurfaceTool.new()
	var dataTool = MeshDataTool.new()

	terrain.noise.offset = position  # Important for chunk-level noise offset

	sTool.clear()
	sTool.create_from(_mesh, 0)
	var arrayMash = sTool.commit()

	dataTool.clear()
	dataTool.create_from_surface(arrayMash, 0)

	var vertex_count = dataTool.get_vertex_count()
	for i in range(vertex_count):
		var vertex = dataTool.get_vertex(i)
		# Sample noise for vertex
		var value = terrain.noise.get_noise_3d(vertex.x, vertex.y, vertex.z)
		vertex.y = value * terrain.terrain_height
		dataTool.set_vertex(i, vertex)

	arrayMash.clear_surfaces()
	dataTool.commit_to_surface(arrayMash)
	sTool.clear()
	sTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	sTool.create_from(arrayMash, 0)
	sTool.generate_normals()
	return sTool.commit()


func get_terrain_height(world_x: float, world_z: float) -> float:
	# Because we set 'terrain.noise.offset = position' before building,
	# the actual local coordinates for sampling are (world_x - position.x, world_z - position.z).
	var local_x = world_x - position.x
	var local_z = world_z - position.z
	var noise_value = terrain.noise.get_noise_3d(local_x, 0, local_z)
	return noise_value * terrain.terrain_height


func create_chunk(pos: Vector3):
	position = pos
	var cName = "c_" + str(pos.x) + "X" + str(pos.z)
	transparency = 1
	terrain.noise.offset = pos

	mesh = PlaneMesh.new()
	mesh.size = Vector2(terrain.chunk_size, terrain.chunk_size)
	name = cName
	mesh = create_lod(pos)
	material_override = load("res://texture/desert.tres")
	var terrain_chunk = create_noise_terrain(mesh)
	mesh = terrain_chunk

	terrain.chunk_list.append(cName)

	if randi() % 100 < 1:
		var random_x = randf_range(0, terrain.chunk_size)
		var random_z = randf_range(0, terrain.chunk_size)
		var world_x = pos.x + random_x
		var world_z = pos.z + random_z
		var height_y = get_terrain_height(world_x, world_z)
		var spawn_pos = Vector3(world_x, height_y, world_z)
		
		var random_rotation = randf() * 360.0
		var random_scale = 1.0
		spawn_plant(spawn_pos + Vector3(0, 0.75, 0), random_rotation, random_scale)

	if randi() % 300 < 1:
		var random_rotation = randf() * 360.0
		var random_scale = 2 + randf() * 1.5
		spawn_structure(
			position + Vector3(terrain.chunk_size * 0.5, 4 * random_scale, terrain.chunk_size * 0.5),
			random_rotation,
			random_scale
		)

	return self


func spawn_structure(pos: Vector3, rotation_y: float, scale_factor: float):
	var ruins = preload("res://src/structure/ruins/ruins_01.tscn").instantiate()
	add_child(ruins)

	ruins.call_deferred("_set_transform", pos, rotation_y, scale_factor)
	ruins.env = terrain.env
	ruins.spawn_loot(pos)


func spawn_plant(pos: Vector3, rotation_y: float, scale_factor: float):
	var yucca = preload("res://src/object/agriculture/yucca.tscn").instantiate()
	add_child(yucca)

	# We'll call a custom method _set_transform() in the yucca scene
	yucca.call_deferred("_set_transform", pos, rotation_y, scale_factor)
