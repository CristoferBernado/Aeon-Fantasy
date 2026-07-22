extends StaticBody3D
class_name NPCBlacksmith

@export var npc_name: String = "Ferreiro"

@onready var label_3d: Label3D = $Label3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var selection_ring: MeshInstance3D = $SelectionRing

var is_selected: bool = false

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("blacksmiths")
	_update_label()
	set_selected(false)

func _update_label() -> void:
	if label_3d:
		label_3d.text = "🔨 %s\n[ Oficina de Reparos ]" % npc_name
		label_3d.modulate = Color(1.0, 0.45, 0.2)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected

func interact(player: Player) -> void:
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		var hud = hud_nodes[0]
		if hud.has_method("open_blacksmith_window"):
			hud.open_blacksmith_window(self)
