extends CanvasLayer
class_name HUDController

@onready var main_node: Node = get_parent()

var player: Player = null
var attributes: CharacterAttributes = null

# Elementos de UI - Status do Jogador (Barras)
var status_container: PanelContainer
var lbl_player_title: Label
var bar_hp: ProgressBar
var lbl_hp: Label
var bar_sp: ProgressBar
var lbl_sp: Label
var bar_base_exp: ProgressBar
var lbl_base_exp: Label
var bar_job_exp: ProgressBar
var lbl_job_exp: Label
var btn_toggle_stats: Button
var btn_toggle_inv: Button

# Elementos de UI - Janela de Atributos
var attr_window: PanelContainer
var lbl_stat_points: Label
var stat_labels: Dictionary = {}
var stat_cost_labels: Dictionary = {}
var stat_buttons: Dictionary = {}

# Labels de Status Derivados
var lbl_derived_atk: Label
var lbl_derived_hit_flee: Label
var lbl_derived_def: Label
var lbl_derived_aspd: Label

# Elementos de UI - Janela do Inventário & Equipamentos
var inv_window: PanelContainer
var tab_btn_backpack: Button
var tab_btn_equip: Button
var backpack_container: VBoxContainer
var equip_container: VBoxContainer
var bar_weight: ProgressBar
var lbl_weight: Label
var grid_inv_slots: GridContainer
var slot_buttons: Array = []

# Slots de Equipamentos do Personagem
var equip_slot_buttons: Dictionary = {}
var selected_slot_idx: int = -1
var selected_equip_key: String = ""

# Elementos de UI - Detalhes do Item Selecionado
var item_detail_panel: PanelContainer
var lbl_item_name: Label
var lbl_item_rarity: Label
var lbl_item_type_weight: Label
var lbl_item_desc: Label
var lbl_item_stats: Label
var btn_use_item: Button
var btn_equip_item: Button
var btn_unequip_item: Button
var btn_drop_item: Button

# Elementos de UI - Tela de Morte
var death_overlay: PanelContainer

# Elementos de UI - Minimapa Radar
var minimap_panel: PanelContainer
var minimap_draw_node: Control

# Sistema de Janelas Flutuantes e Arrastáveis
var dragging_window: Control = null
var window_drag_offset: Vector2 = Vector2.ZERO

# Sistema de Arrastar e Soltar (Drag & Drop da Mochila para o Chão)
var drag_slot_idx: int = -1
var drag_start_pos: Vector2 = Vector2.ZERO
var is_dragging_item: bool = false
var drag_preview_panel: PanelContainer = null

# Elementos de UI - Moedas na Mochila (Éons e Astris)
var lbl_currency_eons: Label
var lbl_currency_astris: Label

# Elementos de UI - Loja do NPC (Shop Window)
var shop_window: PanelContainer
var shop_eons_label: Label
var current_shop_npc: Node = null

# Elementos de UI - Ferreiro (Blacksmith Window)
var blacksmith_window: PanelContainer
var blacksmith_eons_label: Label
var current_blacksmith_npc: Node = null

func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_create_ui_layout()
	_find_player_and_connect()

func _process(_delta: float) -> void:
	if minimap_draw_node and minimap_draw_node.is_visible_in_tree():
		minimap_draw_node.queue_redraw()

func _find_player_and_connect() -> void:
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as Player
		if player:
			attributes = player.attributes
			_connect_signals()
			if player.inventory:
				_on_currency_changed(player.inventory.eons, player.inventory.astris)
			return

