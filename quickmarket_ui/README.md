# SMarket — Online Marketplace Asset (Godot 4.2+)

**SMarket** is a complete online-marketplace asset: a hosted server for
**listing / purchasing / cart / claim / cancel**, plus a ready-made **Shop UI**
and **Inventory UI** — all behind **one API**, `SMarket.gd`.

> **➡️ Full guide: [`SMARKET_GUIDE.md`](SMARKET_GUIDE.md)** (Vietnamese).
> Feature priority: **1) online market · 2) shop · 3) inventory.**

**Quick start — three lines:**

```gdscript
var market := SMarket.new()
add_child(market)
market.initialize("player_id")
await market.set_shop_items()     # loads the online market + the player's cart
```

Everything else (Buy → cart, Claim, Cancel, Sell/Listing from inventory) is
handled automatically. No signals required.

This asset ships as **two addons**: `addons/smarket/` (the `MarketplaceSDK`
server client) and `addons/quickmarket_ui/` (the UI + `SMarket` wrapper).

---

# QuickMarket UI — Shop + Inventory UI reference

The section below documents the **UI layer** in detail (shop grid, inventory
panel, theming). If you use the `SMarket` wrapper above you do **not** need most
of it — it is kept for direct/advanced use.

A **config-driven mobile shop + inventory UI** you can drop into your own Godot
project. Restyle the *whole* UI by editing **one JSON file** — no code changes needed.

**What you get:**
- **Shop:** a 2-column grid of item cards (icon, name, price, **Buy** button, selection highlight).
- **Inventory:** a 5-column grid of slots (icons + stack counts), category-filter tabs on the left,
  and an item-info frame that shows **Sell / Equip / Listing / Delete** action buttons.
- **ON/OFF toggles:** use only the shop *or* only the inventory, whichever your game needs.
- **Portrait ↔ Landscape:** one call flips the layout (shop top/inventory bottom ↔ shop left/inventory right).

---

## Requirements

- Godot **4.2 or newer**.
- Any platform. Designed for a **portrait mobile** viewport (720×1280), but it scales.
- Pure **GDScript** — no C# / .NET, no Supabase connection needed for the UI.

---

## Install

### Option A — ZIP (the packaged asset)
1. Copy `quickmarket_ui.zip` into your project and extract it **at the project root**
   so you get `addons/quickmarket_ui/`.
2. Enable it: **Project → Project Settings → Plugins → QuickMarket UI → Enable**.
3. *(Optional)* Preview: **Project → Tools → QuickMarket UI: Create Demo Shop**.
   This copies a demo scene + `marketplace_config.json` to your project root.

### Option B — manual copy
1. Copy the `addons/quickmarket_ui/` folder into your project's `addons/` folder.
2. Follow steps 2–3 above.

> **Config file:** the asset reads `res://marketplace_config.json`. If you don't have one,
> copy the template from `addons/quickmarket_ui/config/marketplace_config.json` to your
> project root (it holds all colors/texts).

---

## Quick start (for a NEW developer)

Add the **QuickMarketUI** component to your own scene — you do **not** need any
demo scene from this asset.

### Step 1 — Add the component
Either drag `addons/quickmarket_ui/demo/QuickMarketUI.tscn` into your scene,
**or** create it in code (shown below).

### Step 2 — Paste this into a script on any node

