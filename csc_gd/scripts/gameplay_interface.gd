extends Control

var yellow_pieces: Array[ChessPiece] = []
var blue_pieces: Array[ChessPiece] = []
var yellow_cards: Array[CardUI] = []
var blue_cards: Array[CardUI] = []

var _is_dragging: bool = false
var _drag_start_mouse_pos: Vector2
var _drag_start_board_pos: Vector2

var _selected_piece: ChessPiece = null
var _selected_card: CardUI = null

var _cell_menu: PopupMenu
var _deploy_menu: PopupMenu
var _target_cell: BoardCell = null

var _buy_menu_overlay: ColorRect

var _shop_buttons: Array = [[], [], []]
var _weapons_data: Dictionary = {}

const SHOP_YELLOW = [
	["glock", "tec-9", "cz75", "deagle"],
	["mac-10", "pp-19", "nova", "xm1014"],
	["galil ar", "ak47", "ssg08", "awp"]
]

const SHOP_BLUE = [
	["usp-s", "fn57", "cz75", "deagle"],
	["mp9", "pp-19", "nova", "xm1014"],
	["m4a1-s", "m4a4", "ssg08", "awp"]
]

var piece_ghosts: Dictionary = {}
var piece_targets: Dictionary = {}
var piece_deployments: Dictionary = {}
var grid_cells: Dictionary = {}

var active_smokes: Dictionary = {} # grid_position -> remaining actions
var active_fires: Dictionary = {} # grid_position -> remaining actions

var current_turn: int = 1
var current_action: int = 1

var _is_executing_actions: bool = false

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1

func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$BoardContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$LeftPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$RightPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_cell_menu = PopupMenu.new()
	_cell_menu.id_pressed.connect(_on_cell_menu_id_pressed)
	add_child(_cell_menu)
	
	_deploy_menu = PopupMenu.new()
	_deploy_menu.name = "DeployMenu"
	_deploy_menu.add_item("手榴弹", 0)
	_deploy_menu.add_item("烟雾弹", 1)
	_deploy_menu.add_item("燃烧弹", 2)
	_deploy_menu.id_pressed.connect(_on_deploy_menu_id_pressed)
	_cell_menu.add_child(_deploy_menu)
	
	_buy_menu_overlay = ColorRect.new()
	_buy_menu_overlay.color = Color(0, 0, 0, 0.6)
	_buy_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buy_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_buy_menu_overlay.z_index = 100
	_buy_menu_overlay.hide()
	_buy_menu_overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_close_shop()
	)
	add_child(_buy_menu_overlay)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_menu_overlay.add_child(center_container)
	
	var buy_panel = PanelContainer.new()
	buy_panel.custom_minimum_size = Vector2(640, 420)
	buy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.13, 0.15, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 20
	buy_panel.add_theme_stylebox_override("panel", panel_style)
	
	var buy_margin = MarginContainer.new()
	buy_margin.add_theme_constant_override("margin_left", 20)
	buy_margin.add_theme_constant_override("margin_top", 20)
	buy_margin.add_theme_constant_override("margin_right", 20)
	buy_margin.add_theme_constant_override("margin_bottom", 20)
	buy_panel.add_child(buy_margin)
	
	var w_file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if w_file:
		var json = JSON.new()
		if json.parse(w_file.get_as_text()) == OK:
			_weapons_data = json.data
	
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 16)
	buy_margin.add_child(columns_hbox)
	
	for i in range(4):
		var col_vbox = VBoxContainer.new()
		col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_vbox.add_theme_constant_override("separation", 12)
		columns_hbox.add_child(col_vbox)
		
		var title_label = Label.new()
		var col_titles = ["小型", "中型", "大型", "道具"]
		title_label.text = col_titles[i]
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_vbox.add_child(title_label)
		
		if i < 3:
			for j in range(4):
				var btn = Button.new()
				btn.text = "..."
				btn.custom_minimum_size = Vector2(0, 40)
				btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
				
				var center = CenterContainer.new()
				center.name = "IconCenter"
				center.set_anchors_preset(Control.PRESET_FULL_RECT)
				center.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(center)
				
				var icon_rect = TextureRect.new()
				icon_rect.name = "WeaponIcon"
				icon_rect.custom_minimum_size = Vector2(60, 30)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center.add_child(icon_rect)
				
				var name_lbl = Label.new()
				name_lbl.name = "NameLabel"
				name_lbl.add_theme_font_size_override("font_size", 10)
				name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				name_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
				name_lbl.offset_left = 6
				name_lbl.offset_top = 2
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(name_lbl)
				
				var price_lbl = Label.new()
				price_lbl.name = "PriceLabel"
				price_lbl.add_theme_font_size_override("font_size", 10)
				price_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				price_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				price_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				price_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
				price_lbl.offset_right = -6
				price_lbl.offset_bottom = -2
				price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(price_lbl)
				
				_shop_buttons[i].append(btn)
				col_vbox.add_child(btn)
		else:
			for j in range(4):
				var btn = Button.new()
				btn.text = "小按钮"
				btn.custom_minimum_size = Vector2(0, 30)
				col_vbox.add_child(btn)
				
			var spacer = Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col_vbox.add_child(spacer)
			
			var close_btn = Button.new()
			close_btn.text = "关闭商店"
			close_btn.custom_minimum_size = Vector2(0, 60)
			close_btn.pressed.connect(_close_shop)
			col_vbox.add_child(close_btn)
			
	center_container.add_child(buy_panel)
	
	_gather_nodes()
	_bind_interactions()
	_update_turn_ui()

