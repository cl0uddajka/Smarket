class_name SMarket
extends Node

## Unified wrapper that connects QuickMarketUI (player-facing shop + inventory)
## with MarketplaceSDK (online marketplace server).
##
## Quickstart:
##   var market := SMarket.new()
##   add_child(market)
##   market.initialize("player_123")
##
## That's it — the shop + inventory UI appears, wired to the online marketplace.
## Developers never need to touch MarketplaceSDK or QuickMarketUI directly.
##
## Signals let you hook into every marketplace action and UI event from one place.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the player clicks Buy on a shop item.
signal buy_requested(item_id: String)

## Emitted when the player clicks Claim on an in_cart item (shop "cart" tab).
signal claim_requested(inventory_id: String)

## Emitted when the player clicks Cancel on their own listing (shop "cart" tab).
signal cancel_requested(listing_id: String)

## Emitted when the player taps an inventory action button (sell/equip/listing/delete).
signal action_pressed(action: String, item: Dictionary)

## Emitted when the player switches between portrait/landscape.
signal orientation_changed(landscape: bool)

## Emitted after every marketplace operation completes.
signal search_completed(result: Dictionary)
signal purchase_completed(result: Dictionary)
signal listing_completed(result: Dictionary)
signal claim_completed(result: Dictionary)
signal cancel_completed(result: Dictionary)
signal dashboard_loaded(data: Dictionary)

## Emitted after initialization is complete and both subsystems are ready.
signal initialized()


# =============================================================================
# INTERNAL REFERENCES
# =============================================================================

var marketplace: MarketplaceSDK
var ui: QuickMarketUI

var _player_id: String = ""


# =============================================================================
# PHASE 1 — INITIALIZATION
# =============================================================================

## Initialize the entire market system.
## Call this ONCE after adding SMarket to the scene tree.
## [player_id] is your game's player identifier (from your own auth system).
func initialize(player_id: String) -> void:
	_player_id = player_id

	# 1. Create MarketplaceSDK — loads encrypted gateway config in its _ready()
	marketplace = MarketplaceSDK.new()
	marketplace.name = "MarketplaceSDK"
	add_child(marketplace)

	# SDK _ready() runs now; give player session
	marketplace.initialize_player_session(player_id)

	# 2. Create and attach QuickMarketUI (shop + inventory)
	_attach_ui()

	# 3. Wire events between UI and marketplace
	_wire_events()

	print("SMarket: Initialized for player ", player_id)
	initialized.emit()


func _attach_ui() -> void:
	ui = QuickMarketUI.new()
	ui.name = "QuickMarketUI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)


func _wire_events() -> void:
	# Re-emit UI signals (OPTIONAL — developer can listen if they want custom logic)
	ui.buy_requested.connect(func(id: String) -> void: buy_requested.emit(id))
	ui.claim_requested.connect(func(id: String) -> void: claim_requested.emit(id))
	ui.cancel_requested.connect(func(id: String) -> void: cancel_requested.emit(id))
	ui.action_pressed.connect(func(action: String, item: Dictionary) -> void: action_pressed.emit(action, item))
	ui.orientation_changed.connect(func(landscape: bool) -> void: orientation_changed.emit(landscape))

	# AUTO-HANDLE: Buy → purchase from marketplace → move to inventory
	ui.buy_requested.connect(_auto_purchase)

	# AUTO-HANDLE: cart tab → Claim (in_cart item) / Cancel (own listing)
	ui.claim_requested.connect(_auto_claim)
	ui.cancel_requested.connect(_auto_cancel)

	# AUTO-HANDLE: Inventory actions (Sell/Listing → list on marketplace, Delete → remove)
	ui.action_pressed.connect(_auto_handle_inventory_action)


# =============================================================================
# PHASE 2 — MARKETPLACE WRAPPERS (Online Server)
# =============================================================================

## Các field BẮT BUỘC phải có trong item_metadata khi listing lên marketplace.
## Developer có thể mở rộng: SMarket.LISTING_REQUIRED_FIELDS.append("rarity")
const LISTING_REQUIRED_FIELDS: Array[String] = ["name", "category"]


