extends Node3D
class_name CameraController

## Configurações da Câmera Isométrica
@export_group("Isometric Settings")
## Ângulo de inclinação vertical (pitch) da câmera em graus (padrão: 45°)
@export var pitch_angle_degrees: float = 45.0
## Distância da câmera em relação ao centro (pivot)
@export var camera_distance: float = 35.0
## Tamanho da projeção ortográfica (campo de visão)
@export var orthographic_size: float = 18.0

@export_group("Zoom Settings (Estilo Ragnarok Online)")
## Tamanho mínimo da projeção (Zoom In Máximo - Próximo)
@export var min_zoom: float = 8.0
## Tamanho máximo da projeção (Zoom Out Máximo - Distante)
@export var max_zoom: float = 28.0
## Passo de variação do zoom por scroll do mouse
@export var zoom_step: float = 1.5
## Suavidade da transição de zoom
@export var zoom_smoothness: float = 14.0

@export_group("Rotation Settings")
## Duração da animação de rotação em segundos
@export var rotation_duration: float = 0.35
## Ativa a transição suave de rotação de 90°
@export var enable_smooth_rotation: bool = true
## Ativa a rotação livre de 360° segurando o Botão Direito do Mouse
@export var enable_rmb_drag_rotation: bool = true
## Sensibilidade de rotação do mouse
@export var mouse_sensitivity: float = 0.005
## Inclinação vertical mínima em graus
@export var min_pitch: float = 15.0
## Inclinação vertical máxima em graus
@export var max_pitch: float = 85.0

@export_group("Follow Settings")
## Alvo 3D para a câmera seguir (Jogador)
@export var target_node: Node3D = null
## Velocidade de interpolação do acompanhamento
@export var follow_speed: float = 14.0

@onready var pitch_node: Node3D = $CameraPitch
@onready var camera: Camera3D = $CameraPitch/Camera3D

# Controle de índice para os 4 eixos (0: 45°, 1: 135°, 2: 225°, 3: 315°)
var current_step_index: int = 0
var target_yaw_rad: float = deg_to_rad(45.0)
var target_ortho_size: float = 18.0
var tween: Tween = null
var is_animating: bool = false
var is_rmb_dragging: bool = false

# Sinal emitido ao mudar a rotação da câmera
signal rotation_changed(current_angle_degrees: float)

func _ready() -> void:
	# Define a orientação inicial de 45 graus
	rotation.y = target_yaw_rad
	target_ortho_size = orthographic_size
	
	if pitch_node:
		pitch_node.rotation.x = deg_to_rad(-pitch_angle_degrees)
	
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = orthographic_size
		camera.position = Vector3(0, 0, camera_distance)
	
	_find_target()
	emit_signal("rotation_changed", get_current_angle_degrees())

func _find_target() -> void:
	if target_node and is_instance_valid(target_node):
		return
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		target_node = players[0] as Node3D
		if target_node:
			global_position = target_node.global_position

func _physics_process(delta: float) -> void:
	if not target_node or not is_instance_valid(target_node):
		_find_target()
		
	if target_node and is_instance_valid(target_node):
		global_position = global_position.lerp(target_node.global_position, delta * follow_speed)

	# Interpolação suave do Zoom da câmera
	if camera:
		camera.size = lerp(camera.size, target_ortho_size, delta * zoom_smoothness)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and enable_rmb_drag_rotation:
			is_rmb_dragging = event.pressed
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				
	elif event is InputEventMouseMotion and is_rmb_dragging and enable_rmb_drag_rotation:
		# Girar horizontalmente em 360° (Yaw)
		rotation.y -= event.relative.x * mouse_sensitivity
		target_yaw_rad = rotation.y
		
		# Girar verticalmente entre min_pitch e max_pitch (Pitch)
		if pitch_node:
			pitch_angle_degrees = clamp(pitch_angle_degrees + event.relative.y * (mouse_sensitivity * 12.0), min_pitch, max_pitch)
			pitch_node.rotation.x = deg_to_rad(-pitch_angle_degrees)
			
		emit_signal("rotation_changed", get_current_angle_degrees())

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Q, KEY_A, KEY_LEFT]:
			rotate_camera_step(-1) # Girar 90° no sentido anti-horário
		elif event.keycode in [KEY_E, KEY_D, KEY_RIGHT]:
			rotate_camera_step(1)  # Girar 90° no sentido horário
		elif event.keycode == KEY_R:
			reset_camera()         # Resetar para 45°

## Aproxima a câmera (Zoom In)
func zoom_in() -> void:
	target_ortho_size = clamp(target_ortho_size - zoom_step, min_zoom, max_zoom)

## Afasta a câmera (Zoom Out)
func zoom_out() -> void:
	target_ortho_size = clamp(target_ortho_size + zoom_step, min_zoom, max_zoom)

## Gira a câmera em passos de 90 graus (-1 para esquerda, 1 para direita)
func rotate_camera_step(direction: int) -> void:
	if is_animating and enable_smooth_rotation:
		return
		
	current_step_index = (current_step_index + direction) % 4
	if current_step_index < 0:
		current_step_index += 4
		
	# Calcula o novo ângulo alvo (45°, 135°, 225°, 315°)
	target_yaw_rad = deg_to_rad(45.0 + current_step_index * 90.0)
	
	if enable_smooth_rotation:
		_animate_to_target_yaw(direction)
	else:
		rotation.y = target_yaw_rad
		emit_signal("rotation_changed", get_current_angle_degrees())

func _animate_to_target_yaw(direction: int) -> void:
	if tween and tween.is_running():
		tween.kill()
		
	is_animating = true
	
	# Calcula o delta de rotação no sentido correto (sempre 90 graus = PI/2)
	var start_yaw: float = rotation.y
	var step_rad: float = deg_to_rad(90.0) * direction
	var end_yaw: float = start_yaw + step_rad
	
	tween = create_tween().set_parallel(false)
	tween.tween_property(self, "rotation:y", end_yaw, rotation_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	tween.tween_callback(func():
		rotation.y = target_yaw_rad
		is_animating = false
		emit_signal("rotation_changed", get_current_angle_degrees())
	)

## Reseta a câmera para o ângulo inicial de 45 graus
func reset_camera() -> void:
	if is_animating and enable_smooth_rotation:
		return
		
	current_step_index = 0
	target_yaw_rad = deg_to_rad(45.0)
	
	pitch_angle_degrees = 45.0
	if pitch_node:
		pitch_node.rotation.x = deg_to_rad(-pitch_angle_degrees)

	if enable_smooth_rotation:
		_animate_to_target_yaw(-1 if rotation.y > target_yaw_rad else 1)
	else:
		rotation.y = target_yaw_rad
		emit_signal("rotation_changed", get_current_angle_degrees())

## Retorna o ângulo Y atual formatado em graus (0 a 360)
func get_current_angle_degrees() -> float:
	var deg = rad_to_deg(rotation.y)
	deg = fmod(deg, 360.0)
	if deg < 0:
		deg += 360.0
	return deg