func _update_turn_ui() -> void:
	var turn_label = $TurnPanel/MarginContainer/TurnLabel
	if turn_label:
		turn_label.text = "回合 %d：行动 %d" % [current_turn, current_action]

func advance_action() -> void:
	current_action += 1
	_update_turn_ui()

func advance_turn() -> void:
	current_turn += 1
	current_action = 1
	_update_turn_ui()

func _gather_nodes() -> void:
	var board = $BoardContainer
	for child in board.get_children():
		if child is ChessPiece:
			if child.team == "yellow":
				yellow_pieces.append(child)
			elif child.team == "blue":
				blue_pieces.append(child)
		elif child is BoardCell:
			child.cell_clicked.connect(_on_cell_clicked)
			grid_cells[child.grid_position] = child
				
	# Sort pieces from left to right (by board_position.x)
	yellow_pieces.sort_custom(func(a, b): return a.board_position.x < b.board_position.x)
	blue_pieces.sort_custom(func(a, b): return a.board_position.x < b.board_position.x)
	
	# 确保所有棋子在节点树的最后面，这样它们不仅渲染在最上层，也会在UI事件系统中最优先被点击到
	for p in yellow_pieces + blue_pieces:
		p.get_parent().move_child(p, -1)
	
	var left_panel = $LeftPanel
	for child in left_panel.get_children():
		if child is CardUI:
			yellow_cards.append(child)
			
	var right_panel = $RightPanel
	for child in right_panel.get_children():
		if child is CardUI:
			blue_cards.append(child)

