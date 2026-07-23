extends CharacterBody3D
class_name Player

@export var move_speed: float = 8.0
@export var rotation_speed: float = 14.0
@export var attack_range: float = 1.8
@export var attributes: CharacterAttributes = null

@onready var visual_mesh: Node3D = $VisualMesh

var is_moving: bool = false
var target_destination: Vector3 = Vector3.ZERO
var current_move_dir: Vector3 = Vector3.BACK

# Sistema de Alvo e Combate
var target_mob: Mob = null
var target_item: DroppedItem = null
var is_attacking: bool = false
var attack_timer: float = 0.0

# Sistema de HP e SP do Jogador
var current_hp: int = 100
var current_sp: int = 50
var is_dead: bool = false
var spawn_origin: Vector3 = Vector3.ZERO

@onready var feet_left: Node3D = get_node_or_null("VisualMesh/FeetLeft") as Node3D
@onready var feet_right: Node3D = get_node_or_null("VisualMesh/FeetRight") as Node3D
@onready var hand_left: Node3D = get_node_or_null("VisualMesh/HandLeft") as Node3D
@onready var hand_right: Node3D = get_node_or_null("VisualMesh/HandRight") as Node3D
@onready var weapon_sword: Node3D = get_node_or_null("VisualMesh/HandRight/WeaponSword") as Node3D

var walk_anim_time: float = 0.0

# Sistema de Inventário
var inventory: InventoryManager = null

signal target_reached
signal attacked_mob(mob: Mob, damage: int)
signal hp_changed(current: int, max_val: int)
signal sp_changed(current: int, max_val: int)
signal player_died
signal player_respawned

func _ready() -> void:
	add_to_group("players")
	spawn_origin = global_position
	if not attributes:
		attributes = CharacterAttributes.new()
	current_hp = attributes.max_hp
	current_sp = attributes.max_sp
	attack_timer = attributes.get_attack_delay()
	attributes.attributes_changed.connect(_on_attributes_changed)
	
	collision_mask = 1 | 4
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	
	# Inicializar Inventário com itens de teste cobrindo todas as raridades
	inventory = InventoryManager.new()
	inventory.player_ref = self
	_add_starter_items()
	update_weapon_visuals()

func update_weapon_visuals() -> void:
	var weapon_node = get_node_or_null("VisualMesh/HandRight/WeaponSword")
	if not weapon_node:
		return
		
	if not inventory or not inventory.equipped_items.has("weapon") or inventory.equipped_items["weapon"] == null:
		weapon_node.visible = false
		return
		
	var w_item: ItemData = inventory.equipped_items["weapon"]
	if w_item and w_item.item_type == ItemData.ItemType.EQUIPMENT:
		weapon_node.visible = true
	else:
		weapon_node.visible = false

func _add_starter_items() -> void:
	if inventory:
		inventory.add_item(ItemData.create_item("apple", ItemData.Rarity.COMMON), 10)
		inventory.add_item(ItemData.create_item("sp_potion", ItemData.Rarity.COMMON), 5)
		inventory.add_item(ItemData.create_item("sword", ItemData.Rarity.EXCELLENT), 1)
		inventory.add_item(ItemData.create_item("shield", ItemData.Rarity.COMMON), 1)
		inventory.add_item(ItemData.create_item("helmet", ItemData.Rarity.COMMON), 1)
		inventory.add_item(ItemData.create_item("armor", ItemData.Rarity.EXCELLENT), 1)
		inventory.add_item(ItemData.create_item("pants", ItemData.Rarity.COMMON), 1)
		inventory.add_item(ItemData.create_item("boots", ItemData.Rarity.EXCELLENT), 1)
		inventory.add_item(ItemData.create_item("gloves", ItemData.Rarity.COMMON), 1)
		inventory.add_item(ItemData.create_item("ring", ItemData.Rarity.ANCIENT), 1)
		inventory.add_item(ItemData.create_item("earring", ItemData.Rarity.COMMON), 1)
		inventory.add_item(ItemData.create_item("necklace", ItemData.Rarity.ANCIENT), 1)
		inventory.add_item(ItemData.create_item("wings", ItemData.Rarity.GALACTIC), 1)
		inventory.add_item(ItemData.create_item("pet", ItemData.Rarity.GALACTIC), 1)

func _on_attributes_changed() -> void:
	if attributes:
		current_hp = min(current_hp, attributes.max_hp)
		current_sp = min(current_sp, attributes.max_sp)
		emit_signal("hp_changed", current_hp, attributes.max_hp)
		emit_signal("sp_changed", current_sp, attributes.max_sp)

func gain_experience(base_exp: int, job_exp: int) -> void:
	if attributes:
		attributes.gain_base_exp(base_exp)
		attributes.gain_job_exp(job_exp)

