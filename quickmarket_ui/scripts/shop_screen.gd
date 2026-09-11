class_name ShopScreen
extends Control
## Mobile shop/inventory screen: a responsive grid of ItemCards inside a
## ScrollContainer. Fully styled from the theme Dictionary (marketplace_config.json).

signal buy_requested(item_id: String)
signal claim_requested(item_id: String)
signal cancel_requested(item_id: String)
signal selection_changed(item_id: String)

## Special category tab that shows the player's cart: items with status "in_cart"
## (to claim) and the player's own active listings (to cancel).
const CART_CATEGORY := "cart"

var ui_theme := {}

var _items: Array = []
var _cards := {}
var _selected_id := ""
var _active_category := "all"
var _cat_buttons := {}
var _show_cart := false

var _background: Panel
var _title_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty_label: Label
var _category_col: VBoxContainer


func _ready() -> void:
	_build()
	_apply_theme()


func configure(t: Dictionary) -> void:
	ui_theme = t
	if is_inside_tree():
		_apply_theme()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_background = Panel.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ---- Shop area (top, expands) ----
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	v.add_child(_title_label)

	# Body: category column (left) + scrollable card grid (right)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)

	var cat_cfg: Dictionary = ui_theme.get("shop", {}).get("categories", {})
	var cat_width: int = int(cat_cfg.get("width", 84))
	_category_col = VBoxContainer.new()
	_category_col.custom_minimum_size = Vector2(cat_width, 0)
	_category_col.add_theme_constant_override("separation", 4)
	body.add_child(_category_col)
	_build_categories(cat_cfg)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_label.add_theme_font_size_override("font_size", 18)
	margin.add_child(_empty_label)


func _apply_theme() -> void:
	_background.add_theme_stylebox_override("panel", ShopTheme.background_style(ui_theme))
	_title_label.text = ui_theme.get("texts", {}).get("title", "Shop")
	_title_label.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_title"))
	_empty_label.text = ui_theme.get("texts", {}).get("empty_message", "No items available")
	_empty_label.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_subtitle"))
	_update_category_visual()


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
	_rebuild_grid()
	_update_category_visual()


func _cat_style(colors: Dictionary, sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colors.get("bg_selected" if sel else "bg", "#3a3a3a"))
	sb.set_corner_radius_all(4)
	return sb


func _update_category_visual() -> void:
	var cat_cfg: Dictionary = ui_theme.get("shop", {}).get("categories", {})
	var colors: Dictionary = cat_cfg.get("colors", {})
	for cat in _cat_buttons:
		var btn: Button = _cat_buttons[cat]
		var sel: bool = cat == _active_category
		btn.add_theme_stylebox_override("normal", _cat_style(colors, sel))
		btn.add_theme_stylebox_override("hover", _cat_style(colors, sel))
		btn.add_theme_stylebox_override("pressed", _cat_style(colors, true))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(colors.get("text_selected" if sel else "text", "#cfcfcf")))


func set_items(items: Array) -> void:
	_items = items.duplicate()
	_selected_id = ""
	_refresh_categories_from_items()
	_rebuild_grid()


func add_item(item: Dictionary) -> void:
	var id: String = item.get("id", "")
	if _cards.has(id):
		return
	_items.append(item)
	_refresh_categories_from_items()
	_rebuild_grid()


func remove_item(id: String) -> void:
	_items = _items.filter(func(it): return it.get("id", "") != id)
	if _selected_id == id:
		_selected_id = ""
	_refresh_categories_from_items()
	_rebuild_grid()


## Rebuild the category column from the categories actually present in the
## loaded items (item["category"]), instead of the list from the config file.
## "all" is always first. Falls back to the config list when no item has a category.
func _refresh_categories_from_items() -> void:
	var cats: Array = []
	for it in _items:
		if it.has("_cart_type"):
			continue  # cart items belong to the cart tab, not to a normal category
		var c: String = str(it.get("category", "")).strip_edges()
		if c != "" and not cats.has(c):
			cats.append(c)
	if cats.is_empty() and not _show_cart:
		return
	set_categories(cats)


## Whether an item is visible under the currently active category tab.
func _matches_filter(item: Dictionary) -> bool:
	var is_cart: bool = item.has("_cart_type")
	if _active_category == CART_CATEGORY:
		return is_cart
	if is_cart:
		return false  # cart items only appear in the cart tab
	if _active_category == "all":
		return true
	return str(item.get("category", "")) == _active_category


## Show/hide the special "cart" category tab (in_cart items + own listings).
func set_show_cart(show: bool) -> void:
	if _show_cart == show:
		return
	_show_cart = show
	_refresh_categories_from_items()


func is_cart_shown() -> bool:
	return _show_cart


## Replace the category buttons with [categories] (plus "all", and "cart" when enabled).
## Useful when the developer wants to set the categories explicitly.
func set_categories(categories: Array) -> void:
	var cats: Array = ["all"]
	for c in categories:
		var cs: String = str(c).strip_edges()
		if cs != "" and not cats.has(cs):
			cats.append(cs)
	if _show_cart and not cats.has(CART_CATEGORY):
		cats.append(CART_CATEGORY)

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


func _rebuild_grid() -> void:
	for card in _cards.values():
		card.queue_free()
	_cards.clear()

	for item in _items:
		if not _matches_filter(item):
			continue
		var card := ItemCard.new()
		_grid.add_child(card)
		card.setup(item, ui_theme)
		card.card_selected.connect(_on_card_selected)
		card.action_pressed.connect(_on_card_action)
		_cards[item.get("id", "")] = card

	var has := _cards.size() > 0
	_grid.visible = has
	_empty_label.visible = not has


func _on_card_selected(card: ItemCard) -> void:
	_selected_id = card.item.get("id", "")
	for id in _cards:
		_cards[id].set_selected(id == _selected_id)
	selection_changed.emit(_selected_id)


func _on_card_action(action: String, card: ItemCard) -> void:
	var id: String = card.item.get("id", "")
	match action:
		ItemCard.ACTION_CLAIM:  claim_requested.emit(id)
		ItemCard.ACTION_CANCEL: cancel_requested.emit(id)
		_:                      buy_requested.emit(id)