func _input(event: InputEvent) -> void:
	if _buy_menu_overlay != null and _buy_menu_overlay.visible:
		if event is InputEventMouse:
			return

	var board = $BoardContainer
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _is_mouse_over_ui(event.position):
					return
				_is_dragging = true
				_drag_start_mouse_pos = event.position
				_drag_start_board_pos = board.position
			else:
				_is_dragging = false
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _is_mouse_over_ui(event.position):
				return
			_zoom_board(board, event.position, ZOOM_STEP)
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _is_mouse_over_ui(event.position):
				return
			_zoom_board(board, event.position, -ZOOM_STEP)
			
	elif event is InputEventMouseMotion and _is_dragging:
		board.position = _drag_start_board_pos + (event.position - _drag_start_mouse_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo:
		if current_action == 1 and not _is_executing_actions:
			if not _buy_menu_overlay.visible:
				if _selected_piece != null:
					_open_shop()
			else:
				_close_shop()
		return
		
	if _buy_menu_overlay != null and _buy_menu_overlay.visible:
		return

	if _is_executing_actions: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_empty_menu()

func _open_shop() -> void:
	if _selected_piece == null: return
	_buy_menu_overlay.show()
	if _cell_menu.visible: _cell_menu.hide()
	
	var team = _selected_piece.team
	
	var shop_weapons = SHOP_YELLOW if team == "yellow" else SHOP_BLUE
	for i in range(3):
		for j in range(4):
			var w_key = shop_weapons[i][j]
			var btn = _shop_buttons[i][j]
			var icon_rect = btn.get_node_or_null("IconCenter/WeaponIcon")
			var name_lbl = btn.get_node_or_null("NameLabel")
			var price_lbl = btn.get_node_or_null("PriceLabel")
			
			btn.text = ""
			
			if _weapons_data.has(w_key):
				var w_data = _weapons_data[w_key]
				if name_lbl: name_lbl.text = w_data.get("name", "")
				if price_lbl: price_lbl.text = "$ 800"
				
				var icon_path = w_data.get("icon_path", "")
				if icon_path != "" and icon_rect != null:
					icon_rect.texture = load(icon_path)
			else:
				if name_lbl: name_lbl.text = w_key
				if price_lbl: price_lbl.text = "$ 800"
				if icon_rect != null: icon_rect.texture = null
	
	if team == "yellow":
		$LeftPanel.z_index = 101
		move_child($LeftPanel, -1)
		for card in yellow_cards:
			card.set_shop_highlight(false)
	elif team == "blue":
		$RightPanel.z_index = 101
		move_child($RightPanel, -1)
		for card in blue_cards:
			card.set_shop_highlight(false)

func _close_shop() -> void:
	_buy_menu_overlay.hide()
	$LeftPanel.z_index = 0
	$RightPanel.z_index = 0
	for card in yellow_cards:
		card.set_shop_highlight(false)
	for card in blue_cards:
		card.set_shop_highlight(false)

func _show_empty_menu() -> void:
	if _is_executing_actions: return
	_deselect_current()
	_target_cell = null
	_cell_menu.clear()
	_cell_menu.add_item("结束行动", 3)
	_cell_menu.reset_size()
	_cell_menu.position = Vector2i(get_viewport().get_mouse_position())
	_cell_menu.popup()

func _deselect_current() -> void:
	if _selected_piece:
		_selected_piece.set_selected(false)
		_selected_piece = null
	if _selected_card:
		_selected_card.set_selected(false)
		_selected_card = null

func _select_pair(piece: ChessPiece, card: CardUI) -> void:
	if _is_executing_actions: return
	_deselect_current()
	_selected_piece = piece
	_selected_card = card
	if _selected_piece:
		_selected_piece.set_selected(true)
	if _selected_card:
		_selected_card.set_selected(true)
		
	if _buy_menu_overlay != null and _buy_menu_overlay.visible:
		_open_shop()

func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
	var left_panel = $LeftPanel
	var right_panel = $RightPanel
	if left_panel.get_global_rect().has_point(mouse_pos):
		return true
	if right_panel.get_global_rect().has_point(mouse_pos):
		return true
	return false

func _zoom_board(board: Control, mouse_pos: Vector2, zoom_delta: float) -> void:
	var old_scale = board.scale
	var new_scale_val = clamp(old_scale.x + zoom_delta, MIN_ZOOM, MAX_ZOOM)
	var new_scale = Vector2(new_scale_val, new_scale_val)
	
	if old_scale == new_scale:
		return
		
	var mouse_pos_local = (mouse_pos - board.position) / old_scale
	board.scale = new_scale
	board.position = mouse_pos - mouse_pos_local * new_scale
	
	if _is_dragging:
		_drag_start_mouse_pos = mouse_pos
		_drag_start_board_pos = board.position

func _bind_interactions() -> void:
	var file = FileAccess.open("res://data/pieces.json", FileAccess.READ)
	var pieces_data = {}
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			pieces_data = json.data

	var yellow_data = pieces_data.get("yellow", [])
	for i in range(min(yellow_pieces.size(), yellow_cards.size())):
		var piece = yellow_pieces[i]
		var card = yellow_cards[i]
		
		if i < yellow_data.size():
			var data = yellow_data[i]
			piece.name_str = data.get("name", "Name")
			piece.max_hp = data.get("max_hp", 100)
			piece.hp = piece.max_hp
			piece.max_ep = data.get("max_ep", 5)
			piece.shoot = data.get("shoot", 50)
			piece.react = data.get("react", 50)
			
		_connect_pair(piece, card)

	var blue_data = pieces_data.get("blue", [])
	for i in range(min(blue_pieces.size(), blue_cards.size())):
		var piece = blue_pieces[i]
		var card = blue_cards[i]
		
		if i < blue_data.size():
			var data = blue_data[i]
			piece.name_str = data.get("name", "Name")
			piece.max_hp = data.get("max_hp", 100)
			piece.hp = piece.max_hp
			piece.max_ep = data.get("max_ep", 5)
			piece.shoot = data.get("shoot", 50)
			piece.react = data.get("react", 50)
			
		_connect_pair(piece, card)

func _connect_pair(piece: ChessPiece, card: CardUI) -> void:
	piece.piece_hovered.connect(func(_p): card.set_glow(true))
	piece.piece_unhovered.connect(func(_p): card.set_glow(false))
	card.card_hovered.connect(func(_c): piece.set_glow(true))
	card.card_unhovered.connect(func(_c): piece.set_glow(false))
	
	piece.piece_clicked.connect(func(_p): _select_pair(piece, card))
	card.card_clicked.connect(func(_c): _select_pair(piece, card))
	
	piece.hp_changed.connect(card.update_hp)
	card.apply_stats(piece)
	
	piece.piece_died.connect(func(p): _on_piece_died(p, card))

func _on_piece_died(piece: ChessPiece, card: CardUI) -> void:
	if yellow_pieces.has(piece):
		yellow_pieces.erase(piece)
	if blue_pieces.has(piece):
		blue_pieces.erase(piece)
	if yellow_cards.has(card):
		yellow_cards.erase(card)
	if blue_cards.has(card):
		blue_cards.erase(card)
		
	if piece == _selected_piece:
		_deselect_current()
	if card == _selected_card:
		_deselect_current()
	
	if is_instance_valid(piece):
		piece.queue_free()
	if is_instance_valid(card):
		card.mark_dead()

func _on_cell_clicked(cell: BoardCell) -> void:
	if _is_executing_actions: return
	if cell.is_obstacle:
		_show_empty_menu()
		return

	_target_cell = cell
	_cell_menu.clear()
	
	if _selected_piece != null:
		_cell_menu.add_item("静步至", 0)
		_cell_menu.add_item("大拉至", 1)
		_cell_menu.add_item("跳拉至", 2)
		
		_cell_menu.add_submenu_item("部署至", "DeployMenu", 4)
		var has_los = _check_line_of_sight(_selected_piece.board_position, cell.grid_position)
		_cell_menu.set_item_disabled(_cell_menu.item_count - 1, not has_los)
		
		_cell_menu.add_separator()
		
	_cell_menu.add_item("结束行动", 3)
	
	_cell_menu.reset_size()
	_cell_menu.position = Vector2i(get_viewport().get_mouse_position())
	_cell_menu.popup()

func _on_deploy_menu_id_pressed(id: int) -> void:
	match id:
		0:
			if _selected_piece and _target_cell:
				_deploy_grenade(_selected_piece, _target_cell)
		1:
			if _selected_piece and _target_cell:
				_deploy_smoke(_selected_piece, _target_cell)
		2:
			if _selected_piece and _target_cell:
				_deploy_molotov(_selected_piece, _target_cell)

func _on_cell_menu_id_pressed(id: int) -> void:
	match id:
		0:
			if _selected_piece and _target_cell:
				_sneak_to(_selected_piece, _target_cell)
		1:
			if _selected_piece and _target_cell:
				_wide_swing_to(_selected_piece, _target_cell)
		2:
			if _selected_piece and _target_cell:
				_jump_peek_to(_selected_piece, _target_cell)
		3:
			_end_action()
			
	# _deselect_current() # uncomment if clicking menu should deselect

var _final_layouts: Dictionary = {}

func _end_action() -> void:
	if _is_executing_actions: return
	_is_executing_actions = true
	_deselect_current()
	
	_final_layouts = _calculate_final_layouts()
	
	var act_pieces = []
	for p in yellow_pieces + blue_pieces:
		if is_instance_valid(p) and p.hp > 0:
			act_pieces.append(p)
			
	if act_pieces.is_empty():
		print("Action: 结束行动 (空过)")
		_finish_end_action()
		return
		
	# 反应值更高的排在前面
	act_pieces.sort_custom(func(a, b): return a.react > b.react)
	
	print("Action: 结束行动 - 开始依照反应值分批执行")
	_execute_next_action(act_pieces, 0)

func _execute_next_action(pieces: Array, index: int) -> void:
	if index >= pieces.size():
		_finish_end_action()
		return
		
	var piece = pieces[index]
	if not is_instance_valid(piece) or piece.hp <= 0:
		_execute_next_action(pieces, index + 1)
		return
		
	var duration = 0.0
	var tween = create_tween()
	
	if index == 0:
		for p in yellow_pieces + blue_pieces:
			if not piece_targets.has(p): # 非移动棋子，但可能需要根据人数改变大小/位置
				if _final_layouts.has(p):
					var layout = _final_layouts[p]
					if p.position != layout["position"] or p.scale != layout["scale"]:
						tween.parallel().tween_property(p, "position", layout["position"], 0.3)
						tween.parallel().tween_property(p, "scale", layout["scale"], 0.3)
						duration = max(duration, 0.3)
	
	var has_move = false
	var has_proj = false
	var proj_node = null
	
	var target_deploy_cell = null
	var deploy_type = -1
	
	if piece_targets.has(piece):
		has_move = true
		var target_cell = piece_targets[piece]
		var layout = _final_layouts[piece]
		tween.parallel().tween_property(piece, "position", layout["position"], 0.3)
		tween.parallel().tween_property(piece, "scale", layout["scale"], 0.3)
		piece.board_position = target_cell.grid_position
		
		var ghost = piece_ghosts.get(piece)
		if is_instance_valid(ghost):
			ghost.queue_free()
		piece_ghosts.erase(piece)
		duration = max(duration, 0.3)
		piece_targets.erase(piece) # 完成后移除
		
	if piece_deployments.has(piece):
		has_proj = true
		var deploy = piece_deployments[piece]
		deploy_type = deploy["type"]
		target_deploy_cell = deploy["cell"]
		
		var emoji = ["💩", "🌫️", "🔥"][deploy_type]
		proj_node = Label.new()
		proj_node.text = emoji
		proj_node.add_theme_font_size_override("font_size", 32)
		proj_node.position = piece.position + (piece.size / 2.0) - Vector2(16, 16)
		proj_node.z_index = 20
		$BoardContainer.add_child(proj_node)
		
		var target_pos = target_deploy_cell.position + (target_deploy_cell.size / 2.0) - Vector2(16, 16)
		tween.parallel().tween_property(proj_node, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		duration = max(duration, 0.4)
		piece_deployments.erase(piece) # 完成后移除
		
	if duration == 0.0:
		tween.kill() # 未添加动画的 tween 会抛出报错，主动销毁即可
		
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		
	if is_instance_valid(proj_node):
		proj_node.queue_free()
		
	if has_proj and target_deploy_cell:
		var pos = target_deploy_cell.grid_position
		if deploy_type == 1: # Smoke
			active_smokes[pos] = 3
			if active_fires.has(pos):
				active_fires.erase(pos)
		elif deploy_type == 0: # Grenade
			for p in yellow_pieces + blue_pieces:
				if p.board_position == pos: p.take_damage(50)
		elif deploy_type == 2: # Molotov
			if not active_smokes.has(pos):
				active_fires[pos] = 2
				for p in yellow_pieces + blue_pieces:
					if p.board_position == pos: p.take_damage(25)
	
	_update_board_visuals()
	
	var did_shoot = _perform_shoot(piece)
	if did_shoot:
		await get_tree().create_timer(0.3).timeout
	else:
		await get_tree().create_timer(0.1).timeout
		
	_execute_next_action(pieces, index + 1)

func _perform_shoot(piece: ChessPiece) -> bool:
	if not is_instance_valid(piece) or piece.hp <= 0:
		return false
		
	var enemies = blue_pieces if piece.team == "yellow" else yellow_pieces
	var valid_targets = []
	for e in enemies:
		if is_instance_valid(e) and e.hp > 0:
			if _check_line_of_sight(piece.board_position, e.board_position):
				valid_targets.append(e)
				
	if valid_targets.size() > 0:
		valid_targets.shuffle()
		var target = valid_targets.front()
		target.take_damage(10)
		_show_shoot_effect(piece, target)
		print("Shoot: ", piece.name_str, "(", piece.team, ") 击中了 ", target.name_str, "(", target.team, ")")
		return true
		
	return false

func _show_shoot_effect(attacker: ChessPiece, target: ChessPiece) -> void:
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.8, 0.2, 0.8) if attacker.team == "yellow" else Color(0.2, 0.6, 1.0, 0.8)
	
	var start_pos = attacker.position + (attacker.size / 2.0)
	var end_pos = target.position + (target.size / 2.0)
	
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.z_index = 20
	$BoardContainer.add_child(line)
	
	var tw = create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)

