extends CharacterBody3D
class_name Mob

enum State { PATROL, CHASE, ATTACK }

@export_group("Basic Info & Combat Stats")
@export var mob_name: String = "Poring 3D"
@export var level: int = 5
@export var max_hp: int = 150
@export var defence: int = 2           # Hard DEF (Redução Percentual)
@export var soft_def: int = 5          # Soft DEF (Redução Subtrativa)
@export var hit: int = 110             # Precisão de Ataque
@export var flee: int = 80             # Taxa de Esquiva
@export var crit_rate: float = 1.0     # Taxa Crítica (%)
@export var base_exp_reward: int = 45  # Recompensa de Base EXP
@export var job_exp_reward: int = 35   # Recompensa de Job EXP
@export var drop_chance: float = 35.0  # Taxa de Drop de Espólios (%)

@export_group("AI & States")
@export var current_state: State = State.PATROL
@export var is_aggressive: bool = false
@export var detection_radius: float = 6.0
@export var chase_speed: float = 4.0
@export var attack_range: float = 1.8
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.5
@export var max_chase_distance: float = 15.0

@export_group("Patrol Settings")
@export var wander_speed: float = 2.5
@export var wander_radius: float = 8.0
@export var respawn_time: float = 10.0

@export var is_boss: bool = false

var current_hp: int = 150
var is_selected: bool = false
var is_dead: bool = false

var spawn_origin: Vector3 = Vector3.ZERO
var target_wander_pos: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var is_wandering: bool = false

var target_player: Player = null
var mob_attack_timer: float = 0.0

@onready var selection_ring: Node3D = get_node_or_null("SelectionRing") as Node3D
@onready var hp_label: Label3D = get_node_or_null("HpLabel") as Label3D
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

signal hp_changed(current: int, max: int)
signal died(spawn_pos: Vector3, mob_info: Dictionary)
signal state_changed(old_state: State, new_state: State)

func _ready() -> void:
	collision_mask = 1 | 4
	is_dead = false
	current_hp = max_hp
	if spawn_origin == Vector3.ZERO:
		spawn_origin = global_position
		
	if hit == 0: hit = 100 + level * 2
	if flee == 0: flee = 80 + level * 2
	add_to_group("mobs")
	
	if mesh_instance:
		mesh_instance.scale = Vector3(2.5, 2.5, 2.5) if is_boss else Vector3.ONE
		mesh_instance.position = Vector3(0, 1.25 if is_boss else 0.5, 0)
		mesh_instance.visible = true
		
	if selection_ring and is_boss:
		selection_ring.scale = Vector3(2.2, 2.2, 2.2)
		
	var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		col_shape.disabled = false
		col_shape.position = Vector3(0, 1.25 if is_boss else 0.5, 0)
		if is_boss:
			col_shape.scale = Vector3(2.2, 2.2, 2.2)
		
	if hp_label:
		hp_label.position = Vector3(0, 2.85 if is_boss else 1.25, 0)
		hp_label.no_depth_test = true
		hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	_update_ui()
	set_selected(false)
	_pick_new_wander_target()
	_spawn_yellow_aura_effect()

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
		
	var old_state := current_state
	current_state = new_state
	emit_signal("state_changed", old_state, new_state)
	
	if current_state == State.ATTACK:
		# Iniciar o timer de ataque com vento-up (25% do cooldown) para golpes assíncronos e individuais
		mob_attack_timer = attack_cooldown * 0.25
	elif current_state == State.PATROL:
		is_wandering = false
		wander_timer = 0.0
		
	_update_ui()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Prevenção contra penetração física abaixo do chão (y < 0.0)
	if global_position.y < 0.0:
		global_position.y = 0.0
		velocity.y = 0.0
		
	var player_node := _get_target_player()
	
	match current_state:
		State.PATROL:
			_process_patrol_state(delta, player_node)
		State.CHASE:
			_process_chase_state(delta, player_node)
		State.ATTACK:
			_process_attack_state(delta, player_node)

func _get_target_player() -> Player:
	if target_player and is_instance_valid(target_player) and not target_player.is_dead and target_player.current_hp > 0:
		return target_player
		
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		var p = players[0] as Player
		if p and is_instance_valid(p) and not p.is_dead and p.current_hp > 0:
			return p
	return null