func _connect_signals() -> void:
	if player:
		if not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
		if not player.sp_changed.is_connected(_on_player_sp_changed):
			player.sp_changed.connect(_on_player_sp_changed)
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
		if not player.player_respawned.is_connected(_on_player_respawned):
			player.player_respawned.connect(_on_player_respawned)
		if player.inventory:
			if not player.inventory.inventory_updated.is_connected(_on_inventory_updated):
				player.inventory.inventory_updated.connect(_on_inventory_updated)
			if not player.inventory.equipment_changed.is_connected(_on_equipment_changed):
				player.inventory.equipment_changed.connect(_on_equipment_changed)
			if not player.inventory.weight_changed.is_connected(_on_weight_changed):
				player.inventory.weight_changed.connect(_on_weight_changed)
			if not player.inventory.currency_changed.is_connected(_on_currency_changed):
				player.inventory.currency_changed.connect(_on_currency_changed)

	if attributes:
		if not attributes.attributes_changed.is_connected(_on_attributes_changed):
			attributes.attributes_changed.connect(_on_attributes_changed)
		if not attributes.exp_changed.is_connected(_on_exp_changed):
			attributes.exp_changed.connect(_on_exp_changed)
		if not attributes.level_up.is_connected(_on_level_up):
			attributes.level_up.connect(_on_level_up)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_toggle_attribute_window()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I or event.keycode == KEY_B:
			_toggle_inventory_window(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O:
			_toggle_inventory_window(true)
			get_viewport().set_input_as_handled()

	# Processamento de arraste de janelas flutuantes (Mochila / Atributos)
	if dragging_window and is_instance_valid(dragging_window):
		if event is InputEventMouseMotion:
			var viewport_size := get_viewport().get_visible_rect().size
			var target_pos: Vector2 = event.global_position - window_drag_offset
			target_pos.x = clamp(target_pos.x, 0.0, max(0.0, viewport_size.x - 60.0))
			target_pos.y = clamp(target_pos.y, 0.0, max(0.0, viewport_size.y - 40.0))
			dragging_window.global_position = target_pos
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging_window = null

	# Processamento de Drag & Drop do inventário
	if drag_slot_idx >= 0:
		if event is InputEventMouseMotion:
			if not is_dragging_item:
				if event.global_position.distance_to(drag_start_pos) > 6.0:
					is_dragging_item = true
					_create_drag_preview()
			if is_dragging_item and drag_preview_panel:
				drag_preview_panel.global_position = event.global_position + Vector2(10, 10)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging_item:
				_finish_drag_item(event.global_position)
				get_viewport().set_input_as_handled()
			_cancel_drag_item()

func _on_window_header_gui_input(event: InputEvent, win: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_window = win
			window_drag_offset = event.global_position - win.global_position
			win.move_to_front()
		else:
			if dragging_window == win:
				dragging_window = null

func _toggle_attribute_window() -> void:
	if attr_window:
		attr_window.visible = not attr_window.visible
		if attr_window.visible:
			attr_window.move_to_front()
			_update_attribute_window()

func _toggle_inventory_window(show_equip_tab: bool = false) -> void:
	if inv_window:
		inv_window.visible = not inv_window.visible
		if inv_window.visible:
			inv_window.move_to_front()
			if show_equip_tab:
				_switch_to_equip_tab()
			else:
				_switch_to_backpack_tab()
			_update_inventory_ui()

func _create_ui_layout() -> void:
	var root_control := Control.new()
	root_control.name = "HUDControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# --- 1. PAINEL DE BARRAS DE STATUS (Canto Superior Esquerdo) ---
	status_container = PanelContainer.new()
	status_container.set_position(Vector2(20, 20))
	status_container.custom_minimum_size = Vector2(360, 160)
	
	var sb_status := StyleBoxFlat.new()
	sb_status.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	sb_status.set_corner_radius_all(10)
	sb_status.set_border_width_all(2)
	sb_status.border_color = Color(0.25, 0.35, 0.5, 0.8)
	sb_status.content_margin_left = 12
	sb_status.content_margin_right = 12
	sb_status.content_margin_top = 10
	sb_status.content_margin_bottom = 10
	status_container.add_theme_stylebox_override("panel", sb_status)
	root_control.add_child(status_container)

	var vbox_status := VBoxContainer.new()
	vbox_status.add_theme_constant_override("separation", 6)
	status_container.add_child(vbox_status)

	var hbox_header := HBoxContainer.new()
	vbox_status.add_child(hbox_header)

	lbl_player_title = Label.new()
	lbl_player_title.text = "Aprendiz | Base Lv. 1 (Classe Lv. 1)"
	lbl_player_title.add_theme_font_size_override("font_size", 13)
	lbl_player_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	lbl_player_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(lbl_player_title)

	btn_toggle_stats = Button.new()
	btn_toggle_stats.text = " 📊 Atributos "
	btn_toggle_stats.add_theme_font_size_override("font_size", 11)
	btn_toggle_stats.pressed.connect(_toggle_attribute_window)
	hbox_header.add_child(btn_toggle_stats)

	btn_toggle_inv = Button.new()
	btn_toggle_inv.text = " 🎒 Inventário "
	btn_toggle_inv.add_theme_font_size_override("font_size", 11)
	btn_toggle_inv.pressed.connect(func(): _toggle_inventory_window(false))
	hbox_header.add_child(btn_toggle_inv)

	# --- BARRA DE HP ---
	var hp_box := HBoxContainer.new()
	vbox_status.add_child(hp_box)
	
	var lbl_hp_tag := Label.new()
	lbl_hp_tag.text = "HP "
	lbl_hp_tag.custom_minimum_size = Vector2(30, 0)
	lbl_hp_tag.add_theme_font_size_override("font_size", 12)
	lbl_hp_tag.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	hp_box.add_child(lbl_hp_tag)

	bar_hp = ProgressBar.new()
	bar_hp.custom_minimum_size = Vector2(0, 20)
	bar_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_hp.show_percentage = false
	_apply_bar_style(bar_hp, Color(0.2, 0.8, 0.3), Color(0.1, 0.2, 0.12))
	hp_box.add_child(bar_hp)

	lbl_hp = Label.new()
	lbl_hp.text = "100 / 100"
	lbl_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_hp.add_theme_font_size_override("font_size", 11)
	bar_hp.add_child(lbl_hp)

	# --- BARRA DE SP ---
	var sp_box := HBoxContainer.new()
	vbox_status.add_child(sp_box)
	
	var lbl_sp_tag := Label.new()
	lbl_sp_tag.text = "SP "
	lbl_sp_tag.custom_minimum_size = Vector2(30, 0)
	lbl_sp_tag.add_theme_font_size_override("font_size", 12)
	lbl_sp_tag.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	sp_box.add_child(lbl_sp_tag)

	bar_sp = ProgressBar.new()
	bar_sp.custom_minimum_size = Vector2(0, 18)
	bar_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_sp.show_percentage = false
	_apply_bar_style(bar_sp, Color(0.15, 0.55, 0.95), Color(0.08, 0.15, 0.25))
	sp_box.add_child(bar_sp)

	lbl_sp = Label.new()
	lbl_sp.text = "50 / 50"
	lbl_sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_sp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sp.add_theme_font_size_override("font_size", 11)
	bar_sp.add_child(lbl_sp)

	# --- BARRA DE BASE EXP ---
	var base_exp_box := HBoxContainer.new()
	vbox_status.add_child(base_exp_box)
	
	var lbl_bexp_tag := Label.new()
	lbl_bexp_tag.text = "BASE"
	lbl_bexp_tag.custom_minimum_size = Vector2(35, 0)
	lbl_bexp_tag.add_theme_font_size_override("font_size", 10)
	lbl_bexp_tag.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	base_exp_box.add_child(lbl_bexp_tag)

	bar_base_exp = ProgressBar.new()
	bar_base_exp.custom_minimum_size = Vector2(0, 14)
	bar_base_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_base_exp.show_percentage = false
	_apply_bar_style(bar_base_exp, Color(0.9, 0.75, 0.15), Color(0.2, 0.18, 0.05))
	base_exp_box.add_child(bar_base_exp)

	lbl_base_exp = Label.new()
	lbl_base_exp.text = "0 / 100 (0.0%)"
	lbl_base_exp.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_base_exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_base_exp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_base_exp.add_theme_font_size_override("font_size", 9)
	bar_base_exp.add_child(lbl_base_exp)

	# --- BARRA DE JOB EXP ---
	var job_exp_box := HBoxContainer.new()
	vbox_status.add_child(job_exp_box)
	
	var lbl_jexp_tag := Label.new()
	lbl_jexp_tag.text = "JOB "
	lbl_jexp_tag.custom_minimum_size = Vector2(35, 0)
	lbl_jexp_tag.add_theme_font_size_override("font_size", 10)
	lbl_jexp_tag.add_theme_color_override("font_color", Color(0.8, 0.4, 0.95))
	job_exp_box.add_child(lbl_jexp_tag)

	bar_job_exp = ProgressBar.new()
	bar_job_exp.custom_minimum_size = Vector2(0, 14)
	bar_job_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_job_exp.show_percentage = false
	_apply_bar_style(bar_job_exp, Color(0.7, 0.3, 0.85), Color(0.18, 0.08, 0.22))
	job_exp_box.add_child(bar_job_exp)

	lbl_job_exp = Label.new()
	lbl_job_exp.text = "0 / 80 (0.0%)"
	lbl_job_exp.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_job_exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_job_exp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_job_exp.add_theme_font_size_override("font_size", 9)
	bar_job_exp.add_child(lbl_job_exp)

	# --- 2. MINIMAPA RADAR (Canto Superior Direito) ---
	_build_minimap(root_control)

	# --- 3. JANELA DE ATRIBUTOS ---
	_build_attribute_window(root_control)

	# --- 4. JANELA DO INVENTÁRIO & EQUIPAMENTOS ---
	_build_inventory_window(root_control)

	# --- 5. JANELA DA LOJA NPC ---
	_build_shop_window(root_control)

	# --- 6. JANELA DO FERREIRO (REPAROS) ---
	_build_blacksmith_window(root_control)

	# --- 7. OVERLAY TELA DE MORTE ---
	_build_death_overlay(root_control)

func _build_minimap(root_control: Control) -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.offset_left = -185
	minimap_panel.offset_top = 20
	minimap_panel.offset_right = -20
	minimap_panel.offset_bottom = 205
	minimap_panel.custom_minimum_size = Vector2(165, 185)
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var sb_map := StyleBoxFlat.new()
	sb_map.bg_color = Color(0.05, 0.07, 0.11, 0.9)
	sb_map.set_corner_radius_all(10)
	sb_map.set_border_width_all(2)
	sb_map.border_color = Color(0.25, 0.45, 0.75, 0.85)
	sb_map.content_margin_left = 8
	sb_map.content_margin_right = 8
	sb_map.content_margin_top = 6
	sb_map.content_margin_bottom = 8
	minimap_panel.add_theme_stylebox_override("panel", sb_map)
	root_control.add_child(minimap_panel)

	var vbox_map := VBoxContainer.new()
	vbox_map.add_theme_constant_override("separation", 4)
	minimap_panel.add_child(vbox_map)

	var lbl_map_title := Label.new()
	lbl_map_title.text = "🗺️ Campo Prontera"
	lbl_map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_map_title.add_theme_font_size_override("font_size", 11)
	lbl_map_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox_map.add_child(lbl_map_title)

	minimap_draw_node = Control.new()
	minimap_draw_node.custom_minimum_size = Vector2(148, 148)
	minimap_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_draw_node.draw.connect(_on_minimap_draw)
	vbox_map.add_child(minimap_draw_node)

func _on_minimap_draw() -> void:
	if not minimap_draw_node:
		return

	var size := Vector2(148, 148)
	var center := size * 0.5
	var map_radius: float = 68.0

	# 1. Fundo do radar com grade
	minimap_draw_node.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.07, 0.8), true)
	minimap_draw_node.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.35, 0.5, 0.6), false, 1.5)

	# 2. Linhas de cruz do radar N/S/E/W
	minimap_draw_node.draw_line(Vector2(center.x, 4), Vector2(center.x, size.y - 4), Color(0.25, 0.35, 0.5, 0.3), 1.0)
	minimap_draw_node.draw_line(Vector2(4, center.y), Vector2(size.x - 4, center.y), Color(0.25, 0.35, 0.5, 0.3), 1.0)

	# Limite do plano 3D do mapa expandido (tamanho do chão 120m x 120m, raio de 60m)
	var world_half_size: float = 60.0

	# 3. Desenhar Itens no Chão (Pontos Amarelos/Coloridos)
	var items = get_tree().get_nodes_in_group("dropped_items")
	for node in items:
		var dropped_item = node as DroppedItem
		if dropped_item and is_instance_valid(dropped_item) and not dropped_item.is_picked_up:
			var pos_3d: Vector3 = dropped_item.global_position
			var nx: float = clamp(pos_3d.x / world_half_size, -1.0, 1.0)
			var nz: float = clamp(pos_3d.z / world_half_size, -1.0, 1.0)
			var dot_pos: Vector2 = center + Vector2(nx * map_radius, nz * map_radius)
			
			var item_color: Color = dropped_item.item_data.get_rarity_color() if dropped_item.item_data else Color(0.95, 0.85, 0.2)
			minimap_draw_node.draw_circle(dot_pos, 2.5, item_color)

	# 4. Desenhar Mobs Vivos (Pontos Vermelhos)
	var mobs = get_tree().get_nodes_in_group("mobs")
	for node in mobs:
		var mob = node as Mob
		if mob and is_instance_valid(mob) and not mob.is_dead:
			var pos_3d: Vector3 = mob.global_position
			var nx: float = clamp(pos_3d.x / world_half_size, -1.0, 1.0)
			var nz: float = clamp(pos_3d.z / world_half_size, -1.0, 1.0)
			var dot_pos: Vector2 = center + Vector2(nx * map_radius, nz * map_radius)
			
			# Brilho externo suave
			minimap_draw_node.draw_circle(dot_pos, 5.0, Color(1.0, 0.2, 0.2, 0.35))
			# Ponto central vermelho
			minimap_draw_node.draw_circle(dot_pos, 3.2, Color(0.95, 0.2, 0.2))

	# 5. Desenhar o Jogador (Ponto Verde)
	if player and is_instance_valid(player) and not player.is_dead:
		var pos_3d: Vector3 = player.global_position
		var nx: float = clamp(pos_3d.x / world_half_size, -1.0, 1.0)
		var nz: float = clamp(pos_3d.z / world_half_size, -1.0, 1.0)
		var dot_pos: Vector2 = center + Vector2(nx * map_radius, nz * map_radius)
		
		# Anéis de pulso brilhantes do jogador
		minimap_draw_node.draw_circle(dot_pos, 7.5, Color(0.2, 0.95, 0.4, 0.35))
		minimap_draw_node.draw_circle(dot_pos, 4.5, Color(0.2, 0.95, 0.4))