func _finish_end_action() -> void:
	# 1. 提前处理场上的老燃烧弹第二次伤害及老物体的持续时间削减
	for p in yellow_pieces + blue_pieces:
		if active_fires.has(p.board_position):
			p.take_damage(50) # 第二个行动回合的伤害 50 点
			
	var expired_fires = []
	for pos in active_fires.keys():
		active_fires[pos] -= 1
		if active_fires[pos] <= 0:
			expired_fires.append(pos)
	for pos in expired_fires:
		active_fires.erase(pos)
		
	var expired_smokes = []
	for pos in active_smokes.keys():
		active_smokes[pos] -= 1
		if active_smokes[pos] <= 0:
			expired_smokes.append(pos)
	for pos in expired_smokes:
		active_smokes.erase(pos)
		
	_resolve_clashes()
	
	_update_board_visuals()
	_snap_layouts(func():
		advance_action()
		_is_executing_actions = false
		print("Action: 结束行动 - 回合结算完毕，可以进行下一轮规划")
	)

func _resolve_clashes() -> void:
	var cell_contents = {}
	for p in yellow_pieces + blue_pieces:
		if not is_instance_valid(p) or p.hp <= 0: continue
		var pos = p.board_position
		if not cell_contents.has(pos):
			cell_contents[pos] = []
		cell_contents[pos].append(p)
		
	for pos in cell_contents.keys():
		var pieces = cell_contents[pos]
		var yellow_in_cell = []
		var blue_in_cell = []
		for p in pieces:
			if p.team == "yellow": yellow_in_cell.append(p)
			elif p.team == "blue": blue_in_cell.append(p)
			
			if yellow_in_cell.size() > 0 and blue_in_cell.size() > 0:
				yellow_in_cell.shuffle()
				blue_in_cell.shuffle()
				
				while yellow_in_cell.size() > 0 and blue_in_cell.size() > 0:
					var y = yellow_in_cell.front()
					var b = blue_in_cell.front()
					
					if randf() > 0.5:
						print("拼刀: ", y.name_str, "(黄) 击杀了 ", b.name_str, "(蓝)!")
						b.take_damage(b.hp)
						blue_in_cell.pop_front()
					else:
						print("拼刀: ", b.name_str, "(蓝) 击杀了 ", y.name_str, "(黄)!")
						y.take_damage(y.hp)
						yellow_in_cell.pop_front()

