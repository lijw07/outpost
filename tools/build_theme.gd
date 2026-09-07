extends SceneTree

const THEME_PATH := "res://assets/ui/outpost_theme.tres"
const FONT_PATH := "res://assets/ui/font/outpost_pixel.ttf"

const FONT_SIZE_BODY := 28
const FONT_SIZE_SECTION := 38
const FONT_SIZE_HEADING := 52
const FONT_SIZE_TITLE := 76
const WIDGETS := "res://assets/ui/widgets/"
const ICONS := "res://assets/ui/icons/"
const PANELS := "res://assets/ui/panels/"

const CREAM := Color("f7e3b0")
const GOLD := Color("ffb545")
const MUTED := Color("7d7768")
const INK := Color("11131a")

func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = load(FONT_PATH)
	theme.default_font_size = FONT_SIZE_BODY

	_setup_button(theme, "Button")
	_setup_button(theme, "OptionButton")
	theme.set_icon("arrow", "OptionButton", load(ICONS + "icon_arrow_down.png"))
	theme.set_constant("arrow_margin", "OptionButton", 12)

	theme.set_stylebox("panel", "Panel", _panel_box())
	theme.set_stylebox("panel", "PanelContainer", _panel_box())

	_setup_slider(theme)
	_setup_checkbox(theme)
	_setup_progress(theme)
	_setup_plates(theme)
	_setup_line_edit(theme)
	_setup_labels(theme)
	_setup_label_variations(theme)
	_setup_scrollbars(theme)
	_setup_popup_menu(theme)
	_setup_dropdown(theme)

	var err := ResourceSaver.save(theme, THEME_PATH)
	print("theme saved: ", error_string(err))
	quit()

func _texture_box(path: String, margin: int, content: int, modulate := Color.WHITE, content_v := -1) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content
	box.content_margin_right = content
	var vertical := float(content_v) if content_v >= 0 else content * 0.6
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	box.modulate_color = modulate
	return box

func _panel_box() -> StyleBoxTexture:
	return _texture_box(PANELS + "panel_square.png", 46, 58, Color.WHITE, 54)

func _setup_button(theme: Theme, type: String) -> void:
	theme.set_stylebox("normal", type, _texture_box(WIDGETS + "button_wide_normal.png", 26, 22))
	theme.set_stylebox("hover", type, _texture_box(WIDGETS + "button_wide_hover.png", 26, 22))
	theme.set_stylebox("pressed", type, _texture_box(WIDGETS + "button_wide_hover.png", 26, 22, Color(0.62, 0.62, 0.62)))
	theme.set_stylebox("focus", type, _texture_box(WIDGETS + "button_wide_hover.png", 26, 22))
	theme.set_stylebox("disabled", type, _texture_box(WIDGETS + "button_wide_normal.png", 26, 22, Color(0.55, 0.57, 0.6)))
	theme.set_color("font_color", type, CREAM)
	theme.set_color("font_hover_color", type, GOLD)
	theme.set_color("font_pressed_color", type, GOLD)
	theme.set_color("font_focus_color", type, GOLD)
	theme.set_color("font_disabled_color", type, MUTED)

func _setup_slider(theme: Theme) -> void:
	var track := StyleBoxTexture.new()
	track.texture = load(WIDGETS + "slider_track_mid.png")
	track.texture_margin_left = 18
	track.texture_margin_right = 18
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	var fill := StyleBoxTexture.new()
	fill.texture = load(WIDGETS + "slider_fill.png")
	fill.texture_margin_left = 16
	fill.texture_margin_right = 16
	fill.content_margin_top = 11
	fill.content_margin_bottom = 11
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_icon("grabber", "HSlider", load(WIDGETS + "slider_grabber.png"))
	theme.set_icon("grabber_highlight", "HSlider", load(WIDGETS + "slider_grabber_hover.png"))
	theme.set_icon("grabber_disabled", "HSlider", load(WIDGETS + "slider_grabber.png"))
	theme.set_constant("center_grabber", "HSlider", 1)