func use_sp(amount: int) -> bool:
	if is_dead:
		return false
	if current_sp >= amount:
		current_sp -= amount
		emit_signal("sp_changed", current_sp, attributes.max_sp if attributes else 50)
		return true
	return false

func lock_target(mob: Mob, start_attacking: bool = true) -> void:
	if is_dead:
		return
		
	# Se já tinha um alvo selecionado diferente, desativa a seleção do antigo
	if target_mob and is_instance_valid(target_mob) and target_mob != mob:
		target_mob.set_selected(false)
		
	var is_new_mob: bool = (target_mob != mob)
	target_mob = mob
	target_item = null
	is_attacking = start_attacking
	
	if target_mob and is_instance_valid(target_mob):
		target_mob.set_selected(true)
		if not target_mob.died.is_connected(_on_target_mob_died):
			target_mob.died.connect(_on_target_mob_died)
		set_move_target(target_mob.global_position)

func lock_item_target(item: DroppedItem) -> void:
	if is_dead or not item or not is_instance_valid(item) or item.is_picked_up:
		return
		
	clear_target()
	target_item = item
	set_move_target(item.global_position)

## Procura e coleta o item no chão mais próximo ao pressionar a tecla Espaço
func pickup_nearest_item() -> bool:
	if is_dead:
		return false

	var items = get_tree().get_nodes_in_group("dropped_items")
	var closest_item: DroppedItem = null
	var min_dist: float = 9999.0

	for node in items:
		var item = node as DroppedItem
		if item and is_instance_valid(item) and not item.is_picked_up:
			var dist: float = global_position.distance_to(item.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_item = item

	if closest_item:
		if min_dist <= 1.8:
			return closest_item.attempt_pickup(self)
		elif min_dist <= 15.0:
			lock_item_target(closest_item)
			return true

	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			pickup_nearest_item()
			get_viewport().set_input_as_handled()

const STAIR_TOP_WAYPOINT := Vector3(35.0, 3.0, -26.5)
const STAIR_BOTTOM_WAYPOINT := Vector3(35.0, 0.0, -18.5)

var waypoint_queue: Array[Vector3] = []

func clear_target() -> void:
	if target_mob and is_instance_valid(target_mob):
		target_mob.set_selected(false)
	target_mob = null
	target_item = null
	is_attacking = false
	attack_timer = 0.0
	waypoint_queue.clear()

func set_move_target(target_pos: Vector3) -> void:
	if is_dead:
		return
		
	waypoint_queue.clear()
	var cur_y: float = global_position.y
	var dest_y: float = target_pos.y
	
	if cur_y >= 1.5 and dest_y < 1.5:
		if global_position.distance_to(STAIR_TOP_WAYPOINT) > 1.2:
			waypoint_queue.append(STAIR_TOP_WAYPOINT)
		waypoint_queue.append(STAIR_BOTTOM_WAYPOINT)
		waypoint_queue.append(target_pos)
	elif cur_y < 1.5 and dest_y >= 1.5:
		if global_position.distance_to(STAIR_BOTTOM_WAYPOINT) > 1.2:
			waypoint_queue.append(STAIR_BOTTOM_WAYPOINT)
		waypoint_queue.append(STAIR_TOP_WAYPOINT)
		waypoint_queue.append(target_pos)
	else:
		waypoint_queue.append(target_pos)
		
	_advance_waypoint()
	is_moving = true

func _advance_waypoint() -> void:
	if waypoint_queue.size() > 0:
		target_destination = waypoint_queue.pop_front()
	else:
		is_moving = false
		velocity.x = 0.0
		velocity.z = 0.0
		emit_signal("target_reached")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
		
	# Aplicar gravidade para manter o personagem colado ao chão e rampas
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.1
		
	# Processamento de Coleta de Item Focado
	if target_item and is_instance_valid(target_item) and not target_item.is_picked_up:
		if not is_moving and waypoint_queue.is_empty():
			set_move_target(target_item.global_position)
		var dist_to_item: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(target_item.global_position.x, target_item.global_position.z))
		
		if dist_to_item <= 1.5:
			is_moving = false
			waypoint_queue.clear()
			velocity.x = 0.0
			velocity.z = 0.0
			target_item.attempt_pickup(self)
			target_item = null

	# Processamento de Combate / Perseguição ao Alvo
	if target_mob and is_instance_valid(target_mob) and not target_mob.is_dead:
		var dist_to_mob: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(target_mob.global_position.x, target_mob.global_position.z))
		
		# Se estiver fora do alcance de ataque, aproxima-se do mob
		if dist_to_mob > attack_range:
			if not is_moving or waypoint_queue.is_empty():
				set_move_target(target_mob.global_position)
		else:
			# Chegou ao alcance de ataque
			is_moving = false
			waypoint_queue.clear()
			velocity.x = 0.0
			velocity.z = 0.0
			
			# Rotacionar o personagem na direção do mob
			var dir_to_mob: Vector3 = (target_mob.global_position - global_position)
			dir_to_mob.y = 0.0
			if dir_to_mob.length_squared() > 0.001:
				var target_angle: float = atan2(dir_to_mob.x, dir_to_mob.z)
				if visual_mesh:
					visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_angle, delta * rotation_speed)
				else:
					rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
					
			# Se o clique duplo ativou o modo de ataque contínuo
			if is_attacking:
				attack_timer += delta
				var attack_delay: float = attributes.get_attack_delay()
				if attack_timer >= attack_delay:
					attack_timer = 0.0
					_perform_attack(target_mob)
			return

	if is_moving:
		var current_pos_2d := Vector2(global_position.x, global_position.z)
		var target_pos_2d := Vector2(target_destination.x, target_destination.z)
		var dist: float = current_pos_2d.distance_to(target_pos_2d)
		
		if dist <= 0.6:
			if waypoint_queue.size() > 0:
				_advance_waypoint()
			else:
				is_moving = false
				velocity.x = 0.0
				velocity.z = 0.0
				emit_signal("target_reached")
		else:
			var direction: Vector3 = (target_destination - global_position)
			direction.y = 0.0
			
			if direction.length_squared() > 0.001:
				var move_dir := direction.normalized()
				current_move_dir = move_dir
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				
				var target_angle: float = atan2(move_dir.x, move_dir.z)
				if visual_mesh:
					visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_angle, delta * rotation_speed)
				else:
					rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
	move_and_slide()

	# Animação Procedural de Caminhada (Balanço de Pés, Mãos e Bobbing Vertical)
	# Se o personagem estiver travado contra uma parede (velocidade real 2D muito baixa), pausa a animação sem cancelar os waypoints
	var actual_speed_2d := Vector2(velocity.x, velocity.z).length()
	var is_stuck_on_wall: bool = is_on_wall() and actual_speed_2d < 0.2

	if is_moving and not is_stuck_on_wall and actual_speed_2d > 0.05:
		walk_anim_time += delta * 12.0
		var leg_swing: float = sin(walk_anim_time) * 0.18
		var arm_swing: float = sin(walk_anim_time) * 0.14
		var bob_y: float = abs(sin(walk_anim_time)) * 0.06
		
		if feet_left: feet_left.position.z = 0.08 + leg_swing
		if feet_right: feet_right.position.z = 0.08 - leg_swing
		if hand_left: hand_left.position.z = 0.15 - arm_swing
		if hand_right: hand_right.position.z = 0.15 + arm_swing
		if visual_mesh: visual_mesh.position.y = bob_y
	else:
		walk_anim_time = 0.0
		if feet_left: feet_left.position.z = lerp(feet_left.position.z, 0.08, delta * 14.0)
		if feet_right: feet_right.position.z = lerp(feet_right.position.z, 0.08, delta * 14.0)
		if hand_left: hand_left.position.z = lerp(hand_left.position.z, 0.15, delta * 14.0)
		if hand_right: hand_right.position.z = lerp(hand_right.position.z, 0.15, delta * 14.0)
		if visual_mesh: visual_mesh.position.y = lerp(visual_mesh.position.y, 0.0, delta * 14.0)