func _build_attribute_window(root_control: Control) -> void:
	attr_window = PanelContainer.new()
	attr_window.visible = false
	attr_window.set_position(Vector2(20, 200))
	attr_window.custom_minimum_size = Vector2(360, 360)

	var sb_attr := StyleBoxFlat.new()
	sb_attr.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sb_attr.set_corner_radius_all(10)
	sb_attr.set_border_width_all(2)
	sb_attr.border_color = Color(0.85, 0.7, 0.2, 0.9)
	sb_attr.content_margin_left = 14
	sb_attr.content_margin_right = 14
	sb_attr.content_margin_top = 12
	sb_attr.content_margin_bottom = 12
	attr_window.add_theme_stylebox_override("panel", sb_attr)
	attr_window.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, attr_window))
	root_control.add_child(attr_window)

	var vbox_attr := VBoxContainer.new()
	vbox_attr.add_theme_constant_override("separation", 8)
	attr_window.add_child(vbox_attr)

	var hbox_attr_head := HBoxContainer.new()
	hbox_attr_head.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, attr_window))
	vbox_attr.add_child(hbox_attr_head)

	var lbl_attr_title := Label.new()
	lbl_attr_title.text = "⚙️ Atributos do Personagem"
	lbl_attr_title.add_theme_font_size_override("font_size", 15)
	lbl_attr_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	lbl_attr_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_attr_head.add_child(lbl_attr_title)

	var btn_close := Button.new()
	btn_close.text = " X "
	btn_close.pressed.connect(func(): attr_window.visible = false)
	hbox_attr_head.add_child(btn_close)

	lbl_stat_points = Label.new()
	lbl_stat_points.text = "Pontos Disponíveis: 48"
	lbl_stat_points.add_theme_font_size_override("font_size", 13)
	lbl_stat_points.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vbox_attr.add_child(lbl_stat_points)

	var hs1 := HSeparator.new()
	vbox_attr.add_child(hs1)

	var grid_stats := GridContainer.new()
	grid_stats.columns = 4
	grid_stats.add_theme_constant_override("h_separation", 10)
	grid_stats.add_theme_constant_override("v_separation", 6)
	vbox_attr.add_child(grid_stats)

	var stats_data = [
		{"code": "str", "name": "FOR (STR)", "desc": "Ataque Físico & Carga"},
		{"code": "agi", "name": "AGI (AGI)", "desc": "ASPD & Esquiva"},
		{"code": "vit", "name": "VIT (VIT)", "desc": "HP & Defesa"},
		{"code": "int_stat", "name": "INT (INT)", "desc": "Ataque Mágico & SP"},
		{"code": "dex", "name": "DES (DEX)", "desc": "Precisão & ASPD Sec."},
		{"code": "luk", "name": "SOR (LUK)", "desc": "Crítico & ATK"}
	]

	for sdata in stats_data:
		var code: String = sdata["code"]
		var lbl_name := Label.new()
		lbl_name.text = sdata["name"]
		lbl_name.tooltip_text = sdata["desc"]
		lbl_name.custom_minimum_size = Vector2(90, 0)
		lbl_name.add_theme_font_size_override("font_size", 12)
		grid_stats.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = "1"
		lbl_val.custom_minimum_size = Vector2(30, 0)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.add_theme_font_size_override("font_size", 12)
		lbl_val.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		grid_stats.add_child(lbl_val)
		stat_labels[code] = lbl_val

		var lbl_cost := Label.new()
		lbl_cost.text = "(2 pts)"
		lbl_cost.custom_minimum_size = Vector2(50, 0)
		lbl_cost.add_theme_font_size_override("font_size", 10)
		lbl_cost.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		grid_stats.add_child(lbl_cost)
		stat_cost_labels[code] = lbl_cost

		var btn_plus := Button.new()
		btn_plus.text = " + "
		btn_plus.custom_minimum_size = Vector2(28, 24)
		btn_plus.pressed.connect(func(): _on_stat_increase_pressed(code))
		grid_stats.add_child(btn_plus)
		stat_buttons[code] = btn_plus

	var hs2 := HSeparator.new()
	vbox_attr.add_child(hs2)

	var lbl_der_title := Label.new()
	lbl_der_title.text = "📈 Status Calculados"
	lbl_der_title.add_theme_font_size_override("font_size", 12)
	lbl_der_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vbox_attr.add_child(lbl_der_title)

	lbl_derived_atk = Label.new()
	lbl_derived_atk.add_theme_font_size_override("font_size", 11)
	vbox_attr.add_child(lbl_derived_atk)

	lbl_derived_hit_flee = Label.new()
	lbl_derived_hit_flee.add_theme_font_size_override("font_size", 11)
	vbox_attr.add_child(lbl_derived_hit_flee)

	lbl_derived_def = Label.new()
	lbl_derived_def.add_theme_font_size_override("font_size", 11)
	vbox_attr.add_child(lbl_derived_def)

	lbl_derived_aspd = Label.new()
	lbl_derived_aspd.add_theme_font_size_override("font_size", 11)
	vbox_attr.add_child(lbl_derived_aspd)

