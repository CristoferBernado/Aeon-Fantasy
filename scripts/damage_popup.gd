extends Node3D
class_name DamagePopup

## Instancia e exibe um popup numérico 3D no estilo Ragnarok Online (surge GIGANTE e encolhe)
static func spawn(
	parent_node: Node,
	pos: Vector3,
	text: String,
	color: Color,
	font_size: int = 48,
	is_crit: bool = false
) -> void:
	if not parent_node:
		return

	var popup := Label3D.new()
	popup.text = text
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.render_priority = 20
	popup.font_size = font_size if not is_crit else font_size + 12
	popup.outline_size = 14
	popup.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	popup.modulate = color

	# Posição inicial no topo da entidade com leve dispersão aleatória
	var offset := Vector3(
		randf_range(-0.35, 0.35),
		randf_range(1.7, 2.0),
		randf_range(-0.35, 0.35)
	)
	
	parent_node.add_child(popup)
	popup.global_position = pos + offset

	# --- FÍSICA E ANIMAÇÃO ESTILO RAGNAROK ONLINE (VERSÃO AMPLIADA) ---
	# Escalas aumentadas: Surge enorme e encolhe mantendo alta legibilidade
	var initial_scale: float = 4.2 if is_crit else 3.2
	var peak_scale: float = initial_scale * 1.2
	var final_scale: float = 1.6 if is_crit else 1.25
	
	popup.scale = Vector3.ONE * initial_scale

	var tween_scale := popup.create_tween()
	
	# 1. Pop de Impacto (0.07s): Expande rapidamente para o ápice gigante
	tween_scale.tween_property(popup, "scale", Vector3.ONE * peak_scale, 0.07)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# 2. Encolhimento RO (0.45s): Encolhe para o tamanho final destacado
	tween_scale.tween_property(popup, "scale", Vector3.ONE * final_scale, 0.45)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# 3. Subida Flutuante em Paralelo
	var tween_pos := popup.create_tween()
	var float_height: float = 1.9 if is_crit else 1.45
	tween_pos.tween_property(popup, "position:y", popup.position.y + float_height, 0.68)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# 4. Fade Out Transparente Final
	var tween_fade := popup.create_tween()
	tween_fade.tween_interval(0.38)
	tween_fade.tween_property(popup, "modulate:a", 0.0, 0.3)
	tween_fade.tween_callback(popup.queue_free)
