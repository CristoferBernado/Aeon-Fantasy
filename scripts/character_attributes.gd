extends Resource
class_name CharacterAttributes

## Sinais de alteração de atributos, nível e experiência
signal attributes_changed
signal level_up(new_level: int)
signal job_level_up(new_job_level: int)
signal exp_changed(current_base_exp: int, max_base_exp: int, current_job_exp: int, max_job_exp: int)

## Nível e Pontos de Atributos
@export_group("Level & Points")
@export var level: int = 1:
	set(val):
		level = max(1, val)
		base_level = level
		recalculate_stats()
		emit_signal("attributes_changed")

@export var base_level: int = 1
@export var job_level: int = 1

@export var current_base_exp: int = 0
@export var max_base_exp: int = 100
@export var current_job_exp: int = 0
@export var max_job_exp: int = 80

@export var stat_points: int = 48:
	set(val):
		stat_points = max(0, val)
		emit_signal("attributes_changed")

## Atributos Base (Estilo Ragnarok Online)
@export_group("Base Attributes")
## Força (STR): Aumenta o Ataque Físico (ATK) e a Capacidade de Carga
@export var str: int = 1:
	set(val):
		str = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Agilidade (AGI): Aumenta a Velocidade de Ataque (ASPD) e a Esquiva (FLEE)
@export var agi: int = 1:
	set(val):
		agi = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Vitalidade (VIT): Aumenta o HP Máximo, Regeneração e Defesa Física (Soft DEF)
@export var vit: int = 1:
	set(val):
		vit = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Inteligência (INT): Aumenta o Ataque Mágico (MATK), SP Máximo, Regeneração e Redução de Conjuração
@export var int_stat: int = 1:
	set(val):
		int_stat = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Destreza (DEX): Reduz o Tempo de Conjuração (Cast Time), Aumenta a Precisão (HIT) e ASPD Secundária
@export var dex: int = 1:
	set(val):
		dex = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Sorte (LUK): Aumenta a Taxa Crítica (CRIT), Esquiva Perfeita, ATK e MATK
@export var luk: int = 1:
	set(val):
		luk = clamp(val, 1, 99)
		recalculate_stats()
		emit_signal("attributes_changed")

## Status Derivados (Calculados Automatizados)
var max_hp: int = 100
var max_sp: int = 50
var atk: int = 10
var matk: int = 10
var hard_def: int = 0
var soft_def: int = 0
var soft_mdef: int = 0
var hit: int = 100
var flee: int = 100
var crit: float = 1.0

## Velocidade de Ataque (ASPD: 100 a 190 estilo RO)
var aspd: float = 140.0

## Redução da Variável do Tempo de Conjuração (0.0 = 0% a 1.0 = 100% / Instant Cast)
var cast_time_reduction: float = 0.0

# Bônus Ativos provenientes dos Equipamentos do Inventário
var equipment_bonuses: Dictionary = {}

func _init() -> void:
	recalculate_stats()

## Atualiza os bônus acumulados de equipamentos e recalcula os atributos
func update_equipment_bonuses(new_bonuses: Dictionary) -> void:
	equipment_bonuses = new_bonuses.duplicate()
	recalculate_stats()

## Recalcula todos os sub-status com base nos atributos principais e equipamentos equipados
func recalculate_stats(eq_bonuses: Dictionary = {}) -> void:
	if not eq_bonuses.is_empty():
		equipment_bonuses = eq_bonuses.duplicate()

	var bonus_str: int = equipment_bonuses.get("str", 0)
	var bonus_agi: int = equipment_bonuses.get("agi", 0)
	var bonus_vit: int = equipment_bonuses.get("vit", 0)
	var bonus_int: int = equipment_bonuses.get("int_stat", 0)
	var bonus_dex: int = equipment_bonuses.get("dex", 0)
	var bonus_luk: int = equipment_bonuses.get("luk", 0)

	var total_str: int = str + bonus_str
	var total_agi: int = agi + bonus_agi
	var total_vit: int = vit + bonus_vit
	var total_int: int = int_stat + bonus_int
	var total_dex: int = dex + bonus_dex
	var total_luk: int = luk + bonus_luk

	# HP & SP Máximos
	max_hp = int(100 + (level * 35) + (total_vit * 12) + (total_vit * total_vit * 0.1))
	max_sp = int(30 + (level * 8) + (total_int * 5))
	
	# Ataque Físico & Mágico
	atk = int((level / 4.0) + total_str + (pow(total_str / 10.0, 2)) + (total_dex / 5.0) + (total_luk / 5.0)) + equipment_bonuses.get("atk", 0)
	matk = int((level / 4.0) + total_int + (pow(total_int / 8.0, 2)) + (total_luk / 3.0)) + equipment_bonuses.get("matk", 0)
	
	# Defesa Física (Hard DEF equipada e Soft DEF de VIT)
	hard_def = equipment_bonuses.get("hard_def", 0)
	soft_def = int(total_vit * 0.8 + (level / 4.0))
	soft_mdef = int(total_int + (total_vit / 4.0) + (total_dex / 5.0))
	
	# Precisão (HIT) e Esquiva (FLEE)
	hit = int(175 + level + total_dex + (total_luk / 3.0)) + equipment_bonuses.get("hit", 0)
	flee = int(100 + level + total_agi + (total_luk / 5.0)) + equipment_bonuses.get("flee", 0)
	
	# Taxa Crítica (%)
	crit = float(1.0 + (total_luk * 0.3)) + equipment_bonuses.get("crit", 0)
	
	# ASPD (Velocidade de Ataque Estilo RO - Máximo 190)
	var base_aspd: float = 140.0
	var agi_bonus: float = total_agi * 0.45
	var dex_bonus: float = total_dex * 0.09
	aspd = clamp(base_aspd + agi_bonus + dex_bonus + equipment_bonuses.get("aspd", 0), 100.0, 190.0)
	
	# Redução do Tempo de Conjuração (Cast Time Reduction)
	var cast_stat_score: float = (total_dex * 2.0) + total_int
	cast_time_reduction = clamp(cast_stat_score / 300.0, 0.0, 1.0)