func _setup_checkbox(theme: Theme) -> void:
	theme.set_icon("checked", "CheckBox", load(WIDGETS + "checkbox_checked.png"))
	theme.set_icon("unchecked", "CheckBox", load(WIDGETS + "checkbox_unchecked.png"))
	theme.set_icon("checked_disabled", "CheckBox", load(WIDGETS + "checkbox_checked.png"))
	theme.set_icon("unchecked_disabled", "CheckBox", load(WIDGETS + "checkbox_unchecked.png"))
	theme.set_icon("radio_checked", "CheckBox", load(WIDGETS + "checkbox_checked.png"))
	theme.set_icon("radio_unchecked", "CheckBox", load(WIDGETS + "checkbox_unchecked.png"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	theme.set_color("font_color", "CheckBox", CREAM)
	theme.set_color("font_hover_color", "CheckBox", GOLD)

func _setup_progress(theme: Theme) -> void:
	var background := StyleBoxTexture.new()
	background.texture = load(WIDGETS + "slider_track_mid.png")
	background.texture_margin_left = 18
	background.texture_margin_right = 18
	background.content_margin_top = 16
	background.content_margin_bottom = 16
	var fill := StyleBoxTexture.new()
	fill.texture = load(WIDGETS + "slider_fill.png")
	fill.texture_margin_left = 16
	fill.texture_margin_right = 16
	fill.content_margin_top = 13
	fill.content_margin_bottom = 13
	theme.set_stylebox("background", "ProgressBar", background)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", CREAM)

func _setup_plates(theme: Theme) -> void:
	theme.set_type_variation("TitlePlate", "PanelContainer")
	theme.set_stylebox("panel", "TitlePlate",
		_texture_box(PANELS + "panel_banner.png", 34, 44, Color.WHITE, 30))
	theme.set_type_variation("MenuPlate", "PanelContainer")
	theme.set_stylebox("panel", "MenuPlate",
		_texture_box(PANELS + "panel_square_blood_light.png", 46, 54, Color.WHITE, 48))

func _setup_dropdown(theme: Theme) -> void:
	theme.set_type_variation("DropdownToggle", "Button")
	theme.set_icon("arrow", "DropdownToggle", load(ICONS + "icon_arrow_down.png"))
	theme.set_type_variation("DropdownList", "PanelContainer")
	theme.set_stylebox("panel", "DropdownList",
		_texture_box(WIDGETS + "button_wide_normal.png", 26, 14, Color.WHITE, 12))
	theme.set_type_variation("DropdownRow", "Button")
	theme.set_stylebox("normal", "DropdownRow", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "DropdownRow", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "DropdownRow", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "DropdownRow", _texture_box(WIDGETS + "button_wide_hover.png", 26, 16, Color.WHITE, 4))
	theme.set_stylebox("pressed", "DropdownRow", _texture_box(WIDGETS + "button_wide_hover.png", 26, 16, Color(0.62, 0.62, 0.62), 4))
	theme.set_color("font_color", "DropdownRow", CREAM)
	theme.set_color("font_hover_color", "DropdownRow", GOLD)
	theme.set_color("font_pressed_color", "DropdownRow", GOLD)
	theme.set_type_variation("DropdownRowCurrent", "Button")
	theme.set_stylebox("normal", "DropdownRowCurrent", _texture_box(WIDGETS + "button_wide_hover.png", 26, 16, Color(0.74, 0.74, 0.74), 4))
	theme.set_stylebox("disabled", "DropdownRowCurrent", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "DropdownRowCurrent", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "DropdownRowCurrent", _texture_box(WIDGETS + "button_wide_hover.png", 26, 16, Color.WHITE, 4))
	theme.set_stylebox("pressed", "DropdownRowCurrent", _texture_box(WIDGETS + "button_wide_hover.png", 26, 16, Color(0.62, 0.62, 0.62), 4))
	theme.set_color("font_color", "DropdownRowCurrent", GOLD)
	theme.set_color("font_hover_color", "DropdownRowCurrent", GOLD)
	theme.set_color("font_pressed_color", "DropdownRowCurrent", GOLD)

func _setup_popup_menu(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _texture_box(WIDGETS + "button_wide_normal.png", 26, 14, Color.WHITE, 14))
	theme.set_stylebox("hover", "PopupMenu", _texture_box(WIDGETS + "button_wide_hover.png", 26, 14, Color.WHITE, 6))
	theme.set_stylebox("separator", "PopupMenu", StyleBoxEmpty.new())
	theme.set_font("font", "PopupMenu", load(FONT_PATH))
	theme.set_font_size("font_size", "PopupMenu", FONT_SIZE_BODY)
	theme.set_color("font_color", "PopupMenu", CREAM)
	theme.set_color("font_hover_color", "PopupMenu", GOLD)
	theme.set_color("font_disabled_color", "PopupMenu", MUTED)
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_color("font_shadow_color", "PopupMenu", INK)
	theme.set_constant("shadow_offset_x", "PopupMenu", 3)
	theme.set_constant("shadow_offset_y", "PopupMenu", 3)
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)
	theme.set_icon("radio_checked", "PopupMenu", load(ICONS + "icon_marker.png"))
	theme.set_icon("radio_unchecked", "PopupMenu", load(ICONS + "icon_blank.png"))
	theme.set_icon("checked", "PopupMenu", load(ICONS + "icon_marker.png"))
	theme.set_icon("unchecked", "PopupMenu", load(ICONS + "icon_blank.png"))

func _setup_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _texture_box(WIDGETS + "button_wide_normal.png", 26, 22))
	theme.set_stylebox("focus", "LineEdit", _texture_box(WIDGETS + "button_wide_hover.png", 26, 22))
	theme.set_stylebox("read_only", "LineEdit", _texture_box(WIDGETS + "button_wide_normal.png", 26, 22, Color(0.55, 0.57, 0.6)))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("font_selected_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", GOLD)
	theme.set_color("caret_color", "LineEdit", GOLD)

