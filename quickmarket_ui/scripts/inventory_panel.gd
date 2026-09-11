class_name InventoryPanel
extends Control
## A bottom inventory grid: 5 columns of slots, each showing an item icon and an
## optional stack count. Styled from the "inventory" block of marketplace_config.json.

signal slot_selected(slot_index: int, item: Dictionary)
signal action_pressed(action: String, item: Dictionary)

var ui_theme := {}

var _cfg := {}
var _slots := {}
var _icons := {}
var _counts := {}
var _lvls := {}
var _items := {}
var _selected := -1
var _selected_id := ""
var _all_items: Array = []
var _active_category := "all"
var _cat_buttons := {}

var _header_bar: Panel
var _header: Label
var _meta: Label
var _desc: Label
var _actions: HBoxContainer
var _head_margin: MarginContainer
var _action_buttons := {}
var _category_col: VBoxContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _background: Panel


func _ready() -> void:
	_build()


func configure(t: Dictionary) -> void:
	ui_theme = t
	_cfg = t.get("inventory", {})
	if is_inside_tree():
		_apply_size_from_config()
		_apply_header_height()
		_apply_theme()


## Set the panel's minimum height from the config (header + visible rows + padding).
func _apply_size_from_config() -> void:
	var slot_size: int = int(_cfg.get("slot_size", 96))
	var rows: int = int(_cfg.get("rows_visible", 3))
	var header_h: int = int(_cfg.get("header_height", 128))
	var pad := 8
	custom_minimum_size = Vector2(0, header_h + rows * slot_size + pad * 2)


## Lock the selected-item info frame to an exact fixed height (header_height),
## so it never grows or shrinks with the item's text.
func _apply_header_height() -> void:
	if _header_bar == null:
		return
	var header_h: int = int(_cfg.get("header_height", 128))
	_header_bar.custom_minimum_size = Vector2(0, header_h)
	_header_bar.custom_maximum_size = Vector2(INF, header_h)


