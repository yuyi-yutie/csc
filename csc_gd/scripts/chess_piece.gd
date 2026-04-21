extends PanelContainer
class_name ChessPiece

const TEAM_TOP := "yellow"
const TEAM_BOTTOM := "blue"

@export var team: String = ""
@export var board_position: Vector2i = Vector2i.ZERO

signal piece_hovered(piece: ChessPiece)
signal piece_unhovered(piece: ChessPiece)
signal piece_clicked(piece: ChessPiece)

var _is_hovered: bool = false
var _is_selected: bool = false

var name_str: String = "":
	set(value):
		name_str = value
		if is_node_ready() and has_node("NameLabel"):
			$NameLabel.text = value

var hp: int = 100
var max_hp: int = 100

var max_ep: int = 5
var shoot: int = 50
var react: int = 50
signal hp_changed(new_hp: int, max_hp: int)
signal stats_changed(piece: ChessPiece)

var _normal_style: StyleBoxFlat
var _glow_style: StyleBoxFlat

func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10  # 确保棋子永远渲染在格子之上
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_setup_styles()
	_apply_visual_state()
	
	if has_node("NameLabel"):
		$NameLabel.text = name_str
		$NameLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_styles() -> void:
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = _get_team_base_color()
	
	_glow_style = _normal_style.duplicate()
	_glow_style.border_color = _get_border_color()
	_glow_style.border_width_left = 1
	_glow_style.border_width_top = 1
	_glow_style.border_width_right = 1
	_glow_style.border_width_bottom = 1
	_glow_style.shadow_color = _get_glow_color()
	_glow_style.shadow_size = 18

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
	piece_hovered.emit(self)
	set_glow(true)

func _on_mouse_exited() -> void:
	piece_unhovered.emit(self)
	set_glow(false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		piece_clicked.emit(self)

func _apply_visual_state() -> void:
	_update_glow_state()

signal piece_died(piece: ChessPiece)

func take_damage(amount: int) -> void:
	if hp <= 0: return
	hp -= amount
	if hp < 0:
		hp = 0
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		piece_died.emit(self)

func _get_team_base_color() -> Color:
	if team == TEAM_TOP:
		return Color(1.0, 0.8, 0.2, 1.0)
	if team == TEAM_BOTTOM:
		return Color(0.2, 0.6, 1.0, 1.0)
	return Color.WHITE

func _get_glow_color() -> Color:
	if team == TEAM_TOP:
		return Color(1.0, 0.9, 0.2, 0.35)
	if team == TEAM_BOTTOM:
		return Color(0.2, 0.6, 1.0, 0.35)
	return Color(1.0, 1.0, 1.0, 0.35)

func _get_border_color() -> Color:
	if team == TEAM_TOP:
		return Color(1.0, 0.95, 0.4, 0.75)
	if team == TEAM_BOTTOM:
		return Color(0.4, 0.75, 1.0, 0.75)
	return Color(1.0, 1.0, 1.0, 0.75)