## Kiểm tra item_metadata có đủ các field bắt buộc không.
## Trả về Dictionary rỗng {} nếu hợp lệ, hoặc {"error": ..., "message": ...} nếu thiếu.
func validate_listing_metadata(item_metadata: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	for field: String in LISTING_REQUIRED_FIELDS:
		var value: Variant = item_metadata.get(field, null)
		if value == null or str(value).strip_edges() == "":
			missing.append(field)

	if not missing.is_empty():
		return {
			"error": "MissingField",
			"message": "item_metadata thiếu field bắt buộc: %s" % ", ".join(missing),
			"missing_fields": missing
		}
	return {}


## Search the online marketplace. Returns listings matching [search_text].
func search_marketplace(search_text: String = "") -> Dictionary:
	var result: Dictionary = await marketplace.search_marketplace(search_text)
	search_completed.emit(result)
	return result


## List an item for sale on the marketplace.
## [platform_price] is the price in your platform currency.
## [item_metadata] contains item details. BẮT BUỘC phải có "name" và "category"
## (xem LISTING_REQUIRED_FIELDS). Nếu thiếu, trả về {"error": "MissingField", ...}
## và KHÔNG gửi request lên server.
func listing_item(platform_price: float, item_metadata: Dictionary) -> Dictionary:
	# Validate các field bắt buộc trước khi gửi lên server
	var invalid: Dictionary = validate_listing_metadata(item_metadata)
	if not invalid.is_empty():
		push_error("SMarket: " + str(invalid.get("message", "")))
		listing_completed.emit(invalid)
		return invalid

	var result: Dictionary = await marketplace.listing_item(platform_price, item_metadata)
	listing_completed.emit(result)
	return result


## Purchase an item from the marketplace by its [listing_id].
## Set [is_game_currency] to true if the price is in your game's soft currency.
func purchase_item(listing_id: String, is_game_currency: bool = false) -> Dictionary:
	var result: Dictionary = await marketplace.purchase_item(listing_id, is_game_currency)
	purchase_completed.emit(result)
	return result


## Fetch the player's dashboard (active listings, pending purchases, etc.).
func get_player_dashboard_data() -> Dictionary:
	var result: Dictionary = await marketplace.get_player_dashboard_data()
	dashboard_loaded.emit(result)
	return result


## Claim a purchased item from the marketplace into the player's game inventory.
func claim_item_to_game(inventory_id: String) -> Dictionary:
	var result: Dictionary = await marketplace.claim_item_to_game(inventory_id)
	claim_completed.emit(result)
	return result


## Cancel an active listing by its [listing_id].
func cancel_listing(listing_id: String) -> Dictionary:
	var result: Dictionary = await marketplace.cancel_listing(listing_id)
	cancel_completed.emit(result)
	return result


# =============================================================================
# PHASE 3 — SHOP ↔ MARKETPLACE BRIDGE
# =============================================================================

## Fill the shop with items.
## - Call WITHOUT arguments → auto-fetch from online marketplace server.
## - Call WITH an array → use your own items directly (bypasses server).
##
## Usage:
##   market.set_shop_items()            # fetch all from marketplace
##   market.set_shop_items("sword")     # search marketplace for "sword"
##   market.set_shop_items([...])       # use your own item list
func set_shop_items(p_items = null, p_search_text: String = "") -> void:
	# Branch 1: called with an Array → manual mode
	if typeof(p_items) == TYPE_ARRAY:
		ui.set_items(p_items)
		return

	# Branch 2: called with a String → treat as search query
	if typeof(p_items) == TYPE_STRING and p_items != "":
		p_search_text = p_items

	# Branch 3: no args (or empty) → fetch ALL listings + the player's cart
	var result: Variant = await marketplace.search_marketplace(p_search_text)
	search_completed.emit(result if typeof(result) == TYPE_DICTIONARY else {"data": result})

	if typeof(result) == TYPE_DICTIONARY and result.has("error"):
		push_error("SMarket: Marketplace search failed — ", result.get("error"))
		return

	var items: Array = _parse_marketplace_listings(result)

	# Đánh dấu listing của CHÍNH player → chúng chỉ hiện trong tab CART (nút Cancel)
	var own_count: int = 0
	for it: Dictionary in items:
		var author: String = str(it.get("author", "")).strip_edges()
		if author != "" and author == _player_id:
			it["_cart_type"] = "listing"
			own_count += 1

	# Giỏ hàng từ dashboard (item in_cart để Claim)
	var cart_items: Array = await _load_cart_items()

	ui.set_shop_show_cart(true)
	ui.set_items(items + cart_items)
	print("SMarket: Shop loaded — %d listings (%d của bạn) + %d cart items." % [items.size(), own_count, cart_items.size()])


## Fetch the player's dashboard (cart + own listings) and return them as shop
## items marked with "_cart_type" ("in_cart" or "listing").
func _load_cart_items() -> Array:
	var dash: Variant = await marketplace.get_player_dashboard_data()
	dashboard_loaded.emit(dash if typeof(dash) == TYPE_DICTIONARY else {"data": dash})
	return _parse_cart_items(dash)


## Parse the dashboard response into cart items.
## - entries with status "in_cart"      → claimable  (button "Claim")
## - entries coming from a listings set → cancelable (button "Cancel")
## Flexible about the response shape; prints the raw response when it cannot
## recognise it, so you can adapt _parse_cart_items to your server.
func _parse_cart_items(dashboard: Variant) -> Array:
	var out: Array = []
	var buckets: Array = []  # each: {"arr": Array, "listing": bool}

	if typeof(dashboard) == TYPE_ARRAY:
		buckets.append({"arr": dashboard, "listing": false})
	elif typeof(dashboard) == TYPE_DICTIONARY:
		for key: String in ["cart", "in_cart", "inventory", "items"]:
			var v: Variant = dashboard.get(key, null)
			if typeof(v) == TYPE_ARRAY:
				buckets.append({"arr": v, "listing": false})
		for key: String in ["listings", "my_listings", "active_listings"]:
			var v: Variant = dashboard.get(key, null)
			if typeof(v) == TYPE_ARRAY:
				buckets.append({"arr": v, "listing": true})
		# nested payloads under "data"/"dashboard"
		if buckets.is_empty():
			for key: String in ["data", "dashboard"]:
				var v: Variant = dashboard.get(key, null)
				if typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY:
					out.append_array(_parse_cart_items(v))

	if buckets.is_empty():
		print("SMarket: dashboard shape chưa nhận diện được — raw = ", dashboard)

	for bucket: Dictionary in buckets:
		for entry: Variant in bucket["arr"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = _parse_cart_entry(entry, bool(bucket["listing"]))
			if not item.is_empty():
				out.append(item)

	return out


func _parse_cart_entry(entry: Dictionary, is_listing_bucket: bool) -> Dictionary:
	var status: String = str(entry.get("status", "")).strip_edges().to_lower()

	# Suy loại cart item: in_cart (để claim) hay listing (để cancel)
	var cart_type: String = ""
	if status == "in_cart":
		cart_type = "in_cart"
	elif status in ["active", "listing", "listed"]:
		cart_type = "listing"
	elif is_listing_bucket:
		cart_type = "listing"
	elif entry.has("inventory_id"):
		cart_type = "in_cart"
	elif entry.has("listing_id"):
		cart_type = "listing"
	if cart_type == "":
		return {}

	var meta: Dictionary = entry.get("item_metadata", {})
	if typeof(meta) != TYPE_DICTIONARY:
		meta = {}

	var id: String
	if cart_type == "listing":
		id = str(entry.get("listing_id", entry.get("id", "")))
	else:
		id = str(entry.get("inventory_id", entry.get("id", "")))
	if id == "":
		return {}

	return {
		"id": id,
		"name": _pick_str(meta, ["name", "item_name", "title"], _pick_str(entry, ["name", "item_name"], "Unknown Item")),
		"price": float(entry.get("price", 0.0)),
		"image_url": _pick_str(meta, ["image_url", "icon_url", "item_image_url", "image"], _pick_str(entry, ["image_url"], "")),
		"description": _pick_str(meta, ["description", "desc", "item_description"], _pick_str(entry, ["description"], "")),
		"category": _pick_str(meta, ["category", "item_category", "type"], _pick_str(entry, ["category"], "other")),
		"rarity": _pick_str(meta, ["rarity"], ""),
		"author": _pick_str(entry, ["seller_id", "author", "seller", "player_id", "owner_id"], _pick_str(meta, ["author", "seller"], "")),
		"_cart_type": cart_type,
		"_listing_data": entry
	}


## Parse the marketplace response into the item format the shop UI expects.
## Server trả về mỗi listing dạng:
##   { "listing_id": ..., "price": ..., "item_metadata": { "name": ..., "image_url": ..., ... } }
## Hàm này làm phẳng item_metadata ra top-level để UI đọc được.
## Override nếu server của bạn trả về shape khác.
func _parse_marketplace_listings(result: Variant) -> Array:
	var items: Array = []

	# Response có thể là Array trực tiếp, hoặc Dictionary chứa "listings"/"data"/"items"
	var listings: Array = []
	if typeof(result) == TYPE_ARRAY:
		listings = result
	elif typeof(result) == TYPE_DICTIONARY:
		var raw: Variant = result.get("listings", result.get("data", result.get("items", [])))
		if typeof(raw) == TYPE_ARRAY:
			listings = raw

	for listing: Variant in listings:
		if typeof(listing) != TYPE_DICTIONARY:
			continue

		# Fields thực nằm trong item_metadata (có thể thiếu → fallback về top-level)
		var meta: Dictionary = listing.get("item_metadata", {})
		if typeof(meta) != TYPE_DICTIONARY:
			meta = {}

		var item: Dictionary = {
			"id": str(listing.get("listing_id", listing.get("id", ""))),
			"name": _pick_str(meta, ["name", "item_name", "title"], _pick_str(listing, ["name", "item_name"], "Unknown Item")),
			"price": float(listing.get("price", listing.get("platform_price", 0.0))),
			"image_url": _pick_str(meta, ["image_url", "icon_url", "item_image_url", "image"], _pick_str(listing, ["image_url"], "")),
			"description": _pick_str(meta, ["description", "desc", "item_description"], _pick_str(listing, ["description"], "")),
			"category": _pick_str(meta, ["category", "item_category", "type"], _pick_str(listing, ["category"], "other")),
			"rarity": _pick_str(meta, ["rarity"], ""),
			"author": _pick_str(listing, ["seller_id", "author", "seller", "owner_id"], _pick_str(meta, ["author", "seller"], "")),
			"_listing_data": listing
		}
		items.append(item)

	return items


## Add a single item card to the shop.
func add_shop_item(item: Dictionary) -> void:
	ui.add_item(item)


## Remove an item card from the shop by its ID.
func remove_shop_item(id: String) -> void:
	ui.remove_item(id)


## Set the shop category tabs explicitly.
## Mặc định KHÔNG cần gọi — category tab được tự động lấy từ field "category"
## của các item khi set_shop_items() (và khi add/remove item).
## Chỉ gọi hàm này nếu bạn muốn ép danh sách category cố định.
func set_shop_categories(categories: Array) -> void:
	ui.set_shop_categories(categories)


# =============================================================================
# INVENTORY MANAGEMENT
# =============================================================================

## Set the inventory category tabs explicitly.
## Mặc định KHÔNG cần gọi — category tab được tự động lấy từ field "category"
## của các item khi set_inventory_items().
func set_inventory_categories(categories: Array) -> void:
	ui.set_inventory_categories(categories)

## Fill the inventory with items (from your game's own database).
func set_inventory_items(items: Array) -> void:
	ui.set_inventory(items)


## Add one item to the inventory. Stacks on existing items with the same ID/name.
func add_inventory_item(item: Dictionary) -> void:
	var inv: InventoryPanel = ui.get_inventory()
	if inv != null:
		inv.add_item(item)


## Remove [amount] units of an item from the inventory by ID.
func remove_inventory_item(id: String, amount: int = 1) -> void:
	var inv: InventoryPanel = ui.get_inventory()
	if inv != null:
		inv.remove_item(id, amount)


## Clear every item from the inventory.
func clear_inventory() -> void:
	var inv: InventoryPanel = ui.get_inventory()
	if inv != null:
		inv.clear_inventory()


## Direct access to the InventoryPanel for advanced operations.
func get_inventory_panel() -> InventoryPanel:
	return ui.get_inventory()


# =============================================================================
# PHASE 4 — UI CONTROLS
# =============================================================================

## Show/hide/toggle the shop panel.
func open_shop() -> void:    ui.open_shop()
func close_shop() -> void:   ui.close_shop()
func toggle_shop() -> void:  ui.toggle_shop()
func is_shop_open() -> bool: return ui.is_shop_open()

## Show/hide/toggle the inventory panel.
func open_inventory() -> void:    ui.open_inventory()
func close_inventory() -> void:   ui.close_inventory()
func toggle_inventory() -> void:  ui.toggle_inventory()
func is_inventory_open() -> bool: return ui.is_inventory_open()

## Enable/disable the shop section entirely (removes it from layout).
func set_shop_enabled(enabled: bool) -> void:      ui.set_shop_enabled(enabled)
func set_inventory_enabled(enabled: bool) -> void:  ui.set_inventory_enabled(enabled)
func is_shop_enabled() -> bool:      return ui.is_shop_enabled()
func is_inventory_enabled() -> bool: return ui.is_inventory_enabled()

## Switch between portrait / landscape layout.
func set_landscape(landscape: bool) -> void:  ui.set_landscape(landscape)
func toggle_landscape() -> void:              ui.toggle_landscape()
func is_landscape() -> bool:                  return ui.is_landscape()

## Reload the UI from a different config file (default: res://marketplace_config.json).
func reload_config(path: String = "") -> void:
	ui.configure(path)


# =============================================================================
# INTERNAL — AUTO-HANDLE EVERYTHING (developer không cần connect signal)
# =============================================================================

## Auto-handle Claim (shop "cart" tab): claim an in_cart item into the inventory.
func _auto_claim(inventory_id: String) -> void:
	print("SMarket: Claim — ", inventory_id)
	var cart_item: Dictionary = _find_shop_item(inventory_id)

	var result: Dictionary = await marketplace.claim_item_to_game(inventory_id)
	claim_completed.emit(result)

	if result.has("error"):
		push_error("SMarket: Claim failed — ", result.get("error"))
		return

	print("SMarket: Claim OK — ", inventory_id)
	ui.remove_item(inventory_id)

	# Đưa item vào inventory
	if not cart_item.is_empty():
		var inv_item: Dictionary = _build_inventory_item(cart_item, result)
		_add_to_inventory(inv_item)


## Auto-handle Cancel (shop "cart" tab): cancel the player's own listing.
func _auto_cancel(listing_id: String) -> void:
	print("SMarket: Cancel listing — ", listing_id)
	var cart_item: Dictionary = _find_shop_item(listing_id)

	var result: Dictionary = await marketplace.cancel_listing(listing_id)
	cancel_completed.emit(result)

	if result.has("error"):
		push_error("SMarket: Cancel failed — ", result.get("error"))
		return

	print("SMarket: Cancel OK — ", listing_id)
	ui.remove_item(listing_id)

	# Item được trả về inventory
	if not cart_item.is_empty():
		var back: Dictionary = cart_item.duplicate()
		back.erase("_cart_type")
		back.erase("_listing_data")
		back["count"] = 1
		_add_to_inventory(back)


## Tìm một item trong shop theo id (trả về bản copy, an toàn qua await).
func _find_shop_item(id: String) -> Dictionary:
	for it: Dictionary in ui._shop_items:
		if it.get("id", "") == id:
			return it.duplicate()
	return {}


## Auto-handle Buy: purchase the item. KHÔNG tự claim — item vào CART
## (status "in_cart") để player tự bấm Claim trong tab cart.
func _auto_purchase(item_id: String) -> void:
	print("SMarket: Buy — ", item_id)

	# Tìm listing_id từ dữ liệu shop
	var listing_id: String = item_id
	for item: Dictionary in ui._shop_items:
		if item.get("id", "") == item_id:
			var data: Dictionary = item.get("_listing_data", {})
			var lid: String = data.get("listing_id", "")
			if lid != "":
				listing_id = lid
			break

	var result: Dictionary = await marketplace.purchase_item(listing_id, true)
	purchase_completed.emit(result)

	if result.has("error"):
		push_error("SMarket: Purchase failed — ", result.get("error"))
		return

	print("SMarket: Purchase OK — ", listing_id, " (item vào CART)")

	# Item đã bán → bỏ khỏi shop, và làm mới CART để hiện item in_cart
	ui.remove_item(item_id)
	await refresh_cart()


## Làm mới tab CART: lấy lại item in_cart từ server.
## Giữ nguyên các listing của chính player (đã gắn cờ trong set_shop_items).
## Tự động được gọi sau khi purchase. Có thể gọi thủ công bất cứ lúc nào.
func refresh_cart() -> void:
	var cart_items: Array = await _load_cart_items()

	# Chỉ bỏ các item in_cart cũ (KHÔNG bỏ listing của player)
	var old: Array = []
	for it: Dictionary in ui._shop_items:
		if it.get("_cart_type", "") == "in_cart":
			old.append(it.get("id", ""))
	for id: String in old:
		ui.remove_item(id)

	# Thêm item in_cart mới từ dashboard
	for it: Dictionary in cart_items:
		ui.add_item(it)
	ui.set_shop_show_cart(true)
	print("SMarket: Cart refreshed — %d in_cart items." % cart_items.size())


## Tạo inventory item từ shop item + claim result, đảm bảo có đủ name, image_url.
func _build_inventory_item(shop_item: Dictionary, claim_result: Dictionary) -> Dictionary:
	var item: Dictionary = {}

	# Ưu tiên lấy từ claim result (server trả về), fallback về shop item
	item["id"] = _first_str(claim_result, "item_id", shop_item.get("id", ""))
	item["name"] = _first_str(claim_result, "item_name", _first_str(claim_result, "name", shop_item.get("name", "Unknown Item")))
	item["image_url"] = _first_str(claim_result, "image_url", shop_item.get("image_url", ""))
	item["description"] = _first_str(claim_result, "description", shop_item.get("description", ""))
	item["category"] = _first_str(claim_result, "category", shop_item.get("category", "other"))
	item["count"] = 1

	# Copy thêm các field khác từ shop item (trừ _listing_data)
	for key: String in shop_item:
		if key.begins_with("_") or item.has(key):
			continue
		item[key] = shop_item[key]

	return item


## Lấy string đầu tiên khác rỗng từ dict, thử nhiều key.
func _first_str(dict: Dictionary, key1: String, fallback: String) -> String:
	var val: String = str(dict.get(key1, ""))
	if val != "":
		return val
	return fallback


## Trả về giá trị string khác rỗng đầu tiên trong [keys], nếu không có thì [fallback].
func _pick_str(dict: Dictionary, keys: Array, fallback: String) -> String:
	for k: String in keys:
		if dict.has(k):
			var v: String = str(dict.get(k, "")).strip_edges()
			if v != "":
				return v
	return fallback

#INVENTORY WITH 4 BUTTON: SELL, DELETE, LISTING, EQUIP
## Auto-handle inventory actions: Sell/Listing → list lên marketplace, Delete → xóa.
func _auto_handle_inventory_action(action: String, item: Dictionary) -> void:
	# DUPLICATE NGAY LẬP TỨC — tránh bị mất dữ liệu khi await
	var _item: Dictionary = item.duplicate()

	match action:
		"sell", "listing":
			print("SMarket: Auto-listing item — ", _item.get("name", ""))
			var price: float = float(_item.get("price", 1.0))
			var metadata: Dictionary = {
				"name": _item.get("name", ""),
				"description": _item.get("description", ""),
				"category": _item.get("category", ""),
				"image_url": _item.get("image_url", "")
			}
			# Validate field bắt buộc (name, category) trước khi listing
			var invalid: Dictionary = validate_listing_metadata(metadata)
			if not invalid.is_empty():
				push_error("SMarket: " + str(invalid.get("message", "")))
				listing_completed.emit(invalid)
				return

			# Gọi qua self.listing_item để dùng chung validation + emit signal
			var result: Dictionary = await listing_item(price, metadata)
			if result.has("error"):
				push_error("SMarket: Listing failed — ", result.get("error"))
			else:
				print("SMarket: Listed OK — ", _item.get("name", ""))
				# Xóa khỏi inventory
				var inv: InventoryPanel = ui.get_inventory()
				if inv != null:
					inv.remove_item(_item.get("id", ""))
				# Thêm vào shop (dùng bản duplicate đã có đủ name, image_url)
				var shop_item: Dictionary = _item.duplicate()
				shop_item["id"] = str(result.get("listing_id", _item.get("id", "")))
				shop_item["_listing_data"] = result
				ui.add_item(shop_item)

		"delete":
			var id: String = _item.get("id", "")
			print("SMarket: Delete — ", id)
			var inv: InventoryPanel = ui.get_inventory()
			if inv != null:
				inv.remove_item(id)

		"equip":
			print("SMarket: Equip — ", _item.get("name", ""))


func _add_to_inventory(item: Dictionary) -> void:
	var inv: InventoryPanel = ui.get_inventory()
	if inv != null:
		inv.add_item(item)