func _perform_attack(mob: Mob) -> void:
	if not mob or not is_instance_valid(mob) or mob.is_dead:
		return
		
	var p_hit: int = attributes.hit if attributes else 100
	var p_atk: int = attributes.atk if attributes else 10
	var p_crit: float = attributes.crit if attributes else 1.0
	
	var result: Dictionary = mob.take_damage_from(p_hit, p_atk, p_crit)
	emit_signal("attacked_mob", mob, result.get("damage", 0))
	
	# Degradação de durabilidade da arma ao atacar
	if inventory:
		inventory.degrade_equipped_durability("weapon", 1)
	
	# Animação de Golpe de Espada Procedural (Corte em Arco + Fagulhas de Impacto)
	var delay: float = attributes.get_attack_delay() if attributes else 0.5
	var windup_time: float = min(0.06, delay * 0.20)
	var slash_time: float = min(0.10, delay * 0.30)
	var recovery_time: float = min(0.12, delay * 0.40)
	
	if weapon_sword and weapon_sword.visible:
		var tween = create_tween()
		tween.tween_property(weapon_sword, "rotation_degrees:y", -45.0, windup_time)
		tween.tween_property(weapon_sword, "rotation_degrees:y", 65.0, slash_time)
		tween.tween_property(weapon_sword, "rotation_degrees:y", 0.0, recovery_time)
		
		if hand_right:
			var tween_hand = create_tween()
			tween_hand.tween_property(hand_right, "position:z", 0.45, slash_time)
			tween_hand.tween_property(hand_right, "position:z", 0.15, recovery_time)
	elif visual_mesh:
		var tween = create_tween()
		tween.tween_property(visual_mesh, "position:z", 0.3, windup_time + slash_time)
		tween.tween_property(visual_mesh, "position:z", 0.0, recovery_time)
		
	if mob and is_instance_valid(mob):
		_spawn_hit_sparks_effect(mob.global_position + Vector3(0, 0.8, 0))

