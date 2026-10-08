extends Node3D

const MODEL_PATH := "res://assets/characters/base_adventurer_running.glb"\nconst ALTERNATE_MODEL_PATH := "res://Meshy_AI_Game_ready_stylized_s_Running.glb"
const WALK_SPEED := 4.0
const RUN_SPEED := 7.0
const GRAVITY := 18.0

var player: CharacterBody3D
var visuals: Node3D
var camera_pivot: Node3D
var animator: AnimationPlayer
var run_clip := ""
var yaw := 0.0
var pitch := -0.18

func _ready() -> void:
	_make_world()
	_make_player()
	_make_camera()
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
					if "running" in String(animation_name).to_lower():
						run_clip = String(animation_name)
						break
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.8, 0.35)
		camera_pivot.rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
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
		elif animator.is_playing():
			animator.stop()
	camera_pivot.global_position = camera_pivot.global_position.lerp(player.global_position + Vector3(0, 1.5, 0), minf(delta * 8.0, 1.0))
