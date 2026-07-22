extends Node3D

@export var duration: float = 0.5
@export var max_scale: float = 1.2

var tween: Tween

func _ready() -> void:
	scale = Vector3(0.2, 0.2, 0.2)
	_start_animation()

func _start_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	
	# Expande o anel horizontalmente
	tween.tween_property(self, "scale", Vector3(max_scale, 0.2, max_scale), duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst and mesh_inst.material_override:
		var mat: StandardMaterial3D = mesh_inst.material_override.duplicate() as StandardMaterial3D
		mesh_inst.material_override = mat
		tween.tween_property(mat, "albedo_color:a", 0.0, duration)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
			
	tween.chain().tween_callback(queue_free)