func _process_patrol_state(delta: float, player_node: Player) -> void:
	# Transição para CHASE se for agressivo e o jogador entrar na área de detecção
	if is_aggressive and player_node:
		var dist_to_player := global_position.distance_to(player_node.global_position)
		if dist_to_player <= detection_radius:
			target_player = player_node
			change_state(State.CHASE)
			return

	# Lógica de caminhada livre (Patrulha / Wander AI)
	wander_timer -= delta
	if wander_timer <= 0.0:
		_pick_new_wander_target()
		
	if is_wandering:
		var current_2d := Vector2(global_position.x, global_position.z)
		var target_2d := Vector2(target_wander_pos.x, target_wander_pos.z)
		
		if current_2d.distance_to(target_2d) <= 0.3:
			is_wandering = false
			velocity = Vector3.ZERO
		else:
			var dir := (target_wander_pos - global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				dir = dir.normalized()
				velocity = dir * wander_speed
				_rotate_visual(dir, delta, 8.0)
				move_and_slide()
			else:
				velocity = Vector3.ZERO

func _process_chase_state(delta: float, player_node: Player) -> void:
	if not player_node or player_node.current_hp <= 0:
		target_player = null
		change_state(State.PATROL)
		return
		
	target_player = player_node
	var player_pos := player_node.global_position
	var dist_to_player := Vector2(global_position.x, global_position.z).distance_to(Vector2(player_pos.x, player_pos.z))
	var dist_from_spawn := global_position.distance_to(spawn_origin)
	
	# Limite de perseguição (Leash Distance): desiste de perseguir se afastar demais da origem
	if dist_from_spawn > max_chase_distance or dist_to_player > (max_chase_distance * 1.2):
		target_player = null
		change_state(State.PATROL)
		return
		
	# Transição para ATAQUE se estiver no alcance
	if dist_to_player <= attack_range:
		velocity = Vector3.ZERO
		change_state(State.ATTACK)
		return
		
	# Se mob e jogador estiverem em andares diferentes, o mob NÃO pode subir nem descer as escadas
	var mob_high: bool = spawn_origin.y >= 1.5
	var p_high: bool = player_pos.y >= 1.5
	var target_pos := player_pos

	if mob_high != p_high:
		if mob_high:
			# Mob do andar superior: persegue até o limite do platô (Z = -26.5) sem descer a escada
			target_pos.z = min(player_pos.z, -26.5)
			target_pos.x = clamp(player_pos.x, 26.5, 43.5)
		else:
			# Mob do andar inferior: persegue até a base da escada (Z = -18.0) sem subir
			target_pos.z = max(player_pos.z, -18.0)
			
		var dist_to_edge := Vector2(global_position.x, global_position.z).distance_to(Vector2(target_pos.x, target_pos.z))
		if dist_to_edge <= 0.6:
			velocity = Vector3.ZERO
			var look_dir := (player_pos - global_position)
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.001:
				_rotate_visual(look_dir.normalized(), delta, 12.0)
			return

	var dir := (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
		if not is_on_floor():
			velocity.y -= 19.6 * delta
		else:
			velocity.y = -0.1
		_rotate_visual(dir, delta, 12.0)
		move_and_slide()
		
		# Trava física de posição para que mobs nunca cruzem a escada
		if mob_high:
			if global_position.z > -26.0 and global_position.x >= 32.0 and global_position.x <= 38.0:
				global_position.z = -26.0
		else:
			if global_position.z < -18.2 and global_position.x >= 32.0 and global_position.x <= 38.0:
				global_position.z = -18.2
	else:
		velocity = Vector3.ZERO

func _process_attack_state(delta: float, player_node: Player) -> void:
	if not player_node or player_node.current_hp <= 0:
		target_player = null
		change_state(State.PATROL)
		return
		
	target_player = player_node
	var player_pos := player_node.global_position
	var dist_to_player := Vector2(global_position.x, global_position.z).distance_to(Vector2(player_pos.x, player_pos.z))
	
	# Transição de volta para PERSEGUIÇÃO se o jogador se afastar
	if dist_to_player > attack_range:
		change_state(State.CHASE)
		return
		
	velocity = Vector3.ZERO
	
	# Rotacionar na direção do jogador
	var dir := (player_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		_rotate_visual(dir.normalized(), delta, 14.0)
		
	# Cooldown de ataque do mob
	mob_attack_timer += delta
	if mob_attack_timer >= attack_cooldown:
		mob_attack_timer = 0.0
		_perform_mob_attack(player_node)

func _perform_mob_attack(player_ref: Player) -> void:
	if not player_ref or not is_instance_valid(player_ref) or player_ref.current_hp <= 0:
		return
		
	player_ref.take_damage_from(hit, attack_damage, crit_rate)
	
	# Animação visual de avanço do mob
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "position:z", 0.4, 0.08)
		tween.tween_property(mesh_instance, "position:z", 0.0, 0.1)

func _rotate_visual(dir: Vector3, delta: float, speed: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	if mesh_instance:
		mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_angle, delta * speed)
	else:
		rotation.y = lerp_angle(rotation.y, target_angle, delta * speed)

func _pick_new_wander_target() -> void:
	wander_timer = randf_range(3.5, 7.0)
	
	if randf() > 0.4:
		var random_offset := Vector3(
			randf_range(-wander_radius, wander_radius),
			0.0,
			randf_range(-wander_radius, wander_radius)
		)
		target_wander_pos = spawn_origin + random_offset
		target_wander_pos.y = spawn_origin.y
		if spawn_origin.y >= 2.0:
			target_wander_pos.x = clamp(target_wander_pos.x, 28.0, 42.0)
			target_wander_pos.z = clamp(target_wander_pos.z, -42.0, -28.0)
		is_wandering = true
	else:
		is_wandering = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected

## Processa o dano recebido aplicando HIT vs FLEE, Crítico, Hard DEF e Soft DEF
func take_damage_from(attacker_hit: int, attacker_atk: int, attacker_crit: float) -> Dictionary:
	if is_dead:
		return { "is_hit": false, "is_crit": false, "damage": 0 }
		
	var result := CharacterAttributes.calculate_combat_damage(
		attacker_hit,
		attacker_atk,
		attacker_crit,
		flee,
		defence,
		soft_def
	)
	
	if result["is_hit"]:
		var dmg: int = result["damage"]
		current_hp = max(0, current_hp - dmg)
		_update_ui()
		emit_signal("hp_changed", current_hp, max_hp)
		_flash_damage(result["is_crit"])
		
		# Popup numérico no estilo RO (Normal: Branco com contorno | Crítico: Amarelo Dourado)
		if result["is_crit"]:
			DamagePopup.spawn(get_parent(), global_position, "★ %d CRÍTICO!" % dmg, Color(1.0, 0.88, 0.1), 52, true)
		else:
			DamagePopup.spawn(get_parent(), global_position, str(dmg), Color(1.0, 1.0, 1.0), 44, false)
			
		if current_hp <= 0:
			_die()
	else:
		_flash_miss()
		# Popup de Esquiva (MISS)
		DamagePopup.spawn(get_parent(), global_position, "MISS", Color(0.65, 0.85, 1.0), 36, false)
		
	# Contra-ataque: se atacado enquanto em patrulha, passa a perseguir o agressor
	if current_state == State.PATROL:
		var p := _get_target_player()
		if p:
			target_player = p
			change_state(State.CHASE)
			
	return result

func take_damage(amount: int) -> int:
	var result := take_damage_from(999, amount, 0.0)
	return result["damage"]

func _flash_damage(is_crit: bool = false) -> void:
	if mesh_instance:
		var target_scale = Vector3(1.45, 0.55, 1.45) if is_crit else Vector3(1.25, 0.75, 1.25)
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", target_scale, 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.12)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)

func _flash_miss() -> void:
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "rotation:z", deg_to_rad(20.0), 0.06)
		tween.tween_property(mesh_instance, "rotation:z", deg_to_rad(-20.0), 0.06)
		tween.tween_property(mesh_instance, "rotation:z", 0.0, 0.06)

func _update_ui() -> void:
	if hp_label:
		var state_str: String = ""
		match current_state:
			State.PATROL:
				state_str = "Patrulha"
			State.CHASE:
				state_str = "Perseguição"
			State.ATTACK:
				state_str = "Ataque"
				
		if is_boss:
			hp_label.text = "👑 %s (BOSS Lv %d)\n[%s] HP: %d/%d" % [mob_name, level, state_str, current_hp, max_hp]
			hp_label.modulate = Color(1.0, 0.35, 0.1)
			hp_label.font_size = 28
			hp_label.outline_size = 6
		else:
			hp_label.text = "%s (Lv %d)\n[%s] HP: %d/%d" % [mob_name, level, state_str, current_hp, max_hp]
			hp_label.font_size = 22
			hp_label.outline_size = 4

func _die() -> void:
	is_dead = true
	set_selected(false)
	_spawn_death_smoke_effect()
	
	# Conceder experiência e espólios ao jogador
	var p := _get_target_player()
	if p:
		p.gain_experience(base_exp_reward, job_exp_reward)
		_drop_loot(p)
		
	var mob_info = {
		"mob_name": mob_name,
		"level": level,
		"max_hp": max_hp,
		"defence": defence,
		"wander_speed": wander_speed,
		"wander_radius": wander_radius,
		"respawn_time": respawn_time,
		"is_aggressive": is_aggressive,
		"chase_speed": chase_speed,
		"attack_damage": attack_damage,
		"attack_cooldown": attack_cooldown,
		"is_boss": is_boss
	}
	
	emit_signal("died", spawn_origin, mob_info)
	
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3(0.01, 0.01, 0.01), 0.3)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	else:
		queue_free()

