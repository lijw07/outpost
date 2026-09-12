@tool
extends RefCounted

static func label(value: String, variant: StringName = &"") -> Label:
	var node := Label.new()
	node.text = value
	node.theme_type_variation = variant
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(value: String, action: Callable, variant: StringName = &"") -> Button:
	var node := Button.new()
	node.text = value
	node.theme_type_variation = variant
	node.custom_minimum_size.y = 42
	node.pressed.connect(action)
	return node

static func icon(texture: Texture2D, extent: int = 32) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = Vector2.ONE * extent
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func spacer() -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func ignore_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_children(child)