func _build_inventory_window(root_control: Control) -> void:
	inv_window = PanelContainer.new()
	inv_window.visible = false
	inv_window.custom_minimum_size = Vector2(410, 500)
	
	# Posicionamento flutuante inicial centralizado/à direita sem estourar a tela
	var vp_size := get_viewport().get_visible_rect().size
	var init_x: float = max(20.0, vp_size.x - 445.0)
	var init_y: float = clamp(80.0, 20.0, max(20.0, vp_size.y - 520.0))
	inv_window.position = Vector2(init_x, init_y)

	var sb_inv := StyleBoxFlat.new()
	sb_inv.bg_color = Color(0.07, 0.09, 0.13, 0.95)
	sb_inv.set_corner_radius_all(10)
	sb_inv.set_border_width_all(2)
	sb_inv.border_color = Color(0.3, 0.6, 0.9, 0.9)
	sb_inv.content_margin_left = 14
	sb_inv.content_margin_right = 14
	sb_inv.content_margin_top = 12
	sb_inv.content_margin_bottom = 12
	inv_window.add_theme_stylebox_override("panel", sb_inv)
	inv_window.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, inv_window))
	root_control.add_child(inv_window)

	var vbox_main := VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 8)
	inv_window.add_child(vbox_main)

	# --- NAVEGAÇÃO POR ABAS (Mochila / Equipamentos) ---
	var hbox_tabs := HBoxContainer.new()
	hbox_tabs.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, inv_window))
	vbox_main.add_child(hbox_tabs)

	tab_btn_backpack = Button.new()
	tab_btn_backpack.text = " 🎒 Mochila (I) "
	tab_btn_backpack.add_theme_font_size_override("font_size", 12)
	tab_btn_backpack.pressed.connect(_switch_to_backpack_tab)
	hbox_tabs.add_child(tab_btn_backpack)

	tab_btn_equip = Button.new()
	tab_btn_equip.text = " 🛡️ Equipamentos (O) "
	tab_btn_equip.add_theme_font_size_override("font_size", 12)
	tab_btn_equip.pressed.connect(_switch_to_equip_tab)
	hbox_tabs.add_child(tab_btn_equip)

	var btn_close_inv := Button.new()
	btn_close_inv.text = " X "
	btn_close_inv.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_close_inv.pressed.connect(func(): inv_window.visible = false)
	hbox_tabs.add_child(btn_close_inv)

	# --- CONTÊINER 1: MOCHILA ---
	backpack_container = VBoxContainer.new()
	backpack_container.add_theme_constant_override("separation", 6)
	vbox_main.add_child(backpack_container)

	# --- BARRAS DE MOEDAS (Éons e Astris) ---
	var hbox_currencies := HBoxContainer.new()
	hbox_currencies.add_theme_constant_override("separation", 10)
	backpack_container.add_child(hbox_currencies)

	# Éons (Ouro in-game)
	var p_eons := PanelContainer.new()
	p_eons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_eons := StyleBoxFlat.new()
	sb_eons.bg_color = Color(0.12, 0.1, 0.04, 0.9)
	sb_eons.set_corner_radius_all(6)
	sb_eons.set_border_width_all(1)
	sb_eons.border_color = Color(0.9, 0.75, 0.2, 0.8)
	sb_eons.content_margin_left = 8
	sb_eons.content_margin_right = 8
	sb_eons.content_margin_top = 4
	sb_eons.content_margin_bottom = 4
	p_eons.add_theme_stylebox_override("panel", sb_eons)
	hbox_currencies.add_child(p_eons)

	lbl_currency_eons = Label.new()
	lbl_currency_eons.text = "🪙 E: 500 Éons"
	lbl_currency_eons.add_theme_font_size_override("font_size", 11)
	lbl_currency_eons.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	p_eons.add_child(lbl_currency_eons)

	# Astris (Cash)
	var p_astris := PanelContainer.new()
	p_astris.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_astris := StyleBoxFlat.new()
	sb_astris.bg_color = Color(0.04, 0.1, 0.14, 0.9)
	sb_astris.set_corner_radius_all(6)
	sb_astris.set_border_width_all(1)
	sb_astris.border_color = Color(0.2, 0.8, 1.0, 0.8)
	sb_astris.content_margin_left = 8
	sb_astris.content_margin_right = 8
	sb_astris.content_margin_top = 4
	sb_astris.content_margin_bottom = 4
	p_astris.add_theme_stylebox_override("panel", sb_astris)
	hbox_currencies.add_child(p_astris)

	lbl_currency_astris = Label.new()
	lbl_currency_astris.text = "💎 A: 50 Astris"
	lbl_currency_astris.add_theme_font_size_override("font_size", 11)
	lbl_currency_astris.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	p_astris.add_child(lbl_currency_astris)

	# Barra de Capacidade de Peso
	var weight_box := HBoxContainer.new()
	backpack_container.add_child(weight_box)

	var lbl_w_tag := Label.new()
	lbl_w_tag.text = "PESO "
	lbl_w_tag.add_theme_font_size_override("font_size", 11)
	lbl_w_tag.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	weight_box.add_child(lbl_w_tag)

	bar_weight = ProgressBar.new()
	bar_weight.custom_minimum_size = Vector2(0, 18)
	bar_weight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_weight.show_percentage = false
	_apply_bar_style(bar_weight, Color(0.2, 0.75, 0.4), Color(0.1, 0.15, 0.2))
	weight_box.add_child(bar_weight)

	lbl_weight = Label.new()
	lbl_weight.text = "Peso: 0.0 / 2030.0 kg (0.0%)"
	lbl_weight.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_weight.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_weight.add_theme_font_size_override("font_size", 10)
	bar_weight.add_child(lbl_weight)

	var hs_inv1 := HSeparator.new()
	backpack_container.add_child(hs_inv1)

	# Grade de 35 Slots do Inventário
	grid_inv_slots = GridContainer.new()
	grid_inv_slots.columns = 5
	grid_inv_slots.add_theme_constant_override("h_separation", 6)
	grid_inv_slots.add_theme_constant_override("v_separation", 6)
	backpack_container.add_child(grid_inv_slots)

	slot_buttons.clear()
	for i in range(35):
		var btn_slot := Button.new()
		btn_slot.custom_minimum_size = Vector2(68, 42)
		btn_slot.clip_text = false

		var idx: int = i
		btn_slot.pressed.connect(func(): _on_slot_clicked(idx))
		btn_slot.gui_input.connect(func(ev: InputEvent): _on_slot_gui_input(ev, idx))
		grid_inv_slots.add_child(btn_slot)
		slot_buttons.append(btn_slot)

	# --- CONTÊINER 2: ABA DE EQUIPAMENTOS DO PERSONAGEM (Paper Doll Layout) ---
	equip_container = VBoxContainer.new()
	equip_container.visible = false
	equip_container.add_theme_constant_override("separation", 8)
	vbox_main.add_child(equip_container)

	var lbl_eq_title := Label.new()
	lbl_eq_title.text = "🛡️ Equipamentos Ativos do Personagem"
	lbl_eq_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eq_title.add_theme_font_size_override("font_size", 13)
	lbl_eq_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	equip_container.add_child(lbl_eq_title)

	var grid_doll := GridContainer.new()
	grid_doll.columns = 3
	grid_doll.add_theme_constant_override("h_separation", 10)
	grid_doll.add_theme_constant_override("v_separation", 8)
	equip_container.add_child(grid_doll)

	# Mapeamento visual das 3 colunas do Paper Doll
	# Coluna Esquerda: Arma, Armadura, Calça, Botas
	# Coluna Meio: Capacete, Colar, Asas, Pet
	# Coluna Direita: Escudo, Luvas, Anel 1, Anel 2, Brinco
	var doll_slots_layout = [
		{"key": "weapon", "name": "⚔️ Arma"},
		{"key": "helmet", "name": "🪖 Capacete"},
		{"key": "shield", "name": "🛡️ Escudo"},
		
		{"key": "armor", "name": "👕 Armadura"},
		{"key": "necklace", "name": "📿 Colar"},
		{"key": "gloves", "name": "🧤 Luvas"},
		
		{"key": "pants", "name": "👖 Calça"},
		{"key": "wings", "name": "🪽 Asas"},
		{"key": "ring_1", "name": "💍 Anel 1"},
		
		{"key": "boots", "name": "🥾 Botas"},
		{"key": "pet", "name": "🐾 Pet"},
		{"key": "ring_2", "name": "💍 Anel 2"}
	]

	equip_slot_buttons.clear()
	for slot_info in doll_slots_layout:
		var eq_key: String = slot_info["key"]
		var btn_eq := Button.new()
		btn_eq.custom_minimum_size = Vector2(118, 56)
		btn_eq.text = slot_info["name"]
		btn_eq.add_theme_font_size_override("font_size", 11)
		
		btn_eq.pressed.connect(func(): _on_equip_slot_clicked(eq_key))
		btn_eq.gui_input.connect(func(ev: InputEvent): _on_equip_slot_gui_input(ev, eq_key))
		grid_doll.add_child(btn_eq)
		equip_slot_buttons[eq_key] = btn_eq

	# Adicionar o 13º slot (Brinco) centralizado na parte inferior
	var hbox_earring := HBoxContainer.new()
	hbox_earring.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_container.add_child(hbox_earring)

	var btn_earring := Button.new()
	btn_earring.custom_minimum_size = Vector2(130, 48)
	btn_earring.text = "👂 Brinco"
	btn_earring.add_theme_font_size_override("font_size", 11)
	btn_earring.pressed.connect(func(): _on_equip_slot_clicked("earring"))
	btn_earring.gui_input.connect(func(ev: InputEvent): _on_equip_slot_gui_input(ev, "earring"))
	hbox_earring.add_child(btn_earring)
	equip_slot_buttons["earring"] = btn_earring

	var hs_main := HSeparator.new()
	vbox_main.add_child(hs_main)

	# --- PAINEL DE DETALHES DO ITEM SELECIONADO (INSPETOR) ---
	item_detail_panel = PanelContainer.new()
	item_detail_panel.custom_minimum_size = Vector2(0, 140)
	
	var sb_det := StyleBoxFlat.new()
	sb_det.bg_color = Color(0.04, 0.06, 0.09, 0.9)
	sb_det.set_corner_radius_all(6)
	sb_det.set_border_width_all(1)
	sb_det.border_color = Color(0.3, 0.4, 0.5, 0.6)
	sb_det.content_margin_left = 10
	sb_det.content_margin_right = 10
	sb_det.content_margin_top = 8
	sb_det.content_margin_bottom = 8
	item_detail_panel.add_theme_stylebox_override("panel", sb_det)
	vbox_main.add_child(item_detail_panel)

	var vbox_det := VBoxContainer.new()
	vbox_det.add_theme_constant_override("separation", 3)
	item_detail_panel.add_child(vbox_det)

	lbl_item_name = Label.new()
	lbl_item_name.text = "Selecione um item..."
	lbl_item_name.add_theme_font_size_override("font_size", 14)
	vbox_det.add_child(lbl_item_name)

	lbl_item_rarity = Label.new()
	lbl_item_rarity.text = "Raridade: -"
	lbl_item_rarity.add_theme_font_size_override("font_size", 11)
	vbox_det.add_child(lbl_item_rarity)

	lbl_item_type_weight = Label.new()
	lbl_item_type_weight.text = "Tipo: - | Peso: 0 kg"
	lbl_item_type_weight.add_theme_font_size_override("font_size", 10)
	lbl_item_type_weight.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	vbox_det.add_child(lbl_item_type_weight)

	lbl_item_desc = Label.new()
	lbl_item_desc.text = "Clique em um slot da mochila ou equipamento para examinar."
	lbl_item_desc.add_theme_font_size_override("font_size", 10)
	lbl_item_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl_item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_det.add_child(lbl_item_desc)

	lbl_item_stats = Label.new()
	lbl_item_stats.text = ""
	lbl_item_stats.add_theme_font_size_override("font_size", 10)
	lbl_item_stats.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vbox_det.add_child(lbl_item_stats)

	var hbox_item_btns := HBoxContainer.new()
	vbox_det.add_child(hbox_item_btns)

	btn_equip_item = Button.new()
	btn_equip_item.text = " 🛡️ Equipar "
	btn_equip_item.add_theme_font_size_override("font_size", 11)
	btn_equip_item.pressed.connect(_on_equip_item_pressed)
	btn_equip_item.disabled = true
	hbox_item_btns.add_child(btn_equip_item)

	btn_unequip_item = Button.new()
	btn_unequip_item.text = " ↩️ Desequipar "
	btn_unequip_item.add_theme_font_size_override("font_size", 11)
	btn_unequip_item.pressed.connect(_on_unequip_item_pressed)
	btn_unequip_item.disabled = true
	hbox_item_btns.add_child(btn_unequip_item)

	btn_use_item = Button.new()
	btn_use_item.text = " 🍷 Usar "
	btn_use_item.add_theme_font_size_override("font_size", 11)
	btn_use_item.pressed.connect(_on_use_item_pressed)
	btn_use_item.disabled = true
	hbox_item_btns.add_child(btn_use_item)

	btn_drop_item = Button.new()
	btn_drop_item.text = " 🗑️ Descartar "
	btn_drop_item.add_theme_font_size_override("font_size", 11)
	btn_drop_item.pressed.connect(_on_drop_item_pressed)
	btn_drop_item.disabled = true
	hbox_item_btns.add_child(btn_drop_item)