func _setup_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_shadow_color", "Label", INK)
	theme.set_constant("shadow_offset_x", "Label", 3)
	theme.set_constant("shadow_offset_y", "Label", 3)
	theme.set_color("default_color", "RichTextLabel", CREAM)
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

func _setup_label_variations(theme: Theme) -> void:
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", load(FONT_PATH))
	theme.set_font_size("font_size", "TitleLabel", FONT_SIZE_TITLE)
	theme.set_color("font_color", "TitleLabel", CREAM)
	theme.set_color("font_shadow_color", "TitleLabel", INK)
	theme.set_constant("shadow_offset_x", "TitleLabel", 6)
	theme.set_constant("shadow_offset_y", "TitleLabel", 6)
	theme.set_type_variation("SectionLabel", "Label")
	theme.set_font("font", "SectionLabel", load(FONT_PATH))
	theme.set_font_size("font_size", "SectionLabel", FONT_SIZE_SECTION)
	theme.set_color("font_color", "SectionLabel", GOLD)
	theme.set_color("font_shadow_color", "SectionLabel", INK)
	theme.set_constant("shadow_offset_x", "SectionLabel", 3)
	theme.set_constant("shadow_offset_y", "SectionLabel", 3)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", load(FONT_PATH))
	theme.set_font_size("font_size", "HeadingLabel", FONT_SIZE_HEADING)
	theme.set_color("font_color", "HeadingLabel", CREAM)
	theme.set_color("font_shadow_color", "HeadingLabel", INK)
	theme.set_constant("shadow_offset_x", "HeadingLabel", 4)
	theme.set_constant("shadow_offset_y", "HeadingLabel", 4)

func _setup_scrollbars(theme: Theme) -> void:
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.06, 0.07, 0.08, 0.85)
	trough.set_content_margin_all(4)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.42, 0.34, 0.18)
	var grabber_hi := StyleBoxFlat.new()
	grabber_hi.bg_color = GOLD
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, trough)
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, grabber_hi)
		theme.set_stylebox("grabber_pressed", type, grabber_hi)
