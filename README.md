# SMarket — Hướng dẫn sử dụng (Godot 4.2+)

**SMarket** là asset marketplace online hoàn chỉnh cho Godot: server marketplace
(listing / purchase / cart / claim / cancel) + UI Shop + UI Inventory, tất cả gói
trong **một API duy nhất**.

Developer chỉ cần dùng **`SMarket`** — không cần đụng tới `MarketplaceSDK` hay
`QuickMarketUI` trực tiếp.

> **Thứ tự tính năng:** 1) **Market online** (chính) · 2) **Shop** · 3) **Inventory**

---

## Mục lục

- [Cài đặt](#cài-đặt)
- [Bắt đầu nhanh](#bắt-đầu-nhanh-3-dòng)
- [PHẦN 1 — MARKET ONLINE (chính)](#phần-1--market-online-chính)
  - [Khởi tạo](#khởi-tạo)
  - [Bán item — `listing_item`](#bán-item--listing_item)
  - [Mua item — `purchase_item`](#mua-item--purchase_item)
  - [Giỏ hàng & Claim — CART](#giỏ-hàng--claim--cart)
  - [Hủy bán — `cancel_listing`](#hủy-bán--cancel_listing)
  - [Tìm kiếm — `search_marketplace`](#tìm-kiếm--search_marketplace)
  - [Ví / Dashboard](#ví--dashboard)
  - [Signals (sự kiện)](#signals-sự-kiện)
  - [Định dạng item & field bắt buộc](#định-dạng-item--field-bắt-buộc)
- [PHẦN 2 — SHOP](#phần-2--shop)
- [PHẦN 3 — INVENTORY](#phần-3--inventory)
- [Tùy biến giao diện (config)](#tùy-biến-giao-diện-config)
- [Cấu trúc file](#cấu-trúc-file)
- [Kiểm thử](#kiểm-thử)
- [Xử lý sự cố](#xử-lý-sự-cố)

---

## Cài đặt

Asset gồm **2 addon** (đặt cạnh nhau trong `addons/`):

```
addons/
├── smarket/           ← MarketplaceSDK (kết nối server)
│   ├── MarketplaceSDK.gd
│   └── sdk_data.res   ← khóa + URL server (mã hóa)
└── quickmarket_ui/    ← UI Shop + Inventory + SMarket wrapper
	├── SMarket.gd     ← ★ API chính developer dùng
	├── scripts/
	└── ...
```

1. Copy cả hai thư mục `addons/smarket/` và `addons/quickmarket_ui/` vào project.
2. Bật plugin: **Project → Project Settings → Plugins → QuickMarket UI → Enable**.
3. Đảm bảo có `res://marketplace_config.json` (nếu chưa, copy từ
   `addons/quickmarket_ui/config/marketplace_config.json`).

---

## Bắt đầu nhanh (3 dòng)

```gdscript
extends Node

var market: SMarket

func _ready() -> void:
	market = SMarket.new()
	add_child(market)
	market.initialize("player_id_cua_ban")   # ID người chơi của bạn

	# Shop: tự tải toàn bộ item từ server + giỏ hàng của player
	await market.set_shop_items()

	# Inventory: từ database của bạn (SQLite, Firebase, ...)
	market.set_inventory_items(my_inventory)
```

**Xong.** Mọi hành động (Buy / Claim / Cancel / Listing / Delete) được xử lý tự
động — không cần connect signal.

---

# PHẦN 1 — MARKET ONLINE (chính)

Đây là phần cốt lõi: đưa item lên chợ, mua bán, quản lý giỏ hàng — tất cả qua
server. UI Shop và Inventory chỉ là lớp hiển thị (Phần 2 & 3).

## Khởi tạo

```gdscript
var market := SMarket.new()
add_child(market)
market.initialize("player_id")     # gọi 1 lần, sau khi add_child
```

`initialize()` sẽ:
1. Tạo `MarketplaceSDK` (tự nạp cấu hình server từ `sdk_data.res`).
2. Tạo `QuickMarketUI` (Shop + Inventory) gắn vào cây scene.
3. Nối sự kiện giữa UI và marketplace.

| Tham số | Kiểu | Ý nghĩa |
|---|---|---|
| `player_id` | `String` | ID người chơi từ hệ thống đăng nhập của bạn |

Sau khi xong, signal `initialized` phát ra.

---

## Bán item — `listing_item`

Đưa một item lên chợ cho người khác mua.

```gdscript
var result := await market.listing_item(price, item_metadata)
```

| Tham số | Kiểu | Ý nghĩa |
|---|---|---|
| `price` | `float` | Giá bán |
| `item_metadata` | `Dictionary` | Thông tin item |

**`item_metadata` BẮT BUỘC có `name` và `category`.** Nếu thiếu, hàm trả về lỗi
và **không gửi request** lên server:

```gdscript
var result := await market.listing_item(200.0, {
	"name": "Plate Armor",
	"category": "armor",
	"image_url": "res://icons/armor.png",   # tùy chọn
	"description": "Phòng thủ +20",          # tùy chọn
	"rarity": "Rare"                          # tùy chọn
})
if result.has("error"):
	print("Lỗi: ", result.get("message"))
```

### Kiểm tra trước khi bán

```gdscript
var check := market.validate_listing_metadata(item_metadata)
if not check.is_empty():
	print(check.get("message"))          # "thiếu field bắt buộc: category"
	print(check.get("missing_fields"))   # ["category"]
```

### Mở rộng field bắt buộc

```gdscript
SMarket.LISTING_REQUIRED_FIELDS.append("rarity")
```

---

## Mua item — `purchase_item`

```gdscript
var result := await market.purchase_item(listing_id, is_game_currency)
```

| Tham số | Kiểu | Mặc định | Ý nghĩa |
|---|---|---|---|
| `listing_id` | `String` | — | ID listing cần mua |
| `is_game_currency` | `bool` | `false` | `true` nếu trả bằng tiền game |

Sau khi mua thành công, **item KHÔNG tự vào inventory** — nó vào **giỏ hàng
(CART)** với trạng thái `in_cart`. Người chơi phải bấm **Claim** để nhận
(xem phần dưới).

> Khi mua qua nút **Buy** trên Shop, luồng này chạy tự động:
> `purchase_item` → item vào CART → tab cart tự làm mới.

---

## Giỏ hàng & Claim — CART

Giỏ hàng chứa 2 loại:

| Loại | Trạng thái | Nút hiển thị | Hành động |
|---|---|---|---|
| Item đã mua, chưa nhận | `in_cart` | **Claim** | Nhận item về inventory |
| Item player đang bán | `active` (listing) | **Cancel** | Hủy bán, trả item về inventory |

### Lấy giỏ hàng

```gdscript
var dashboard := await market.get_player_dashboard_data()
# { "success": true, "cart": [ {...}, {...} ], "wallet": {...} }
```

### Nhận item (Claim)

```gdscript
var result := await market.claim_item_to_game(inventory_id)
```

`inventory_id` lấy từ mảng `cart` của dashboard (field `inventory_id`).

### Làm mới tab CART

```gdscript
await market.refresh_cart()   # lấy lại cart từ server (tự gọi sau khi purchase)
```

> Trên UI, tab **cart** hiển thị mọi item trong giỏ. Bấm **Claim** / **Cancel**
> được xử lý tự động.

---

## Hủy bán — `cancel_listing`

```gdscript
var result := await market.cancel_listing(listing_id)
```

Item sẽ được trả về inventory.

---

## Tìm kiếm — `search_marketplace`

```gdscript
var result := await market.search_marketplace("kiếm")
```

Trả về danh sách listing khớp từ khóa (để trống = tất cả).

---

## Ví / Dashboard

`get_player_dashboard_data()` trả về dữ liệu người chơi, ví dụ:

```json
{
  "success": true,
  "cart": [
	{
	  "inventory_id": "c35c0310-...",
	  "player_id": "player_1",
	  "item_metadata": { "rarity": "Rare", "item_name": "Giáp Vàng" },
	  "status": "in_cart",
	  "purchased_at": "2026-09-01T13:47:42Z",
	  "claimed_at": null
	}
  ],
  "wallet": { "platform_balance": 100.0 }
}
```

---

## Signals (sự kiện)

Signal là **tùy chọn** — luồng mặc định đã tự động. Dùng khi bạn muốn logic riêng.

| Signal | Payload | Khi nào |
|---|---|---|
| `initialized` | — | Khởi tạo xong |
| `buy_requested` | `(item_id)` | Player bấm **Buy** |
| `claim_requested` | `(inventory_id)` | Player bấm **Claim** |
| `cancel_requested` | `(listing_id)` | Player bấm **Cancel** |
| `action_pressed` | `(action, item)` | Player bấm **Sell/Equip/Listing/Delete** |
| `search_completed` | `(result)` | Tìm kiếm xong |
| `purchase_completed` | `(result)` | Mua xong |
| `listing_completed` | `(result)` | Đăng bán xong |
| `claim_completed` | `(result)` | Claim xong |
| `cancel_completed` | `(result)` | Hủy bán xong |
| `dashboard_loaded` | `(data)` | Tải dashboard xong |
| `orientation_changed` | `(landscape)` | Đổi ngang/dọc |

```gdscript
market.purchase_completed.connect(func(result):
	if result.has("error"):
		show_toast("Mua thất bại")
	else:
		show_toast("Đã mua — vào giỏ hàng để nhận")
)
```

---

## Định dạng item & field bắt buộc

| Field | Bắt buộc khi bán | Mô tả |
|---|---|---|
| `name` | ✅ | Tên item |
| `category` | ✅ | Phân loại (tạo tab shop) |
| `image_url` | — | Đường dẫn `res://` tới icon |
| `description` | — | Mô tả |
| `rarity` | — | `common`/`uncommon`/`rare`/`epic`/`legendary` |
| `price` | — | Giá (khi hiển thị) |
| `author` | — | Người bán (`seller_id`). Hiển thị "by &lt;author&gt;" trên card |

> **`author`** được đọc tự động từ `seller_id`/`author`/`seller`/`owner_id` của
> listing và hiển thị trên card shop. Listing do **chính player** đăng được nhận
> diện qua `author == player_id` và chỉ hiện trong tab **CART** (nút Cancel).

> **Server dùng tên field linh hoạt:** wrapper tự đọc `name`/`item_name`/`title`,
> `image_url`/`icon_url`/`image`, `category`/`item_category`/`type`. Bạn không cần
> đổi server nếu field tên hơi khác.

---

# PHẦN 2 — SHOP

UI Shop hiển thị item từ server, có tab category và tab **cart**.

## Tải item vào Shop

```gdscript
await market.set_shop_items()             # tải TẤT CẢ từ server + cart
await market.set_shop_items("kiếm")       # tìm "kiếm" rồi hiển thị
market.set_shop_items(my_items_array)     # dùng item của bạn (offline)
```

## Tab category — lấy từ chính item

Category tab **tự sinh** từ field `category` của các item — không dùng danh sách
trong config nữa. Ví dụ item có `weapon`, `armor` → tab `all, weapon, armor`.

Ép danh sách cố định (nếu muốn):

```gdscript
market.set_shop_categories(["weapon", "armor", "item"])
```

## Tab CART

Tab `cart` luôn xuất hiện khi dùng `set_shop_items()` (online mode). Hiển thị
item trong giỏ (Claim/Cancel).

## Thêm / xóa item thủ công

```gdscript
market.add_shop_item({"id": "x", "name": "Gem", "price": 99.0, "category": "material"})
market.remove_shop_item("x")
```

## Điều khiển Shop

```gdscript
market.open_shop() / market.close_shop() / market.toggle_shop()
market.is_shop_open()
market.set_shop_enabled(false)     # ẩn hẳn shop (app chỉ có inventory)
```

---

# PHẦN 3 — INVENTORY

UI Inventory hiển thị item từ database của bạn, có tab category và 4 nút hành động.

> **Lưu ý:** Inventory dùng **database của riêng bạn** (SQLite, Realm, Firebase, ...).
> Asset chỉ cung cấp UI + hành động, không lưu inventory giúp bạn.

## Tải item vào Inventory

```gdscript
market.set_inventory_items([
	{"id": "ring", "name": "Ruby Ring", "count": 1, "category": "other",
	 "image_url": "res://icons/ring.png", "price": 150.0},
	{"id": "sword", "name": "Iron Sword", "count": 1, "category": "weapon", "price": 85.0},
])
```

## Thêm / xóa

```gdscript
market.add_inventory_item(item)                 # cộng dồn nếu trùng id/name
market.remove_inventory_item("ring", 1)
market.clear_inventory()
```

## 4 nút hành động (tự động xử lý)

| Nút | Hành động tự động |
|---|---|
| **Sell** / **Listing** | Đăng bán lên marketplace → xóa khỏi inventory → thêm vào shop |
| **Delete** | Xóa khỏi inventory |
| **Equip** | Log ra console (game-specific — xử lý qua signal `action_pressed`) |

## Tab category — lấy từ chính item

Giống Shop: tự sinh từ field `category` của item trong inventory.

```gdscript
market.set_inventory_categories(["weapon", "armor"])   # ép danh sách (tùy chọn)
```

## Điều khiển Inventory

```gdscript
market.open_inventory() / market.close_inventory() / market.toggle_inventory()
market.is_inventory_open()
market.set_inventory_enabled(false)     # ẩn hẳn inventory
```

## Xoay ngang / dọc

```gdscript
market.set_landscape(true)     # shop trái / inventory phải
market.toggle_landscape()
market.is_landscape()
```

---

## Tùy biến giao diện (config)

Toàn bộ màu sắc, chữ, kích thước nằm trong `res://marketplace_config.json`
(khối `ui_theme`). Sửa file — **không cần sửa code**.

```gdscript
market.reload_config()                          # nạp lại config mặc định
market.reload_config("res://config_cua_toi.json")  # config khác
```

Các nhóm chính: `ui_theme.colors.*`, `ui_theme.texts.*`,
`ui_theme.layout.*` (tỉ lệ, hướng), `ui_theme.inventory.*`,
`ui_theme.shop.*`.

---

## Cấu trúc file

| File | Vai trò |
|---|---|
| `addons/quickmarket_ui/SMarket.gd` | **★ API chính** — wrapper thống nhất |
| `addons/smarket/MarketplaceSDK.gd` | Kết nối server (HTTP) |
| `addons/quickmarket_ui/scripts/quick_market_ui.gd` | Component UI Shop + Inventory |
| `addons/quickmarket_ui/scripts/shop_screen.gd` | Grid shop + tab category + tab cart |
| `addons/quickmarket_ui/scripts/item_card.gd` | Card item (Buy/Claim/Cancel) |
| `addons/quickmarket_ui/scripts/inventory_panel.gd` | Grid inventory + 4 nút hành động |
| `addons/quickmarket_ui/scripts/shop_theme.gd` | Đọc config → style |
| `addons/quickmarket_ui/config/marketplace_config.json` | Config mẫu |
| `res://test_smarket.tscn` + `.gd` | Demo đầy đủ (chạy F6) |

---

## Kiểm thử

1. Mở `res://test_smarket.tscn`, nhấn **F6**.
2. Shop hiện item từ server; tab **cart** hiện item trong giỏ.
3. Bấm **Claim** để nhận item về inventory.
4. Dùng các nút DEBUG góc phải để toggle Shop/Inventory, thêm item, xóa inventory.

---

## Xử lý sự cố

| Triệu chứng | Nguyên nhân / cách xử lý |
|---|---|
| `[SDK Warning] Đang có request khác đang xử lý` | Có request trước chưa xong. Đợi rồi thử lại (khóa chống double-request). |
| Shop hiện "Unknown Item" | Server trả field tên khác. Wrapper đã hỗ trợ `item_name`/`name`/`title`; nếu vẫn lỗi, xem log `dashboard raw`. |
| Item không có ảnh | `item_metadata` thiếu `image_url`. Thêm `image_url` phía server, hoặc để icon mặc định. |
| Listing báo lỗi `MissingField` | `item_metadata` thiếu `name` hoặc `category`. |
| Cart rỗng dù đã mua | Server chưa tạo bản ghi `in_cart`. Kiểm tra hàm `get_dashboard` phía server. |
| Nút panel debug không bấm được | `QuickMarketUI` chặn input; panel phải có `mouse_filter = STOP` + `z_index` cao. |
