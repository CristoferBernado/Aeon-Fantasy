extends Resource
class_name InventoryManager

signal inventory_updated
signal equipment_changed
signal weight_changed(current_weight: float, max_weight: float)
signal item_used(item: ItemData)
signal currency_changed(eons: int, astris: int)

@export var max_slots: int = 35

# Moedas do Jogo: Éons (Ouro in-game) e Astris (Cash)
@export var eons: int = 500
@export var astris: int = 50

# Lista de Slots da Mochila: { "item": ItemData, "quantity": int } ou null
var slots: Array = []

# Dicionário de Equipamentos Equipados no Personagem
var equipped_items: Dictionary = {
	"weapon": null,
	"shield": null,
	"helmet": null,
	"armor": null,
	"pants": null,
	"boots": null,
	"gloves": null,
	"ring_1": null,
	"ring_2": null,
	"earring": null,
	"necklace": null,
	"wings": null,
	"pet": null
}

var player_ref: Player = null

## Adiciona saldo de Éons (ouro in-game)
func add_eons(amount: int) -> void:
	if amount > 0:
		eons += amount
		emit_signal("currency_changed", eons, astris)

## Remove saldo de Éons caso possua fundos suficientes
func remove_eons(amount: int) -> bool:
	if amount > 0 and eons >= amount:
		eons -= amount
		emit_signal("currency_changed", eons, astris)
		return true
	return false

## Adiciona saldo de Astris (moeda premium/cash)
func add_astris(amount: int) -> void:
	if amount > 0:
		astris += amount
		emit_signal("currency_changed", eons, astris)

## Remove saldo de Astris caso possua fundos suficientes
func remove_astris(amount: int) -> bool:
	if amount > 0 and astris >= amount:
		astris -= amount
		emit_signal("currency_changed", eons, astris)
		return true
	return false

func _init() -> void:
	clear_inventory()

func clear_inventory() -> void:
	slots.clear()
	for i in range(max_slots):
		slots.append(null)

## Calcula a capacidade máxima de peso em kg derivada da Força (STR)
func get_max_weight() -> float:
	if player_ref and player_ref.attributes:
		# Fórmula clássica RO: Capacidade = 2000.0 + (STR * 30.0)
		return 2000.0 + (float(player_ref.attributes.str) * 30.0)
	return 2000.0

## Calcula o peso atual total ocupado no inventário + equipamentos em kg
func get_current_weight() -> float:
	var total_w: float = 0.0
	for slot in slots:
		if slot != null and slot.get("item") is ItemData:
			var item: ItemData = slot["item"]
			var qty: int = slot.get("quantity", 1)
			total_w += item.weight * float(qty)
			
	for eq_key in equipped_items.keys():
		var eq_item: ItemData = equipped_items[eq_key]
		if eq_item:
			total_w += eq_item.weight
			
	return total_w

## Tenta adicionar um item ao inventário respeitando limite de peso e empilhamento
func add_item(item: ItemData, quantity: int = 1) -> bool:
	if not item or quantity <= 0:
		return false
		
	var item_total_weight: float = item.weight * float(quantity)
	if get_current_weight() + item_total_weight > get_max_weight():
		return false

	if item.max_stack > 1:
		for i in range(max_slots):
			var slot = slots[i]
			if slot != null and slot["item"].id == item.id and slot["item"].rarity == item.rarity:
				var current_qty: int = slot["quantity"]
				if current_qty < item.max_stack:
					var space: int = item.max_stack - current_qty
					var add_qty: int = min(space, quantity)
					slot["quantity"] += add_qty
					quantity -= add_qty
					if quantity <= 0:
						_emit_updates()
						return true

	while quantity > 0:
		var empty_idx: int = _find_empty_slot()
		if empty_idx == -1:
			_emit_updates()
			return false
			
		var put_qty: int = min(item.max_stack, quantity)
		slots[empty_idx] = {
			"item": item,
			"quantity": put_qty
		}
		quantity -= put_qty

	_emit_updates()
	return true

