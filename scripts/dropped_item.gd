extends Node3D
class_name DroppedItem

@export var item_data: ItemData = null
@export var quantity: int = 1
@export var lifespan: float = 20.0

var despawn_timer: float = 20.0
var is_picked_up: bool = false
var float_offset: float = 0.0

@onready var visual_mesh: MeshInstance3D = get_node_or_null("VisualMesh") as MeshInstance3D
@onready var item_label: Label3D = get_node_or_null("ItemLabel") as Label3D
@onready var pickup_area: Area3D = get_node_or_null("PickupArea") as Area3D

func _ready() -> void:
	add_to_group("dropped_items")
	despawn_timer = lifespan
	float_offset = randf() * 6.28
	
	if not visual_mesh:
		_create_default_visuals()
	else:
		_setup_existing_visuals()

func setup_item(data: ItemData, qty: int = 1) -> void:
	item_data = data
	quantity = qty
	if is_inside_tree():
		_update_display()

func _create_default_visuals() -> void:
	# Malha 3D do item no chão (Gema / Prisma brilhante)
	visual_mesh = MeshInstance3D.new()
	visual_mesh.name = "VisualMesh"
	
	var prism_mesh := PrismMesh.new()
	prism_mesh.size = Vector3(0.4, 0.4, 0.4)
	visual_mesh.mesh = prism_mesh
	visual_mesh.position = Vector3(0, 0.3, 0)
	visual_mesh.rotation.x = deg_to_rad(180.0)
	
	var mat := StandardMaterial3D.new()
	var rarity_color := item_data.get_rarity_color() if item_data else Color.WHITE
	mat.albedo_color = rarity_color
	mat.emission_enabled = true
	mat.emission = rarity_color
	mat.emission_energy_multiplier = 0.8
	mat.roughness = 0.2
	mat.metallic = 0.5
	visual_mesh.material_override = mat
	add_child(visual_mesh)
	
	# Rótulo 3D Flutuante estilo MU Online
	item_label = Label3D.new()
	item_label.name = "ItemLabel"
	item_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item_label.position = Vector3(0, 0.75, 0)
	item_label.font_size = 24
	item_label.outline_size = 6
	item_label.outline_color = Color(0, 0, 0, 0.9)
	item_label.no_depth_test = true
	item_label.render_priority = 10
	
	# Fundo estilo MU Online (Caixa retangular escura atrás do nome do item)
	item_label.background_color = Color(0.04, 0.05, 0.08, 0.88)
	add_child(item_label)
	
	# Área de Colisão / Raycast para clique de mouse
	pickup_area = Area3D.new()
	pickup_area.name = "PickupArea"
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	col.shape = sphere
	col.position = Vector3(0, 0.3, 0)
	pickup_area.add_child(col)
	add_child(pickup_area)
	
	_update_display()

func _setup_existing_visuals() -> void:
	_update_display()

func _update_display() -> void:
	if not item_data:
		return
		
	var rarity_color := item_data.get_rarity_color()
	
	if item_label:
		var qty_str: String = " x%d" % quantity if quantity > 1 else ""
		var rarity_tag: String = ""
		match item_data.rarity:
			ItemData.Rarity.EXCELLENT: rarity_tag = " [Excelente]"
			ItemData.Rarity.ANCIENT: rarity_tag = " [Ancient]"
			ItemData.Rarity.GALACTIC: rarity_tag = " [★ GALÁCTICO ★]"
			
		item_label.text = " %s%s%s " % [item_data.name, qty_str, rarity_tag]
		item_label.modulate = rarity_color
		
	if visual_mesh and visual_mesh.material_override is StandardMaterial3D:
		var mat := visual_mesh.material_override as StandardMaterial3D
		mat.albedo_color = rarity_color
		mat.emission = rarity_color

func _process(delta: float) -> void:
	if is_picked_up:
		return
		
	despawn_timer -= delta
	
	# Animação suave de rotação e flutuação da gema no chão
	if visual_mesh:
		visual_mesh.rotation.y += delta * 2.0
		float_offset += delta * 3.0
		visual_mesh.position.y = 0.3 + sin(float_offset) * 0.06
		
	# Efeito de piscar/fade nos últimos 4 segundos antes de sumir
	if despawn_timer <= 4.0:
		var alpha: float = (sin(despawn_timer * 12.0) + 1.0) * 0.4 + 0.2
		if item_label:
			item_label.modulate.a = alpha
		if visual_mesh:
			visual_mesh.transparency = 1.0 - alpha
			
	if despawn_timer <= 0.0:
		queue_free()

func attempt_pickup(player: Player) -> bool:
	if is_picked_up or not player or not player.inventory or not item_data:
		return false
		
	# Caso especial: Item de Moeda (Éons)
	if item_data.name == "Saco de Éons":
		is_picked_up = true
		player.inventory.add_eons(quantity)
		DamagePopup.spawn(get_parent(), global_position + Vector3(0, 0.5, 0), "+ %d Éons" % quantity, Color(1.0, 0.85, 0.1), 32, true)
		
		# Animação visual de absorção pelo jogador
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", player.global_position + Vector3(0, 0.8, 0), 0.18)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
		tween.chain().tween_callback(queue_free)
		return true

	var added := player.inventory.add_item(item_data, quantity)
	if added:
		is_picked_up = true
		# Feedback numérico / popup de item no estilo RO
		var text_str: String = "+ %s" % item_data.name
		if quantity > 1:
			text_str += " x%d" % quantity
		DamagePopup.spawn(get_parent(), global_position + Vector3(0, 0.5, 0), text_str, item_data.get_rarity_color(), 28, (item_data.rarity == ItemData.Rarity.GALACTIC))
		
		# Animação visual de absorção pelo jogador
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", player.global_position + Vector3(0, 0.8, 0), 0.18)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
		tween.chain().tween_callback(queue_free)
		return true
	else:
		# Feedback de inventário cheio
		DamagePopup.spawn(get_parent(), global_position + Vector3(0, 0.5, 0), "Mochila Cheia!", Color(1.0, 0.3, 0.3), 32, false)
		return false
