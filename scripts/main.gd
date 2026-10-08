extends Node3D

const MODEL_PATH := "res://assets/characters/base_adventurer_running.glb"
const ALTERNATE_MODEL_PATH := "res://Meshy_AI_Game_ready_stylized_s_Running.glb"
const WALK_SPEED := 4.0
const RUN_SPEED := 7.0
const GRAVITY := 18.0

var player: CharacterBody3D
var visuals: Node3D
var camera_pivot: Node3D
var animator: AnimationPlayer
var run_clip := ""
var idle_clip := ""
var idle_pose: Animation
var idle_ready := false
var yaw := 0.0
var pitch := -0.18
var hud: Label
var resource_nodes: Array[Node3D] = []
var wood := 0
var stone := 0
var stamina := 100.0
var camera_distance := 5.0

func _ready() -> void:
	_make_world()
	_make_player()
	_make_camera()
	_make_camp()
	_make_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.57, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.8)
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 0.4, 80)
	mesh.mesh = box
	mesh.position.y = -0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.39, 0.27)
	mesh.material_override = mat
	ground.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.4, 80)
	collider.shape = shape
	collider.position.y = -0.2
	ground.add_child(collider)

func _add_primitive(parent: Node3D, shape_mesh: Mesh, pos: Vector3, tint: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape_mesh
	item.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	item.material_override = material
	parent.add_child(item)
	return item

func _make_camp() -> void:
	# Lightweight test environment suitable for Compatibility renderer.
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var distance := 9.0 + float(i % 4) * 3.5
		var pos := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var tree := Node3D.new()
		tree.name = "Tree_%02d" % i
		tree.position = pos
		add_child(tree)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.22
		trunk.bottom_radius = 0.33
		trunk.height = 2.4
		_add_primitive(tree, trunk, Vector3(0, 1.2, 0), Color(0.36, 0.23, 0.13))
		var crown := SphereMesh.new()
		crown.radius = 1.35
		crown.height = 2.5
		_add_primitive(tree, crown, Vector3(0, 3.1, 0), Color(0.15, 0.34 + 0.02 * (i % 3), 0.17))
		tree.set_meta("resource_type", "wood")
		resource_nodes.append(tree)
	for i in range(12):
		var angle := float(i) * TAU / 12.0 + 0.23
		var distance := 5.5 + float(i % 3) * 4.0
		var rock := Node3D.new()
		rock.name = "Rock_%02d" % i
		rock.position = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		add_child(rock)
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.65
		rock_mesh.height = 0.9
		_add_primitive(rock, rock_mesh, Vector3(0, 0.35, 0), Color(0.40, 0.43, 0.43))
		rock.set_meta("resource_type", "stone")
		resource_nodes.append(rock)
	var camp := Node3D.new()
	camp.name = "Camp"
	camp.position = Vector3(3, 0, 2)
	add_child(camp)
	var pit := CylinderMesh.new()
	pit.top_radius = 0.85
	pit.bottom_radius = 0.85
	pit.height = 0.2
	_add_primitive(camp, pit, Vector3(0, 0.1, 0), Color(0.22, 0.2, 0.19))
	var ember := SphereMesh.new()
	ember.radius = 0.4
	ember.height = 0.4
	_add_primitive(camp, ember, Vector3(0, 0.25, 0), Color(0.98, 0.41, 0.09))

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 20)
	hud.add_theme_font_size_override("font_size", 19)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	_update_hud()

func _update_hud() -> void:
	var nearby := _nearest_resource()
	var hint := ""
	if nearby != null:
		hint = " | E: %s topla" % ("Odun" if String(nearby.get_meta("resource_type")) == "wood" else "Tas")
	hud.text = "ASHVALE - KESIF TESTI\nOdun: %d   Tas: %d   Dayaniklilik: %d\nWASD: hareket  Shift: kos  Space: zipla  ESC: fare\nFare tekerlegi: kamera%s" % [wood, stone, int(stamina), hint]

func _nearest_resource() -> Node3D:
	var best: Node3D = null
	var best_distance := 3.0
	for node in resource_nodes:
		if not is_instance_valid(node):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _collect_resource() -> void:
	var target := _nearest_resource()
	if target == null:
		return
	if String(target.get_meta("resource_type")) == "wood":
		wood += 1
	else:
		stone += 1
	resource_nodes.erase(target)
	target.queue_free()
	_update_hud()

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	player.add_child(col)
	visuals = Node3D.new()
	visuals.name = "Visuals"
	player.add_child(visuals)
	if ResourceLoader.exists(MODEL_PATH):
		var resource := load(MODEL_PATH)
		if resource is PackedScene:
			var character := (resource as PackedScene).instantiate()
			visuals.add_child(character)
			animator = _find_animator(character)
			if animator != null:
				for animation_name in animator.get_animation_list():
					if "idle" in String(animation_name).to_lower():
						idle_clip = String(animation_name)
					if "running" in String(animation_name).to_lower():
						run_clip = String(animation_name)
				if not idle_clip.is_empty():
					animator.play(idle_clip)
				elif not run_clip.is_empty():
					# Use the animation start as a temporary neutral rest pose.
					animator.play(run_clip)
					animator.seek(0.0, true)
					animator.pause()
	else:
		print("Meshy karakter dosyasi bulunamadi. Gecici test karakteri kullaniliyor.")
		var body := MeshInstance3D.new()
		var fallback := CapsuleMesh.new()
		fallback.radius = 0.35
		fallback.height = 1.8
		body.mesh = fallback
		body.position.y = 0.9
		visuals.add_child(body)

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animator(child)
		if found != null:
			return found
	return null

func _make_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	camera_pivot.position = player.position + Vector3(0, 1.5, 0)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 1.0, 5.0)
	camera.current = true
	camera_pivot.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_collect_resource()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.8, 0.35)
		camera_pivot.rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		camera_distance = clampf(camera_distance + (-0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5), 2.5, 8.5)
		camera_pivot.get_node("Camera").position.z = camera_distance
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and stamina > 1.0 and input.length_squared() > 0.01
	stamina = clampf(stamina + (-22.0 if sprint else 16.0) * delta, 0.0, 100.0)
	var speed := RUN_SPEED if sprint else WALK_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = 6.0
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	if direction.length_squared() > 0.01:
		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	if animator != null and not run_clip.is_empty():
		if input.length_squared() > 0.01:
			if animator.current_animation != run_clip or not animator.is_playing():
				animator.play(run_clip)
			animator.speed_scale = 1.1 if sprint else 0.65
		else:
			if not idle_clip.is_empty():
				if animator.current_animation != idle_clip or not animator.is_playing():
					animator.play(idle_clip, 0.2)
			else:
				# Do not freeze in a random running frame.
				animator.play(run_clip)
				animator.seek(0.0, true)
				animator.pause()
	camera_pivot.global_position = camera_pivot.global_position.lerp(player.global_position + Vector3(0, 1.5, 0), minf(delta * 8.0, 1.0))
	_update_hud()