func _build() -> void:
	_cfg = ui_theme.get("inventory", {})
	var slot_size: int = int(_cfg.get("slot_size", 96))
	var rows: int = int(_cfg.get("rows_visible", 3))
	var header_h: int = int(_cfg.get("header_height", 128))
	var cols: int = int(_cfg.get("columns", 5))
	var pad := 8
	_apply_size_from_config()

	_background = Panel.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Header bar (shows the inventory title or the selected item's info + actions).
	# A plain Panel (not PanelContainer) so the frame NEVER grows with content:
	# it keeps its fixed header_height even when the action buttons appear.
	_header_bar = Panel.new()
	_header_bar.clip_contents = true
	_header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head_margin := MarginContainer.new()
	head_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	head_margin.add_theme_constant_override("margin_left", 6)
	head_margin.add_theme_constant_override("margin_top", 2)
	head_margin.add_theme_constant_override("margin_right", 6)
	head_margin.add_theme_constant_override("margin_bottom", 4)
	_head_margin = head_margin
	_header_bar.add_child(head_margin)
	var head_v := VBoxContainer.new()
	head_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	head_v.add_theme_constant_override("separation", 2)
	head_margin.add_child(head_v)

	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head_v.add_child(_header)

	_meta = Label.new()
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head_v.add_child(_meta)

	_desc = Label.new()
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head_v.add_child(_desc)

	root.add_child(_header_bar)
	_apply_header_height()

	# Floating bottom action bar: the action buttons are detached from the info
	# header and float at the bottom of the panel, always visible (unusable ones
	# are greyed out). This way the info frame never changes size.
	_build_action_bar()

	# Body: category column (left) + scrollable grid
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	var cat_cfg: Dictionary = _cfg.get("categories", {})
	var cat_width: int = int(cat_cfg.get("width", 84))
	_category_col = VBoxContainer.new()
	_category_col.custom_minimum_size = Vector2(cat_width, 0)
	_category_col.add_theme_constant_override("separation", 4)
	body.add_child(_category_col)
	_build_categories(cat_cfg)

	# Scrollable grid
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	var grid_wrap := MarginContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_wrap.add_theme_constant_override("margin_left", pad)
	grid_wrap.add_theme_constant_override("margin_right", pad)
	grid_wrap.add_theme_constant_override("margin_top", pad)
	grid_wrap.add_theme_constant_override("margin_bottom", pad)
	_scroll.add_child(grid_wrap)

	_grid = GridContainer.new()
	_grid.columns = cols
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	grid_wrap.add_child(_grid)

	var total := rows * cols
	for i in total:
		_grid.add_child(_make_slot(i, slot_size))

	_apply_theme()


func _make_slot(index: int, cell: int) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(0, cell)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.focus_mode = Control.FOCUS_NONE
	slot.button_down.connect(func(): _on_slot_pressed(index))
	slot.add_theme_stylebox_override("normal", _slot_style(false))
	slot.add_theme_stylebox_override("hover", _slot_style(false))
	slot.add_theme_stylebox_override("pressed", _slot_style(true))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -cell * 0.34
	icon.offset_top = -cell * 0.34
	icon.offset_right = cell * 0.34
	icon.offset_bottom = cell * 0.34
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	slot.add_child(icon)

	var count := Label.new()
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -cell * 0.4
	count.offset_top = -cell * 0.4
	count.offset_right = -5
	count.offset_bottom = -3
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.visible = false
	count.add_theme_font_size_override("font_size", 15)
	slot.add_child(count)

	var lvl := Label.new()
	lvl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lvl.offset_left = 4
	lvl.offset_top = 2
	lvl.offset_right = cell * 0.65
	lvl.offset_bottom = cell * 0.3
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lvl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lvl.visible = false
	lvl.add_theme_font_size_override("font_size", 13)
	lvl.add_theme_color_override("font_color", Color.WHITE)
	slot.add_child(lvl)

	_slots[index] = slot
	_icons[index] = icon
	_counts[index] = count
	_lvls[index] = lvl
	return slot


func _slot_style(selected: bool, rarity_key := "") -> StyleBoxFlat:
	var colors: Dictionary = _cfg.get("colors", {})
	var rar: Dictionary = _cfg.get("rarities", {})
	var base: Color
	if rarity_key != "" and rar.has(rarity_key):
		base = Color(rar.get(rarity_key, {}).get("color", "#c8ccd8"))
	else:
		base = Color(colors.get("selected_slot" if selected else "slot", "#292929"))
	base = base.lightened(0.30) if selected else base.darkened(0.45)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	var border: Color = Color(colors.get("slot_border", "#3a3a3a"))
	if selected:
		border = Color(rar.get(rarity_key, {}).get("color", "#3a3a3a")) if (rarity_key != "" and rar.has(rarity_key)) else Color(colors.get("selected_slot", "#e9703e"))
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(_cfg.get("slot_radius", 8)))
	return sb


func _build_categories(cat_cfg: Dictionary) -> void:
	var list: Array = cat_cfg.get("list", ["weapon", "armor", "item", "other"])
	var cats: Array = ["all"]
	cats.append_array(list)
	for cat in cats:
		var btn := Button.new()
		btn.text = cat
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func(): _on_category_pressed(cat))
		_category_col.add_child(btn)
		_cat_buttons[cat] = btn
	_update_category_visual()


func _on_category_pressed(cat: String) -> void:
	_active_category = cat
	_rebuild(true)
	_update_category_visual()


func _cat_style(colors: Dictionary, sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colors.get("bg_selected" if sel else "bg", "#3a3a3a"))
	sb.set_corner_radius_all(4)
	return sb


func _update_category_visual() -> void:
	var cat_cfg: Dictionary = _cfg.get("categories", {})
	var colors: Dictionary = cat_cfg.get("colors", {})
	for cat in _cat_buttons:
		var btn: Button = _cat_buttons[cat]
		var sel: bool = cat == _active_category
		btn.add_theme_stylebox_override("normal", _cat_style(colors, sel))
		btn.add_theme_stylebox_override("hover", _cat_style(colors, sel))
		btn.add_theme_stylebox_override("pressed", _cat_style(colors, true))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(colors.get("text_selected" if sel else "text", "#cfcfcf")))


