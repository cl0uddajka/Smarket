extends Control
## Demo bootstrap for the QuickMarket asset.
## Instances the reusable QuickMarketUI component (which reads
## res://marketplace_config.json), pre-populates the shop + inventory, and wires
## a demo "buy moves item into inventory" flow so you can preview the UI.
##
## NOTE: real developers do NOT need this script — they instance
## QuickMarketUI.tscn (or QuickMarketUI.new()) in their own scene.

var _demo: Array = []


func _ready() -> void:
	var ui := QuickMarketUI.new()
	add_child(ui)

	_demo = _demo_items()
	ui.set_items(_demo)

	var inv := ui.get_inventory()
	if inv != null:
		inv.set_inventory(_demo_inventory())
		inv.action_pressed.connect(func(action: String, item: Dictionary):
			print("Item action: ", action, " -> ", item.get("name", ""))
		)

	ui.buy_requested.connect(func(item_id: String):
		ui.remove_item(item_id)
		var it := _find_demo_item(item_id)
		if not it.is_empty() and inv != null:
			inv.add_item(it)
		print("Bought item: ", item_id)
	)


func _demo_items() -> Array:
	return [
		{"id": "demo_1", "name": "Health Potion", "price": 12.5, "image_url": "res://addons/quickmarket_ui/assets/icon_potion_frame_0.png", "category": "item", "description": "Phục hồi 50 HP ngay lập tức"},
		{"id": "demo_2", "name": "Iron Sword", "price": 85.0, "image_url": "res://addons/quickmarket_ui/assets/icon_sword_frame_0.png", "category": "weapon", "description": "Sát thương 25, crit dmg 10%"},
		{"id": "demo_3", "name": "Guard Shield", "price": 64.0, "image_url": "res://addons/quickmarket_ui/assets/icon_shield_frame_0.png", "category": "armor", "description": "Phòng thủ +15, giảm 10% sát thương"},
		{"id": "demo_4", "name": "Blue Gem", "price": 250.0, "image_url": "res://addons/quickmarket_ui/assets/icon_gem_frame_0.png", "category": "other", "description": "Nguyên liệu quý dùng để cường hóa trang bị"}
	]


func _find_demo_item(id: String) -> Dictionary:
	for it in _demo:
		if it.get("id", "") == id:
			return it
	return {}


func _demo_inventory() -> Array:
	return [
		{"id": "inv_ring", "name": "Ruby Ring", "count": 1, "image_url": "res://addons/quickmarket_ui/assets/icon_ring_frame_0.png", "category": "other", "description": "Nhẫn bạc nạm hồng ngọc, tăng 5% sát thương"},
		{"id": "inv_sword", "name": "Iron Sword", "count": 1, "image_url": "res://addons/quickmarket_ui/assets/icon_sword_frame_0.png", "category": "weapon", "description": "Sát thương 25, crit dmg 10%, crit chance 5%"},
		{"id": "inv_armor", "name": "Plate Armor", "count": 2, "image_url": "res://addons/quickmarket_ui/assets/icon_armor_frame_0.png", "category": "armor", "description": "Giáp nặng: phòng thủ +20, giảm 15% sát thương"},
		{"id": "inv_coins", "name": "Gold Coins", "count": 12, "image_url": "res://addons/quickmarket_ui/assets/icon_coins_frame_0.png", "category": "item", "description": "Tiền tệ dùng để giao dịch trong shop"},
		{"id": "inv_potion", "name": "Health Potion", "count": 2, "image_url": "res://addons/quickmarket_ui/assets/icon_potion_frame_0.png", "category": "item", "description": "Phục hồi 50 HP ngay lập tức"}
	]