const DroppedItemScene = preload("res://scenes/dropped_item.tscn")

func _drop_loot(player_ref: Player) -> void:
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene

	# 1. DROP GARANTIDO DE ÉONS (Ouro in-game proporcional ao nível do mob)
	var eons_chance: float = 100.0 if is_boss else clamp(70.0 + level * 3.0, 70.0, 95.0)
	if randf() * 100.0 <= eons_chance:
		var eons_amount: int = randi_range(level * 80, level * 150) if is_boss else randi_range(level * 12, level * 28)
		var eons_item_data := ItemData.create_item("eons_pouch", ItemData.Rarity.COMMON)
		var dropped_eons = DroppedItemScene.instantiate() as DroppedItem
		parent_node.add_child(dropped_eons)
		var scatter_eons := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
		dropped_eons.global_position = global_position + scatter_eons
		dropped_eons.setup_item(eons_item_data, eons_amount)

	# 2. DROP DE EQUIPAMENTOS E CONSUMÍVEIS (Taxa de drop de itens)
	var num_drops: int = randi_range(2, 4) if is_boss else 1
	if not is_boss and randf() * 100.0 > drop_chance:
		return

	for d in range(num_drops):
		var rng := randf() * 100.0
		var item_rarity := ItemData.Rarity.COMMON
		
		if is_boss:
			if rng < 40.0:
				item_rarity = ItemData.Rarity.GALACTIC
			else:
				item_rarity = ItemData.Rarity.ANCIENT
		else:
			if rng < 5.0:         # 5% de chance de item GALÁCTICO
				item_rarity = ItemData.Rarity.GALACTIC
			elif rng < 20.0:      # 15% de chance de item ANCIENT
				item_rarity = ItemData.Rarity.ANCIENT
			elif rng < 50.0:      # 30% de chance de item EXCELENTE
				item_rarity = ItemData.Rarity.EXCELLENT

		var possible_items = ["apple", "sp_potion", "sword", "shield", "helmet", "armor", "pants", "boots", "gloves", "ring", "jewel_simplicity", "jewel_ethrel", "card"]
		var chosen_id: String = possible_items[randi() % possible_items.size()]
		var loot := ItemData.create_item(chosen_id, item_rarity)
		
		var qty: int = 1
		if chosen_id == "apple" or chosen_id == "sp_potion":
			qty = randi_range(3, 8) if is_boss else randi_range(1, 3)
			
		# Instanciar o item no chão 3D
		var dropped_item = DroppedItemScene.instantiate() as DroppedItem
		parent_node.add_child(dropped_item)
		
		var scatter := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		dropped_item.global_position = global_position + scatter
		dropped_item.setup_item(loot, qty)

func _spawn_yellow_aura_effect() -> void:
	var parent_node = get_parent()
	if not parent_node: parent_node = get_tree().current_scene
	
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18 if not is_boss else 0.45
	mesh.height = 0.36 if not is_boss else 0.90
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.2, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.1)
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 28 if not is_boss else 45
	particles.lifetime = 0.95
	particles.one_shot = true
	particles.explosiveness = 0.35
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 45.0
	particles.gravity = Vector3(0, 1.8, 0)
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.4
	
	parent_node.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.2, 0)
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(particles.queue_free)

func _spawn_death_smoke_effect() -> void:
	var parent_node = get_parent()
	if not parent_node: parent_node = get_tree().current_scene
	
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32 if not is_boss else 0.8
	mesh.height = 0.64 if not is_boss else 1.6
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.95, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.9
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 24 if not is_boss else 50
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.gravity = Vector3(0, 0.8, 0)
	particles.initial_velocity_min = 2.2 if not is_boss else 4.5
	particles.initial_velocity_max = 4.8 if not is_boss else 9.0
	
	parent_node.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.6, 0)
	particles.emitting = true
	
	var timer = get_tree().create_timer(0.7)
	timer.timeout.connect(particles.queue_free)
