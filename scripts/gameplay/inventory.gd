## 背包容器（阶段3）：纯数据 {item_id: count}，无节点依赖
## 静态定义（名称/图标）由 DataManager 按 id 重建（doc 16），容器只存数量
class_name Inventory
extends RefCounted

var items: Dictionary = {}  # {item_id: count}


func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + count
	EventBus.item_added.emit(item_id, count)


func remove_item(item_id: String, count: int = 1) -> bool:
	var have := int(items.get(item_id, 0))
	if count <= 0 or have < count:
		return false
	items[item_id] = have - count
	if items[item_id] <= 0:
		items.erase(item_id)
	EventBus.item_removed.emit(item_id, count)
	return true


func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))


func has_item(item_id: String, count: int = 1) -> bool:
	return get_count(item_id) >= count
