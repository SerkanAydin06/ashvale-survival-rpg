extends Node3D

# Ashvale: single-player 3D movement sandbox.
# The character GLB includes only "Running". Idle is its neutral pose.
const MODEL_PATH := "res://assets/characters/base_adventurer_running.glb"
const MOVE_SPEED := 4.2
const RUN_SPEED := 7.0
const MOUSE_SENSITIVITY := 0.003
const GRAVITY := 18.0

var player: CharacterBody3D
var visual_pivot: Node3D
var animation_player: AnimationPlayer
var camera_pivot: Node3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.29
var captured := true
var running_animation := ""
var animation_active := false
var hud_status: Label
var health := 100

func _ready() -> void:
	_build_environment()
	_build_player()
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("ASHVALE loaded. W/A/S/D movement, Shift sprint, mouse look, ESC release.")

func _process(_delta: float) -> void:
	if camera_pivot != null and is_instance_valid(player):
		camera_pivot.global_position = camera_pivot.global_position.lerp(player.global_position + Vector3(0, 1.5, 0), 0.13)
	if hud_status != null:
		hud_status.text = "ASHVALE  |  HP %d  |  %s" % [health, "KOŞUYOR" if player.velocity.length() > 5.2 else "KEŞİF"]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		captured = not captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not captured:
		captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and captured:
		camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		camera_pitch = clampf(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -0.85, 0.22)
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)

func _physics_process(delta: float) -> void:
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var input_vector := Vector2(x, z).normalized()
	var basis_yaw := Basis(Vector3.UP, camera_yaw)
	var direction := (basis_yaw * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := RUN_SPEED if sprinting else MOVE_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = 6.0
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	if direction.length_squared() > 0.001:
		visual_pivot.rotation.y = lerp_angle(visual_pivot.rotation.y, atan2(direction.x, direction.z), delta * 11.0)
	_update_animation(input_vector.length() > 0.01)

func _update_animation(is_moving: bool) -> void:
	if animation_player == null or running_animation.is_empty():
		return
	if is_moving and not animation_active:
		animation_player.play(running_animation)
		animation_active = true
	elif not is_moving and animation_active:
		animation_player.stop()
		animation_active = false
	if is_moving:
		animation_player.speed_scale = 1.15 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.65

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.15, 0)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95
	player.add_child(collision)
	visual_pivot = Node3D.new()
	visual_pivot.name = "VisualPivot"
	player.add_child(visual_pivot)
	if ResourceLoader.exists(MODEL_PATH):
		var packed = load(MODEL_PATH)
		if packed is PackedScene:
			var model: Node3D = packed.instantiate()
			model.name = "MeshyCharacter"
			visual_pivot.add_child(model)
			# Meshy exports vary in height and orientation. Scale to approx 1.8m tall.
			var aabb := _find_visual_aabb(model)
			if aabb.size.y > 0.01:
				model.scale = Vector3.ONE * (1.8 / aabb.size.y)
				model.position.y = -aabb.position.y * model.scale.y
			animation_player = _find_animation_player(model)
			if animation_player:
				for animation_name in animation_player.get_animation_list():
					if "Running" in String(animation_name):
						running_animation = String(animation_name)
						break
				if running_animation.is_empty() and animation_player.get_animation_list().size() > 0:
					running_animation = String(animation_player.get_animation_list()[0])
				animation_player.stop()
				print("Animation: ", running_animation)
	else:
		print("WARNING: Character GLB not found")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_visual_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var item: Node = stack.pop_back()
		if item is MeshInstance3D:
			var mesh_node := item as MeshInstance3D
			var box := mesh_node.get_aabb()
			var local_transform := node.global_transform.affine_inverse() * mesh_node.global_transform
			var transformed := local_transform * box
			if first:
				result = transformed
				first = false
			else:
				result = result.merge(transformed)
		for child in item.get_children():
			stack.push_back(child)
	return result

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.5, 0)
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.position = Vector3(0, 1.3, 5.5)
	camera.fov = 70
	camera.current = true
	camera_pivot.add_child(camera)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("90a4b1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4ced2")
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	_add_box("Ground", Vector3(0, -0.25, 0), Vector3(95, 0.5, 95), Color("4b604b"), true)
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var distance := 11.0 + float(i % 4) * 4.8
		var point := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		_make_tree(point, 0.9 + float(i % 3) * 0.25)
	for i in range(9):
		var p := Vector3(-14.0 + i * 3.1, 0, -14 + (i % 2) * 1.7)
		_add_box("Stone_%d" % i, p + Vector3(0, 0.32, 0), Vector3(1.3, 0.64, 0.9), Color("6f726e"), true)
	_add_box("CampPlatform", Vector3(6, 0.06, 2), Vector3(4, 0.12, 3.4), Color("58463a"), false)
	for i in range(3):
		_add_box("Crate_%d" % i, Vector3(5 + i * 1.0, 0.48, -0.5), Vector3(0.8, 0.9, 0.8), Color("9a7045"), true)

func _make_tree(pos: Vector3, factor: float) -> void:
	_add_cylinder("Trunk", pos + Vector3(0, 1.5 * factor, 0), 0.27 * factor, 3.0 * factor, Color("634a38"))
	var top := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 1.4 * factor
	cone.height = 3.8 * factor
	top.mesh = cone
	top.position = pos + Vector3(0, 4.0 * factor, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("263f31")
	top.material_override = mat
	add_child(top)

func _add_cylinder(name: String, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh.mesh = cyl
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	add_child(mesh)

func _add_box(name: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var instance := StaticBody3D.new() if solid else Node3D.new()
	instance.name = name
	instance.position = pos
	add_child(instance)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	instance.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var collision_box := BoxShape3D.new()
		collision_box.size = size
		shape.shape = collision_box
		instance.add_child(shape)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(300, 100)
	canvas.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	hud_status = Label.new()
	hud_status.text = "ASHVALE  |  HP 100"
	content.add_child(hud_status)
	var tip := Label.new()
	tip.text = "WASD: Hareket  |  SHIFT: Koş\nMOUSE: Kamera  |  SPACE: Zıpla\nESC: Fareyi bırak / yakala"
	content.add_child(tip)
	var bottom := Label.new()
	bottom.text = "PROTOTİP • Meshy karakter • Godot 4"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(20, -40)
	canvas.add_child(bottom)