func _build_action_bar() -> void:
	var a_cfg: Dictionary = _cfg.get("actions", {})
	var h: int = int(a_cfg.get("height", 30))
	var pad: int = int(a_cfg.get("bar_padding", 8))
	if _header_bar == null:
		return
	# The buttons float at the bottom of the selected-item frame with NO
	# background bar — each button keeps only its own background.
	_actions = HBoxContainer.new()
	_actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_actions.offset_top = -h - pad
	_actions.offset_bottom = -pad
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 8)
	_header_bar.add_child(_actions)
	_build_actions()
	# Reserve space in the info area so text sits above the floating buttons.
	if _head_margin != null:
		_head_margin.offset_bottom = -(h + pad)


func _build_actions() -> void:
	var cfg: Dictionary = _cfg.get("actions", {})
	var list: Array = cfg.get("list", [
		{"key": "sell", "text": "Sell"},
		{"key": "equip", "text": "Equip"},
		{"key": "listing", "text": "Listing"},
		{"key": "delete", "text": "Delete"}
	])
	var h: int = int(cfg.get("height", 30))
	for a in list:
		var key: String = a.get("key", "")
		var text: String = a.get("text", key)
		var btn := Button.new()
		btn.text = text
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, h)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func(): _on_action_pressed(key))
		_actions.add_child(btn)
		_action_buttons[key] = btn


func _on_action_pressed(key: String) -> void:
	action_pressed.emit(key, _selected_item())


func _action_style(colors: Dictionary, key: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colors.get(key, "#3d3d3d"))
	sb.set_corner_radius_all(6)
	sb.set_content_margin(SIDE_LEFT, 12)
	sb.set_content_margin(SIDE_RIGHT, 12)
	return sb


func _apply_actions_theme() -> void:
	var cfg: Dictionary = _cfg.get("actions", {})
	var colors: Dictionary = cfg.get("colors", {})
	for key in _action_buttons:
		var btn: Button = _action_buttons[key]
		btn.add_theme_stylebox_override("normal", _action_style(colors, "bg"))
		btn.add_theme_stylebox_override("hover", _action_style(colors, "bg_hover"))
		btn.add_theme_stylebox_override("pressed", _action_style(colors, "bg_pressed"))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var dsc := StyleBoxFlat.new()
		dsc.bg_color = Color(colors.get("bg_disabled", "#2b2b2b"))
		dsc.set_corner_radius_all(6)
		dsc.set_content_margin(SIDE_LEFT, 12)
		dsc.set_content_margin(SIDE_RIGHT, 12)
		btn.add_theme_stylebox_override("disabled", dsc)
		btn.add_theme_color_override("font_color", Color(colors.get("text", "#ffffff")))
		btn.add_theme_color_override("font_disabled_color", Color(colors.get("text_disabled", "#777777")))
		btn.add_theme_font_size_override("font_size", 14)


func _apply_theme() -> void:
	var colors: Dictionary = _cfg.get("colors", {})
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(colors.get("background", "#1e1e1e"))
	_background.add_theme_stylebox_override("panel", panel)

	var header := StyleBoxFlat.new()
	header.bg_color = Color(colors.get("header_bg", "#707070"))
	header.set_content_margin_all(4)
	_header_bar.add_theme_stylebox_override("panel", header)

	_header.text = _cfg.get("texts", {}).get("header_title", "Inventory")
	_header.add_theme_color_override("font_color", Color(colors.get("header_text", "#e9703e")))
	_header.add_theme_font_size_override("font_size", 18)

	_meta.add_theme_color_override("font_color", Color(colors.get("header_text", "#e9703e")).lightened(0.15))
	_meta.add_theme_font_size_override("font_size", 13)

	_desc.add_theme_color_override("font_color", Color(colors.get("header_text", "#e9703e")).lightened(0.35))
	_desc.add_theme_font_size_override("font_size", 13)

	for i in _counts:
		var count: Label = _counts[i]
		count.add_theme_color_override("font_color", Color(colors.get("count_text", "#ffffff")))
		count.add_theme_color_override("font_outline_color", Color(colors.get("count_outline", "#000000")))
		count.add_theme_constant_override("outline_size", 3)
		var lvl: Label = _lvls[i]
		lvl.add_theme_color_override("font_color", Color.WHITE)
		lvl.add_theme_color_override("font_outline_color", Color(colors.get("count_outline", "#000000")))
		lvl.add_theme_constant_override("outline_size", 2)

	_update_category_visual()
	_apply_actions_theme()
	_apply_header_style("")