func _spawn_hit_sparks_effect(pos: Vector3) -> void:
	var parent_node = get_parent()
	if not parent_node: parent_node = get_tree().current_scene
	
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 14
	particles.lifetime = 0.25
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	
	parent_node.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(particles.queue_free)

func _on_target_mob_died() -> void:
	clear_target()

## Processa dano recebido pelo jogador aplicando HIT vs FLEE, Crítico, Hard DEF e Soft DEF
func take_damage_from(attacker_hit: int, attacker_atk: int, attacker_crit: float) -> Dictionary:
	if current_hp <= 0:
		return { "is_hit": false, "is_crit": false, "damage": 0 }
		
	var p_flee: int = attributes.flee if attributes else 100
	var p_hard_def: int = attributes.hard_def if attributes else 0
	var p_soft_def: int = attributes.soft_def if attributes else 0
	
	var result := CharacterAttributes.calculate_combat_damage(
		attacker_hit,
		attacker_atk,
		attacker_crit,
		p_flee,
		p_hard_def,
		p_soft_def
	)
	
	if result["is_hit"]:
		var dmg: int = result["damage"]
		current_hp = max(0, current_hp - dmg)
		emit_signal("hp_changed", current_hp, attributes.max_hp if attributes else 100)
		
		# Degradação de durabilidade dos equipamentos de defesa ao receber dano
		if inventory:
			inventory.degrade_equipped_durability("armor", 1)
		_flash_damage(result["is_crit"])
		
		# Popup de dano recebido pelo jogador (Vermelho estilo RO)
		if result["is_crit"]:
			DamagePopup.spawn(get_parent(), global_position, "-%d CRÍTICO!" % dmg, Color(1.0, 0.25, 0.25), 52, true)
		else:
			DamagePopup.spawn(get_parent(), global_position, "-%d" % dmg, Color(1.0, 0.4, 0.4), 44, false)
			
		if current_hp <= 0:
			_die()
	else:
		_flash_miss()
		# Popup de esquiva do jogador
		DamagePopup.spawn(get_parent(), global_position, "ESQUIVA!", Color(0.4, 0.95, 1.0), 36, false)
		
	return result

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_moving = false
	velocity = Vector3.ZERO
	clear_target()
	emit_signal("player_died")
	
	# Animação visual de queda (tombamento no chão)
	if visual_mesh:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_mesh, "rotation:z", deg_to_rad(-85.0), 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_mesh, "position:y", -0.4, 0.35)

func respawn() -> void:
	is_dead = false
	is_moving = false
	velocity = Vector3.ZERO
	clear_target()
	
	# Restaurar HP e SP
	current_hp = attributes.max_hp if attributes else 100
	current_sp = attributes.max_sp if attributes else 50
	emit_signal("hp_changed", current_hp, attributes.max_hp if attributes else 100)
	emit_signal("sp_changed", current_sp, attributes.max_sp if attributes else 50)
	
	# Teleportar para a origem no início do mapa
	global_position = spawn_origin
	target_destination = spawn_origin
	
	# Restaurar transformação visual da malha
	if visual_mesh:
		visual_mesh.rotation = Vector3.ZERO
		visual_mesh.position = Vector3.ZERO
		visual_mesh.scale = Vector3.ONE
		
	emit_signal("player_respawned")

func take_damage(amount: int) -> int:
	var result := take_damage_from(999, amount, 0.0)
	return result["damage"]

func _flash_damage(is_crit: bool = false) -> void:
	if visual_mesh:
		var target_scale = Vector3(1.3, 0.7, 1.3) if is_crit else Vector3(1.2, 0.8, 1.2)
		var tween = create_tween()
		tween.tween_property(visual_mesh, "scale", target_scale, 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.12)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)

func _flash_miss() -> void:
	if visual_mesh:
		var tween = create_tween()
		tween.tween_property(visual_mesh, "rotation:z", deg_to_rad(15.0), 0.06)
		tween.tween_property(visual_mesh, "rotation:z", deg_to_rad(-15.0), 0.06)
		tween.tween_property(visual_mesh, "rotation:z", 0.0, 0.06)
