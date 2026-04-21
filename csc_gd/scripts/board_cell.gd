extends ColorRect
class_name BoardCell

@export var grid_position: Vector2i = Vector2i.ZERO
@export var cell_size: Vector2 = Vector2(96.0, 96.0)
@export var is_obstacle: bool = false

var has_smoke: bool = false
var has_fire: bool = false

var status_label: Label

func _ready() -> void:
	_update_color()
	custom_minimum_size = cell_size
	size = cell_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	status_label.offset_left = 0
	status_label.offset_top = 0
	status_label.offset_right = -4
	status_label.offset_bottom = -2
	status_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(status_label)
	
	queue_redraw()

signal cell_clicked(cell: BoardCell)

func _update_color() -> void:
	if is_obstacle:
		color = Color(0.1, 0.1, 0.1, 0.8)
	elif has_fire:
		color = Color(0.5, 0.15, 0.15, 1.0)
	elif has_smoke:
		color = Color(0.4, 0.4, 0.4, 1.0)
	else:
		color = Color(0.16, 0.18, 0.22, 1.0)

func update_status(smoke_val: int, fire_val: int) -> void:
	has_smoke = smoke_val > 0
	has_fire = fire_val > 0
	
	if has_fire:
		status_label.text = "🔥 %d" % fire_val
	elif has_smoke:
		status_label.text = "🌫️ %d" % smoke_val
	else:
		status_label.text = ""
		
	_update_color()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		cell_clicked.emit(self)

func _draw() -> void:
	if is_obstacle:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.3, 1.0), false, 2.0)
		draw_line(Vector2.ZERO, size, Color(0.3, 0.3, 0.3, 1.0), 2.0)
		draw_line(Vector2(size.x, 0), Vector2(0, size.y), Color(0.3, 0.3, 0.3, 1.0), 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.85, 0.85, 1.0), false, 2.0)