## Replace the whole inventory with the given item list (category filter applies).
func set_inventory(items: Array) -> void:
	_all_items = []
	for item in items:
		_all_items.append(item)
	_refresh_categories_from_items()
	_rebuild()


## Add an item; stacks on an existing same-id (or same-name) item or appends it.
func add_item(item: Dictionary) -> void:
	var id: String = item.get("id", "")
	var item_name: String = item.get("name", "")
	for it in _all_items:
		if not it.is_empty():
			var same: bool = (id != "" and it.get("id", "") == id) or (item_name != "" and it.get("name", "") == item_name)
			if same:
				it["count"] = int(it.get("count", 1)) + int(item.get("count", 1))
				_refresh_categories_from_items()
				_rebuild()
				return
	var copy := {}
	for k in item:
		copy[k] = item[k]
	copy["count"] = int(copy.get("count", 1))
	_all_items.append(copy)
	_refresh_categories_from_items()
	_rebuild()


## Remove one unit; drops the item when the count reaches 0.
func remove_item(id: String, amount := 1) -> void:
	for it in _all_items:
		if not it.is_empty() and it.get("id", "") == id:
			it["count"] = int(it.get("count", 1)) - amount
			if int(it["count"]) <= 0:
				_all_items.erase(it)
			_refresh_categories_from_items()
			_rebuild()
			return


func clear_inventory() -> void:
	set_inventory([])


## Rebuild the category column from the categories actually present in the
## inventory items (item["category"]), instead of the list from the config file.
## "all" is always first. Falls back to the config list when no item has a category.
func _refresh_categories_from_items() -> void:
	var cats: Array = []
	for item in _all_items:
		var c: String = str(item.get("category", "")).strip_edges()
		if c != "" and not cats.has(c):
			cats.append(c)
	if cats.is_empty():
		return
	set_categories(cats)


## Replace the category buttons with [categories] (plus "all").
## Useful when the developer wants to set the categories explicitly.
func set_categories(categories: Array) -> void:
	var cats: Array = ["all"]
	for c in categories:
		var cs: String = str(c).strip_edges()
		if cs != "" and not cats.has(cs):
			cats.append(cs)

	# Reset the active filter if it no longer exists
	if not cats.has(_active_category):
		_active_category = "all"

	for btn in _category_col.get_children():
		btn.queue_free()
	_cat_buttons.clear()

	for cat in cats:
		var btn := Button.new()
		btn.text = cat
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func(): _on_category_pressed(cat))
		_category_col.add_child(btn)
		_cat_buttons[cat] = btn
	_update_category_visual()


## Re-render the visible slots from _all_items filtered by the active category.
## When keep_selection is true (tab switch), the currently selected item stays
## selected even if it is filtered out of view.
func _rebuild(keep_selection := false) -> void:
	for i in _slots:
		_set_slot(i, {})
	var idx := 0
	var sel_visible := -1
	for item in _all_items:
		if _active_category != "all" and item.get("category", "") != _active_category:
			continue
		if idx >= _slots.size():
			break
		_set_slot(idx, item)
		if keep_selection and _selected_id != "" and item.get("id", "") == _selected_id:
			sel_visible = idx
		idx += 1
	if keep_selection and _selected_id != "":
		_selected = sel_visible
		_update_header(_selected_item())
	else:
		_selected = -1
		var first: Dictionary = _items.get(0, {})
		_selected_id = first.get("id", "")
		_update_header(first)
	_apply_selected_visual()