## Remove uma quantidade de um slot específico da mochila
func remove_item_at(slot_idx: int, quantity: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	var slot = slots[slot_idx]
	if slot == null:
		return false
		
	slot["quantity"] -= quantity
	if slot["quantity"] <= 0:
		slots[slot_idx] = null
		
	_emit_updates()
	return true

## Descarta um item do inventário criando uma instância de DroppedItem no chão próximo ao jogador
func drop_item_to_ground(slot_idx: int, quantity: int = -1) -> Node:
	if slot_idx < 0 or slot_idx >= max_slots:
		return null
	var slot = slots[slot_idx]
	if slot == null or not (slot.get("item") is ItemData):
		return null

	var item: ItemData = slot["item"]
	var total_qty: int = slot.get("quantity", 1)
	var drop_qty: int = total_qty if quantity <= 0 else min(quantity, total_qty)

	# Atualizar inventário
	slot["quantity"] -= drop_qty
	if slot["quantity"] <= 0:
		slots[slot_idx] = null

	_emit_updates()

	# Instanciar o item no chão 3D perto do jogador
	if player_ref and is_instance_valid(player_ref) and player_ref.get_parent():
		var DroppedItemScene = preload("res://scenes/dropped_item.tscn")
		var dropped_item = DroppedItemScene.instantiate() as DroppedItem
		player_ref.get_parent().add_child(dropped_item)
		
		# Posição ligeiramente à frente ou lado do jogador
		var offset := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
		dropped_item.global_position = player_ref.global_position + offset
		dropped_item.setup_item(item, drop_qty)
		return dropped_item
		
	return null

## Troca a posição de dois slots na mochila
func swap_slots(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= max_slots or idx_b < 0 or idx_b >= max_slots:
		return false
	var temp = slots[idx_a]
	slots[idx_a] = slots[idx_b]
	slots[idx_b] = temp
	_emit_updates()
	return true

## Equipar um item da mochila no personagem
func equip_item_from_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	var slot = slots[slot_idx]
	if slot == null or not (slot.get("item") is ItemData):
		return false

	var item: ItemData = slot["item"]
	if item.item_type != ItemData.ItemType.EQUIPMENT or item.equip_slot == ItemData.EquipSlot.NONE:
		return false

	var target_key: String = _get_target_equip_key(item.equip_slot)
	if target_key == "":
		return false

	var prev_equipped: ItemData = equipped_items[target_key]
	
	# Colocar novo equipamento no slot do personagem
	equipped_items[target_key] = item
	
	# Se já havia um equipado, colocar o antigo na mochila, caso contrário esvaziar o slot
	if prev_equipped:
		slots[slot_idx] = { "item": prev_equipped, "quantity": 1 }
	else:
		slots[slot_idx] = null

	_emit_updates()
	_update_player_stats()
	emit_signal("equipment_changed")
	return true

## Desequipar um item do personagem e mover de volta para a mochila
func unequip_item(equip_key: String) -> bool:
	if not equipped_items.has(equip_key) or equipped_items[equip_key] == null:
		return false

	var empty_idx: int = _find_empty_slot()
	if empty_idx == -1:
		# Mochila cheia
		return false

	var item: ItemData = equipped_items[equip_key]
	equipped_items[equip_key] = null
	slots[empty_idx] = { "item": item, "quantity": 1 }

	_emit_updates()
	_update_player_stats()
	emit_signal("equipment_changed")
	return true

## Calcula a soma total dos bônus de todos os equipamentos equipados
func get_total_equipment_bonuses() -> Dictionary:
	var totals: Dictionary = {}
	for eq_key in equipped_items.keys():
		var item: ItemData = equipped_items[eq_key]
		if item:
			var eff_stats := item.get_effective_stats()
			for stat_key in eff_stats.keys():
				var val: int = eff_stats[stat_key]
				totals[stat_key] = totals.get(stat_key, 0) + val
	return totals

## Desgasta equipamentos equipados durante o combate (ao atacar ou levar dano)
func degrade_equipped_durability(slot_type: String = "all", amount: int = 1) -> void:
	var updated: bool = false
	if slot_type == "weapon" or slot_type == "all":
		var weapon: ItemData = equipped_items.get("weapon")
		if weapon and weapon.current_durability > 0:
			weapon.damage_durability(amount)
			updated = true
			
	if slot_type == "armor" or slot_type == "all":
		for armor_key in ["shield", "helmet", "armor", "pants", "boots", "gloves"]:
			var eq: ItemData = equipped_items.get(armor_key)
			if eq and eq.current_durability > 0:
				eq.damage_durability(amount)
				updated = true

	if updated:
		_update_player_stats()
		emit_signal("equipment_changed")

## Retorna o custo de reparo em Éons para um determinado item
func get_repair_cost(item: ItemData) -> int:
	if not item or item.item_type != ItemData.ItemType.EQUIPMENT or item.current_durability >= item.max_durability:
		return 0
	var missing: int = item.max_durability - item.current_durability
	var cost_per_pt: int = 2
	match item.rarity:
		ItemData.Rarity.EXCELLENT: cost_per_pt = 3
		ItemData.Rarity.ANCIENT: cost_per_pt = 5
		ItemData.Rarity.GALACTIC: cost_per_pt = 8
	return max(5, missing * cost_per_pt)

## Repara um item específico consumindo Éons
func repair_item(item: ItemData) -> bool:
	if not item or item.item_type != ItemData.ItemType.EQUIPMENT:
		return false
	var cost: int = get_repair_cost(item)
	if cost == 0:
		return false
	if remove_eons(cost):
		item.repair_durability()
		_update_player_stats()
		emit_signal("equipment_changed")
		emit_signal("inventory_updated")
		return true
	return false

## Repara TODOS os equipamentos danificados (equipados e na mochila)
func repair_all_equipment() -> Dictionary:
	var items_to_repair: Array = []
	var total_cost: int = 0
	
	# Checar equipamentos equipados
	for eq_key in equipped_items.keys():
		var eq: ItemData = equipped_items[eq_key]
		if eq and eq.current_durability < eq.max_durability:
			items_to_repair.append(eq)
			total_cost += get_repair_cost(eq)
			
	# Checar equipamentos na mochila
	for slot in slots:
		if slot != null and slot.get("item") is ItemData:
			var item: ItemData = slot["item"]
			if item.item_type == ItemData.ItemType.EQUIPMENT and item.current_durability < item.max_durability:
				items_to_repair.append(item)
				total_cost += get_repair_cost(item)

	if items_to_repair.is_empty():
		return {"success": false, "count": 0, "cost": 0, "reason": "No damage"}
		
	if remove_eons(total_cost):
		for item in items_to_repair:
			item.repair_durability()
		_update_player_stats()
		emit_signal("equipment_changed")
		emit_signal("inventory_updated")
		return {"success": true, "count": items_to_repair.size(), "cost": total_cost}
	else:
		return {"success": false, "count": items_to_repair.size(), "cost": total_cost, "reason": "No eons"}

func _update_player_stats() -> void:
	if player_ref and player_ref.attributes:
		var bonuses := get_total_equipment_bonuses()
		player_ref.attributes.recalculate_stats(bonuses)
		player_ref.attributes.emit_signal("attributes_changed")

## Usa um item consumível do inventário
func use_item_at(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	var slot = slots[slot_idx]
	if slot == null:
		return false
		
	var item: ItemData = slot["item"]
	if item.item_type == ItemData.ItemType.CONSUMABLE and player_ref:
		if item.hp_heal > 0:
			player_ref.current_hp = min(player_ref.current_hp + item.hp_heal, player_ref.attributes.max_hp)
			player_ref.emit_signal("hp_changed", player_ref.current_hp, player_ref.attributes.max_hp)
			
		if item.sp_heal > 0:
			player_ref.current_sp = min(player_ref.current_sp + item.sp_heal, player_ref.attributes.max_sp)
			player_ref.emit_signal("sp_changed", player_ref.current_sp, player_ref.attributes.max_sp)
			
		emit_signal("item_used", item)
		remove_item_at(slot_idx, 1)
		return true
	return false

func _get_target_equip_key(slot_type: ItemData.EquipSlot) -> String:
	match slot_type:
		ItemData.EquipSlot.WEAPON: return "weapon"
		ItemData.EquipSlot.SHIELD: return "shield"
		ItemData.EquipSlot.HELMET: return "helmet"
		ItemData.EquipSlot.ARMOR: return "armor"
		ItemData.EquipSlot.PANTS: return "pants"
		ItemData.EquipSlot.BOOTS: return "boots"
		ItemData.EquipSlot.GLOVES: return "gloves"
		ItemData.EquipSlot.RING:
			if equipped_items["ring_1"] == null:
				return "ring_1"
			return "ring_2"
		ItemData.EquipSlot.EARRING: return "earring"
		ItemData.EquipSlot.NECKLACE: return "necklace"
		ItemData.EquipSlot.WINGS: return "wings"
		ItemData.EquipSlot.PET: return "pet"
		_: return ""

func _find_empty_slot() -> int:
	for i in range(max_slots):
		if slots[i] == null:
			return i
	return -1

func _emit_updates() -> void:
	emit_signal("inventory_updated")
	emit_signal("weight_changed", get_current_weight(), get_max_weight())
