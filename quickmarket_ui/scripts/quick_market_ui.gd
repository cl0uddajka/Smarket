class_name QuickMarketUI
extends Control
## Reusable mobile shop + inventory component (Godot 4.2+).
##
## Drop this into YOUR OWN scene (instance QuickMarketUI.tscn, or
## QuickMarketUI.new() + add_child). On _ready it reads
## res://marketplace_config.json (or config_path) and builds the shop and/or
## inventory automatically. Then populate with:
##     ui.set_items([...])                 # shop items
##     ui.set_inventory([...])             # inventory items
##
## LAYOUT (ui_theme.layout in marketplace_config.json):
##   shop      occupies the top    shop_height_ratio  of the screen (default 0.5)
##   inventory occupies the bottom inventory_height_ratio (default 0.5)
##   the middle is left free for your own HUD (e.g. character info).
##   Shop is drawn above inventory (shop_z_index > inventory_z_index).
##
## Turn each part ON/OFF:  ui_theme.shop.enabled / ui_theme.inventory.enabled
## (or set_shop_enabled() / set_inventory_enabled()).
## Show / hide at runtime:  open_shop() / close_shop() / open_inventory() / ...

signal buy_requested(item_id: String)
signal claim_requested(item_id: String)
signal cancel_requested(item_id: String)
signal selection_changed(item_id: String)
signal action_pressed(action: String, item: Dictionary)
signal orientation_changed(landscape: bool)

## Path to the config file this component reads. Set before add_child() if your
## config is not at res://marketplace_config.json.
var config_path := "res://marketplace_config.json"
var ui_theme := {}

var _shop: ShopScreen
var _inventory: InventoryPanel
var _shop_items: Array = []
var _inv_items: Array = []
var _shop_ratio := 0.5
var _inv_ratio := 0.5
var _orientation := "portrait"
var _inv_width_ratio := 0.45
var _orientation_button: Button


func _ready() -> void:
	ui_theme = ShopTheme.from_config(config_path)
	resized.connect(_apply_bands)
	_rebuild()
	var parent := get_parent()
	if parent is Control and not (parent is Container):
		parent.resized.connect(_sync_to_parent)
	else:
		var vp := get_viewport()
		if vp != null:
			vp.size_changed.connect(_sync_to_parent)
	call_deferred("_sync_to_parent")


## Reload the config (optionally from a custom path) and rebuild the UI.
func configure(path: String = "") -> void:
	if path != "":
		config_path = path
	ui_theme = ShopTheme.from_config(config_path)
	if is_inside_tree():
		_rebuild()
		call_deferred("_sync_to_parent")


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_shop = null
	_inventory = null
	_build()
	if _shop != null and not _shop_items.is_empty():
		_shop.set_items(_shop_items)
	if _inventory != null and not _inv_items.is_empty():
		_inventory.set_inventory(_inv_items)
	_apply_theme()
	call_deferred("_apply_bands")


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var layout: Dictionary = ui_theme.get("layout", {})
	_shop_ratio = clampf(float(layout.get("shop_height_ratio", 0.5)), 0.05, 0.95)
	_inv_ratio = clampf(float(layout.get("inventory_height_ratio", 0.5)), 0.05, 0.95)
	_inv_width_ratio = clampf(float(layout.get("inventory_width_ratio", 0.45)), 0.1, 0.9)
	_orientation = str(layout.get("orientation", "portrait"))
	if _orientation != "landscape":
		_orientation = "portrait"
	var shop_z: int = int(layout.get("shop_z_index", 10))
	var inv_z: int = int(layout.get("inventory_z_index", 0))

	var shop_on: bool = ui_theme.get("shop", {}).get("enabled", true)
	var inv_on: bool = ui_theme.get("inventory", {}).get("enabled", true)

	if shop_on:
		_shop = ShopScreen.new()
		_shop.z_index = shop_z
		add_child(_shop)
		_shop.buy_requested.connect(func(id: String): buy_requested.emit(id))
		_shop.claim_requested.connect(func(id: String): claim_requested.emit(id))
		_shop.cancel_requested.connect(func(id: String): cancel_requested.emit(id))
		_shop.selection_changed.connect(func(id: String): selection_changed.emit(id))

	if inv_on:
		_inventory = InventoryPanel.new()
		_inventory.z_index = inv_z
		add_child(_inventory)
		_inventory.action_pressed.connect(func(a: String, it: Dictionary): action_pressed.emit(a, it))

	if bool(layout.get("show_orientation_button", true)):
		_build_orientation_button(layout.get("orientation_button", {}))


## Floating button (top-right) that switches portrait <-> landscape.
func _build_orientation_button(btn_cfg: Dictionary) -> void:
	_orientation_button = Button.new()
	_orientation_button.z_index = 100
	_orientation_button.focus_mode = Control.FOCUS_NONE
	_orientation_button.custom_minimum_size = Vector2(0, 34)
	_orientation_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_orientation_button.add_theme_font_size_override("font_size", int(btn_cfg.get("font_size", 14)))
	var colors: Dictionary = btn_cfg.get("colors", {})
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colors.get("bg", "#2c2c3a"))
	sb.set_corner_radius_all(int(btn_cfg.get("radius", 8)))
	sb.set_content_margin(SIDE_LEFT, 12)
	sb.set_content_margin(SIDE_RIGHT, 12)
	_orientation_button.add_theme_stylebox_override("normal", sb)
	_orientation_button.add_theme_stylebox_override("hover", sb)
	_orientation_button.add_theme_stylebox_override("pressed", sb)
	_orientation_button.add_theme_color_override("font_color", Color(colors.get("text", "#ffffff")))
	_orientation_button.pressed.connect(toggle_landscape)
	add_child(_orientation_button)
	_update_orientation_button_text()