func _snap_layouts(callback: Callable = Callable()) -> void:
	var final_layouts = _calculate_final_layouts()
	var need_wait = false
	for p in yellow_pieces + blue_pieces:
		if final_layouts.has(p):
			var layout = final_layouts[p]
			if p.position != layout["position"] or p.scale != layout["scale"]:
				need_wait = true
				break
				
	if not need_wait:
		if callback.is_valid():
			callback.call()
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	for p in yellow_pieces + blue_pieces:
		if final_layouts.has(p):
			var layout = final_layouts[p]
			if p.position != layout["position"] or p.scale != layout["scale"]:
				tween.tween_property(p, "position", layout["position"], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(p, "scale", layout["scale"], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		if callback.is_valid():
			callback.call()
	)

func _update_board_visuals() -> void:
	for cell in grid_cells.values():
		var pos = cell.grid_position
		var smoke_val = active_smokes.get(pos, 0)
		var fire_val = active_fires.get(pos, 0)
		cell.update_status(smoke_val, fire_val)

func _calculate_final_layouts() -> Dictionary:
	var layouts = {}
	var cell_contents = {}
	
	for p in yellow_pieces + blue_pieces:
		var pos = p.board_position
		if piece_targets.has(p):
			pos = piece_targets[p].grid_position
		
		if not cell_contents.has(pos):
			cell_contents[pos] = []
		cell_contents[pos].append(p)
		
	for pos in cell_contents.keys():
		var pieces_in_cell = cell_contents[pos]
		pieces_in_cell.sort_custom(func(a, b): 
			if a.team != b.team: return a.team > b.team
			return a.react > b.react
		)
		
		var count = pieces_in_cell.size()
		var cell = grid_cells.get(pos)
		if not cell:
			continue
			
		var cell_origin = cell.position
		var cell_size_vec = cell.size
		var piece_base_size = Vector2(68, 68)
		
		var centers = []
		var target_scale = 1.0
		
		match count:
			1:
				target_scale = 1.0
				centers = [Vector2(0.5, 0.5)]
			2:
				target_scale = 0.6
				centers = [Vector2(0.25, 0.5), Vector2(0.75, 0.5)]
			3:
				target_scale = 0.5
				centers = [Vector2(0.5, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
			4:
				target_scale = 0.45
				centers = [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
			_:
				target_scale = 0.4
				centers = [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
				
		for i in range(count):
			var p = pieces_in_cell[i]
			var idx = i if i < centers.size() else centers.size() - 1
			var center_rel = centers[idx]
			var center_abs = cell_origin + cell_size_vec * center_rel
			var target_pos = center_abs - (piece_base_size * target_scale / 2.0)
			layouts[p] = { "position": target_pos, "scale": Vector2(target_scale, target_scale) }
			
	return layouts

func _sneak_to(piece: ChessPiece, cell: BoardCell) -> void:
	_set_move_command(piece, cell)
	print("Action: 静步至 ", cell.grid_position, " by piece ", piece.team, " at ", piece.board_position)

func _wide_swing_to(piece: ChessPiece, cell: BoardCell) -> void:
	_set_move_command(piece, cell)
	print("Action: 大拉至 ", cell.grid_position, " by piece ", piece.team, " at ", piece.board_position)

func _jump_peek_to(piece: ChessPiece, cell: BoardCell) -> void:
	_set_move_command(piece, cell)
	print("Action: 跳拉至 ", cell.grid_position, " by piece ", piece.team, " at ", piece.board_position)

func _deploy_grenade(piece: ChessPiece, cell: BoardCell) -> void:
	piece_deployments[piece] = {"type": 0, "cell": cell}
	print("Action: 计划部署手榴弹至 ", cell.grid_position, " by piece ", piece.team)

func _deploy_smoke(piece: ChessPiece, cell: BoardCell) -> void:
	piece_deployments[piece] = {"type": 1, "cell": cell}
	print("Action: 计划部署烟雾弹至 ", cell.grid_position, " by piece ", piece.team)

func _deploy_molotov(piece: ChessPiece, cell: BoardCell) -> void:
	piece_deployments[piece] = {"type": 2, "cell": cell}
	print("Action: 计划部署燃烧弹至 ", cell.grid_position, " by piece ", piece.team)

func _check_line_of_sight(start_pos: Vector2i, end_pos: Vector2i) -> bool:
	# 如果棋子本身在烟雾内，完全丢失视野，无法部署投掷物
	if active_smokes.has(start_pos):
		return false

	var x0 = start_pos.x
	var y0 = start_pos.y
	var x1 = end_pos.x
	var y1 = end_pos.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	
	var x = x0
	var y = y0
	
	var n = 1 + dx + dy
	var x_inc = 1 if x1 > x0 else -1
	var y_inc = 1 if y1 > y0 else -1
	
	var error = dx - dy
	dx *= 2
	dy *= 2
	
	while n > 0:
		var pos = Vector2i(x, y)
		# 不检测起点和终点自身是否为障碍物
		if pos != start_pos and pos != end_pos:
			if grid_cells.has(pos):
				if grid_cells[pos].is_obstacle:
					return false
			# 烟雾阻挡途中的视线
			if active_smokes.has(pos):
				return false
		
		if error > 0:
			x += x_inc
			error -= dy
		elif error < 0:
			y += y_inc
			error += dx
		else:
			x += x_inc
			y += y_inc
			n -= 1
		n -= 1

	return true

func _set_move_command(piece: ChessPiece, cell: BoardCell) -> void:
	piece_targets[piece] = cell
	
	var ghost: ChessPiece
	if piece_ghosts.has(piece):
		ghost = piece_ghosts[piece]
	else:
		var chess_piece_scene = load("res://scenes/chess_piece.tscn")
		ghost = chess_piece_scene.instantiate()
		$BoardContainer.add_child(ghost)
		piece_ghosts[piece] = ghost
		
		ghost.team = piece.team
		ghost.modulate.a = 0.5  # 半透明表示虚影
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	ghost.board_position = cell.grid_position
	# 格子大小为 96x96，棋子大小为 68x68，居中偏移量为 14x14
	ghost.position = cell.position + Vector2(14, 14)
