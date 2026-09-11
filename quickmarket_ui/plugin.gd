@tool
extends EditorPlugin
## Adds a Project > Tools menu action to drop a QuickMarket demo shop scene
## (and its config template) into the project. The shop + inventory are fully
## styled from marketplace_config.json — no code changes needed to restyle.

const ADDON := "res://addons/quickmarket_ui"
const DEMO_SCENE := "res://addons/quickmarket_ui/demo/ShopMain.tscn"
const CONFIG_TEMPLATE := "res://addons/quickmarket_ui/config/marketplace_config.json"
const TARGET_SCENE := "res://ShopMain.tscn"
const TARGET_CONFIG := "res://marketplace_config.json"


func _enter_tree() -> void:
	add_tool_menu_item("SMarket: Create Demo Shop", _create_demo_shop)


func _exit_tree() -> void:
	remove_tool_menu_item("SMarket: Create Demo Shop")


func _create_demo_shop() -> void:
	if not FileAccess.file_exists(TARGET_SCENE):
		DirAccess.copy_absolute(DEMO_SCENE, TARGET_SCENE)
	if not FileAccess.file_exists(TARGET_CONFIG) and FileAccess.file_exists(CONFIG_TEMPLATE):
		DirAccess.copy_absolute(CONFIG_TEMPLATE, TARGET_CONFIG)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(TARGET_SCENE)
