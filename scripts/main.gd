extends Node3D

@onready var camera_rig: CameraController = $CameraRig
@onready var player: Player = get_node_or_null("NavigationRegion3D/Player") as Player
@onready var camera3d: Camera3D = $CameraRig/CameraPitch/Camera3D

const ClickMarkerScene = preload("res://scenes/click_marker.tscn")
const MobScene = preload("res://scenes/mob.tscn")
const HUDControllerClass = preload("res://scripts/hud_controller.gd")

# Sistema de Detecção de Clique Duplo
var last_click_time: float = 0.0
var last_clicked_mob: Mob = null
const DOUBLE_CLICK_TIME: float = 0.35

const NPCShopScene = preload("res://scenes/npc_shop.tscn")
const NPCBlacksmithScene = preload("res://scenes/npc_blacksmith.tscn")

func _ready() -> void:
	# Instanciar a UI do HUD (HP, SP, EXP, Atributos e Minimapa)
	var hud = HUDControllerClass.new()
	add_child(hud)

	# Conectar sinais dos mobs já existentes no mapa para o sistema de Respawn
	_connect_mobs_respawn()
	
	# Gerar mobs adicionais espalhados pelo mapa amplo de 120m x 120m
	_spawn_initial_map_mobs()

	# Instanciar o NPC Vendedor e o Ferreiro próximo ao centro (livre de colisão)
	_spawn_npc_merchant()
	_spawn_npc_blacksmith()

func _spawn_npc_merchant() -> void:
	var npc = NPCShopScene.instantiate() as NPCShop
	var nav_region = get_node_or_null("NavigationRegion3D")
	if nav_region:
		nav_region.add_child(npc)
	else:
		add_child(npc)
	npc.global_position = Vector3(2.0, 0, 6.0)

func _spawn_npc_blacksmith() -> void:
	var blacksmith = NPCBlacksmithScene.instantiate() as NPCBlacksmith
	var nav_region = get_node_or_null("NavigationRegion3D")
	if nav_region:
		nav_region.add_child(blacksmith)
	else:
		add_child(blacksmith)
	blacksmith.global_position = Vector3(-2.0, 0, 6.0)

func _spawn_initial_map_mobs() -> void:
	var extra_mobs_info = [
		{"name": "Lunático 3D", "level": 7, "hp": 180, "pos": Vector3(25, 0, 25), "aggr": false, "is_boss": false},
		{"name": "Fabre 3D", "level": 10, "hp": 240, "pos": Vector3(-30, 0, 20), "aggr": false, "is_boss": false},
		{"name": "Esporito 3D", "level": 12, "hp": 300, "pos": Vector3(-25, 0, -35), "aggr": false, "is_boss": false},
		{"name": "Esqueleto Guerreiro", "level": 18, "hp": 450, "pos": Vector3(40, 0, -25), "aggr": true, "is_boss": false},
		{"name": "Golem de Pedra", "level": 25, "hp": 750, "pos": Vector3(-45, 0, 45), "aggr": true, "is_boss": false},
		{"name": "Poring Rei", "level": 15, "hp": 500, "pos": Vector3(38, 0, 38), "aggr": false, "is_boss": false},
		{"name": "Saeron", "level": 35, "hp": 3500, "pos": Vector3(35, 3.0, -35), "aggr": true, "is_boss": true}
	]

	for info in extra_mobs_info:
		var mob_data = {
			"mob_name": info["name"],
			"level": info["level"],
			"max_hp": info["hp"],
			"defence": 4 + info["level"],
			"wander_speed": 2.5,
			"wander_radius": 8.0,
			"respawn_time": 25.0 if info["is_boss"] else 10.0,
			"is_aggressive": info["aggr"],
			"chase_speed": 4.5,
			"attack_damage": 35 + info["level"] * 3 if info["is_boss"] else 10 + info["level"] * 2,
			"attack_cooldown": 1.2 if info["is_boss"] else 1.4,
			"is_boss": info["is_boss"]
		}
		_spawn_new_mob(info["pos"], mob_data)

func _connect_mobs_respawn() -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob:
			if not node.died.is_connected(_on_mob_died):
				node.died.connect(_on_mob_died)

func _on_mob_died(spawn_pos: Vector3, mob_info: Dictionary) -> void:
	var respawn_delay: float = mob_info.get("respawn_time", 10.0)
	await get_tree().create_timer(respawn_delay).timeout
	_spawn_new_mob(spawn_pos, mob_info)