func _set_slot(index: int, item: Dictionary) -> void:
	_items[index] = item
	var icon: TextureRect = _icons[index]
	var count: Label = _counts[index]
	var lvl: Label = _lvls[index]
	if item.is_empty():
		icon.visible = false
		count.visible = false
		lvl.visible = false
	else:
		icon.texture = ShopTheme.item_icon(ui_theme, item)
		icon.visible = icon.texture != null
		var c := int(item.get("count", 1))
		count.visible = c > 1
		count.text = str(c)
		var lv := int(item.get("level", 0))
		lvl.visible = lv > 0
		lvl.text = "Lv %d" % lv
	_apply_selected_visual()


func _on_slot_pressed(index: int) -> void:
	var item: Dictionary = _items.get(index, {})
	_selected = index
	_selected_id = item.get("id", "")
	_apply_selected_visual()
	_update_header(item)
	slot_selected.emit(index, item)


func _selected_item() -> Dictionary:
	if _selected_id == "":
		return {}
	for it in _all_items:
		if it.get("id", "") == _selected_id:
			return it
	return {}


func _update_header(item: Dictionary = {}) -> void:
	if item.is_empty():
		_header.text = _cfg.get("texts", {}).get("header_title", "Inventory")
		_meta.visible = false
		_desc.visible = false
		_apply_header_style("")
	else:
		var item_name: String = item.get("name", "")
		var desc: String = item.get("description", "")
		var rk: String = ShopTheme.rarity_key(item)
		_header.text = item_name
		_header.add_theme_color_override("font_color", ShopTheme.rarity_color(ui_theme, rk).lightened(0.25))
		var parts: Array = []
		var lv := int(item.get("level", 0))
		if lv > 0:
			parts.append("Lv %d" % lv)
		var dmg = item.get("damage", 0.0)
		if dmg != 0.0:
			parts.append("Sát thương %d" % int(dmg))
		var c := int(item.get("count", 1))
		if c > 1:
			parts.append("x%d" % c)
		_meta.text = "  •  ".join(PackedStringArray(parts))
		_meta.visible = not parts.is_empty()
		_desc.text = desc
		_desc.visible = desc != ""
		_desc.tooltip_text = desc  # full text on hover / long-press
		_apply_header_style(rk)
	# Buttons are ALWAYS shown so the frame never changes size; unusable ones are greyed out.
	_actions.visible = true
	_update_action_states(item)


## Enable/disable the action buttons. With no selected item all are greyed out;
## a per-item "disabled_actions" array can grey out specific buttons (e.g. an
## already-equipped item disabling "Equip"). The row stays visible either way.
func _update_action_states(item: Dictionary = {}) -> void:
	var has_item: bool = not item.is_empty()
	var disabled_list: Array = item.get("disabled_actions", []) if has_item else []
	for key in _action_buttons:
		var btn: Button = _action_buttons[key]
		btn.disabled = (not has_item) or (key in disabled_list)


## Tint the selected-item info frame by rarity (neutral when no item).
func _apply_header_style(rarity_key: String) -> void:
	var colors: Dictionary = _cfg.get("colors", {})
	var rar: Dictionary = _cfg.get("rarities", {})
	var header := StyleBoxFlat.new()
	var base: Color = Color(colors.get("header_bg", "#707070"))
	if rarity_key != "" and rar.has(rarity_key):
		var rc: Color = Color(rar.get(rarity_key, {}).get("color", "#707070"))
		base = base.lerp(rc, 0.4)
	header.bg_color = base
	header.set_content_margin_all(4)
	_header_bar.add_theme_stylebox_override("panel", header)


func _apply_selected_visual() -> void:
	for i in _slots:
		var slot: Button = _slots[i]
		var item: Dictionary = _items.get(i, {})
		var is_sel: bool = (i == _selected) and not item.is_empty()
		var rk: String = ShopTheme.rarity_key(item) if not item.is_empty() else ""
		slot.add_theme_stylebox_override("normal", _slot_style(is_sel, rk))
		slot.add_theme_stylebox_override("pressed", _slot_style(i == _selected, rk))