func _switch_to_backpack_tab() -> void:
	if backpack_container and equip_container:
		backpack_container.visible = true
		equip_container.visible = false
		tab_btn_backpack.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		tab_btn_equip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _switch_to_equip_tab() -> void:
	if backpack_container and equip_container:
		backpack_container.visible = false
		equip_container.visible = true
		tab_btn_equip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		tab_btn_backpack.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _build_death_overlay(root_control: Control) -> void:
	death_overlay = PanelContainer.new()
	death_overlay.visible = false
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var sb_death := StyleBoxFlat.new()
	sb_death.bg_color = Color(0.1, 0.02, 0.02, 0.88)
	death_overlay.add_theme_stylebox_override("panel", sb_death)
	root_control.add_child(death_overlay)

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.add_child(center_box)

	var vbox_death := VBoxContainer.new()
	vbox_death.add_theme_constant_override("separation", 14)
	vbox_death.custom_minimum_size = Vector2(360, 0)
	center_box.add_child(vbox_death)

	var lbl_skull := Label.new()
	lbl_skull.text = "☠️ VOCÊ MORREU!"
	lbl_skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_skull.add_theme_font_size_override("font_size", 28)
	lbl_skull.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	vbox_death.add_child(lbl_skull)

	var lbl_death_msg := Label.new()
	lbl_death_msg.text = "Seu HP chegou a 0.\nVocê foi derrotado em combate!"
	lbl_death_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_death_msg.add_theme_font_size_override("font_size", 14)
	lbl_death_msg.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	vbox_death.add_child(lbl_death_msg)

	var btn_respawn := Button.new()
	btn_respawn.text = " 🔄 Renascer no Início do Mapa "
	btn_respawn.custom_minimum_size = Vector2(0, 44)
	btn_respawn.add_theme_font_size_override("font_size", 15)
	btn_respawn.pressed.connect(_on_respawn_button_pressed)
	vbox_death.add_child(btn_respawn)

func _apply_bar_style(pbar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = bg_color
	sb_bg.set_corner_radius_all(4)
	pbar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.set_corner_radius_all(4)
	pbar.add_theme_stylebox_override("fill", sb_fill)

func _on_stat_increase_pressed(stat_code: String) -> void:
	if attributes:
		attributes.add_stat_point(stat_code)

func _on_player_hp_changed(current: int, max_val: int) -> void:
	if bar_hp and lbl_hp:
		bar_hp.max_value = max_val
		bar_hp.value = current
		lbl_hp.text = "HP: %d / %d" % [current, max_val]

func _on_player_sp_changed(current: int, max_val: int) -> void:
	if bar_sp and lbl_sp:
		bar_sp.max_value = max_val
		bar_sp.value = current
		lbl_sp.text = "SP: %d / %d" % [current, max_val]

func _on_exp_changed(current_base: int, max_base: int, current_job: int, max_job: int) -> void:
	if bar_base_exp and lbl_base_exp:
		bar_base_exp.max_value = max_base
		bar_base_exp.value = current_base
		var pct_base: float = (float(current_base) / float(max_base)) * 100.0 if max_base > 0 else 0.0
		lbl_base_exp.text = "BASE EXP: %d / %d (%.1f%%)" % [current_base, max_base, pct_base]

	if bar_job_exp and lbl_job_exp:
		bar_job_exp.max_value = max_job
		bar_job_exp.value = current_job
		var pct_job: float = (float(current_job) / float(max_job)) * 100.0 if max_job > 0 else 0.0
		lbl_job_exp.text = "JOB EXP: %d / %d (%.1f%%)" % [current_job, max_job, pct_job]

func _on_inventory_updated() -> void:
	_update_inventory_ui()

func _on_equipment_changed() -> void:
	_update_inventory_ui()
	_update_attribute_window()

func _on_weight_changed(cur_w: float, max_w: float) -> void:
	if bar_weight and lbl_weight:
		bar_weight.max_value = max_w
		bar_weight.value = cur_w
		var pct := (cur_w / max_w) * 100.0 if max_w > 0 else 0.0
		lbl_weight.text = "Peso: %.1f / %.1f kg (%.1f%%)" % [cur_w, max_w, pct]
		
		if pct >= 90.0:
			_apply_bar_style(bar_weight, Color(0.9, 0.2, 0.2), Color(0.2, 0.05, 0.05))
		elif pct >= 50.0:
			_apply_bar_style(bar_weight, Color(0.9, 0.7, 0.2), Color(0.2, 0.15, 0.05))
		else:
			_apply_bar_style(bar_weight, Color(0.2, 0.75, 0.4), Color(0.1, 0.15, 0.2))

func _on_level_up(new_lvl: int) -> void:
	_update_all_ui()
	if btn_toggle_stats:
		btn_toggle_stats.text = " 🌟 Atributos! "

func _on_attributes_changed() -> void:
	_update_all_ui()

func _on_player_died() -> void:
	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(death_overlay, "modulate:a", 1.0, 0.35)

func _on_player_respawned() -> void:
	if death_overlay:
		death_overlay.visible = false

func _on_respawn_button_pressed() -> void:
	if player:
		player.respawn()

func _update_all_ui() -> void:
	if not attributes or not player:
		return

	lbl_player_title.text = "Aprendiz | Base Lv. %d (Classe Lv. %d)" % [attributes.base_level, attributes.job_level]
	
	_on_player_hp_changed(player.current_hp, attributes.max_hp)
	_on_player_sp_changed(player.current_sp, attributes.max_sp)
	_on_exp_changed(attributes.current_base_exp, attributes.max_base_exp, attributes.current_job_exp, attributes.max_job_exp)
	_update_attribute_window()
	_update_inventory_ui()

func _update_attribute_window() -> void:
	if not attributes:
		return

	var pts: int = attributes.stat_points
	lbl_stat_points.text = "Pontos Disponíveis: %d" % pts
	if pts > 0:
		lbl_stat_points.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if btn_toggle_stats:
			btn_toggle_stats.text = " 🌟 Atributos (%d) " % pts
	else:
		lbl_stat_points.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		if btn_toggle_stats:
			btn_toggle_stats.text = " 📊 Atributos "

	var stat_codes = ["str", "agi", "vit", "int_stat", "dex", "luk"]
	for code in stat_codes:
		var val: int = attributes.get(code)
		var cost: int = attributes.get_stat_upgrade_cost(val)
		
		if stat_labels.has(code):
			stat_labels[code].text = str(val)
		if stat_cost_labels.has(code):
			stat_cost_labels[code].text = "(%d pts)" % cost
		if stat_buttons.has(code):
			var can_buy: bool = (val < 99) and (pts >= cost)
			stat_buttons[code].disabled = not can_buy

	if lbl_derived_atk:
		lbl_derived_atk.text = "ATK: %d | MATK: %d" % [attributes.atk, attributes.matk]
	if lbl_derived_hit_flee:
		lbl_derived_hit_flee.text = "Precisão (HIT): %d | Esquiva (FLEE): %d | Crítico: %.1f%%" % [attributes.hit, attributes.flee, attributes.crit]
	if lbl_derived_def:
		lbl_derived_def.text = "DEF: %d + %d (Soft DEF)" % [attributes.hard_def, attributes.soft_def]
	if lbl_derived_aspd:
		lbl_derived_aspd.text = "ASPD: %.1f (%.2f ataques/segundo)" % [attributes.aspd, attributes.get_attack_frequency()]

func _update_inventory_ui() -> void:
	if not player or not player.inventory:
		return

	var inv: InventoryManager = player.inventory
	_on_weight_changed(inv.get_current_weight(), inv.get_max_weight())

	# Atualizar Slots da Mochila
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		var slot = inv.slots[i]

		if slot != null and slot.get("item") is ItemData:
			var item: ItemData = slot["item"]
			var qty: int = slot.get("quantity", 1)
			
			var qty_str: String = " x%d" % qty if qty > 1 else ""
			btn.text = "%s%s" % [item.name, qty_str]
			
			var r_color := item.get_rarity_color()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
			sb.set_corner_radius_all(6)
			sb.set_border_width_all(2)
			sb.border_color = r_color
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_color_override("font_color", r_color)
			btn.add_theme_font_size_override("font_size", 10)
		else:
			btn.text = "Vazio"
			var sb_empty := StyleBoxFlat.new()
			sb_empty.bg_color = Color(0.05, 0.06, 0.08, 0.6)
			sb_empty.set_corner_radius_all(6)
			sb_empty.set_border_width_all(1)
			sb_empty.border_color = Color(0.2, 0.25, 0.3, 0.4)
			btn.add_theme_stylebox_override("normal", sb_empty)
			btn.add_theme_stylebox_override("hover", sb_empty)
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			btn.add_theme_font_size_override("font_size", 9)

	# Atualizar Slots de Equipamentos do Personagem
	var slot_labels_map = {
		"weapon": "⚔️ Arma", "shield": "🛡️ Escudo", "helmet": "🪖 Capacete",
		"armor": "👕 Armadura", "pants": "👖 Calça", "boots": "🥾 Botas",
		"gloves": "🧤 Luvas", "ring_1": "💍 Anel 1", "ring_2": "💍 Anel 2",
		"earring": "👂 Brinco", "necklace": "📿 Colar", "wings": "🪽 Asas", "pet": "🐾 Pet"
	}

	for eq_key in equip_slot_buttons.keys():
		var btn_eq: Button = equip_slot_buttons[eq_key]
		var item: ItemData = inv.equipped_items.get(eq_key)
		var label_default: String = slot_labels_map.get(eq_key, eq_key)

		if item:
			btn_eq.text = "%s\n%s" % [label_default, item.name]
			var r_color := item.get_rarity_color()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.12, 0.15, 0.22, 0.95)
			sb.set_corner_radius_all(6)
			sb.set_border_width_all(2)
			sb.border_color = r_color
			btn_eq.add_theme_stylebox_override("normal", sb)
			btn_eq.add_theme_stylebox_override("hover", sb)
			btn_eq.add_theme_color_override("font_color", r_color)
		else:
			btn_eq.text = "%s\n(Vazio)" % label_default
			var sb_empty := StyleBoxFlat.new()
			sb_empty.bg_color = Color(0.06, 0.08, 0.1, 0.7)
			sb_empty.set_corner_radius_all(6)
			sb_empty.set_border_width_all(1)
			sb_empty.border_color = Color(0.25, 0.3, 0.4, 0.5)
			btn_eq.add_theme_stylebox_override("normal", sb_empty)
			btn_eq.add_theme_stylebox_override("hover", sb_empty)
			btn_eq.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	_update_item_inspector()