func _spawn_new_mob(spawn_pos: Vector3, mob_info: Dictionary) -> void:
	var new_mob = MobScene.instantiate() as Mob
	new_mob.mob_name = mob_info.get("mob_name", "Poring 3D")
	new_mob.level = mob_info.get("level", 5)
	new_mob.max_hp = mob_info.get("max_hp", 150)
	new_mob.current_hp = new_mob.max_hp
	new_mob.defence = mob_info.get("defence", 2)
	new_mob.wander_speed = mob_info.get("wander_speed", 2.5)
	new_mob.wander_radius = mob_info.get("wander_radius", 8.0)
	new_mob.respawn_time = mob_info.get("respawn_time", 10.0)
	new_mob.is_aggressive = mob_info.get("is_aggressive", false)
	new_mob.chase_speed = mob_info.get("chase_speed", 4.0)
	new_mob.attack_damage = mob_info.get("attack_damage", 12)
	new_mob.attack_cooldown = mob_info.get("attack_cooldown", 1.5)
	new_mob.is_boss = mob_info.get("is_boss", false)
	new_mob.spawn_origin = spawn_pos
	new_mob.position = spawn_pos
	
	var nav_region = get_node_or_null("NavigationRegion3D")
	if nav_region:
		nav_region.add_child(new_mob)
	else:
		add_child(new_mob)
		
	new_mob.global_position = spawn_pos
	new_mob.spawn_origin = spawn_pos
	new_mob.current_hp = new_mob.max_hp
	new_mob.is_dead = false
	if new_mob.mesh_instance:
		new_mob.mesh_instance.scale = Vector3.ONE
		new_mob.mesh_instance.visible = true
	new_mob.died.connect(_on_mob_died)
	new_mob._update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position)

func _handle_mouse_click(screen_position: Vector2) -> void:
	if not camera3d or not player:
		return
		
	var space_state = get_world_3d().direct_space_state
	var ray_origin = camera3d.project_ray_origin(screen_position)
	var ray_end = ray_origin + camera3d.project_ray_normal(screen_position) * 2000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var collider = result.collider
		var clicked_mob: Mob = null
		var clicked_item: DroppedItem = null
		var clicked_npc: Node = null
		
		if collider is DroppedItem:
			clicked_item = collider
		elif collider.get_parent() is DroppedItem:
			clicked_item = collider.get_parent() as DroppedItem
		elif collider is Mob:
			clicked_mob = collider
		elif collider.get_parent() is Mob:
			clicked_mob = collider.get_parent() as Mob
		elif collider.is_in_group("npcs"):
			clicked_npc = collider
		elif collider.get_parent() and collider.get_parent().is_in_group("npcs"):
			clicked_npc = collider.get_parent()
			
		var current_time: float = Time.get_ticks_msec() / 1000.0
		
		if clicked_item and not clicked_item.is_picked_up:
			_close_hud_npc_windows()
			last_clicked_mob = null
			player.lock_item_target(clicked_item)
			_spawn_click_marker(clicked_item.global_position)
		elif clicked_npc:
			last_clicked_mob = null
			player.clear_target()
			player.set_move_target(clicked_npc.global_position)
			if clicked_npc.has_method("interact"):
				clicked_npc.interact(player)
			_spawn_click_marker(clicked_npc.global_position)
		elif clicked_mob and not clicked_mob.is_dead:
			_close_hud_npc_windows()
			var is_double_click: bool = (clicked_mob == last_clicked_mob) and ((current_time - last_click_time) <= DOUBLE_CLICK_TIME)
			
			last_click_time = current_time
			last_clicked_mob = clicked_mob
			
			player.lock_target(clicked_mob, is_double_click)
		else:
			_close_hud_npc_windows()
			last_clicked_mob = null
			player.clear_target()
			if result.has("position"):
				var click_pos: Vector3 = result.position
				player.set_move_target(click_pos)
				_spawn_click_marker(click_pos)

func _close_hud_npc_windows() -> void:
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		var hud = hud_nodes[0]
		if hud.has_method("close_npc_windows"):
			hud.close_npc_windows()

func _spawn_click_marker(pos: Vector3) -> void:
	var marker = ClickMarkerScene.instantiate() as Node3D
	add_child(marker)
	marker.global_position = Vector3(pos.x, 0.05, pos.z)
