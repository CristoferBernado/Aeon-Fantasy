extends StaticBody3D
class_name NPCShop

@export var npc_name: String = "Vendedor de Equipamentos"

@onready var label_3d: Label3D = $Label3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var selection_ring: MeshInstance3D = $SelectionRing

var is_selected: bool = false

# Lista de itens disponíveis para venda na Loja
var shop_catalog: Array = [
	# Consumíveis
	{"id": "apple", "rarity": ItemData.Rarity.COMMON, "price": 20},
	{"id": "sp_potion", "rarity": ItemData.Rarity.COMMON, "price": 35},
	# Armadura Completa para Iniciante
	{"id": "helmet", "rarity": ItemData.Rarity.COMMON, "price": 150},
	{"id": "armor", "rarity": ItemData.Rarity.COMMON, "price": 350},
	{"id": "pants", "rarity": ItemData.Rarity.COMMON, "price": 220},
	{"id": "boots", "rarity": ItemData.Rarity.COMMON, "price": 180},
	{"id": "gloves", "rarity": ItemData.Rarity.COMMON, "price": 150},
	# Armas & Escudos
	{"id": "sword", "rarity": ItemData.Rarity.COMMON, "price": 250},
	{"id": "shield", "rarity": ItemData.Rarity.COMMON, "price": 200},
	# Joias de Refinamento (+0 a +9)
	{"id": "jewel_simplicity", "rarity": ItemData.Rarity.COMMON, "price": 300},
	{"id": "jewel_ethrel", "rarity": ItemData.Rarity.COMMON, "price": 850}
]

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("shops")
	_update_label()
	set_selected(false)

func _update_label() -> void:
	if label_3d:
		label_3d.text = "🛍️ %s\n[ Loja de Equipamentos ]" % npc_name
		label_3d.modulate = Color(1.0, 0.9, 0.3)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected

func interact(player: Player) -> void:
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		var hud = hud_nodes[0]
		if hud.has_method("open_shop_window"):
			hud.open_shop_window(self)
