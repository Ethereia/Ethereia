## 背包面板（阶段3）：I 键开关的简单列表（物品名×数量），只读不暂停世界
extends Control

@onready var _item_list: ItemList = $Panel/VBox/ItemList
@onready var _title_label: Label = $Panel/VBox/TitleLabel


func _ready() -> void:
	visible = false
	EventBus.item_added.connect(_on_items_changed)
	EventBus.item_removed.connect(_on_items_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		if visible:
			_refresh()


func _on_items_changed(_item_id: String, _count: int) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_item_list.clear()
	var managers := get_tree().get_nodes_in_group("inventory_manager")
	if managers.is_empty():
		return
	var items: Dictionary = managers[0].inventory.items
	var total := 0
	for item_id: String in items:
		var data := DataManager.get_entry("items", item_id) as ItemData
		var name := data.display_name if data else item_id
		_item_list.add_item("%s ×%d" % [name, int(items[item_id])])
		total += 1
	if total == 0:
		_item_list.add_item("（空空如也）")
	_title_label.text = "背包（%d 种）" % total