```gdscript
extends Node

func _ready() -> void:
	# 1) Create the shop + inventory component
	var ui := QuickMarketUI.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	# 2) Fill the SHOP
	ui.set_items([
		{ "id": "pot", "name": "Health Potion", "price": 12.5, "image_url": "res://icon_potion.png", "category": "item",   "description": "Hồi 50 HP" },
		{ "id": "swd", "name": "Iron Sword",    "price": 85.0, "image_url": "res://icon_sword.png",   "category": "weapon", "description": "Sát thương 25" },
	])

	# 3) Fill the INVENTORY
	ui.set_inventory([
		{ "id": "ring", "name": "Ruby Ring", "count": 1,   "image_url": "res://icon_ring.png", "category": "other", "description": "Tăng 5% sát thương" },
		{ "id": "coin", "name": "Coins",     "count": 120, "image_url": "res://icon_coin.png", "category": "item",  "description": "Tiền tệ" },
	])

	# 4) Wire events to your own logic
	ui.buy_requested.connect(_on_buy)
	ui.action_pressed.connect(_on_action)
	ui.selection_changed.connect(func(item_id): print("Selected: ", item_id))

	# 5) Portrait or landscape
	ui.set_landscape(true)     # landscape (shop left / inventory right)
	ui.set_landscape(false)    # portrait (shop top / inventory bottom)
	ui.toggle_landscape()      # flip current orientation
	ui.is_landscape()          # -> bool
	ui.orientation_changed.connect(func(land): print("Ngang?", land))

func _on_buy(item_id: String) -> void:
	print("Player wants to buy: ", item_id)
	# TODO: charge currency / grant item via your backend

func _on_action(action: String, item: Dictionary) -> void:
	print("Action: ", action, " on ", item.get("name", ""))
	# action is one of: "sell" | "equip" | "listing" | "delete"
	# TODO: sell / equip / list / delete the item
```

Press **F5** → you now have a working shop + inventory. 🎉

---

## Main functions (the core API)

All of these are called on the **`QuickMarketUI`** node you created. Each section
below lists the function, what it does, and a short usage example.

### 1. Component setup
| Function | What it does |
|----------|--------------|
| `QuickMarketUI.new()` | Creates the component (shop + inventory). |
| `ui.config_path = "res://x.json"` | Point at a custom config. **Must be set before `add_child()`.** |
| `add_child(ui)` | Adds it to your scene; it fills its parent / the viewport. |

```gdscript
var ui := QuickMarketUI.new()
ui.config_path = "res://marketplace_config.json"  # optional (it's the default)
add_child(ui)
```

### 2. Filling data (shop & inventory)
| Function | What it does |
|----------|--------------|
| `set_items(items: Array)` | **Replace** all shop items. |
| `add_item(item: Dictionary)` | Append one shop item. |
| `remove_item(item_id: String)` | Remove a shop item by id. |
| `set_inventory(items: Array)` | **Replace** all inventory items (recommended way to load). |
| `get_inventory() -> InventoryPanel` | The live inventory panel (or `null` when disabled). |

```gdscript
ui.set_items([{"id":"a","name":"Sword","price":50.0,"image_url":"res://i.png"}])
ui.set_inventory([{"id":"a","name":"Sword","count":2,"level":5,"damage":25}])
```

### 3. Open / Close a section
Use these to show or hide the shop / inventory. **Data is kept** — nothing is lost.
When one section is closed, the other automatically fills the screen.

| Function | What it does |
|----------|--------------|
| `open_shop()` / `close_shop()` / `toggle_shop()` | Show / hide / flip the shop. |
| `open_inventory()` / `close_inventory()` / `toggle_inventory()` | Show / hide / flip the inventory. |
| `is_shop_open()` / `is_inventory_open()` | Check the current visible state. |

### 4. ON / OFF toggles (keep only one panel in your app)
Use this when you want a **shop-only** or **inventory-only** app. Unlike open/close,
this **removes the section from the layout entirely**.

```gdscript
ui.set_shop_enabled(false)        # inventory-only app
ui.set_inventory_enabled(false)   # shop-only app
ui.is_shop_enabled()              # -> bool
```

> Same effect via config: `ui_theme.shop.enabled` / `ui_theme.inventory.enabled`.

### 5. Orientation (portrait ↔ landscape)
| Function | What it does |
|----------|--------------|
| `set_landscape(true/false)` | Force landscape (shop left, inventory right) or portrait (shop top, inventory bottom). |
| `toggle_landscape()` | Flip the current orientation. |
| `is_landscape() -> bool` | Current orientation. |
| `orientation_changed(landscape)` | **Signal** — fires whenever the orientation changes. |

