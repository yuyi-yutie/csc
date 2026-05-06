extends Button

var w_key: String = ""
var price: int = 0

func _get_drag_data(at_position: Vector2) -> Variant:
	if disabled or w_key == "":
		return null
		
	var preview = TextureRect.new()
	var ic = get_node_or_null("IconCenter/WeaponIcon")
	if ic and ic.texture:
		preview.texture = ic.texture
		
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(80, 40)
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0
	
	set_drag_preview(c)
	return {"type": "weapon", "w_key": w_key, "price": price}