## Place the shop and inventory into their bands. Portrait: shop top, inventory
## bottom (middle free for the HUD). Landscape: shop left, inventory right.
func _apply_bands() -> void:
	var w := size.x
	var h := size.y
	if _orientation == "landscape":
		var inv_w := w * _inv_width_ratio
		if _shop != null and _shop.visible:
			_shop.position = Vector2.ZERO
			_shop.size = Vector2(w - inv_w, h)
		if _inventory != null and _inventory.visible:
			_inventory.position = Vector2(w - inv_w, 0)
			_inventory.size = Vector2(inv_w, h)
	else:
		if _shop != null and _shop.visible:
			_shop.position = Vector2.ZERO
			_shop.size = Vector2(w, h * _shop_ratio)
		if _inventory != null and _inventory.visible:
			_inventory.position = Vector2(0, h * (1.0 - _inv_ratio))
			_inventory.size = Vector2(w, h * _inv_ratio)
	if _orientation_button != null and _orientation_button.visible:
		_orientation_button.position = Vector2(w - _orientation_button.size.x - 8, 8)


## Switch to landscape (shop right / inventory left) or back to portrait.
func set_landscape(landscape: bool) -> void:
	var new_mode := "landscape" if landscape else "portrait"
	if _orientation == new_mode:
		return
	_orientation = new_mode
	_update_orientation_button_text()
	_apply_bands()
	orientation_changed.emit(landscape)


func is_landscape() -> bool:
	return _orientation == "landscape"


func toggle_landscape() -> void:
	set_landscape(not is_landscape())


func _update_orientation_button_text() -> void:
	if _orientation_button == null:
		return
	_orientation_button.text = "Ngang ⟲" if _orientation == "landscape" else "Dọc ⟲"


func _apply_theme() -> void:
	if _shop != null:
		_shop.configure(ui_theme)
	if _inventory != null:
		_inventory.configure(ui_theme)


# ---------------- Toggles (enable/disable a section) ----------------

func is_shop_enabled() -> bool:
	return _shop != null


func is_inventory_enabled() -> bool:
	return _inventory != null


func set_shop_enabled(enabled: bool) -> void:
	ui_theme["shop"] = _set_key(ui_theme.get("shop", {}), "enabled", enabled)
	_rebuild()


func set_inventory_enabled(enabled: bool) -> void:
	ui_theme["inventory"] = _set_key(ui_theme.get("inventory", {}), "enabled", enabled)
	_rebuild()


func _set_key(d: Dictionary, k: String, v: Variant) -> Dictionary:
	var out := {}
	for key in d:
		out[key] = d[key]
	out[k] = v
	return out


# ---------------- Open / Close (show or hide, data is kept) ----------------

func open_shop() -> void:
	if _shop != null:
		_shop.visible = true
	_apply_bands()


func close_shop() -> void:
	if _shop != null:
		_shop.visible = false
	_apply_bands()


func toggle_shop() -> void:
	if _shop != null:
		_shop.visible = not _shop.visible
	_apply_bands()


func is_shop_open() -> bool:
	return _shop != null and _shop.visible


func open_inventory() -> void:
	if _inventory != null:
		_inventory.visible = true
	_apply_bands()


func close_inventory() -> void:
	if _inventory != null:
		_inventory.visible = false
	_apply_bands()


func toggle_inventory() -> void:
	if _inventory != null:
		_inventory.visible = not _inventory.visible
	_apply_bands()


func is_inventory_open() -> bool:
	return _inventory != null and _inventory.visible


# ---------------- Shop data ----------------

func set_items(items: Array) -> void:
	_shop_items = items.duplicate()
	if _shop != null:
		_shop.set_items(_shop_items)


func add_item(item: Dictionary) -> void:
	_shop_items.append(item)
	if _shop != null:
		_shop.add_item(item)


func remove_item(id: String) -> void:
	_shop_items = _shop_items.filter(func(it): return it.get("id", "") != id)
	if _shop != null:
		_shop.remove_item(id)


## Set the shop category tabs explicitly. By default the tabs are derived from
## the "category" field of the loaded shop items, so calling this is optional.
func set_shop_categories(categories: Array) -> void:
	if _shop != null:
		_shop.set_categories(categories)


## Show/hide the special "cart" category tab in the shop.
func set_shop_show_cart(show: bool) -> void:
	if _shop != null:
		_shop.set_show_cart(show)


## Set the inventory category tabs explicitly. By default the tabs are derived
## from the "category" field of the loaded inventory items.
func set_inventory_categories(categories: Array) -> void:
	if _inventory != null:
		_inventory.set_categories(categories)


# ---------------- Inventory data ----------------

## Populate the inventory. Prefer this over get_inventory().set_inventory()
## because the component remembers the data across runtime toggles.
func set_inventory(items: Array) -> void:
	_inv_items = items.duplicate()
	if _inventory != null:
		_inventory.set_inventory(_inv_items)


# ---------------- Inventory access ----------------

## Returns the InventoryPanel, or null when inventory is disabled.
func get_inventory() -> InventoryPanel:
	return _inventory


# ---------------- Sizing ----------------

## Fill the parent Control. If the parent is not a Control (e.g. the component
## is added to a Node2D scene root), fill the whole viewport instead.
func _sync_to_parent() -> void:
	var parent := get_parent()
	if parent is Container:
		return
	if parent is Control:
		set_deferred("size", parent.size)
		set_deferred("position", Vector2.ZERO)
	else:
		var vp := get_viewport()
		if vp != null:
			set_deferred("size", vp.get_visible_rect().size)
			set_deferred("position", Vector2.ZERO)
	call_deferred("_apply_bands")
