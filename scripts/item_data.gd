extends Resource
class_name ItemData

enum Rarity { COMMON, EXCELLENT, ANCIENT, GALACTIC }
enum ItemType { CONSUMABLE, EQUIPMENT, MATERIAL, MISC }
enum EquipSlot { NONE, WEAPON, SHIELD, HELMET, ARMOR, PANTS, BOOTS, GLOVES, RING, EARRING, NECKLACE, WINGS, PET }

@export var id: String = "item_generic" # ID do catálogo/protótipo
@export var uid: String = ""            # ID Único de Instância (Número de Série / Serial UUID)
@export var name: String = "Item Genérico"
@export var description: String = "Descrição do item."
@export var rarity: Rarity = Rarity.COMMON
@export var item_type: ItemType = ItemType.MATERIAL
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var weight: float = 1.0
@export var max_stack: int = 99
@export var stats_bonus: Dictionary = {}
@export var hp_heal: int = 0
@export var sp_heal: int = 0
@export var price_eons: int = 100        # Preço de compra em Éons na Loja NPC
@export var max_durability: int = 50      # Durabilidade Máxima
@export var current_durability: int = 50  # Durabilidade Atual
@export var icon_color: Color = Color.WHITE

## Retorna a durabilidade máxima padrão para a raridade do equipamento
func get_default_durability_for_rarity() -> int:
	match rarity:
		Rarity.COMMON: return 50
		Rarity.EXCELLENT: return 80
		Rarity.ANCIENT: return 120
		Rarity.GALACTIC: return 200
	return 50

## Retorna os atributos efetivos considerando se o item está quebrado (durabilidade 0 = perda de 80% dos stats)
func get_effective_stats() -> Dictionary:
	if item_type != ItemType.EQUIPMENT:
		return {}
		
	var eff_stats: Dictionary = {}
	var mult: float = 0.20 if current_durability <= 0 else 1.0
	
	for stat_key in stats_bonus.keys():
		var base_val: int = stats_bonus[stat_key]
		eff_stats[stat_key] = int(round(float(base_val) * mult))
		
	return eff_stats

## Reduz a durabilidade do equipamento em combate
func damage_durability(amount: int = 1) -> void:
	if item_type == ItemType.EQUIPMENT and current_durability > 0:
		current_durability = max(0, current_durability - amount)

## Repara completamente a durabilidade do item
func repair_durability() -> void:
	current_durability = max_durability

## Retorna a cor característica da raridade
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.9, 0.9, 0.9)       # Branco Prata
		Rarity.EXCELLENT:
			return Color(0.2, 0.95, 0.4)      # Verde Esmeralda (Excelente)
		Rarity.ANCIENT:
			return Color(0.15, 0.7, 1.0)      # Azul Elétrico (Ancient)
		Rarity.GALACTIC:
			return Color(0.95, 0.25, 0.95)     # Violeta Cósmico (Galáctico)
	return Color.WHITE

## Retorna o nome formatado da raridade
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Comum"
		Rarity.EXCELLENT:
			return "Excelente"
		Rarity.ANCIENT:
			return "Ancient (Ancestral)"
		Rarity.GALACTIC:
			return "★ GALÁCTICO ★"
	return "Desconhecido"

## Retorna o multiplicador de atributos baseado na raridade
func get_rarity_multiplier() -> float:
	match rarity:
		Rarity.COMMON:
			return 1.0
		Rarity.EXCELLENT:
			return 1.3
		Rarity.ANCIENT:
			return 1.75
		Rarity.GALACTIC:
			return 2.5
	return 1.0

## Retorna o nome do slot de equipamento
func get_equip_slot_name() -> String:
	match equip_slot:
		EquipSlot.WEAPON: return "Arma"
		EquipSlot.SHIELD: return "Escudo"
		EquipSlot.HELMET: return "Capacete"
		EquipSlot.ARMOR: return "Armadura"
		EquipSlot.PANTS: return "Calça"
		EquipSlot.BOOTS: return "Botas"
		EquipSlot.GLOVES: return "Luvas"
		EquipSlot.RING: return "Anel"
		EquipSlot.EARRING: return "Brinco"
		EquipSlot.NECKLACE: return "Colar"
		EquipSlot.WINGS: return "Asas"
		EquipSlot.PET: return "Mascote / Pet"
		_: return "Nenhum"

## Gera um identificador único de instância (Número de Série / Serial UUID)
static func generate_uid() -> String:
	var usec := Time.get_ticks_usec()
	var rand_part := randi() % 1000000
	return "itm_%d_%06d" % [usec, rand_part]