## Retorna o tempo final de conjuração em segundos para uma habilidade
func get_cast_time(base_cast_time: float) -> float:
	return base_cast_time * (1.0 - cast_time_reduction)

## Retorna o intervalo em segundos entre cada ataque baseado na ASPD
func get_attack_delay() -> float:
	# Fórmula RO: Intervalo entre ataques (segundos) = (200 - ASPD) / 50
	var delay: float = (200.0 - aspd) / 50.0
	return max(0.1, delay)

## Retorna a frequência de golpes (ataques por segundo) derivada da ASPD
func get_attack_frequency() -> float:
	var delay: float = get_attack_delay()
	return 1.0 / delay if delay > 0.0 else 10.0

## Custo em pontos para subir o atributo (fórmula clássica do RO)
func get_stat_upgrade_cost(current_stat_val: int) -> int:
	return int(floor((current_stat_val - 1) / 10.0) + 2)

## Aumenta um atributo consumindo pontos disponíveis (ex: 'str', 'agi', 'vit', 'int_stat', 'dex', 'luk')
func add_stat_point(stat_name: String) -> bool:
	var current_val = get(stat_name)
	if current_val == null:
		return false
		
	var cost: int = get_stat_upgrade_cost(current_val)
	if current_val < 99 and stat_points >= cost:
		stat_points -= cost
		set(stat_name, current_val + 1)
		return true
	return false

## Sistema Central de Resolução de Combate (HIT vs FLEE, Crítico, Hard DEF e Soft DEF)
static func calculate_combat_damage(
	attacker_hit: int,
	attacker_atk: int,
	attacker_crit: float,
	defender_flee: int,
	defender_hard_def: int,
	defender_soft_def: int
) -> Dictionary:
	var rng_crit := randf() * 100.0
	var is_crit: bool = (rng_crit < attacker_crit)
	
	if not is_crit:
		# Fórmula RO de Precisão vs Esquiva: Taxa de Acerto (%) = 80 + HIT - FLEE (entre 5% e 100%)
		var hit_chance: float = clamp(80.0 + float(attacker_hit) - float(defender_flee), 5.0, 100.0)
		var rng_hit := randf() * 100.0
		if rng_hit > hit_chance:
			return { "is_hit": false, "is_crit": false, "damage": 0 }
			
	var raw_damage: float = float(attacker_atk)
	
	if is_crit:
		# Golpe Crítico: ignora Hard DEF e concede bônus de 40% de dano
		raw_damage *= 1.4
	else:
		# Variação natural do ataque (95% a 105%)
		var variance := randf_range(0.95, 1.05)
		raw_damage *= variance
		# Redução por Hard DEF (Redução Percentual)
		var hard_def_reduction: float = clamp(1.0 - (float(defender_hard_def) / 100.0), 0.1, 1.0)
		raw_damage *= hard_def_reduction
		
	# Redução por Soft DEF (Redução Subtrativa baseada em VIT / Level)
	var final_damage: int = max(1, int(round(raw_damage)) - defender_soft_def)
	
	return {
		"is_hit": true,
		"is_crit": is_crit,
		"damage": final_damage
	}

## Adiciona Experiência Base e processa Level Up se necessário
func gain_base_exp(amount: int) -> void:
	current_base_exp += amount
	while current_base_exp >= max_base_exp:
		current_base_exp -= max_base_exp
		base_level += 1
		level = base_level
		stat_points += (base_level + 2)
		max_base_exp = int(100 * pow(base_level, 1.4))
		recalculate_stats()
		emit_signal("level_up", base_level)
	emit_signal("exp_changed", current_base_exp, max_base_exp, current_job_exp, max_job_exp)
	emit_signal("attributes_changed")

## Adiciona Experiência de Classe e processa Level Up de Classe
func gain_job_exp(amount: int) -> void:
	current_job_exp += amount
	while current_job_exp >= max_job_exp:
		current_job_exp -= max_job_exp
		job_level += 1
		max_job_exp = int(80 * pow(job_level, 1.35))
		recalculate_stats()
		emit_signal("job_level_up", job_level)
	emit_signal("exp_changed", current_base_exp, max_base_exp, current_job_exp, max_job_exp)
	emit_signal("attributes_changed")
