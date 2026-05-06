extends PanelContainer
class_name CardUI

signal card_hovered(card: CardUI)
signal card_unhovered(card: CardUI)
signal card_clicked(card: CardUI)

@export var team: String = "yellow"
@export var character_name: String = "Name"

@onready var team_dot: ColorRect = $MarginContainer/VBoxContainer/Header/TeamDot
@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPRow/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPRow/HPValue
@onready var ep_boxes: HBoxContainer = $MarginContainer/VBoxContainer/EPRow/EPBoxes
@onready var weapon_icon: TextureRect = $MarginContainer/VBoxContainer/WeaponRow/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/VBoxContainer/WeaponRow/WeaponName
@onready var shoot_label: Label = $MarginContainer/VBoxContainer/StatsRow/ShootValue
@onready var react_label: Label = $MarginContainer/VBoxContainer/StatsRow/ReactValue

var _normal_style: StyleBoxFlat
var _glow_style: StyleBoxFlat

var _is_hovered: bool = false
var _is_selected: bool = false
var is_dead: bool = false
var is_shop_highlighted: bool = false

static var _weapons_data: Dictionary = {}

static func _load_weapons_data() -> void:
	if not _weapons_data.is_empty():
		return
	var file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			_weapons_data = json.data

func _ready() -> void:
	name_label.text = character_name
	_load_weapons_data()
	
	var base_color = Color.WHITE
	var weapon_id = ""
	
	if team == "yellow":
		base_color = Color(1.0, 0.8, 0.2, 1.0)
		weapon_id = "glock"
	elif team == "blue":
		base_color = Color(0.2, 0.6, 1.0, 1.0)
		weapon_id = "usp-s"
		
	if _weapons_data.has(weapon_id):
		var w_data = _weapons_data[weapon_id]
		weapon_name.text = w_data.get("name", "")
		var icon_path = w_data.get("icon_path", "")
		if icon_path != "":
			weapon_icon.texture = load(icon_path)
			
	team_dot.color = base_color
	
	update_hp(100, 100)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = base_color
	hp_bar.add_theme_stylebox_override("fill", style_box)
	
	_setup_glow_styles()
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_disable_child_mouse_filters($MarginContainer)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _disable_child_mouse_filters(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_child_mouse_filters(child)

func _setup_glow_styles() -> void:
	var panel_style = get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		_normal_style = panel_style.duplicate()
		_glow_style = panel_style.duplicate()
		
		var glow_color = _get_glow_color()
		var border_color = _get_border_color()
		
		_glow_style.border_color = border_color
		_glow_style.shadow_color = glow_color
		_glow_style.shadow_size = 18
		
		add_theme_stylebox_override("panel", _normal_style)

@onready var money_label: Label = $MarginContainer/VBoxContainer/Header/MoneyLabel

func apply_stats(piece: ChessPiece) -> void:
	name_label.text = piece.name_str
	character_name = piece.name_str
	shoot_label.text = str(piece.shoot)
	react_label.text = str(piece.react)
	
	update_hp(piece.hp, piece.max_hp)
	update_money(piece.money)
	change_weapon(piece.weapon_id)
	
	# Rebuild EP boxes
	for child in ep_boxes.get_children():
		child.queue_free()
		
	var base_color = team_dot.color
	for i in range(piece.max_ep):
		var box = ColorRect.new()
		box.custom_minimum_size = Vector2(0, 6)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.color = base_color
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ep_boxes.add_child(box)

func update_money(new_money: int) -> void:
	if money_label:
		money_label.text = "$ %d" % new_money

func change_weapon(w_id: String) -> void:
	if _weapons_data.has(w_id):
		var w_data = _weapons_data[w_id]
		weapon_name.text = w_data.get("name", "")
		var icon_path = w_data.get("icon_path", "")
		if icon_path != "":
			weapon_icon.texture = load(icon_path)
		else:
			weapon_icon.texture = null
	else:
		weapon_name.text = ""
		weapon_icon.texture = null

func update_hp(hp: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if hp_label:
		hp_label.text = str(hp)

signal weapon_dropped_on(card: CardUI, w_id: String, price: int)
signal weapon_swapped_with(source_card: CardUI, target_card: CardUI)

func _get_drag_data(at_position: Vector2) -> Variant:
	if is_dead or weapon_name.text == "": 
		return null
		
	var preview = TextureRect.new()
	if weapon_icon.texture:
		preview.texture = weapon_icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(80, 40)
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0
	
	set_drag_preview(c)
	return {"type": "swap_weapon", "source_card": self}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_dead: return false
	if typeof(data) == TYPE_DICTIONARY and data.has("type"):
		if data["type"] == "weapon":
			return true
		if data["type"] == "swap_weapon":
			var src = data["source_card"] as CardUI
			if src != self and src.team == self.team:
				return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if is_dead: return
	if typeof(data) == TYPE_DICTIONARY:
		if data["type"] == "weapon":
			weapon_dropped_on.emit(self, data["w_key"], data["price"])
		elif data["type"] == "swap_weapon":
			weapon_swapped_with.emit(data["source_card"], self)

func mark_dead() -> void:
	is_dead = true
	modulate = Color(0.4, 0.4, 0.4, 0.8) # 变灰并稍微透明
	update_hp(0, hp_bar.max_value if hp_bar else 100)
	
	for child in ep_boxes.get_children():
		child.queue_free()
		
	weapon_icon.texture = null
	weapon_name.text = ""
	update_money(0)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_is_hovered = false
	_is_selected = false
	_update_glow_state()

func set_glow(active: bool) -> void:
	if is_dead: return
	_is_hovered = active
	_update_glow_state()

func set_selected(active: bool) -> void:
	if is_dead: return
	_is_selected = active
	_update_glow_state()

func set_shop_highlight(active: bool) -> void:
	if is_dead: return
	is_shop_highlighted = active
	_update_glow_state()

func _update_glow_state() -> void:
	if is_dead and _normal_style:
		add_theme_stylebox_override("panel", _normal_style)
		return
		
	if (_is_hovered or _is_selected or is_shop_highlighted) and _glow_style:
		add_theme_stylebox_override("panel", _glow_style)
	elif _normal_style:
		add_theme_stylebox_override("panel", _normal_style)

func _on_mouse_entered() -> void:
	if is_dead: return
	card_hovered.emit(self)
	set_glow(true)

func _on_mouse_exited() -> void:
	if is_dead: return
	card_unhovered.emit(self)
	set_glow(false)

func _on_gui_input(event: InputEvent) -> void:
	if is_dead: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		card_clicked.emit(self)

func _get_glow_color() -> Color:
	if team == "yellow":
		return Color(1.0, 0.9, 0.2, 0.35)
	if team == "blue":
		return Color(0.2, 0.6, 1.0, 0.35)
	return Color(1.0, 1.0, 1.0, 0.35)

func _get_border_color() -> Color:
	if team == "yellow":
		return Color(1.0, 0.95, 0.4, 0.75)
	if team == "blue":
		return Color(0.4, 0.75, 1.0, 0.75)
	return Color(1.0, 1.0, 1.0, 0.75)