A floating toggle button (top-right) can do this for you — hide it with
`layout.show_orientation_button: false`.

### 6. Events / signals (connect on `ui`)
| Signal | Payload | When it fires |
|--------|---------|---------------|
| `buy_requested` | `(item_id: String)` | Player taps **Buy** on a shop card. |
| `action_pressed` | `(action: String, item: Dictionary)` | Player taps **Sell / Equip / Listing / Delete**. `action` is the button's `key`. |
| `selection_changed` | `(item_id: String)` | The selected inventory slot changes. |
| `inventory.slot_selected` | `(index: int, item: Dictionary)` | On the `InventoryPanel` (see below). |

```gdscript
ui.buy_requested.connect(_on_buy)
ui.action_pressed.connect(_on_action)
ui.selection_changed.connect(func(id): print("Selected: ", id))
```

> Buying a shop item emits `buy_requested(item_id)` **only**. If you want the item to
> automatically move into the inventory, see the demo pattern in `shop_boot.gd`.

### Working with the InventoryPanel directly
```gdscript
var inv: InventoryPanel = ui.get_inventory()
inv.slot_selected.connect(func(idx, item): print(idx, " -> ", item))
# inv.slot_selected is a pre-defined signal on the panel
```

---

## ON / OFF toggles via config

```jsonc
"shop":      { "enabled": true },   // set false to hide the shop (inventory-only app)
"inventory": { "enabled": true }    // set false to hide the inventory (shop-only app)
```

---

## Item data format

Each item can use any of these fields:

```jsonc
{
  "id": "sword_1",
  "name": "Iron Sword",
  "price": 85.0,
  "image_url": "res://icon.png",
  "category": "weapon",          // matches a category tab; filters the grid
  "count": 1,                    // stack size (shown bottom-right when > 1)
  "description": "Dmg 25, crit 10%",  // shown in the item-info frame when selected

  // --- base weapon fields (optional) ---
  "level": 5,                    // shown as "Lv 5" on the inventory slot
  "damage": 25,                  // base damage (shown in the selected-item frame)
  "rarity": "epic",              // "common"/"uncommon"/"rare"/"epic"/"legendary"
  "stats": ["+5 dmg", "+3% crit"], // stat/affix lines

  // --- action buttons (optional) ---
  "disabled_actions": ["equip"]  // grey out these buttons for this item
}
```

### `disabled_actions` — grey out action buttons per item
The 4 action buttons (**Sell / Equip / Listing / Delete**) are **always visible** and
float at the bottom of the selected-item frame, so the frame never changes size.
For each item you can grey out specific buttons by listing their keys:

```jsonc
{ "id": "swd", "name": "Iron Sword", "disabled_actions": ["equip"] }  // Equip greyed
{ "id": "gem", "name": "Ruby Gem",   "disabled_actions": ["equip", "sell"] } // two greyed
```

When **no item is selected**, all 4 buttons are greyed out automatically.

> **Rarity** drives the slot background color and the selected-item frame tint.
> If `rarity` is omitted it is **auto-derived from the number of `stats` lines**:
> 0–1 → common, 2 → uncommon, 3 → rare, 4 → epic, 5+ → legendary.
> Tint colors are editable under `ui_theme.inventory.rarities`.

> **No icon? No problem.** If `image_url` is empty, missing, or the file isn't found,
> the item automatically shows a built-in **default item image**
> (`textures.default_item` in `ui_theme`, default
> `res://addons/quickmarket_ui/assets/default_item.png`). Replace that PNG with your
> own to change the placeholder everywhere.

---

## Theming (edit config only — no code)

Everything is in the **`ui_theme`** block of `marketplace_config.json`:

- **Shop:** `colors.background`, `item_card_bg`, `item_card_border`, `selected_item`,
  `button`, `button_hover`, `button_pressed`, `text_*`; `corner_radius`; `texts.*`.
  **Shop categories:** `shop.categories.list` (e.g. `["weapon","armor","item","other"]`),
  `shop.categories.width`, `shop.categories.colors.*` — a category column on the left
  filters the shop grid, just like the inventory.