func _on_slot_clicked(slot_idx: int) -> void:
	selected_slot_idx = slot_idx
	selected_equip_key = ""
	_update_item_inspector()

func _on_equip_slot_clicked(eq_key: String) -> void:
	selected_equip_key = eq_key
	selected_slot_idx = -1
	_update_item_inspector()

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if player and player.inventory:
					var slot = player.inventory.slots[slot_idx]
					if slot != null and slot.get("item") is ItemData:
						drag_slot_idx = slot_idx
						drag_start_pos = event.global_position
						is_dragging_item = false
			else:
				if is_dragging_item:
					_finish_drag_item(event.global_position)
				elif drag_slot_idx == slot_idx:
					_on_slot_clicked(slot_idx)
				_cancel_drag_item()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_slot_right_clicked(slot_idx)

func _create_drag_preview() -> void:
	_cancel_drag_preview_node()
	if not player or not player.inventory or drag_slot_idx < 0:
		return
	var slot = player.inventory.slots[drag_slot_idx]
	if slot == null or not (slot.get("item") is ItemData):
		return

	var item: ItemData = slot["item"]
	var qty: int = slot.get("quantity", 1)

	drag_preview_panel = PanelContainer.new()
	drag_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview_panel.z_index = 100
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = item.get_rarity_color()
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	drag_preview_panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	var qty_str: String = " x%d" % qty if qty > 1 else ""
	lbl.text = "✊ %s%s" % [item.name, qty_str]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", item.get_rarity_color())
	drag_preview_panel.add_child(lbl)

	add_child(drag_preview_panel)
	drag_preview_panel.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)

func _finish_drag_item(release_pos: Vector2) -> void:
	if not player or not player.inventory or drag_slot_idx < 0:
		return

	var inv: InventoryManager = player.inventory
	if drag_slot_idx >= inv.max_slots:
		return

	# Verificar se foi solto fora da janela do inventário (no mundo 3D / chão)
	var is_outside: bool = true
	if inv_window and inv_window.visible:
		var inv_rect := inv_window.get_global_rect()
		if inv_rect.has_point(release_pos):
			is_outside = false

	if is_outside:
		# Jogar o item no chão 3D!
		inv.drop_item_to_ground(drag_slot_idx)
		if selected_slot_idx == drag_slot_idx:
			selected_slot_idx = -1
			_update_item_inspector()
	else:
		# Verificar se foi solto sobre outro slot da mochila
		var target_slot_idx: int = -1
		for i in range(slot_buttons.size()):
			var btn: Button = slot_buttons[i]
			if btn and btn.get_global_rect().has_point(release_pos):
				target_slot_idx = i
				break

		if target_slot_idx >= 0 and target_slot_idx != drag_slot_idx:
			var drag_slot = inv.slots[drag_slot_idx]
			var target_slot = inv.slots[target_slot_idx]
			
			var is_jewel_upgrade: bool = false
			if drag_slot and drag_slot.get("item") is ItemData and target_slot and target_slot.get("item") is ItemData:
				var drag_item: ItemData = drag_slot["item"]
				var target_item: ItemData = target_slot["item"]
				if (drag_item.id == "jewel_simplicity" or drag_item.id == "jewel_ethrel") and target_item.item_type == ItemData.ItemType.EQUIPMENT:
					var res := inv.apply_jewel_to_item(drag_slot_idx, target_slot_idx)
					if res.get("success", false):
						DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "✨ %s!" % res["item_name"], Color(1.0, 0.85, 0.2), 34, true)
					else:
						DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), res.get("reason", "Falha!"), Color(1.0, 0.3, 0.3), 32, false)
					is_jewel_upgrade = true
					
			if not is_jewel_upgrade:
				inv.swap_slots(drag_slot_idx, target_slot_idx)
				
			selected_slot_idx = target_slot_idx
			_update_item_inspector()

func _cancel_drag_item() -> void:
	drag_slot_idx = -1
	is_dragging_item = false
	_cancel_drag_preview_node()

func _cancel_drag_preview_node() -> void:
	if drag_preview_panel and is_instance_valid(drag_preview_panel):
		drag_preview_panel.queue_free()
	drag_preview_panel = null

func _on_slot_right_clicked(slot_idx: int) -> void:
	if not player or not player.inventory:
		return
	var inv: InventoryManager = player.inventory
	if slot_idx < 0 or slot_idx >= inv.max_slots:
		return
	var slot = inv.slots[slot_idx]
	if slot == null or not (slot.get("item") is ItemData):
		return

	var item: ItemData = slot["item"]
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		inv.equip_item_from_slot(slot_idx)
		selected_slot_idx = -1
	elif item.item_type == ItemData.ItemType.CONSUMABLE:
		if item.id == "jewel_simplicity" or item.id == "jewel_ethrel":
			if selected_slot_idx >= 0 and selected_slot_idx != slot_idx:
				var res := inv.apply_jewel_to_item(slot_idx, selected_slot_idx)
				if res.get("success", false):
					DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "✨ %s!" % res["item_name"], Color(1.0, 0.85, 0.2), 34, true)
				else:
					DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), res.get("reason", "Falha!"), Color(1.0, 0.3, 0.3), 32, false)
				_update_item_inspector()
				return
		inv.use_item_at(slot_idx)

