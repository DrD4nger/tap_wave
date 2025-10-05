# BoatMesh.gd
#
# Generates a placeholder boat mesh to use for now while building out
# the game.

@tool
extends MeshInstance3D

func _ready():
	create_boat_mesh()

func create_boat_mesh():
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Define vertices for a simple boat hull
	# Bottom is narrower and V-shaped, top is wider and flat
	var vertices = PackedVector3Array([
		# Bottom vertices (keel)
		Vector3(0.0, -0.3, 0.0),      # 0 - Center bottom (keel)
		
		# Mid-level vertices
		Vector3(-0.8, -0.1, 0.4),     # 1 - Left mid front
		Vector3(-0.8, -0.1, -0.4),    # 2 - Left mid back
		Vector3(0.8, -0.1, 0.4),      # 3 - Right mid front
		Vector3(0.8, -0.1, -0.4),     # 4 - Right mid back
		
		# Top vertices (deck)
		Vector3(-1.0, 0.2, 0.5),      # 5 - Left top front
		Vector3(-1.0, 0.2, -0.5),     # 6 - Left top back
		Vector3(1.0, 0.2, 0.5),       # 7 - Right top front
		Vector3(1.0, 0.2, -0.5),      # 8 - Right top back
		
		# Bow and stern points
		Vector3(1.2, 0.1, 0.0),       # 9 - Bow (front point)
		Vector3(-1.2, 0.1, 0.0),      # 10 - Stern (back point)
	])
	
	# Define the faces (triangles)
	var indices = PackedInt32Array([
		# Hull bottom - V shape
		0, 1, 3,  # Front V
		0, 3, 4,  # Right V
		0, 4, 2,  # Back V
		0, 2, 1,  # Left V
		
		# Hull sides
		1, 5, 3,  # Left front to right front lower
		3, 5, 7,  # Left front to right front upper
		
		3, 7, 4,  # Right front to right back lower
		4, 7, 8,  # Right front to right back upper
		
		4, 8, 2,  # Right back to left back lower
		2, 8, 6,  # Right back to left back upper
		
		2, 6, 1,  # Left back to left front lower
		1, 6, 5,  # Left back to left front upper
		
		# Bow (front point)
		7, 9, 8,  # Top
		3, 9, 7,  # Right
		4, 9, 3,  # Right bottom
		8, 9, 4,  # Left bottom
		
		# Stern (back point)
		6, 10, 5,  # Top
		1, 10, 6,  # Left
		2, 10, 1,  # Left bottom
		5, 10, 2,  # Right bottom
		
		# Deck
		5, 6, 7,  # Left triangle
		6, 8, 7,  # Right triangle
	])
	
	# Calculate normals
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(vertices.size()):
		normals[i] = Vector3.UP  # Default up, will be recalculated
	
	# Recalculate normals based on faces
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		
		var normal = (v1 - v0).cross(v2 - v0).normalized()
		
		normals[i0] = normal
		normals[i1] = normal
		normals[i2] = normal
	
	# Create UV coordinates
	var uvs = PackedVector2Array()
	for vertex in vertices:
		uvs.append(Vector2(vertex.x * 0.5 + 0.5, vertex.z * 0.5 + 0.5))
	
	# Assign arrays
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Create mesh
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
