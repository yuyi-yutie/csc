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
@onready var ep_boxes: HBoxContainer = $MarginContainer/VBoxContainer/EPRow/EPBoxes
@onready var weapon_icon: TextureRect = $MarginContainer/VBoxContainer/WeaponRow/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/VBoxContainer/WeaponRow/WeaponName

var _normal_style: StyleBoxFlat
var _glow_style: StyleBoxFlat

var _is_hovered: bool = false
var _is_selected: bool = false

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
		base_color = Color(1.0, 0.54, 0.45, 1.0)
		weapon_id = "glock"
	elif team == "blue":
		base_color = Color(0.5, 1.0, 0.72, 1.0)
		weapon_id = "usp"
		
	if _weapons_data.has(weapon_id):
		var w_data = _weapons_data[weapon_id]
		weapon_name.text = w_data.get("name", "")
		var icon_path = w_data.get("icon_path", "")
		if icon_path != "":
			weapon_icon.texture = load(icon_path)
			
	team_dot.color = base_color
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = base_color
	hp_bar.add_theme_stylebox_override("fill", style_box)
	
	# Add 5 EP boxes
	for i in range(5):
		var box = ColorRect.new()
		box.custom_minimum_size = Vector2(0, 6)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.color = base_color
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ep_boxes.add_child(box)
		
	_setup_glow_styles()
	
	mouse_filter = Control.MOUSE_FILTER_STOP
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

func set_glow(active: bool) -> void:
	_is_hovered = active
	_update_glow_state()

func set_selected(active: bool) -> void:
	_is_selected = active
	_update_glow_state()

func _update_glow_state() -> void:
	if (_is_hovered or _is_selected) and _glow_style:
		add_theme_stylebox_override("panel", _glow_style)
	elif _normal_style:
		add_theme_stylebox_override("panel", _normal_style)

func _on_mouse_entered() -> void:
	card_hovered.emit(self)
	set_glow(true)

func _on_mouse_exited() -> void:
	card_unhovered.emit(self)
	set_glow(false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		card_clicked.emit(self)

func _get_glow_color() -> Color:
	if team == "yellow":
		return Color(1.0, 80.0 / 255.0, 80.0 / 255.0, 0.35)
	if team == "blue":
		return Color(40.0 / 255.0, 220.0 / 255.0, 120.0 / 255.0, 0.35)
	return Color(1.0, 1.0, 1.0, 0.35)

func _get_border_color() -> Color:
	if team == "yellow":
		return Color(1.0, 120.0 / 255.0, 120.0 / 255.0, 0.75)
	if team == "blue":
		return Color(60.0 / 255.0, 220.0 / 255.0, 140.0 / 255.0, 0.75)
	return Color(1.0, 1.0, 1.0, 0.75)