- **Inventory:** `inventory.colors.*` (background, slot, slot_border, selected_slot,
  header, count), `inventory.texts.header_title`,
  `inventory.columns` / `slot_size` / `slot_radius` / `rows_visible` / `header_height`.
- **Selected-item frame:** `header_height` (fixed frame height — currently 128, big
  enough for the item info **plus** the action buttons floating at its bottom).
- **Categories:** `inventory.categories.list` (e.g. `["weapon","armor","item","other"]`),
  `inventory.categories.colors.*`, `inventory.categories.width`.
- **Action buttons:** `inventory.actions.list` (each `{"key": "...", "text": "..."}`),
  `inventory.actions.colors.*` (`bg`, `bg_hover`, `bg_pressed`, `bg_disabled`, `text`,
  `text_disabled`), `inventory.actions.height`.
- **Layout (fixed screen halves):** `layout.shop_height_ratio` and
  `layout.inventory_height_ratio` set each section's height as a fraction of the screen —
  shop on top, inventory on the bottom. The middle is left free for your own HUD.
  Example: `0.45` / `0.45` leaves 10% in the middle.
  `layout.shop_z_index` / `layout.inventory_z_index` control draw order.
- **Portrait / Landscape:** `layout.orientation` (`"portrait"` default). In **portrait**
  shop is on top and inventory on the bottom. In **landscape** shop is on the **left**
  and inventory on the **right** (`layout.inventory_width_ratio`, default 0.45, sets the
  right column width). Hide the toggle button with `layout.show_orientation_button: false`.

---

## Testing guide (for new developers)

### Run the demo
- Open `ShopMain.tscn` (if you created it) and press **F5**.
- Expect a portrait screen: shop grid on top, inventory (tabs + slots) at the bottom.

### Click-through checklist
| Test | How | Expected |
|------|-----|----------|
| **Buy** | Tap a card's Buy | Card disappears; item appears in the inventory. Same-name items stack. |
| **Select** | Tap a slot | Slot highlights; item-info frame shows name + description + action buttons. |
| **Greyed buttons** | Select an item with `disabled_actions` | Those buttons appear dim/greyed; others stay active. |
| **Filter** | Tap a category tab | Grid filters to that category; active tab highlighted. |
| **Keep selection** | Select a weapon, then "armor" | Frame still shows the weapon's info; back to "all" → re-selected. |
| **Actions** | With an item selected, tap **Sell** | Console prints `Item action: sell -> <name>` (asset only emits the signal). |
| **Stack count** | Item with `count > 1` | Number shown bottom-right of the slot. |
| **Fixed frame** | Select items with/without description | The item-info frame height never changes (no jumping). |

### Prove it's config-driven
Edit `res://marketplace_config.json` → `ui_theme`, re-run (F5), no code edits:
- `colors.button` → shop Buy button color.
- `inventory.colors.selected_slot` → selection highlight color.
- `inventory.actions.list` texts → action button labels.

---

## Folder layout

| Path | Purpose |
|------|---------|
| `scripts/quick_market_ui.gd` | **The reusable component** — add it to your scene. |
| `scripts/shop_screen.gd` | The shop grid (cards + Buy). |
| `scripts/item_card.gd` | One item card (icon, name, price, Buy). |
| `scripts/inventory_panel.gd` | Inventory: slots, counts, category tabs, item-info frame + action buttons. |
| `scripts/shop_theme.gd` | Reads the config → styleboxes/colors (deep-merges defaults). |
| `scripts/shop_boot.gd` | Demo bootstrap (populates shop + inventory). |
| `demo/QuickMarketUI.tscn` | The component as a scene — drag into your own scene. |
| `demo/ShopMain.tscn` | Optional full demo scene (preview only). |
| `config/marketplace_config.json` | Default config template. |
| `assets/` | Demo item icons + `default_item.png` fallback. |