func _on_equip_slot_gui_input(event: InputEvent, eq_key: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_on_equip_slot_right_clicked(eq_key)

func _on_equip_slot_right_clicked(eq_key: String) -> void:
	if not player or not player.inventory:
		return
	var inv: InventoryManager = player.inventory
	if inv.equipped_items.get(eq_key) != null:
		inv.unequip_item(eq_key)
		selected_equip_key = ""

func _update_item_inspector() -> void:
	if not player or not player.inventory:
		return

	var inv: InventoryManager = player.inventory
	var item: ItemData = null
	var is_from_equip: bool = false
	var qty: int = 1

	if selected_equip_key != "":
		item = inv.equipped_items.get(selected_equip_key)
		is_from_equip = true
	elif selected_slot_idx >= 0 and selected_slot_idx < inv.max_slots:
		var slot = inv.slots[selected_slot_idx]
		if slot != null and slot.get("item") is ItemData:
			item = slot["item"]
			qty = slot.get("quantity", 1)

	if item == null:
		lbl_item_name.text = "Selecione um item..."
		lbl_item_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lbl_item_rarity.text = "Raridade: -"
		lbl_item_type_weight.text = "Tipo: - | Peso: 0 kg"
		lbl_item_desc.text = "Clique em um slot da mochila ou equipamento para examinar."
		lbl_item_stats.text = ""
		btn_equip_item.disabled = true
		btn_unequip_item.disabled = true
		btn_use_item.disabled = true
		btn_drop_item.disabled = true
		return

	var r_color := item.get_rarity_color()
	var item_name_formatted: String = item.get_display_name()
	lbl_item_name.text = "%s (x%d)" % [item_name_formatted, qty] if not is_from_equip else item_name_formatted
	lbl_item_name.add_theme_color_override("font_color", r_color)

	lbl_item_rarity.text = "Raridade: %s" % item.get_rarity_name()
	lbl_item_rarity.add_theme_color_override("font_color", r_color)

	var type_str: String = "Consumível" if item.item_type == ItemData.ItemType.CONSUMABLE else ("Equipamento (%s)" % item.get_equip_slot_name() if item.item_type == ItemData.ItemType.EQUIPMENT else ("Moeda / Diverso" if item.item_type == ItemData.ItemType.MISC else "Material"))
	lbl_item_type_weight.text = "Tipo: %s | Peso: %.1f kg" % [type_str, item.weight]
	lbl_item_desc.text = item.description

	var stats_text: String = ""
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		var dur_tag: String = "🟢" if item.current_durability > (item.max_durability * 0.4) else ("🟡" if item.current_durability > 0 else "🔴 QUEBRADO (-80%)")
		stats_text += "🔨 Durabilidade: %d / %d [%s]\n" % [item.current_durability, item.max_durability, dur_tag]

		if not item.req_stats.is_empty():
			stats_text += "📜 Requisitos de Atributo: "
			var req_parts: Array = []
			for req_key in item.req_stats.keys():
				var req_val: int = item.req_stats[req_key]
				var cur_val: int = player.attributes.get_stat_value(req_key) if player and player.attributes else 0
				var status_tag: String = "🟢" if cur_val >= req_val else "🔴"
				req_parts.append("%s %d %s" % [str(req_key).to_upper(), req_val, status_tag])
			stats_text += ", ".join(req_parts) + "\n"

	if item.hp_heal > 0:
		stats_text += "❤️ Restaura %d HP  " % item.hp_heal
	if item.sp_heal > 0:
		stats_text += "🔷 Restaura %d SP  " % item.sp_heal
		
	var eff_stats := item.get_effective_stats() if item.item_type == ItemData.ItemType.EQUIPMENT else item.stats_bonus
	for stat_key in item.stats_bonus.keys():
		var base_val: int = item.stats_bonus[stat_key]
		var eff_val: int = eff_stats.get(stat_key, base_val)
		if item.current_durability <= 0 and item.item_type == ItemData.ItemType.EQUIPMENT:
			stats_text += "✨ +%d %s (Original: %d)  " % [eff_val, str(stat_key).to_upper(), base_val]
		else:
			stats_text += "✨ +%d %s  " % [eff_val, str(stat_key).to_upper()]
		
	lbl_item_stats.text = stats_text

	btn_equip_item.disabled = is_from_equip or (item.item_type != ItemData.ItemType.EQUIPMENT)
	btn_unequip_item.disabled = not is_from_equip
	btn_use_item.disabled = is_from_equip or (item.item_type != ItemData.ItemType.CONSUMABLE)
	btn_drop_item.disabled = is_from_equip

func _on_equip_item_pressed() -> void:
	if player and player.inventory and selected_slot_idx >= 0:
		player.inventory.equip_item_from_slot(selected_slot_idx)
		selected_slot_idx = -1

func _on_unequip_item_pressed() -> void:
	if player and player.inventory and selected_equip_key != "":
		player.inventory.unequip_item(selected_equip_key)
		selected_equip_key = ""

func _on_use_item_pressed() -> void:
	if player and player.inventory and selected_slot_idx >= 0:
		player.inventory.use_item_at(selected_slot_idx)

func _on_drop_item_pressed() -> void:
	if player and player.inventory and selected_slot_idx >= 0:
		player.inventory.drop_item_to_ground(selected_slot_idx)
		selected_slot_idx = -1
		_update_item_inspector()

func _on_currency_changed(eons: int, astris: int) -> void:
	if lbl_currency_eons:
		lbl_currency_eons.text = "🪙 E: %d Éons" % eons
	if lbl_currency_astris:
		lbl_currency_astris.text = "💎 A: %d Astris" % astris
	if shop_eons_label:
		shop_eons_label.text = "🪙 Seu Saldo: %d Éons" % eons

func close_npc_windows() -> void:
	if shop_window:
		shop_window.visible = false
	if blacksmith_window:
		blacksmith_window.visible = false

func open_shop_window(npc: Node) -> void:
	close_npc_windows()
	current_shop_npc = npc
	if not shop_window:
		return
	shop_window.visible = true
	shop_window.move_to_front()
	_update_shop_ui()

func _build_shop_window(root_control: Control) -> void:
	shop_window = PanelContainer.new()
	shop_window.visible = false
	shop_window.custom_minimum_size = Vector2(440, 480)
	
	# Posicionamento centralizado na tela
	var vp_size := get_viewport().get_visible_rect().size
	shop_window.position = Vector2((vp_size.x - 440) * 0.5, (vp_size.y - 480) * 0.5)

	var sb_shop := StyleBoxFlat.new()
	sb_shop.bg_color = Color(0.08, 0.09, 0.13, 0.96)
	sb_shop.set_corner_radius_all(10)
	sb_shop.set_border_width_all(2)
	sb_shop.border_color = Color(0.9, 0.75, 0.2, 0.9)
	sb_shop.content_margin_left = 14
	sb_shop.content_margin_right = 14
	sb_shop.content_margin_top = 12
	sb_shop.content_margin_bottom = 12
	shop_window.add_theme_stylebox_override("panel", sb_shop)
	shop_window.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, shop_window))
	root_control.add_child(shop_window)

	var vbox_shop := VBoxContainer.new()
	vbox_shop.add_theme_constant_override("separation", 8)
	shop_window.add_child(vbox_shop)

	# Cabeçalho da Loja
	var hbox_shop_head := HBoxContainer.new()
	hbox_shop_head.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, shop_window))
	vbox_shop.add_child(hbox_shop_head)

	var lbl_title := Label.new()
	lbl_title.text = "🛍️ Loja de Equipamentos (NPC)"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_shop_head.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = " X "
	btn_close.pressed.connect(func(): shop_window.visible = false)
	hbox_shop_head.add_child(btn_close)

	# Exibição do Saldo de Éons do Jogador
	shop_eons_label = Label.new()
	shop_eons_label.text = "🪙 Seu Saldo: 500 Éons"
	shop_eons_label.add_theme_font_size_override("font_size", 12)
	shop_eons_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vbox_shop.add_child(shop_eons_label)

	var hs := HSeparator.new()
	vbox_shop.add_child(hs)

	# Scroll Container com a Lista de Itens da Loja
	var scroll_shop := ScrollContainer.new()
	scroll_shop.custom_minimum_size = Vector2(0, 360)
	scroll_shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_shop.add_child(scroll_shop)

	var vbox_items := VBoxContainer.new()
	vbox_items.name = "ShopItemsVBox"
	vbox_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_items.add_theme_constant_override("separation", 6)
	scroll_shop.add_child(vbox_items)

func _update_shop_ui() -> void:
	if not shop_window or not current_shop_npc:
		return
		
	if player and player.inventory and shop_eons_label:
		shop_eons_label.text = "🪙 Seu Saldo: %d Éons" % player.inventory.eons

	var vbox_items = shop_window.find_child("ShopItemsVBox", true, false) as VBoxContainer
	if not vbox_items:
		return

	for child in vbox_items.get_children():
		child.queue_free()

	for entry in current_shop_npc.shop_catalog:
		var item_id: String = entry["id"]
		var rarity = entry.get("rarity", ItemData.Rarity.COMMON)
		var price: int = entry.get("price", 100)

		var item_data := ItemData.create_item(item_id, rarity)

		var p_item := PanelContainer.new()
		var sb_item := StyleBoxFlat.new()
		sb_item.bg_color = Color(0.12, 0.14, 0.2, 0.9)
		sb_item.set_corner_radius_all(6)
		sb_item.content_margin_left = 8
		sb_item.content_margin_right = 8
		sb_item.content_margin_top = 6
		sb_item.content_margin_bottom = 6
		p_item.add_theme_stylebox_override("panel", sb_item)
		vbox_items.add_child(p_item)

		var hbox_row := HBoxContainer.new()
		hbox_row.add_theme_constant_override("separation", 8)
		p_item.add_child(hbox_row)

		var lbl_name := Label.new()
		lbl_name.text = item_data.name
		lbl_name.add_theme_font_size_override("font_size", 12)
		lbl_name.add_theme_color_override("font_color", item_data.get_rarity_color())
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.tooltip_text = item_data.description
		hbox_row.add_child(lbl_name)

		var lbl_price := Label.new()
		lbl_price.text = "%d Éons" % price
		lbl_price.add_theme_font_size_override("font_size", 12)
		lbl_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		hbox_row.add_child(lbl_price)

		var btn_buy := Button.new()
		btn_buy.text = " Comprar "
		btn_buy.add_theme_font_size_override("font_size", 11)

		var cur_item = item_data
		var cur_price = price
		btn_buy.pressed.connect(func(): _buy_shop_item(cur_item, cur_price))
		hbox_row.add_child(btn_buy)