## Gera um item pré-definido pelo ID
static func create_item(item_id: String, item_rarity: Rarity = Rarity.COMMON) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = item_id
	item.uid = generate_uid()
	item.rarity = item_rarity
	item.max_durability = item.get_default_durability_for_rarity()
	item.current_durability = item.max_durability
	var mult: float = item.get_rarity_multiplier()

	match item_id:
		"eons_pouch":
			item.name = "Saco de Éons"
			item.description = "Moedas douradas de Éons usadas para transações no reino."
			item.item_type = ItemType.MISC
			item.weight = 0.0
			item.max_stack = 99999
			item.icon_color = Color(1.0, 0.85, 0.1)

		"apple":
			item.name = "Maçã de Poring"
			item.description = "Uma fruta suculenta e doce derrubada por Porings. Restaura vida."
			item.item_type = ItemType.CONSUMABLE
			item.weight = 0.5
			item.max_stack = 99
			item.hp_heal = int(45.0 * mult)
			item.price_eons = 20
			item.icon_color = Color(1.0, 0.3, 0.3)

		"sp_potion":
			item.name = "Poção de Mana Azul"
			item.description = "Frasco com elixir mágico refinado. Restaura energia espiritual (SP)."
			item.item_type = ItemType.CONSUMABLE
			item.weight = 1.0
			item.max_stack = 99
			item.sp_heal = int(35.0 * mult)
			item.price_eons = 35
			item.icon_color = Color(0.2, 0.5, 1.0)

		"sword":
			item.name = "Lâmina do Caçador"
			item.description = "Uma espada afiada forjada com aço temperado. Aumenta o poder de ataque."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.WEAPON
			item.weight = 4.5
			item.max_stack = 1
			item.price_eons = 250
			item.stats_bonus = {"atk": int(22.0 * mult), "str": int(3.0 * mult)}
			item.icon_color = Color(0.85, 0.85, 0.95)

		"shield":
			item.name = "Escudo Guardião"
			item.description = "Um pesado escudo de metal usado por cavaleiros experientes."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.SHIELD
			item.weight = 6.0
			item.max_stack = 1
			item.price_eons = 200
			item.stats_bonus = {"hard_def": int(10.0 * mult), "vit": int(4.0 * mult)}
			item.icon_color = Color(0.7, 0.75, 0.8)

		"helmet":
			item.name = "Capacete de Aço"
			item.description = "Protege a cabeça contra golpes físicos pesados."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.HELMET
			item.weight = 2.5
			item.max_stack = 1
			item.price_eons = 150
			item.stats_bonus = {"hard_def": int(6.0 * mult), "str": int(1.0 * mult)}

		"armor":
			item.name = "Armadura de Ferro Iniciante"
			item.description = "Armadura de ferro forjada para novos aventureiros."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.ARMOR
			item.weight = 8.0
			item.max_stack = 1
			item.price_eons = 350
			item.stats_bonus = {"hard_def": int(16.0 * mult), "vit": int(5.0 * mult)}

		"pants":
			item.name = "Calça Tática de Couro"
			item.description = "Garante flexibilidade e proteção para as pernas."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.PANTS
			item.weight = 3.0
			item.max_stack = 1
			item.price_eons = 220
			item.stats_bonus = {"hard_def": int(7.0 * mult), "agi": int(2.0 * mult)}

		"boots":
			item.name = "Botas de Mercenário"
			item.description = "Aumenta a velocidade de esquiva e agilidade do usuário."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.BOOTS
			item.weight = 1.5
			item.max_stack = 1
			item.price_eons = 180
			item.stats_bonus = {"agi": int(4.0 * mult), "flee": int(8.0 * mult)}

		"gloves":
			item.name = "Luvas do Combate"
			item.description = "Reforça a precisão dos golpes com a arma."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.GLOVES
			item.weight = 1.0
			item.max_stack = 1
			item.price_eons = 150
			item.stats_bonus = {"dex": int(3.0 * mult), "hit": int(10.0 * mult)}

		"ring":
			item.name = "Anel do Vento Astral"
			item.description = "Um anel misterioso que canaliza energia estelar para aumentar agilidade."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.RING
			item.weight = 0.8
			item.max_stack = 1
			item.price_eons = 500
			item.stats_bonus = {"agi": int(4.0 * mult), "dex": int(3.0 * mult), "aspd": int(3.0 * mult)}

		"earring":
			item.name = "Brinco da Sabedoria"
			item.description = "Um brinco encantado que eleva a inteligência e energia espiritual."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.EARRING
			item.weight = 0.3
			item.max_stack = 1
			item.price_eons = 500
			item.stats_bonus = {"int_stat": int(5.0 * mult), "matk": int(15.0 * mult)}

		"necklace":
			item.name = "Colar da Vida Eterna"
			item.description = "Um colar sagrado que expande a vitalidade do portador."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.NECKLACE
			item.weight = 0.5
			item.max_stack = 1
			item.price_eons = 550
			item.stats_bonus = {"vit": int(4.0 * mult), "hard_def": int(5.0 * mult)}

		"wings":
			item.name = "Asas do Arcanjo Cósmico"
			item.description = "Asas majestosas que concedem velocidade divina, esquiva e ataque."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.WINGS
			item.weight = 2.0
			item.max_stack = 1
			item.price_eons = 2000
			item.stats_bonus = {"agi": int(6.0 * mult), "atk": int(15.0 * mult), "aspd": int(5.0 * mult)}

		"pet":
			item.name = "Ovo de Poring Dourado (Pet)"
			item.description = "Um adorável mascote leal que acompanha e fortalece o jogador."
			item.item_type = ItemType.EQUIPMENT
			item.equip_slot = EquipSlot.PET
			item.weight = 1.0
			item.max_stack = 1
			item.price_eons = 2500
			item.stats_bonus = {"luk": int(8.0 * mult), "crit": int(6.0 * mult)}

		"card":
			item.name = "Essência Galáctica"
			item.description = "Um cristal brilhante pulsando com o poder do cosmos. Altamente valioso."
			item.item_type = ItemType.MATERIAL
			item.weight = 0.2
			item.max_stack = 99

		_:
			item.name = "Espólio Misterioso"
			item.description = "Um item misterioso encontrado nos confins do mapa."
			item.item_type = ItemType.MATERIAL
			item.weight = 1.0
			item.max_stack = 50

	return item
