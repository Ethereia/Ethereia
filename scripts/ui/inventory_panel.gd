## 背包面板（阶段3→5）：I 键开关列表 + 选中使用（丹药/功法残页走 EffectResolver 分发）
extends Control

@onready var _item_list: ItemList = $Panel/VBox/ItemList
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _use_button: Button = $Panel/VBox/UseButton


func _ready() -> void:
	visible = false
	EventBus.item_added.connect(_on_items_changed)
	EventBus.item_removed.connect(_on_items_changed)
	_use_button.pressed.connect(_on_use_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		if visible:
			_refresh()


func _get_selected_item_id() -> String:
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		return ""
	var text := _item_list.get_item_text(selected[0])  # "名称 ×N"——不含 id，需按序号映射
	return _visible_ids[selected[0]] if selected[0] < _visible_ids.size() else ""


## 与 _refresh 刷新顺序对齐的 id 列表（ItemList 不存 id，用并行数组）
var _visible_ids: Array[String] = []


func _on_use_pressed() -> void:
	var item_id := _get_selected_item_id()
	if item_id.is_empty():
		return
	var data := DataManager.get_entry("items", item_id) as ItemData
	if data == null:
		return
	if not (data.item_type == ItemData.ItemType.PILL or data.item_type == ItemData.ItemType.TECHNIQUE_PAGE):
		print("[Inventory] %s 不可使用" % data.display_name)
		return
	# 使用：先结算效果再扣数量（效果分发走 EffectResolver 统一路径）
	var managers := get_tree().get_nodes_in_group("inventory_manager")
	if managers.is_empty():
		return
	EffectResolver.apply_all(data.effects, self)
	managers[0].inventory.remove_item(item_id, 1)
	print("[Inventory] 使用了 %s" % data.display_name)
	_refresh()


func _on_items_changed(_item_id: String, _count: int) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_item_list.clear()
	_visible_ids.clear()
	var managers := get_tree().get_nodes_in_group("inventory_manager")
	if managers.is_empty():
		return
	var items: Dictionary = managers[0].inventory.items
	var total := 0
	for item_id: String in items:
		var data := DataManager.get_entry("items", item_id) as ItemData
		var display_name: String = data.display_name if data != null else item_id
		_item_list.add_item("%s ×%d" % [display_name, int(items[item_id])])
		_visible_ids.append(item_id)
		total += 1
	if total == 0:
		_item_list.add_item("（空空如也）")
	_title_label.text = "背包（%d 种）" % total