func _buy_shop_item(item_data: ItemData, price: int) -> void:
	if not player or not player.inventory:
		return
		
	if player.inventory.remove_eons(price):
		var added := player.inventory.add_item(item_data, 1)
		if added:
			DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "+ Comprado!", Color(0.3, 0.95, 0.4), 30, true)
		else:
			player.inventory.add_eons(price)
			DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "Mochila Cheia!", Color(1.0, 0.3, 0.3), 30, false)
		_update_shop_ui()
		_update_inventory_ui()
	else:
		DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "Éons Insuficientes!", Color(1.0, 0.3, 0.3), 32, false)

func open_blacksmith_window(npc: Node) -> void:
	close_npc_windows()
	current_blacksmith_npc = npc
	if not blacksmith_window:
		return
	blacksmith_window.visible = true
	blacksmith_window.move_to_front()
	_update_blacksmith_ui()

func _build_blacksmith_window(root_control: Control) -> void:
	blacksmith_window = PanelContainer.new()
	blacksmith_window.visible = false
	blacksmith_window.custom_minimum_size = Vector2(460, 500)
	
	# Posicionamento centralizado na tela
	var vp_size := get_viewport().get_visible_rect().size
	blacksmith_window.position = Vector2((vp_size.x - 460) * 0.5, (vp_size.y - 500) * 0.5)

	var sb_blacksmith := StyleBoxFlat.new()
	sb_blacksmith.bg_color = Color(0.1, 0.08, 0.11, 0.96)
	sb_blacksmith.set_corner_radius_all(10)
	sb_blacksmith.set_border_width_all(2)
	sb_blacksmith.border_color = Color(1.0, 0.45, 0.2, 0.9)
	sb_blacksmith.content_margin_left = 14
	sb_blacksmith.content_margin_right = 14
	sb_blacksmith.content_margin_top = 12
	sb_blacksmith.content_margin_bottom = 12
	blacksmith_window.add_theme_stylebox_override("panel", sb_blacksmith)
	blacksmith_window.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, blacksmith_window))
	root_control.add_child(blacksmith_window)

	var vbox_smith := VBoxContainer.new()
	vbox_smith.add_theme_constant_override("separation", 8)
	blacksmith_window.add_child(vbox_smith)

	# Cabeçalho do Ferreiro
	var hbox_smith_head := HBoxContainer.new()
	hbox_smith_head.gui_input.connect(func(ev: InputEvent): _on_window_header_gui_input(ev, blacksmith_window))
	vbox_smith.add_child(hbox_smith_head)

	var lbl_title := Label.new()
	lbl_title.text = "🔨 Oficina do Ferreiro (Reparos)"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_smith_head.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = " X "
	btn_close.pressed.connect(func(): blacksmith_window.visible = false)
	hbox_smith_head.add_child(btn_close)

	# Exibição do Saldo de Éons
	blacksmith_eons_label = Label.new()
	blacksmith_eons_label.text = "🪙 Seu Saldo: 500 Éons"
	blacksmith_eons_label.add_theme_font_size_override("font_size", 12)
	blacksmith_eons_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vbox_smith.add_child(blacksmith_eons_label)

	# Botão Principal: Reparar TODOS os Equipamentos
	var btn_repair_all := Button.new()
	btn_repair_all.name = "BtnRepairAll"
	btn_repair_all.text = "✨ REPARAR TODOS OS EQUIPAMENTOS ✨"
	btn_repair_all.custom_minimum_size = Vector2(0, 34)
	btn_repair_all.add_theme_font_size_override("font_size", 12)
	btn_repair_all.pressed.connect(_repair_all_items)
	vbox_smith.add_child(btn_repair_all)

	var hs := HSeparator.new()
	vbox_smith.add_child(hs)

	var lbl_sub := Label.new()
	lbl_sub.text = "Equipamentos Danificados no Inventário / Corpo:"
	lbl_sub.add_theme_font_size_override("font_size", 11)
	lbl_sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox_smith.add_child(lbl_sub)

	# Scroll Container com Itens Danificados
	var scroll_smith := ScrollContainer.new()
	scroll_smith.custom_minimum_size = Vector2(0, 300)
	scroll_smith.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_smith.add_child(scroll_smith)

	var vbox_damaged := VBoxContainer.new()
	vbox_damaged.name = "DamagedItemsVBox"
	vbox_damaged.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_damaged.add_theme_constant_override("separation", 6)
	scroll_smith.add_child(vbox_damaged)

func _update_blacksmith_ui() -> void:
	if not blacksmith_window or not current_blacksmith_npc:
		return

	if player and player.inventory and blacksmith_eons_label:
		blacksmith_eons_label.text = "🪙 Seu Saldo: %d Éons" % player.inventory.eons

	var vbox_damaged = blacksmith_window.find_child("DamagedItemsVBox", true, false) as VBoxContainer
	if not vbox_damaged:
		return

	for child in vbox_damaged.get_children():
		child.queue_free()

	if not player or not player.inventory:
		return

	var inv: InventoryManager = player.inventory
	var damaged_items: Array = []

	# Coletar equipamentos equipados danificados
	for eq_key in inv.equipped_items.keys():
		var eq: ItemData = inv.equipped_items[eq_key]
		if eq and eq.current_durability < eq.max_durability:
			damaged_items.append({"item": eq, "slot": "Equipado (" + eq.get_equip_slot_name() + ")"})

	# Coletar equipamentos na mochila danificados
	for i in range(inv.slots.size()):
		var slot = inv.slots[i]
		if slot != null and slot.get("item") is ItemData:
			var item: ItemData = slot["item"]
			if item.item_type == ItemData.ItemType.EQUIPMENT and item.current_durability < item.max_durability:
				damaged_items.append({"item": item, "slot": "Mochila Slot " + str(i + 1)})

	var btn_repair_all = blacksmith_window.find_child("BtnRepairAll", true, false) as Button
	if btn_repair_all:
		btn_repair_all.disabled = damaged_items.is_empty()

	if damaged_items.is_empty():
		var lbl_empty := Label.new()
		lbl_empty.text = "🟢 Nenhum equipamento danificado para reparar!"
		lbl_empty.add_theme_font_size_override("font_size", 12)
		lbl_empty.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_damaged.add_child(lbl_empty)
		return

	for entry in damaged_items:
		var item: ItemData = entry["item"]
		var slot_name: String = entry["slot"]
		var cost: int = inv.get_repair_cost(item)

		var p_item := PanelContainer.new()
		var sb_item := StyleBoxFlat.new()
		sb_item.bg_color = Color(0.15, 0.12, 0.18, 0.9)
		sb_item.set_corner_radius_all(6)
		sb_item.content_margin_left = 8
		sb_item.content_margin_right = 8
		sb_item.content_margin_top = 6
		sb_item.content_margin_bottom = 6
		p_item.add_theme_stylebox_override("panel", sb_item)
		vbox_damaged.add_child(p_item)

		var hbox_row := HBoxContainer.new()
		hbox_row.add_theme_constant_override("separation", 8)
		p_item.add_child(hbox_row)

		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox_row.add_child(vbox_info)

		var lbl_name := Label.new()
		lbl_name.text = "%s [%s]" % [item.name, slot_name]
		lbl_name.add_theme_font_size_override("font_size", 12)
		lbl_name.add_theme_color_override("font_color", item.get_rarity_color())
		vbox_info.add_child(lbl_name)

		var dur_str: String = "🔨 Durabilidade: %d / %d" % [item.current_durability, item.max_durability]
		if item.current_durability <= 0:
			dur_str += " 🔴 QUEBRADO"
		var lbl_dur := Label.new()
		lbl_dur.text = dur_str
		lbl_dur.add_theme_font_size_override("font_size", 10)
		lbl_dur.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		vbox_info.add_child(lbl_dur)

		var lbl_price := Label.new()
		lbl_price.text = "%d Éons" % cost
		lbl_price.add_theme_font_size_override("font_size", 12)
		lbl_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		lbl_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox_row.add_child(lbl_price)

		var btn_repair := Button.new()
		btn_repair.text = " Reparar "
		btn_repair.add_theme_font_size_override("font_size", 11)

		var cur_item = item
		btn_repair.pressed.connect(func(): _repair_single_item(cur_item))
		hbox_row.add_child(btn_repair)

func _repair_single_item(item: ItemData) -> void:
	if not player or not player.inventory:
		return
	if player.inventory.repair_item(item):
		DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "✨ Item Reparado!", Color(0.3, 0.95, 0.4), 30, true)
		_update_blacksmith_ui()
		_update_inventory_ui()
	else:
		DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "Éons Insuficientes!", Color(1.0, 0.3, 0.3), 32, false)

func _repair_all_items() -> void:
	if not player or not player.inventory:
		return
	var res := player.inventory.repair_all_equipment()
	if res.get("success", false):
		DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "✨ Todos os Itens Reparados!", Color(0.3, 0.95, 0.4), 34, true)
		_update_blacksmith_ui()
		_update_inventory_ui()
	else:
		var reason: String = res.get("reason", "")
		if reason == "No damage":
			DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "Nenhum Item Danificado!", Color(0.6, 0.8, 1.0), 30, false)
		else:
			DamagePopup.spawn(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), "Éons Insuficientes!", Color(1.0, 0.3, 0.3), 32, false)
