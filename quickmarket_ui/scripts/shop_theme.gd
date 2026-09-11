class_name ShopTheme
## Reads the "ui_theme" block from marketplace_config.json and turns it into
## Godot styleboxes/colors. Developers restyle the whole shop by editing that
## JSON file only — no code changes needed.

const DEFAULT_ITEM_IMAGE := "res://addons/quickmarket_ui/assets/default_item.png"

const DEFAULT := {
	"colors": {
		"background": "#1b1c31",
		"item_card_bg": "#26294d",
		"item_card_border": "#3d426b",
		"selected_item": "#4f46e5",
		"button": "#e94560",
		"button_hover": "#ff6b81",
		"button_pressed": "#b3364d",
		"text_title": "#ffffff",
		"text_name": "#eef0ff",
		"text_price": "#ffd166",
		"text_subtitle": "#9aa1c9"
	},
	"corner_radius": 14,
	"shop": {
		"enabled": true
	},
	"inventory": {
		"enabled": true,
		"rarities": {
			"common":    { "color": "#c8ccd8" },
			"uncommon":  { "color": "#3ddc84" },
			"rare":      { "color": "#3d8bff" },
			"epic":      { "color": "#b45cff" },
			"legendary": { "color": "#ff9f43" }
		}
	},
	"textures": {
		"background": "",
		"item_card": "",
		"selected_item": "",
		"button": "",
		"default_item": "res://addons/quickmarket_ui/assets/default_item.png"
	},
	"texts": {
		"title": "Shop",
		"buy_button": "Buy",
		"price_prefix": "$",
		"empty_message": "No items available",
		"your_listings": "Your Listings"
	}
}


static func from_config(path := "res://marketplace_config.json") -> Dictionary:
	var cfg := load_config(path)
	var theme: Dictionary = cfg.get("ui_theme", {})
	return merge(DEFAULT, theme)


static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


static func merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var out := {}
	for k in base:
		out[k] = base[k]
	for k in override:
		var bv = out.get(k)
		var ov = override[k]
		if typeof(bv) == TYPE_DICTIONARY and typeof(ov) == TYPE_DICTIONARY:
			out[k] = merge(bv, ov)
		else:
			out[k] = ov
	return out


static func color(theme: Dictionary, key: String) -> Color:
	var hex: String = theme.get("colors", {}).get(key, "#ffffff")
	return Color(hex)


## Resolve an item's rarity tier key. Uses the explicit "rarity" field if given,
## otherwise derives it from the number of stat/affix lines the item has
## (more lines = higher rarity).
static func rarity_key(item: Dictionary) -> String:
	var r: String = str(item.get("rarity", ""))
	if r != "":
		return r
	var n: int = int(item.get("stats", []).size())
	if n >= 5:
		return "legendary"
	if n >= 4:
		return "epic"
	if n >= 3:
		return "rare"
	if n >= 2:
		return "uncommon"
	return "common"


## Rarity color for a tier key. Uses ui_theme.inventory.rarities if configured,
## otherwise falls back to a built-in palette so rarity colors always work in
## any project, even without a config file.
static func rarity_color(theme: Dictionary, key: String) -> Color:
	var rar: Dictionary = theme.get("inventory", {}).get("rarities", {})
	if rar.has(key):
		return Color(rar.get(key, {}).get("color", "#c8ccd8"))
	var fallback := {
		"common": "#c8ccd8", "uncommon": "#3ddc84", "rare": "#3d8bff",
		"epic": "#b45cff", "legendary": "#ff9f43"
	}
	return Color(fallback.get(key, "#c8ccd8"))


static func card_style(theme: Dictionary, selected := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var colors: Dictionary = theme.get("colors", {})
	var bg_key := "selected_item" if selected else "item_card_bg"
	sb.bg_color = Color(colors.get(bg_key, "#26294d"))
	sb.border_color = Color(colors.get("item_card_border", "#3d426b"))
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(int(theme.get("corner_radius", 12)))
	sb.set_content_margin_all(10)
	return sb


static func background_style(theme: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(theme, "background")
	return sb


static func button_style(theme: Dictionary, color_key: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(theme, color_key)
	sb.set_corner_radius_all(int(theme.get("corner_radius", 12)))
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


## Resolve an item's icon texture. If the item has no image_url, or the file
## does not exist / fails to load, fall back to the default base item image
## (ui_theme.textures.default_item), so a placeholder is always shown.
static func item_icon(theme: Dictionary, item: Dictionary) -> Texture2D:
	var icon_path: String = item.get("image_url", "")
	if icon_path != "" and FileAccess.file_exists(icon_path):
		var t: Texture2D = load(icon_path)
		if t != null:
			return t
	var def: String = theme.get("textures", {}).get("default_item", DEFAULT_ITEM_IMAGE)
	if def != "" and FileAccess.file_exists(def):
		var d: Texture2D = load(def)
		if d != null:
			return d
	return null
