class_name ItemCard
extends PanelContainer
## A single themeable shop item card: icon, name, price and a Buy button.
## All visuals come from the ui_theme Dictionary (marketplace_config.json).

signal card_selected(card)
## Emitted when the card's action button is pressed.
## [action] is one of: "buy" (shop) | "claim" (in_cart) | "cancel" (own listing).
signal action_pressed(action: String, card)

const ACTION_BUY := "buy"
const ACTION_CLAIM := "claim"
const ACTION_CANCEL := "cancel"

var item := {}
var ui_theme := {}
var _selected := false

var _icon: TextureRect
var _name_label: Label
var _author_label: Label
var _price_label: Label


## The action this card performs, based on the item's "_cart_type" marker.
func action_type() -> String:
	match str(item.get("_cart_type", "")):
		"in_cart": return ACTION_CLAIM
		"listing": return ACTION_CANCEL
		_: return ACTION_BUY


func _action_label(action: String) -> String:
	var texts: Dictionary = ui_theme.get("texts", {})
	match action:
		ACTION_CLAIM:  return texts.get("claim_button", "Claim")
		ACTION_CANCEL: return texts.get("cancel_button", "Cancel")
		_:             return texts.get("buy_button", "Buy")


func setup(data: Dictionary, t: Dictionary) -> void:
	item = data
	ui_theme = t
	_build()
	refresh()


func set_selected(selected: bool) -> void:
	_selected = selected
	add_theme_stylebox_override("panel", ShopTheme.card_style(ui_theme, selected))


func _build() -> void:
	custom_minimum_size = Vector2(0, 186)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_selected(false)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(0, 76)
	v.add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_name"))
	_name_label.add_theme_font_size_override("font_size", 14)
	v.add_child(_name_label)

	# Người bán (author/seller_id của listing)
	_author_label = Label.new()
	_author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_author_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_author_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_author_label.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_subtitle"))
	_author_label.add_theme_font_size_override("font_size", 11)
	v.add_child(_author_label)

	_price_label = Label.new()
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_price"))
	_price_label.add_theme_font_size_override("font_size", 15)
	v.add_child(_price_label)

	var act: String = action_type()
	var btn := Button.new()
	btn.text = _action_label(act)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_stylebox_override("normal", ShopTheme.button_style(ui_theme, "button"))
	btn.add_theme_stylebox_override("hover", ShopTheme.button_style(ui_theme, "button_hover"))
	btn.add_theme_stylebox_override("pressed", ShopTheme.button_style(ui_theme, "button_pressed"))
	btn.add_theme_color_override("font_color", ShopTheme.color(ui_theme, "text_title"))
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): action_pressed.emit(act, self))
	v.add_child(btn)

	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_selected.emit(self)


func refresh() -> void:
	if _name_label == null:
		return
	_name_label.text = item.get("name", "Item")
	_price_label.text = "%s%.2f" % [ui_theme.get("texts", {}).get("price_prefix", "$"), float(item.get("price", 0.0))]
	_icon.texture = ShopTheme.item_icon(ui_theme, item)
	# tint the item name by its rarity
	_name_label.add_theme_color_override("font_color", ShopTheme.rarity_color(ui_theme, ShopTheme.rarity_key(item)).lightened(0.25))

	# Người bán: chỉ hiện khi có author
	var author: String = str(item.get("author", "")).strip_edges()
	var prefix: String = ui_theme.get("texts", {}).get("author_prefix", "by")
	_author_label.visible = author != ""
	_author_label.text = "%s %s" % [prefix, author] if author != "" else ""
